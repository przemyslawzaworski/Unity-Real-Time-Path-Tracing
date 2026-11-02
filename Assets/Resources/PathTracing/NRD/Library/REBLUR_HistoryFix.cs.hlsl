/*
Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto. Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#include "NRD.hlsli"
#include "ml.hlsli"

#include "REBLUR_Config.hlsli"
#include "REBLUR_HistoryFix.resources.hlsli"

#include "Common.hlsli"

#include "REBLUR_Common.hlsli"

groupshared float s_DiffLuma[ BUFFER_Y ][ BUFFER_X ];
groupshared float s_SpecLuma[ BUFFER_Y ][ BUFFER_X ];

void Preload( uint2 sharedPos, int2 globalPos )
{
    globalPos = clamp( globalPos, 0, gRectSizeMinusOne );

    float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, globalPos ) );

    #if( NRD_HAS_DIFF )
        float diffFast = NRD_SURFACE( gIn_DiffFast, globalPos );
        s_DiffLuma[ sharedPos.y ][ sharedPos.x ] = !IsInDenoisingRange( viewZ ) ? REBLUR_INVALID : diffFast;
    #endif

    #if( NRD_HAS_SPEC )
        float specFast = NRD_SURFACE( gIn_SpecFast, globalPos );
        s_SpecLuma[ sharedPos.y ][ sharedPos.x ] = !IsInDenoisingRange( viewZ ) ? REBLUR_INVALID : specFast;
    #endif
}

[numthreads( GROUP_X, GROUP_Y, 1 )]
NRD_EXPORT void NRD_CS_MAIN( NRD_CS_MAIN_ARGS )
{
    NRD_CTA_ORDER_REVERSED;

    float isSky = NRD_SURFACE( gIn_Tiles, pixelPos >> 4 ).x;
    PRELOAD_INTO_SMEM_WITH_TILE_CHECK;

    if( isSky != 0.0 )
        return;

    int2 clampedPixelPos = min( pixelPos, gRectSizeMinusOne );
    REBLUR_DATA1_TYPE frameNum = UnpackData1( NRD_SURFACE( gIn_Data1, clampedPixelPos ) );

    float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, clampedPixelPos ) );
    frameNum = !IsInDenoisingRange( viewZ ) ? REBLUR_MAX_ACCUM_FRAME_NUM : frameNum;

    float2 stride = float2( frameNum < gHistoryFixFrameNum );
    #if( NRD_SUPPORTS_QUAD_INTRINSICS == 1 )
    {

        float2 d10 = QuadReadAcrossX( stride );
        float2 d01 = QuadReadAcrossY( stride );

        float2 avg = ( d10 + d01 + stride ) / 3.0;
        stride = min( stride, avg );
    }
    #endif

    if( !IsInDenoisingRange( viewZ ) || any( pixelPos > gRectSizeMinusOne ) )
        return;

    float materialID;
    float4 normalAndRoughness = NRD_FrontEnd_UnpackNormalAndRoughness( NRD_SURFACE( gIn_Normal_Roughness, pixelPos ), materialID );
    float3 N = normalAndRoughness.xyz;
    float roughness = normalAndRoughness.w;

    float frustumSize = GetFrustumSize( gMinRectDimMulUnproject, gOrthoMode, viewZ );
    float2 pixelUv = float2( pixelPos + 0.5 ) * gRectSizeInv;
    float3 Xv = Geometry::ReconstructViewPosition( pixelUv, gFrustum, viewZ, gOrthoMode );
    float3 Nv = Geometry::RotateVectorInverse( gViewToWorld, N );
    float3 Vv = GetViewVector( Xv, true );
    float NoV = abs( dot( Nv, Vv ) );

    int2 smemPos = threadPos + NRD_BORDER;

    float invHistoryFixFrameNum = 1.0 / max( gHistoryFixFrameNum, NRD_EPS );
    float2 frameNumAvgNorm = saturate( frameNum * invHistoryFixFrameNum );

    stride /= 1.0 + 1.0;
    stride *= 2.0 / REBLUR_HISTORY_FIX_FILTER_RADIUS;
    stride *= materialID == gHistoryFixAlternatePixelStrideMaterialID ? gHistoryFixAlternatePixelStride : gHistoryFixBasePixelStride;

    #if( NRD_HAS_DIFF )
    {
        REBLUR_TYPE diff = NRD_SURFACE( gIn_Diff, pixelPos );
        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE diffSh = NRD_SURFACE( gIn_DiffSh, pixelPos );
        #endif

        float diffNonLinearAccumSpeed = 1.0 / ( 1.0 + frameNum.x );

        float hitDistScale = _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, 1.0 );
        float hitDist = ExtractHitDist( diff ) * hitDistScale;
        float hitDistFactor = GetHitDistFactor( hitDist, frustumSize );
        hitDist = ExtractHitDist( diff );

        stride.x *= lerp( 0.25 + 0.75 * Math::Sqrt01( hitDistFactor ), 1.0, diffNonLinearAccumSpeed );
        stride.x = round( stride.x );

        if( stride.x != 0.0 )
        {

            float normalWeightParam = GetNormalWeightParam( diffNonLinearAccumSpeed, gLobeAngleFraction );
            float2 geometryWeightParams = GetGeometryWeightParams( gPlaneDistSensitivity, frustumSize, Xv, Nv );
            float2 hitDistanceWeightParams = GetHitDistanceWeightParams( hitDist, diffNonLinearAccumSpeed );

            float sumd = 1.0 + frameNum.x;
            #if( REBLUR_PERFORMANCE_MODE == 1 )
                sumd = 1.0 + 1.0 / ( 1.0 + gMaxAccumulatedFrameNum ) - diffNonLinearAccumSpeed;
            #endif

            diff *= sumd;
            #if( NRD_MODE == NRD_MODE_SH )
                diffSh *= sumd;
            #endif

            [unroll]
            for( j = -REBLUR_HISTORY_FIX_FILTER_RADIUS; j <= REBLUR_HISTORY_FIX_FILTER_RADIUS; j++ )
            {
                [unroll]
                for( i = -REBLUR_HISTORY_FIX_FILTER_RADIUS; i <= REBLUR_HISTORY_FIX_FILTER_RADIUS; i++ )
                {

                    if( i == 0 && j == 0 )
                        continue;

                    if( abs( i ) + abs( j ) == REBLUR_HISTORY_FIX_FILTER_RADIUS * 2 )
                        continue;

                    float2 uv = pixelUv + float2( i, j ) * stride.x * gRectSizeInv;

                    uv = MirrorUv( uv );

                    int2 pos = int2( uv * gRectSize );

                    float zs = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, pos ) );
                    float3 Xvs = Geometry::ReconstructViewPosition( uv, gFrustum, zs, gOrthoMode );

                    float materialIDs;
                    float4 Ns = NRD_SURFACE( gIn_Normal_Roughness, pos );
                    Ns = NRD_FrontEnd_UnpackNormalAndRoughness( Ns, materialIDs );

                    float angle = Math::AcosApproxPositive( dot( Ns.xyz, N ) );
                    float NoX = dot( Nv, Xvs );

                    float w = float( CompareMaterials( materialID, materialIDs, gDiffMinMaterial ) );
                    w *= ComputeExponentialWeight( angle, normalWeightParam, 0.0 );

                    #if( REBLUR_PERFORMANCE_MODE == 0 )
                        w *= 1.0 + UnpackData1( NRD_SURFACE( gIn_Data1, pos ) ).x;
                    #endif

                    w = ApplyGeometryWeightLast( w, zs, NoX, geometryWeightParams );

                    REBLUR_TYPE s = NRD_SURFACE( gIn_Diff, pos );
                    s = Denanify( w, s );

                    w *= ComputeExponentialWeight( ExtractHitDist( s ), hitDistanceWeightParams.x, hitDistanceWeightParams.y );

                    sumd += w;

                    diff += s * w;
                    #if( NRD_MODE == NRD_MODE_SH )
                        REBLUR_SH_TYPE sh = NRD_SURFACE( gIn_DiffSh, pos );
                        sh = Denanify( w, sh );

                        diffSh += sh * w;
                    #endif
                }
            }

            sumd = Math::PositiveRcp( sumd );
            diff *= sumd;
            #if( NRD_MODE == NRD_MODE_SH )
                diffSh *= sumd;
            #endif
        }

        float diffLuma = GetLuma( diff );

        float f = frameNumAvgNorm.x;

        float diffFastCenter = s_DiffLuma[ smemPos.y ][ smemPos.x ];
        diffFastCenter = lerp( diffLuma, diffFastCenter, f );

        NRD_SURFACE( gOut_DiffFast, pixelPos ) = diffFastCenter;

        float diffFastM1 = diffFastCenter;
        float diffFastM2 = diffFastCenter * diffFastCenter;
        float diffAntiFireflyM1 = 0;
        float diffAntiFireflyM2 = 0;

        [unroll]
        for( j = -NRD_BORDER; j <= NRD_BORDER; j++ )
        {
            [unroll]
            for( i = -NRD_BORDER; i <= NRD_BORDER; i++ )
            {
                if( i == 0 && j == 0 )
                    continue;

                int2 pos = smemPos + int2( i, j );

                float d = s_DiffLuma[ pos.y ][ pos.x ];
                d = d == REBLUR_INVALID ? diffFastCenter : d;

                if( abs( i ) <= REBLUR_FAST_HISTORY_CLAMPING_RADIUS && abs( j ) <= REBLUR_FAST_HISTORY_CLAMPING_RADIUS )
                {
                    diffFastM1 += d;
                    diffFastM2 += d * d;
                }

                if( NRD_SUPPORTS_ANTIFIREFLY == 1 && !( abs( i ) <= 1 && abs( j ) <= 1 ) )
                {
                    diffAntiFireflyM1 += d;
                    diffAntiFireflyM2 += d * d;
                }
            }
        }

        if( NRD_SUPPORTS_ANTIFIREFLY == 1 && gAntiFirefly != 0.0 )
        {
            float invNorm = 1.0 / ( ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 ) - 3 * 3 );
            diffAntiFireflyM1 *= invNorm;
            diffAntiFireflyM2 *= invNorm;

            float diffAntiFireflySigma = GetStdDev( diffAntiFireflyM1, diffAntiFireflyM2 ) * REBLUR_ANTI_FIREFLY_SIGMA_SCALE;

            diffLuma = clamp( diffLuma, diffAntiFireflyM1 - diffAntiFireflySigma, diffAntiFireflyM1 + diffAntiFireflySigma );
        }

        {
            float invNorm = 1.0 / ( ( REBLUR_FAST_HISTORY_CLAMPING_RADIUS * 2 + 1 ) * ( REBLUR_FAST_HISTORY_CLAMPING_RADIUS * 2 + 1 ) );
            diffFastM1 *= invNorm;
            diffFastM2 *= invNorm;

            float diffFastSigma = GetStdDev( diffFastM1, diffFastM2 ) * gFastHistoryClampingSigmaScale;
            float diffLumaClamped = clamp( diffLuma, diffFastM1 - diffFastSigma, diffFastM1 + diffFastSigma );

            diffLuma = lerp( diffLumaClamped, diffLuma, 1.0 / ( 1.0 + float( gMaxFastAccumulatedFrameNum < gMaxAccumulatedFrameNum ) * frameNum.x * 2.0 ) );
        }

        #if( REBLUR_SHOW == REBLUR_SHOW_FAST_HISTORY )
            diffLuma = diffFastCenter;
        #endif

        #if( NRD_MODE == NRD_MODE_SH )
            diffSh *= GetLumaScale( GetLuma( diff ), diffLuma );
        #endif
        diff = ChangeLuma( diff, diffLuma );

        NRD_SURFACE( gOut_Diff, pixelPos ) = diff;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_DiffSh, pixelPos ) = diffSh;
        #endif
    }
    #endif

    #if( NRD_HAS_SPEC )
    {
        REBLUR_TYPE spec = NRD_SURFACE( gIn_Spec, pixelPos );
        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE specSh = NRD_SURFACE( gIn_SpecSh, pixelPos );
        #endif

        float smc = GetSpecMagicCurve( roughness );
        float specNonLinearAccumSpeed = 1.0 / ( 1.0 + frameNum.y );

        float hitDistScale = _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, roughness );
        float hitDist = ExtractHitDist( spec ) * hitDistScale;
        #if( NRD_MODE != NRD_MODE_OCCLUSION )

            hitDist = lerp( NRD_SURFACE( gIn_SpecHitDistForTracking, pixelPos ), hitDist, smc );
        #endif
        float hitDistFactor = GetHitDistFactor( hitDist, frustumSize );
        hitDist = saturate( hitDist / hitDistScale );

        stride.y *= lerp( 0.25 + 0.75 * Math::Sqrt01( hitDistFactor ), 1.0, specNonLinearAccumSpeed );
        stride.y *= lerp( 0.25, 1.0, smc );
        stride.y = round( stride.y );

        if( stride.y != 0 )
        {

            float normalWeightParam = GetNormalWeightParam( specNonLinearAccumSpeed, gLobeAngleFraction, roughness );
            float2 geometryWeightParams = GetGeometryWeightParams( gPlaneDistSensitivity, frustumSize, Xv, Nv );
            float2 hitDistanceWeightParams = GetHitDistanceWeightParams( hitDist, specNonLinearAccumSpeed );
            float2 relaxedRoughnessWeightParams = GetRelaxedRoughnessWeightParams( roughness * roughness, sqrt( gRoughnessFraction ) );

            float sums = 1.0 + frameNum.y;
            #if( REBLUR_PERFORMANCE_MODE == 1 )
                sums = 1.0 + 1.0 / ( 1.0 + gMaxAccumulatedFrameNum ) - specNonLinearAccumSpeed;
            #endif

            spec *= sums;
            #if( NRD_MODE == NRD_MODE_SH )
                specSh *= sums;
            #endif

            [unroll]
            for( j = -REBLUR_HISTORY_FIX_FILTER_RADIUS; j <= REBLUR_HISTORY_FIX_FILTER_RADIUS; j++ )
            {
                [unroll]
                for( i = -REBLUR_HISTORY_FIX_FILTER_RADIUS; i <= REBLUR_HISTORY_FIX_FILTER_RADIUS; i++ )
                {

                    if( i == 0 && j == 0 )
                        continue;

                    if( abs( i ) + abs( j ) == REBLUR_HISTORY_FIX_FILTER_RADIUS * 2 )
                        continue;

                    float2 uv = pixelUv + float2( i, j ) * stride.y * gRectSizeInv;

                    uv = MirrorUv( uv );

                    int2 pos = int2( uv * gRectSize );

                    float zs = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, pos ) );
                    float3 Xvs = Geometry::ReconstructViewPosition( uv, gFrustum, zs, gOrthoMode );

                    float materialIDs;
                    float4 Ns = NRD_SURFACE( gIn_Normal_Roughness, pos );
                    Ns = NRD_FrontEnd_UnpackNormalAndRoughness( Ns, materialIDs );

                    float angle = Math::AcosApproxPositive( dot( Ns.xyz, N ) );
                    float NoX = dot( Nv, Xvs );

                    float w = float( CompareMaterials( materialID, materialIDs, gSpecMinMaterial ) );
                    w *= ComputeExponentialWeight( angle, normalWeightParam, 0.0 );
                    w *= ComputeExponentialWeight( Ns.w * Ns.w, relaxedRoughnessWeightParams.x, relaxedRoughnessWeightParams.y );

                    #if( REBLUR_PERFORMANCE_MODE == 0 )
                        w *= 1.0 + UnpackData1( NRD_SURFACE( gIn_Data1, pos ) ).y;
                    #endif

                    w = ApplyGeometryWeightLast( w, zs, NoX, geometryWeightParams );

                    REBLUR_TYPE s = NRD_SURFACE( gIn_Spec, pos );
                    s = Denanify( w, s );

                    w *= ComputeExponentialWeight( ExtractHitDist( s ), hitDistanceWeightParams.x, hitDistanceWeightParams.y );

                    sums += w;

                    spec += s * w;
                    #if( NRD_MODE == NRD_MODE_SH )
                        REBLUR_SH_TYPE sh = NRD_SURFACE( gIn_SpecSh, pos );
                        sh = Denanify( w, sh );

                        specSh += sh * w;
                    #endif
                }
            }

            sums = Math::PositiveRcp( sums );
            spec *= sums;
            #if( NRD_MODE == NRD_MODE_SH )
                specSh *= sums;
            #endif
        }

        float specLuma = GetLuma( spec );

        float f = frameNumAvgNorm.y;
        f = lerp( 1.0, f, smc );

        float specFastCenter = s_SpecLuma[ smemPos.y ][ smemPos.x ];
        specFastCenter = lerp( specLuma, specFastCenter, f );

        NRD_SURFACE( gOut_SpecFast, pixelPos ) = specFastCenter;

        float specFastM1 = specFastCenter;
        float specFastM2 = specFastCenter * specFastCenter;
        float specAntiFireflyM1 = 0;
        float specAntiFireflyM2 = 0;

        [unroll]
        for( j = -NRD_BORDER; j <= NRD_BORDER; j++ )
        {
            [unroll]
            for( i = -NRD_BORDER; i <= NRD_BORDER; i++ )
            {
                if( i == 0 && j == 0 )
                    continue;

                int2 pos = smemPos + int2( i, j );

                float s = s_SpecLuma[ pos.y ][ pos.x ];
                s = s == REBLUR_INVALID ? specFastCenter : s;

                if( abs( i ) <= REBLUR_FAST_HISTORY_CLAMPING_RADIUS && abs( j ) <= REBLUR_FAST_HISTORY_CLAMPING_RADIUS )
                {
                    specFastM1 += s;
                    specFastM2 += s * s;
                }

                if( NRD_SUPPORTS_ANTIFIREFLY == 1 && !( abs( i ) <= 1 && abs( j ) <= 1 ) )
                {
                    specAntiFireflyM1 += s;
                    specAntiFireflyM2 += s * s;
                }
            }
        }

        if( NRD_SUPPORTS_ANTIFIREFLY == 1 && gAntiFirefly != 0.0 )
        {
            float invNorm = 1.0 / ( ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 ) - 3 * 3 );
            specAntiFireflyM1 *= invNorm;
            specAntiFireflyM2 *= invNorm;

            float specAntiFireflySigma = GetStdDev( specAntiFireflyM1, specAntiFireflyM2 ) * REBLUR_ANTI_FIREFLY_SIGMA_SCALE;

            specLuma = clamp( specLuma, specAntiFireflyM1 - specAntiFireflySigma, specAntiFireflyM1 + specAntiFireflySigma );
        }

        {
            float invNorm = 1.0 / ( ( REBLUR_FAST_HISTORY_CLAMPING_RADIUS * 2 + 1 ) * ( REBLUR_FAST_HISTORY_CLAMPING_RADIUS * 2 + 1 ) );
            specFastM1 *= invNorm;
            specFastM2 *= invNorm;

            float fastHistoryClampingSigmaScale = gFastHistoryClampingSigmaScale;
            if( materialID == gStrandMaterialID )
                fastHistoryClampingSigmaScale = max( fastHistoryClampingSigmaScale, 3.0 );

            float specFastSigma = GetStdDev( specFastM1, specFastM2 ) * fastHistoryClampingSigmaScale;
            float specLumaClamped = clamp( specLuma, specFastM1 - specFastSigma, specFastM1 + specFastSigma );

            specLuma = lerp( specLumaClamped, specLuma, 1.0 / ( 1.0 + float( gMaxFastAccumulatedFrameNum < gMaxAccumulatedFrameNum ) * frameNum.y * 2.0 ) );
        }

        #if( REBLUR_SHOW == REBLUR_SHOW_FAST_HISTORY )
            specLuma = specFastCenter;
        #endif

        #if( NRD_MODE == NRD_MODE_SH )
            specSh *= GetLumaScale( GetLuma( spec ), specLuma );
        #endif
        spec = ChangeLuma( spec, specLuma );

        NRD_SURFACE( gOut_Spec, pixelPos ) = spec;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_SpecSh, pixelPos ) = specSh;
        #endif
    }
    #endif
}
