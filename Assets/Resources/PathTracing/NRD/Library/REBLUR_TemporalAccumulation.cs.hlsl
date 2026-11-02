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
#include "REBLUR_TemporalAccumulation.resources.hlsli"

#include "Common.hlsli"

#include "REBLUR_Common.hlsli"

groupshared float4 s_Normal_HitDistForTracking[ BUFFER_Y ][ BUFFER_X ];

float2 StochasticBilinear( float2 uv, float2 texSize )
{
    #if( REBLUR_USE_STF == 1 && NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )

        Filtering::Bilinear f = Filtering::GetBilinearFilter( uv, texSize );

        float2 rnd = Rng::Hash::GetFloat2( );
        f.origin += step( rnd, f.weights );

        return ( f.origin + 0.5 ) / texSize;
    #else
        return uv;
    #endif
}

void Preload( uint2 sharedPos, int2 globalPos )
{
    globalPos = clamp( globalPos, 0, gRectSizeMinusOne );

    float3 N = NRD_FrontEnd_UnpackNormalAndRoughness( NRD_SURFACE( gIn_Normal_Roughness, globalPos ) ).xyz;
    float hitDistForTracking = 0.0;

    #if( NRD_HAS_SPEC )
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            uint shift = gSpecCheckerboard != 2 ? 1 : 0;
            uint2 pos = uint2( globalPos.x >> shift, globalPos.y );
        #else
            uint2 pos = globalPos;
        #endif

        REBLUR_TYPE spec = NRD_SURFACE( gIn_Spec, pos );
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            float hitDist = ExtractHitDist( spec );
        #else
            float hitDist = gSpecPrepassBlurRadius == 0.0 ? ExtractHitDist( spec ) : NRD_SURFACE( gIn_SpecHitDistForTracking, globalPos );
        #endif

        float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, globalPos ) );

        hitDistForTracking = ( hitDist == 0.0 || !IsInDenoisingRange( viewZ ) ) ? NRD_INF : hitDist;
    #endif

    s_Normal_HitDistForTracking[ sharedPos.y ][ sharedPos.x ] = float4( N, hitDistForTracking );
}

[numthreads( GROUP_X, GROUP_Y, 1 )]
NRD_EXPORT void NRD_CS_MAIN( NRD_CS_MAIN_ARGS )
{
    NRD_CTA_ORDER_DEFAULT;

    float isSky = NRD_SURFACE( gIn_Tiles, pixelPos >> 4 ).x;
    PRELOAD_INTO_SMEM_WITH_TILE_CHECK;

    if( isSky != 0.0 || any( pixelPos > gRectSizeMinusOne ) )
        return;

    float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, pixelPos ) );
    if( !IsInDenoisingRange( viewZ ) )
        return;

    float2 pixelUv = float2( pixelPos + 0.5 ) * gRectSizeInv;
    float3 Xv = Geometry::ReconstructViewPosition( pixelUv, gFrustum, viewZ, gOrthoMode );
    float3 X = Geometry::RotateVector( gViewToWorld, Xv );

    float3 Navg = 0.0;
    #if( NRD_HAS_SPEC )
        float hitDistForTracking = NRD_INF;
    #endif

    [unroll]
    for( j = 0; j <= NRD_BORDER * 2; j++ )
    {
        [unroll]
        for( i = 0; i <= NRD_BORDER * 2; i++ )
        {
            int2 pos = threadPos + int2( i, j );
            float4 data = s_Normal_HitDistForTracking[ pos.y ][ pos.x ];

            if( i < 2 && j < 2 )
                Navg += data.xyz * 0.25;

            #if( NRD_HAS_SPEC )

                hitDistForTracking = min( hitDistForTracking, data.w );
            #endif
        }
    }

    float materialID;
    float4 normalAndRoughness = NRD_FrontEnd_UnpackNormalAndRoughness( NRD_SURFACE( gIn_Normal_Roughness, pixelPos ), materialID );
    float3 N = normalAndRoughness.xyz;
    float roughness = normalAndRoughness.w;

    #if( NRD_HAS_SPEC )

        float roughnessModified = Filtering::GetModifiedRoughnessFromNormalVariance( roughness, Navg );

        #if( REBLUR_USE_STF == 1 && NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
            Rng::Hash::Initialize( pixelPos, gFrameIndex );
        #endif

        hitDistForTracking = hitDistForTracking == NRD_INF ? 0.0 : hitDistForTracking;

        float hitDistNormalization = _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, roughness );
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            hitDistForTracking *= hitDistNormalization;
        #else
            hitDistForTracking *= gSpecPrepassBlurRadius == 0.0 ? hitDistNormalization : 1.0;
        #endif

        NRD_SURFACE( gOut_SpecHitDistForTracking, pixelPos ) = hitDistForTracking;
    #endif

    float3 mv = NRD_SURFACE( gIn_Mv, pixelPos ) * gMvScale.xyz + gMvBias.xyz;
    float3 Xprev = X;
    float2 smbPixelUv = pixelUv + mv.xy;

    if( gMvScale.w == 0.0 )
    {
        if( gMvScale.z == 0.0 )
            mv.z = Geometry::AffineTransform( gWorldToViewPrev, X ).z - viewZ;

        float viewZprev = viewZ + mv.z;
        float3 Xvprevlocal = Geometry::ReconstructViewPosition( smbPixelUv, gFrustumPrev, viewZprev, gOrthoMode );

        Xprev = Geometry::RotateVectorInverse( gWorldToViewPrev, Xvprevlocal ) + gCameraDelta.xyz;
    }
    else
    {
        Xprev += mv;
        smbPixelUv = Geometry::GetScreenUv( gWorldToClipPrev, Xprev );
    }

    Filtering::CatmullRom smbCatromFilter = Filtering::GetCatmullRomFilter( smbPixelUv, gRectSizePrev );
    float2 smbCatromGatherUv = NRD_PIXEL_POS( gPrev_ViewZ, smbCatromFilter.origin ) * gResourceSizeInvPrev;
    float4 smbViewZ0 = gPrev_ViewZ.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 1, 1 ) ).wzxy;
    float4 smbViewZ1 = gPrev_ViewZ.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 3, 1 ) ).wzxy;
    float4 smbViewZ2 = gPrev_ViewZ.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 1, 3 ) ).wzxy;
    float4 smbViewZ3 = gPrev_ViewZ.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 3, 3 ) ).wzxy;

    float3 prevViewZ0 = UnpackViewZ( smbViewZ0.yzw );
    float3 prevViewZ1 = UnpackViewZ( smbViewZ1.xzw );
    float3 prevViewZ2 = UnpackViewZ( smbViewZ2.xyw );
    float3 prevViewZ3 = UnpackViewZ( smbViewZ3.xyz );

    Filtering::Bilinear smbBilinearFilter = Filtering::GetBilinearFilter( smbPixelUv, gRectSizePrev );
    float smbNoN;
    float4 smbNoN2x2;
    {

        float3 Nt = Navg;

        #if( NRD_USE_PREV_WORLD_SPACE_MATRIX == 1 )
            Nt = Geometry::RotateVectorInverse( gWorldPrevToWorld, Nt );
        #endif

        int3 p = int3( int2( NRD_PIXEL_POS( gPrev_Normal_Roughness, smbBilinearFilter.origin ) ), 0 );
        float3 n00 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p ) ).xyz;
        float3 n10 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 1, 0 ) ) ).xyz;
        float3 n01 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 0, 1 ) ) ).xyz;
        float3 n11 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 1, 1 ) ) ).xyz;

        smbNoN2x2.x = dot( n00, Nt );
        smbNoN2x2.y = dot( n10, Nt );
        smbNoN2x2.z = dot( n01, Nt );
        smbNoN2x2.w = dot( n11, Nt );

        smbNoN = Filtering::ApplyBilinearFilter( smbNoN2x2.x, smbNoN2x2.y, smbNoN2x2.z, smbNoN2x2.w, smbBilinearFilter );
    }

    float smbParallaxInPixels1 = ComputeParallaxInPixels( Xprev + gCameraDelta.xyz, gOrthoMode == 0.0 ? smbPixelUv : pixelUv, gWorldToClipPrev, gRectSize );
    float smbParallaxInPixels2 = ComputeParallaxInPixels( Xprev - gCameraDelta.xyz, gOrthoMode == 0.0 ? pixelUv : smbPixelUv, gWorldToClip, gRectSize );

    float smbParallaxInPixelsMax = max( smbParallaxInPixels1, smbParallaxInPixels2 );
    float smbParallaxInPixelsMin = min( smbParallaxInPixels1, smbParallaxInPixels2 );

    float pixelSize = PixelRadiusToWorld( gUnproject, gOrthoMode, 1.0, viewZ );
    float frustumSize = GetFrustumSize( gMinRectDimMulUnproject, gOrthoMode, viewZ );

    float disocclusionThresholdMix = 0;
    if( materialID == gStrandMaterialID )
        disocclusionThresholdMix = NRD_GetNormalizedStrandThickness( gStrandThickness, pixelSize );
    if( gHasDisocclusionThresholdMix != 0 && NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX == 1 )
        disocclusionThresholdMix = NRD_SURFACE( gIn_DisocclusionThresholdMix, pixelPos );

    float disocclusionThreshold = lerp( gDisocclusionThreshold, gDisocclusionThresholdAlternate, disocclusionThresholdMix );
    if( materialID == gStrandMaterialID )
    {

        float mediumParallax = Math::SmoothStep01( smbParallaxInPixelsMax );
        disocclusionThreshold = lerp( NRD_STRAND_RELAXED_DISOCCLUSION_THRESHOLD, disocclusionThreshold, mediumParallax );
    }

    float smallParallax = Math::LinearStep( 0.25, 0.0, smbParallaxInPixelsMax );
    float cosMaxAngle = REBLUR_ALMOST_ZERO_ANGLE - 0.25 * smallParallax;

    float3 V = GetViewVector( X );
    float NoV = abs( dot( N, V ) );
    float NoVstrict = lerp( NoV, 1.0, saturate( smbParallaxInPixelsMax / 30.0 ) );

    float4 smbDisocclusionThreshold = float4( smbNoN2x2 > cosMaxAngle );
    smbDisocclusionThreshold *= IsInScreenBilinear( smbBilinearFilter.origin, gRectSizePrev );
    smbDisocclusionThreshold *= GetDisocclusionThreshold( disocclusionThreshold, frustumSize, NoVstrict );
    smbDisocclusionThreshold -= NRD_EPS;

    float3 Xvprev = Geometry::AffineTransform( gWorldToViewPrev, Xprev );
    float3 smbPlaneDist0 = abs( prevViewZ0 - Xvprev.z );
    float3 smbPlaneDist1 = abs( prevViewZ1 - Xvprev.z );
    float3 smbPlaneDist2 = abs( prevViewZ2 - Xvprev.z );
    float3 smbPlaneDist3 = abs( prevViewZ3 - Xvprev.z );
    float3 smbOcclusion0 = step( smbPlaneDist0, smbDisocclusionThreshold.x ) * float3( IsInDenoisingRange( prevViewZ0 ) );
    float3 smbOcclusion1 = step( smbPlaneDist1, smbDisocclusionThreshold.y ) * float3( IsInDenoisingRange( prevViewZ1 ) );
    float3 smbOcclusion2 = step( smbPlaneDist2, smbDisocclusionThreshold.z ) * float3( IsInDenoisingRange( prevViewZ2 ) );
    float3 smbOcclusion3 = step( smbPlaneDist3, smbDisocclusionThreshold.w ) * float3( IsInDenoisingRange( prevViewZ3 ) );

    #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
        uint4 smbInternalData0 = gPrev_InternalData.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 1, 1 ) ).wzxy;
        uint4 smbInternalData1 = gPrev_InternalData.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 3, 1 ) ).wzxy;
        uint4 smbInternalData2 = gPrev_InternalData.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 1, 3 ) ).wzxy;
        uint4 smbInternalData3 = gPrev_InternalData.GatherRed( gNearestClamp, smbCatromGatherUv, int2( 3, 3 ) ).wzxy;

        float3 smbMaterialID0 = float3( UnpackInternalData( smbInternalData0.y ).z, UnpackInternalData( smbInternalData0.z ).z, UnpackInternalData( smbInternalData0.w ).z );
        float3 smbMaterialID1 = float3( UnpackInternalData( smbInternalData1.x ).z, UnpackInternalData( smbInternalData1.z ).z, UnpackInternalData( smbInternalData1.w ).z );
        float3 smbMaterialID2 = float3( UnpackInternalData( smbInternalData2.x ).z, UnpackInternalData( smbInternalData2.y ).z, UnpackInternalData( smbInternalData2.w ).z );
        float3 smbMaterialID3 = float3( UnpackInternalData( smbInternalData3.x ).z, UnpackInternalData( smbInternalData3.y ).z, UnpackInternalData( smbInternalData3.z ).z );

        float minMaterialID = min( gSpecMinMaterial, gDiffMinMaterial );
        smbOcclusion0 *= float3( CompareMaterials( materialID, smbMaterialID0, minMaterialID ) );
        smbOcclusion1 *= float3( CompareMaterials( materialID, smbMaterialID1, minMaterialID ) );
        smbOcclusion2 *= float3( CompareMaterials( materialID, smbMaterialID2, minMaterialID ) );
        smbOcclusion3 *= float3( CompareMaterials( materialID, smbMaterialID3, minMaterialID ) );

        uint4 smbInternalData = uint4( smbInternalData0.w, smbInternalData1.z, smbInternalData2.y, smbInternalData3.x );
    #else
        float2 smbBilinearGatherUv = ( NRD_PIXEL_POS( gPrev_ViewZ, smbBilinearFilter.origin ) + 1.0 ) * gResourceSizeInvPrev;
        uint4 smbInternalData = gPrev_InternalData.GatherRed( gNearestClamp, smbBilinearGatherUv ).wzxy;
    #endif

    float4 smbOcclusionWeights = Filtering::GetBilinearCustomWeights( smbBilinearFilter, float4( smbOcclusion0.z, smbOcclusion1.y, smbOcclusion2.y, smbOcclusion3.x ) );
    bool smbAllowCatRom = dot( smbOcclusion0 + smbOcclusion1 + smbOcclusion2 + smbOcclusion3, 1.0 ) > 11.5 && REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TA == 1;

    float fbits = smbOcclusion0.z * 1.0;
    fbits += smbOcclusion1.y * 2.0;
    fbits += smbOcclusion2.y * 4.0;
    fbits += smbOcclusion3.x * 8.0;

    float2 internalData00 = UnpackInternalData( smbInternalData.x ).xy;
    float2 internalData10 = UnpackInternalData( smbInternalData.y ).xy;
    float2 internalData01 = UnpackInternalData( smbInternalData.z ).xy;
    float2 internalData11 = UnpackInternalData( smbInternalData.w ).xy;

    #if( NRD_HAS_DIFF )
        float4 diffAccumSpeeds = float4( internalData00.x, internalData10.x, internalData01.x, internalData11.x );
        float diffAccumSpeed = Filtering::ApplyBilinearCustomWeights( diffAccumSpeeds.x, diffAccumSpeeds.y, diffAccumSpeeds.z, diffAccumSpeeds.w, smbOcclusionWeights );
    #endif

    #if( NRD_HAS_SPEC )
        float4 specAccumSpeeds = float4( internalData00.y, internalData10.y, internalData01.y, internalData11.y );
        float smbSpecAccumSpeed = Filtering::ApplyBilinearCustomWeights( specAccumSpeeds.x, specAccumSpeeds.y, specAccumSpeeds.z, specAccumSpeeds.w, smbOcclusionWeights );
    #endif

    float3 smbVprev = GetViewVectorPrev( Xprev, gCameraDelta.xyz );
    float NoVprev = abs( dot( N, smbVprev ) );
    float sizeQuality = ( NoVprev + 1e-3 ) / ( NoV + 1e-3 );
    sizeQuality *= sizeQuality;
    sizeQuality = lerp( 0.1, 1.0, saturate( sizeQuality ) );

    float smbFootprintQuality = Filtering::ApplyBilinearFilter( smbOcclusion0.z, smbOcclusion1.y, smbOcclusion2.y, smbOcclusion3.x, smbBilinearFilter );
    smbFootprintQuality = Math::Sqrt01( smbFootprintQuality );
    smbFootprintQuality *= sizeQuality;

    uint checkerboard = Sequence::CheckerBoard( pixelPos, gFrameIndex );
    #if( NRD_MODE == NRD_MODE_OCCLUSION )
        int3 checkerboardPos = pixelPos.xxy + int3( -1, 1, 0 );
        checkerboardPos.x = max( checkerboardPos.x, 0 );
        checkerboardPos.y = min( checkerboardPos.y, gRectSizeMinusOne.x );
        float viewZ0 = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, checkerboardPos.xz ) );
        float viewZ1 = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, checkerboardPos.yz ) );
        float disocclusionThresholdCheckerboard = GetDisocclusionThreshold( NRD_DISOCCLUSION_THRESHOLD, frustumSize, NoV );
        float2 wc = GetDisocclusionWeight( float2( viewZ0, viewZ1 ), viewZ, disocclusionThresholdCheckerboard );
        wc.x = ( !IsInDenoisingRange( viewZ0 ) || pixelPos.x < 1 ) ? 0.0 : wc.x;
        wc.y = ( !IsInDenoisingRange( viewZ1 ) || pixelPos.x >= gRectSizeMinusOne.x ) ? 0.0 : wc.y;
        wc *= Math::PositiveRcp( wc.x + wc.y );
        checkerboardPos.xy >>= 1;
    #endif

    #if( NRD_HAS_SPEC )

        float smbSpecHistoryConfidence = smbFootprintQuality;
        if( gHasHistoryConfidence != 0 && NRD_SUPPORTS_HISTORY_CONFIDENCE == 1 )
        {
            float confidence = saturate( gIn_SpecConfidence.SampleLevel( gLinearClamp, smbPixelUv, 0 ) );
            smbSpecHistoryConfidence = min( smbSpecHistoryConfidence, confidence );
        }
        smbSpecAccumSpeed *= lerp( smbSpecHistoryConfidence, 1.0, 1.0 / ( 1.0 + smbSpecAccumSpeed ) );

        bool specHasData = NRD_SUPPORTS_CHECKERBOARD == 0 || gSpecCheckerboard == 2 || checkerboard == gSpecCheckerboard;
        int2 specPos = pixelPos;
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            specPos.x >>= gSpecCheckerboard == 2 ? 0 : 1;
        #endif

        REBLUR_TYPE spec = NRD_SURFACE( gIn_Spec, specPos );

        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            if( !specHasData )
            {
                float s0 = NRD_SURFACE( gIn_Spec, checkerboardPos.xz );
                float s1 = NRD_SURFACE( gIn_Spec, checkerboardPos.yz );

                s0 = Denanify( wc.x, s0 );
                s1 = Denanify( wc.y, s1 );

                spec = s0 * wc.x + s1 * wc.y;
            }
        #endif

        float curvature = 0.0;
        {

            float2 uvForZeroParallax = gOrthoMode == 0.0 ? smbPixelUv : pixelUv;
            float2 deltaUv = uvForZeroParallax - Geometry::GetScreenUv( gWorldToClipPrev, Xprev + gCameraDelta.xyz );
            deltaUv *= gRectSize;
            deltaUv /= max( smbParallaxInPixels1, 1.0 / 256.0 );

            float3 n10, x10;
            {
                float3 xv = Geometry::ReconstructViewPosition( pixelUv + float2( 1, 0 ) * gRectSizeInv, gFrustum, 1.0, gOrthoMode );
                float3 x = Geometry::RotateVector( gViewToWorld, xv );
                float3 v = GetViewVector( x );
                float3 o = gOrthoMode == 0.0 ? 0 : x;

                x10 = o + v * dot( X - o, N ) / dot( N, v );
                n10 = s_Normal_HitDistForTracking[ threadPos.y + NRD_BORDER ][ threadPos.x + NRD_BORDER + 1 ].xyz;
            }

            float3 n01, x01;
            {
                float3 xv = Geometry::ReconstructViewPosition( pixelUv + float2( 0, 1 ) * gRectSizeInv, gFrustum, 1.0, gOrthoMode );
                float3 x = Geometry::RotateVector( gViewToWorld, xv );
                float3 v = GetViewVector( x );
                float3 o = gOrthoMode == 0.0 ? 0 : x;

                x01 = o + v * dot( X - o, N ) / dot( N, v );
                n01 = s_Normal_HitDistForTracking[ threadPos.y + NRD_BORDER + 1 ][ threadPos.x + NRD_BORDER ].xyz;
            }

            float2 ww = abs( deltaUv ) + 1.0 / 256.0;
            ww /= ww.x + ww.y;

            float3 x = x10 * ww.x + x01 * ww.y;
            float3 n = _NRD_SafeNormalize( n10 * ww.x + n01 * ww.y );

            float2 motionUvHigh = pixelUv + smbParallaxInPixelsMin * deltaUv * gRectSizeInv;

            if( smbParallaxInPixelsMin > sqrt( 2.0 ) && IsInScreenNearest( motionUvHigh ) != 0.0 )
            {
                float2 uvScaled = ClampUvToViewport( motionUvHigh ) + float2( NRD_PIXEL_POS( gIn_ViewZ, int2( 0, 0 ) ) ) * gResourceSizeInv;

                float zHigh = UnpackViewZ( gIn_ViewZ.SampleLevel( gLinearClamp, uvScaled, 0 ) );
                float3 xHigh = Geometry::ReconstructViewPosition( motionUvHigh, gFrustum, zHigh, gOrthoMode );
                xHigh = Geometry::RotateVector( gViewToWorld, xHigh );

                float3 nHigh = NRD_FrontEnd_UnpackNormalAndRoughness( gIn_Normal_Roughness.SampleLevel( STOCHASTIC_BILINEAR_FILTER, StochasticBilinear( uvScaled, gRectSize ), 0 ) ).xyz;

                float2 geometryWeightParams = GetGeometryWeightParams( NRD_CURVATURE_HIGH_PARALLAX_DISOCCLUSION_THRESHOLD, frustumSize, X, N );
                float NoX = dot( N, xHigh );

                float w = ApplyGeometryWeightLast( 1.0, zHigh, NoX, geometryWeightParams );
                bool cmp = w > 0.5;

                n = cmp ? nHigh : n;
                x = cmp ? xHigh : x;
            }

            float3 edge = x - X;
            float edgeLenSq = Math::LengthSquared( edge );
            curvature = dot( n - N, edge ) * Math::PositiveRcp( edgeLenSq );

            if( curvature < 0 )
            {
                float2 uv1 = Geometry::GetScreenUv( gWorldToClipPrev, GetXvirtual( hitDistForTracking, curvature, X, X, N, V, roughness ) );
                float2 uv2 = Geometry::GetScreenUv( gWorldToClipPrev, X );
                float a = length( ( uv1 - uv2 ) * gRectSize );
                curvature *= float( a < NRD_MAX_ALLOWED_VIRTUAL_MOTION_ACCELERATION * smbParallaxInPixelsMax + gRectSizeInv.x );
            }
        }

        float3 Xvirtual = GetXvirtual( hitDistForTracking, curvature, X, Xprev, N, V, roughness );
        float XvirtualLength = length( Xvirtual );
        float hitDistanceToLobeSpreadInPixels = 1.0 / PixelRadiusToWorld( gUnproject, gOrthoMode, 1.0, XvirtualLength );

        float2 vmbPixelUv = Geometry::GetScreenUv( gWorldToClipPrev, Xvirtual );
        vmbPixelUv = materialID == gCameraAttachedReflectionMaterialID ? smbPixelUv : vmbPixelUv;

        float2 vmbDelta = vmbPixelUv - smbPixelUv;
        float vmbPixelsTraveled = length( vmbDelta * gRectSize ) * REBLUR_FRAME_RATE_COMPENSATION;

        Filtering::Bilinear vmbBilinearFilter = Filtering::GetBilinearFilter( vmbPixelUv, gRectSizePrev );
        float2 vmbBilinearGatherUv = ( NRD_PIXEL_POS( gPrev_ViewZ, vmbBilinearFilter.origin ) + 1.0 ) * gResourceSizeInvPrev;

        float4 vmbRoughness;
        float4 vmbN;
        float4 vmbNoN2x2;
        float vmbNoN;
        {
            float3 Nt = N;

            #if( NRD_USE_PREV_WORLD_SPACE_MATRIX == 1 )
                Nt = Geometry::RotateVectorInverse( gWorldPrevToWorld, Nt );
            #endif

            int3 p = int3( int2( NRD_PIXEL_POS( gPrev_Normal_Roughness, vmbBilinearFilter.origin ) ), 0 );
            float4 n00 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p ) );
            float4 n10 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 1, 0 ) ) );
            float4 n01 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 0, 1 ) ) );
            float4 n11 = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.Load( p, int2( 1, 1 ) ) );

            vmbRoughness = float4( n00.w, n10.w, n01.w, n11.w );

            vmbNoN2x2.x = dot( n00.xyz, Nt );
            vmbNoN2x2.y = dot( n10.xyz, Nt );
            vmbNoN2x2.z = dot( n01.xyz, Nt );
            vmbNoN2x2.w = dot( n11.xyz, Nt );

            vmbNoN = Filtering::ApplyBilinearFilter( vmbNoN2x2.x, vmbNoN2x2.y, vmbNoN2x2.z, vmbNoN2x2.w, vmbBilinearFilter );

            vmbN = Filtering::ApplyBilinearFilter( n00, n10, n01, n11, vmbBilinearFilter );
            vmbN.xyz = _NRD_SafeNormalize( vmbN.xyz );

            #if( NRD_USE_PREV_WORLD_SPACE_MATRIX == 1 )
                vmbN.xyz = Geometry::RotateVector( gWorldPrevToWorld, vmbN.xyz );
            #endif
        }

        float virtualHistoryConfidence;
        float4 roughnessWeights;
        {
            float2 relaxedRoughnessWeightParams = GetRelaxedRoughnessWeightParams( roughness * roughness, gRoughnessFraction, REBLUR_ROUGHNESS_SENSITIVITY_IN_TA );

            roughnessWeights = ComputeNonExponentialWeight( vmbRoughness * vmbRoughness, relaxedRoughnessWeightParams.x, relaxedRoughnessWeightParams.y );
            roughnessWeights = lerp( 1.0, roughnessWeights, Math::SmoothStep01( vmbPixelsTraveled ) );

            float roughnessWeight = Filtering::ApplyBilinearFilter( roughnessWeights.x, roughnessWeights.y, roughnessWeights.z, roughnessWeights.w, vmbBilinearFilter );
            virtualHistoryConfidence = roughnessWeight;
        }

        float4 vmbOcclusionWeights;
        float vmbSpecAccumSpeed;
        bool vmbAllowCatRom;
        {

            float4 vmbOcclusionThreshold = float4( vmbNoN2x2 > cosMaxAngle );
            vmbOcclusionThreshold *= step( 0.5, roughnessWeights );
            vmbOcclusionThreshold *= IsInScreenBilinear( vmbBilinearFilter.origin, gRectSizePrev );
            vmbOcclusionThreshold *= disocclusionThreshold * frustumSize;
            vmbOcclusionThreshold *= lerp( 0.1, 1.0, NoV );
            vmbOcclusionThreshold -= NRD_EPS;

            float4 vmbViewZ = UnpackViewZ( gPrev_ViewZ.GatherRed( gNearestClamp, vmbBilinearGatherUv ).wzxy );
            float3 vmbVv = Geometry::ReconstructViewPosition( vmbPixelUv, gFrustumPrev, 1.0 );
            float3 Nv = Geometry::RotateVector( gWorldToViewPrev, N );
            float NoXcurr = dot( N, Xprev - gCameraDelta.xyz );
            float4 NoXprev = ( Nv.x * vmbVv.x + Nv.y * vmbVv.y ) * ( gOrthoMode == 0 ? vmbViewZ : gOrthoMode ) + Nv.z * vmbVv.z * vmbViewZ;
            float4 vmbPlaneDist = abs( NoXprev - NoXcurr );

            float4 vmbOcclusion = step( vmbPlaneDist, vmbOcclusionThreshold ) * float4( IsInDenoisingRange( vmbViewZ ) );

            uint4 vmbInternalData = gPrev_InternalData.GatherRed( gNearestClamp, vmbBilinearGatherUv ).wzxy;

            float3 vmbInternalData00 = UnpackInternalData( vmbInternalData.x );
            float3 vmbInternalData10 = UnpackInternalData( vmbInternalData.y );
            float3 vmbInternalData01 = UnpackInternalData( vmbInternalData.z );
            float3 vmbInternalData11 = UnpackInternalData( vmbInternalData.w );

            #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )

                float4 vmbMaterialID = float4( vmbInternalData00.z, vmbInternalData10.z, vmbInternalData01.z, vmbInternalData11.z  );
                vmbOcclusion *= float4( CompareMaterials( materialID, vmbMaterialID, gSpecMinMaterial ) );
            #endif

            fbits += vmbOcclusion.x * 16.0;
            fbits += vmbOcclusion.y * 32.0;
            fbits += vmbOcclusion.z * 64.0;
            fbits += vmbOcclusion.w * 128.0;

            vmbOcclusionWeights = Filtering::GetBilinearCustomWeights( vmbBilinearFilter, vmbOcclusion );
            vmbSpecAccumSpeed = Filtering::ApplyBilinearCustomWeights( vmbInternalData00.y, vmbInternalData10.y, vmbInternalData01.y, vmbInternalData11.y, vmbOcclusionWeights );

            float vmbFootprintQuality = Filtering::ApplyBilinearFilter( vmbOcclusion.x, vmbOcclusion.y, vmbOcclusion.z, vmbOcclusion.w, vmbBilinearFilter );
            vmbFootprintQuality = Math::Sqrt01( vmbFootprintQuality );

            float vmbSpecHistoryConfidence = vmbFootprintQuality;
            if( gHasHistoryConfidence != 0 && NRD_SUPPORTS_HISTORY_CONFIDENCE == 1 )
            {
                float confidence = saturate( gIn_SpecConfidence.SampleLevel( gLinearClamp, vmbPixelUv, 0 ) );
                vmbSpecHistoryConfidence = min( vmbSpecHistoryConfidence, confidence );
            }
            vmbSpecAccumSpeed *= lerp( vmbSpecHistoryConfidence, 1.0, 1.0 / ( 1.0 + vmbSpecAccumSpeed ) );

            vmbAllowCatRom = dot( vmbOcclusion, 1.0 ) > 3.5 && REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TA == 1;
            vmbAllowCatRom = vmbAllowCatRom && smbAllowCatRom;
        }

        float curvatureAngle;
        float lobeHalfAngle;
        {

            float curvatureAngleTan = pixelSize * abs( curvature );
            curvatureAngleTan *= max( vmbPixelsTraveled / max( NoV, 0.01 ), 1.0 );
            curvatureAngleTan *= 2.0;

            curvatureAngle = atan( curvatureAngleTan );

            float percentOfVolume = NRD_MAX_PERCENT_OF_LOBE_VOLUME / ( 1.0 + vmbSpecAccumSpeed );
            float lobeTanHalfAngle = ImportanceSampling::GetSpecularLobeTanHalfAngle( roughness, percentOfVolume );

            lobeTanHalfAngle = max( lobeTanHalfAngle, NRD_NORMAL_ENCODING_ERROR );
            hitDistanceToLobeSpreadInPixels *= lobeTanHalfAngle;

            lobeHalfAngle = atan( lobeTanHalfAngle );
        }

        float parallaxWeight;
        {

            float hitDistForTrackingPrev = gPrev_SpecHitDistForTracking.SampleLevel( gLinearClamp, vmbPixelUv * gResolutionScalePrev + float2( NRD_PIXEL_POS( gPrev_SpecHitDistForTracking, int2( 0, 0 ) ) ) * gResourceSizeInvPrev, 0 );
            float3 XvirtualPrev = GetXvirtual( hitDistForTrackingPrev, curvature, X, Xprev, N, V, roughness );

            float2 vmbPixelUvPrev = Geometry::GetScreenUv( gWorldToClipPrev, XvirtualPrev );
            vmbPixelUvPrev = materialID == gCameraAttachedReflectionMaterialID ? smbPixelUv : vmbPixelUvPrev;

            float r = min( hitDistForTracking, hitDistForTrackingPrev ) * hitDistanceToLobeSpreadInPixels;
            r *= 0.5;
            r = max( r, 0.1 * roughness );

            float d = length( ( vmbPixelUvPrev - vmbPixelUv ) * gRectSize ) * REBLUR_FRAME_RATE_COMPENSATION;

            parallaxWeight = Math::LinearStep( r, 0.0, d );

        }

        {

            float normalWeight = GetEncodingAwareNormalWeight( N, vmbN.xyz, lobeHalfAngle, curvatureAngle, REBLUR_NORMAL_ULP );
            normalWeight = lerp( 1.0, normalWeight, Math::SmoothStep01( vmbPixelsTraveled ) );

            virtualHistoryConfidence *= normalWeight;
        }

        {

            float stepBetweenTaps = min( vmbPixelsTraveled * 2.0 * gFrameRateScale / REBLUR_FRAME_RATE_COMPENSATION, 2.0 ) + vmbPixelsTraveled / REBLUR_VIRTUAL_MOTION_PREV_PREV_WEIGHT_ITERATION_NUM;
            vmbDelta *= Math::Rsqrt( Math::LengthSquared( vmbDelta ) );
            vmbDelta /= gRectSizePrev;

            float2 relaxedRoughnessWeightParams = GetRelaxedRoughnessWeightParams( vmbN.w * vmbN.w, gRoughnessFraction, REBLUR_ROUGHNESS_SENSITIVITY_IN_TA );

            [unroll]
            for( i = 1; i <= REBLUR_VIRTUAL_MOTION_PREV_PREV_WEIGHT_ITERATION_NUM; i++ )
            {
                float2 vmbPixelUvPrev = vmbPixelUv + vmbDelta * i * stepBetweenTaps;

                float4 vmbNormalAndRoughnessPrev = NRD_FrontEnd_UnpackNormalAndRoughness( gPrev_Normal_Roughness.SampleLevel( STOCHASTIC_BILINEAR_FILTER, StochasticBilinear( vmbPixelUvPrev, gRectSizePrev ) * gResolutionScalePrev + float2( NRD_PIXEL_POS( gPrev_Normal_Roughness, int2( 0, 0 ) ) ) * gResourceSizeInvPrev, 0 ) );

                #if( NRD_USE_PREV_WORLD_SPACE_MATRIX == 1 )
                    vmbNormalAndRoughnessPrev.xyz = Geometry::RotateVector( gWorldPrevToWorld, vmbNormalAndRoughnessPrev.xyz );
                #endif

                float w = GetEncodingAwareNormalWeight( vmbN.xyz, vmbNormalAndRoughnessPrev.xyz, lobeHalfAngle, curvatureAngle * ( 1.0 + i * stepBetweenTaps ), REBLUR_NORMAL_ULP );
                w *= ComputeNonExponentialWeight( vmbNormalAndRoughnessPrev.w * vmbNormalAndRoughnessPrev.w, relaxedRoughnessWeightParams.x, relaxedRoughnessWeightParams.y );

                #if( REBLUR_USE_STF == 1 && NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )

                    w = lerp( 1.0, w, saturate( stepBetweenTaps ) );
                #endif

                w = IsInScreenNearest( vmbPixelUvPrev ) != 0.0 ? w : 1.0;

                virtualHistoryConfidence = min( virtualHistoryConfidence, w );
            }
        }

        virtualHistoryConfidence *= parallaxWeight;

        float mvLengthInPixels = length( ( smbPixelUv - pixelUv ) * gRectSize ) * REBLUR_FRAME_RATE_COMPENSATION;
        float slowMotionFactor = saturate( mvLengthInPixels / 0.25 );

        float surfaceHistoryConfidence;
        {

            float a = atan( REBLUR_FRAME_RATE_COMPENSATION * smbParallaxInPixelsMax * pixelSize / length( X ) );

            a *= lerp( 0.1, 1.0, slowMotionFactor );

            float nonLinearAccumSpeed = 1.0 / ( 1.0 + smbSpecAccumSpeed );

            float hPrev = ExtractHitDist( gHistory_Spec.SampleLevel( gLinearClamp, smbPixelUv * gResolutionScalePrev + float2( NRD_PIXEL_POS( gHistory_Spec, int2( 0, 0 ) ) ) * gResourceSizeInvPrev, 0 ) );
            float h = lerp( hPrev, ExtractHitDist( spec ), nonLinearAccumSpeed ) * hitDistNormalization;

            float tana0 = ImportanceSampling::GetSpecularLobeTanHalfAngle( roughnessModified, NRD_MAX_PERCENT_OF_LOBE_VOLUME );
            tana0 *= lerp( NoV, 1.0, roughnessModified );
            tana0 *= nonLinearAccumSpeed;
            tana0 /= GetHitDistFactor( h, frustumSize ) + NRD_EPS;

            float a0 = max( atan( tana0 ), NRD_NORMAL_ENCODING_ERROR );

            float f = Math::LinearStep( a0, 0.0, a );
            surfaceHistoryConfidence = Math::Pow01( f, 4.0 );

            f = Math::LinearStep( 0.8, 0.9, roughnessModified );
            surfaceHistoryConfidence = lerp( surfaceHistoryConfidence, 1.0, f );
        }

        float smbSpecAccumSpeed_NoHistoryFix;
        float vmbSpecAccumSpeed_NoHistoryFix;
        {

            float responsiveFactor = RemapRoughnessToResponsiveFactor( roughnessModified );
            float smc = GetSpecMagicCurve( roughnessModified );

            float2 f;
            f.x = smbNoN;
            f.y = vmbNoN;
            f = lerp( smc, 1.0, responsiveFactor ) * Math::Pow01( f, lerp( 32.0, 1.0, smc ) * ( 1.0 - responsiveFactor ) );

            float2 maxResponsiveFrameNum = gMaxAccumulatedFrameNum;
            maxResponsiveFrameNum *= f;
            maxResponsiveFrameNum = max( maxResponsiveFrameNum, float( gResponsiveAccumulationMinAccumulatedFrameNum ) );

            float2 maxFrameNum = gMaxAccumulatedFrameNum * float2( surfaceHistoryConfidence, virtualHistoryConfidence );
            float2 maxFrameNum_NoHistoryFix = min( maxFrameNum, max( maxResponsiveFrameNum, gHistoryFixFrameNum ) );

            smbSpecAccumSpeed_NoHistoryFix = min( smbSpecAccumSpeed, maxFrameNum_NoHistoryFix.x );
            vmbSpecAccumSpeed_NoHistoryFix = min( vmbSpecAccumSpeed, maxFrameNum_NoHistoryFix.y );

            maxFrameNum = min( maxFrameNum, maxResponsiveFrameNum );

            smbSpecAccumSpeed = min( smbSpecAccumSpeed, maxFrameNum.x );
            vmbSpecAccumSpeed = min( vmbSpecAccumSpeed, maxFrameNum.y );
        }

        float virtualHistoryAmount;
        {

            virtualHistoryAmount = 1.0 + ( vmbSpecAccumSpeed - smbSpecAccumSpeed ) / ( 1.0 + 0.5 * max( vmbSpecAccumSpeed, smbSpecAccumSpeed ) );
            virtualHistoryAmount = saturate( virtualHistoryAmount );

            if( materialID != gCameraAttachedReflectionMaterialID )
                virtualHistoryAmount *= slowMotionFactor;

            if( !smbAllowCatRom || !vmbAllowCatRom )
                virtualHistoryAmount = step( 0.5, virtualHistoryAmount );
        }

        REBLUR_TYPE specHistory;
        REBLUR_FAST_TYPE specFastHistory;
        REBLUR_SH_TYPE specShHistory;
        {
            float2 uv = lerp( smbPixelUv, vmbPixelUv, virtualHistoryAmount );
            float4 occlusionWeights = lerp( smbOcclusionWeights, vmbOcclusionWeights, virtualHistoryAmount );
            bool allowCatRom = virtualHistoryAmount < 0.5 ? smbAllowCatRom : vmbAllowCatRom;

            BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights(
                NRD_PIXEL_POS( gHistory_Spec, saturate( uv ) * gRectSizePrev ), gResourceSizeInvPrev,
                occlusionWeights, allowCatRom,
                gHistory_Spec, specHistory,
                gHistory_SpecFast, specFastHistory
                #if( NRD_MODE == NRD_MODE_SH )
                    , gHistory_SpecSh, specShHistory
                #endif
            );

            specHistory = ClampNegativeToZero( specHistory );
            specFastHistory = max( specFastHistory, 0.0 );
        }

        float specAccumSpeedCorrected = lerp( smbSpecAccumSpeed_NoHistoryFix, vmbSpecAccumSpeed_NoHistoryFix, virtualHistoryAmount );
        float specAccumSpeed = lerp( smbSpecAccumSpeed, vmbSpecAccumSpeed, virtualHistoryAmount );
        float specNonLinearAccumSpeed = 1.0 / ( 1.0 + specAccumSpeed );

        if( !specHasData )
            specNonLinearAccumSpeed *= lerp( 1.0 - gCheckerboardResolveAccumSpeed, 1.0, specNonLinearAccumSpeed );

        REBLUR_TYPE specResult = MixHistoryAndCurrent( specHistory, spec, specNonLinearAccumSpeed, roughness );

        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE specSh = NRD_SURFACE( gIn_SpecSh, specPos );
            REBLUR_SH_TYPE specShResult = lerp( specShHistory, specSh, specNonLinearAccumSpeed );
        #endif

        float specMaxRelativeIntensity = gFireflySuppressorMinRelativeScale + REBLUR_FIREFLY_SUPPRESSOR_MAX_RELATIVE_INTENSITY / ( specAccumSpeed + 1.0 );

        float specAntifireflyFactor = specAccumSpeed * gMaxBlurRadius * REBLUR_FIREFLY_SUPPRESSOR_RADIUS_SCALE;
        specAntifireflyFactor /= 1.0 + specAntifireflyFactor;

        #if( NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
        {
            float specLumaResult = GetLuma( specResult );
            float specLumaClamped = min( specLumaResult, GetLuma( specHistory ) * specMaxRelativeIntensity );
            specLumaClamped = lerp( specLumaResult, specLumaClamped, specAntifireflyFactor );

            #if( NRD_MODE == NRD_MODE_SH )
                specShResult *= GetLumaScale( GetLuma( specResult ), specLumaClamped );
            #endif
            specResult = ChangeLuma( specResult, specLumaClamped );

            float specHitDistMaxRelativeIntensity = 1.2 + 1.0 / ( specAccumSpeed + 1.0 );
            specResult.w = lerp( specResult.w, min( specResult.w, specHistory.w * specHitDistMaxRelativeIntensity ), specAntifireflyFactor );
        }
        #endif

        NRD_SURFACE( gOut_Spec, pixelPos ) = specResult;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_SpecSh, pixelPos ) = specShResult;
        #endif

        {
            float maxFastAccumulatedFrameNum = gMaxFastAccumulatedFrameNum;
            if( materialID == gStrandMaterialID )
                maxFastAccumulatedFrameNum = max( maxFastAccumulatedFrameNum, gMaxAccumulatedFrameNum / 5 );

            float specHistoryConfidence = lerp( surfaceHistoryConfidence, virtualHistoryConfidence, virtualHistoryAmount );
            float specFastNonLinearAccumSpeed = GetNonLinearAccumSpeed( specAccumSpeed, maxFastAccumulatedFrameNum, specHistoryConfidence, specHasData );
            float specFastResult = lerp( specFastHistory, GetLuma( spec ), specFastNonLinearAccumSpeed );

            #if( NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
                float specFastClamped = min( specFastResult, GetLuma( specHistory ) * specMaxRelativeIntensity * REBLUR_FIREFLY_SUPPRESSOR_FAST_RELATIVE_INTENSITY );
                specFastResult = lerp( specFastResult, specFastClamped, specAntifireflyFactor );
            #endif

            NRD_SURFACE( gOut_SpecFast, pixelPos ) = specFastResult;
        }

        #if( REBLUR_SHOW == REBLUR_SHOW_CURVATURE )
            virtualHistoryAmount = abs( curvature ) * pixelSize * 30.0;
        #elif( REBLUR_SHOW == REBLUR_SHOW_CURVATURE_SIGN )
            virtualHistoryAmount = sign( curvature ) * 0.5 + 0.5;
        #elif( REBLUR_SHOW == REBLUR_SHOW_SURFACE_HISTORY_CONFIDENCE )
            virtualHistoryAmount = surfaceHistoryConfidence;
        #elif( REBLUR_SHOW == REBLUR_SHOW_VIRTUAL_HISTORY_CONFIDENCE )
            virtualHistoryAmount = virtualHistoryConfidence;
        #elif( REBLUR_SHOW == REBLUR_SHOW_HIT_DIST_FOR_TRACKING )
            float smc = GetSpecMagicCurve( roughness );
            virtualHistoryAmount = hitDistForTracking * lerp( 1.0, 5.0, smc ) / ( 1.0 + hitDistForTracking * lerp( 1.0, 5.0, smc ) );
        #endif
    #else
        float specAccumSpeedCorrected = 0;
        float curvature = 0;
        float virtualHistoryAmount = 0;
    #endif

    #if( NRD_MODE != NRD_MODE_OCCLUSION )

        NRD_SURFACE( gOut_Data2, pixelPos ) = PackData2( fbits, curvature, virtualHistoryAmount, smbAllowCatRom );
    #endif

    #if( NRD_HAS_DIFF )

        float diffHistoryConfidence = smbFootprintQuality;
        if( gHasHistoryConfidence != 0 && NRD_SUPPORTS_HISTORY_CONFIDENCE == 1 )
        {
            float confidence = saturate( gIn_DiffConfidence.SampleLevel( gLinearClamp, smbPixelUv, 0 ) );
            diffHistoryConfidence = min( diffHistoryConfidence, confidence );
        }
        diffAccumSpeed *= lerp( diffHistoryConfidence, 1.0, 1.0 / ( 1.0 + diffAccumSpeed ) );

        bool diffHasData = NRD_SUPPORTS_CHECKERBOARD == 0 || gDiffCheckerboard == 2 || checkerboard == gDiffCheckerboard;
        int2 diffPos = pixelPos;
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            diffPos.x >>= gDiffCheckerboard == 2 ? 0 : 1;
        #endif

        REBLUR_TYPE diff = NRD_SURFACE( gIn_Diff, diffPos );

        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            if( !diffHasData )
            {
                float d0 = NRD_SURFACE( gIn_Diff, checkerboardPos.xz );
                float d1 = NRD_SURFACE( gIn_Diff, checkerboardPos.yz );

                d0 = Denanify( wc.x, d0 );
                d1 = Denanify( wc.y, d1 );

                diff = d0 * wc.x + d1 * wc.y;
            }
        #endif

        REBLUR_TYPE diffHistory;
        REBLUR_FAST_TYPE diffFastHistory;
        REBLUR_SH_TYPE diffShHistory;
        {
            BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights(
                NRD_PIXEL_POS( gHistory_Diff, saturate( smbPixelUv ) * gRectSizePrev ), gResourceSizeInvPrev,
                smbOcclusionWeights, smbAllowCatRom,
                gHistory_Diff, diffHistory,
                gHistory_DiffFast, diffFastHistory
                #if( NRD_MODE == NRD_MODE_SH )
                    , gHistory_DiffSh, diffShHistory
                #endif
            );

            diffHistory = ClampNegativeToZero( diffHistory );
            diffFastHistory = max( diffFastHistory, 0.0 );
        }

        float diffNonLinearAccumSpeed = 1.0 / ( 1.0 + diffAccumSpeed );

        if( !diffHasData )
            diffNonLinearAccumSpeed *= lerp( 1.0 - gCheckerboardResolveAccumSpeed, 1.0, diffNonLinearAccumSpeed );

        REBLUR_TYPE diffResult = MixHistoryAndCurrent( diffHistory, diff, diffNonLinearAccumSpeed );
        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE diffSh = NRD_SURFACE( gIn_DiffSh, diffPos );
            REBLUR_SH_TYPE diffShResult = lerp( diffShHistory, diffSh, diffNonLinearAccumSpeed );
        #endif

        #if( NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
            float diffMaxRelativeIntensity = gFireflySuppressorMinRelativeScale + REBLUR_FIREFLY_SUPPRESSOR_MAX_RELATIVE_INTENSITY / ( diffAccumSpeed + 1.0 );

            float diffAntifireflyFactor = diffAccumSpeed * gMaxBlurRadius * REBLUR_FIREFLY_SUPPRESSOR_RADIUS_SCALE;
            diffAntifireflyFactor /= 1.0 + diffAntifireflyFactor;

            float diffLumaResult = GetLuma( diffResult );
            float diffLumaClamped = min( diffLumaResult, GetLuma( diffHistory ) * diffMaxRelativeIntensity );
            diffLumaClamped = lerp( diffLumaResult, diffLumaClamped, diffAntifireflyFactor );

            #if( NRD_MODE == NRD_MODE_SH )
                diffShResult *= GetLumaScale( GetLuma( diffResult ), diffLumaClamped );
            #endif
            diffResult = ChangeLuma( diffResult, diffLumaClamped );

            float diffHitDistMaxRelativeIntensity = 1.2 + 1.0 / ( diffAccumSpeed + 1.0 );
            diffResult.w = lerp( diffResult.w, min( diffResult.w, diffHistory.w * diffHitDistMaxRelativeIntensity ), diffAntifireflyFactor );
        #endif

        NRD_SURFACE( gOut_Diff, pixelPos ) = diffResult;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_DiffSh, pixelPos ) = diffShResult;
        #endif

        {
            float diffFastAccumSpeed = min( diffAccumSpeed, gMaxFastAccumulatedFrameNum );
            float diffFastNonLinearAccumSpeed = 1.0 / ( 1.0 + diffFastAccumSpeed );

            if( !diffHasData )
                diffFastNonLinearAccumSpeed *= lerp( 1.0 - gCheckerboardResolveAccumSpeed, 1.0, diffFastNonLinearAccumSpeed );

            float diffFastResult = lerp( diffFastHistory, GetLuma( diff ), diffFastNonLinearAccumSpeed );

            #if( NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )

                float diffFastClamped = min( diffFastResult, GetLuma( diffHistory ) * diffMaxRelativeIntensity * REBLUR_FIREFLY_SUPPRESSOR_FAST_RELATIVE_INTENSITY );
                diffFastResult = lerp( diffFastResult, diffFastClamped, diffAntifireflyFactor );
            #endif

            NRD_SURFACE( gOut_DiffFast, pixelPos ) = diffFastResult;
        }
    #else
        float diffAccumSpeed = 0;
    #endif

    NRD_SURFACE( gOut_Data1, pixelPos ) = PackData1( diffAccumSpeed, specAccumSpeedCorrected );
}
