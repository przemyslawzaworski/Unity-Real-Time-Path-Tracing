/*
Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto. Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#ifndef REBLUR_SPATIAL_PASS
    #error REBLUR_SPATIAL_PASS must be defined!
#endif

#ifndef TEMPORAL_STABILIZATION
    #define TEMPORAL_STABILIZATION 0
#endif

#ifndef REBLUR_SPATIAL_LOBE
    #error REBLUR_SPATIAL_LOBE must be defined!
#endif

#ifndef MAX_BLUR_RADIUS
    #define MAX_BLUR_RADIUS             gMaxBlurRadius
#endif

#if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
    #define POISSON_SAMPLE_NUM          REBLUR_PRE_PASS_POISSON_SAMPLE_NUM
    #define POISSON_SAMPLES( i )        REBLUR_PRE_PASS_POISSON_SAMPLES( i )
#else
    #define POISSON_SAMPLE_NUM          REBLUR_POISSON_SAMPLE_NUM
    #define POISSON_SAMPLES( i )        REBLUR_POISSON_SAMPLES( i )
#endif

#if( REBLUR_SPATIAL_LOBE == REBLUR_DIFF )
    #define USE_SCREEN_SPACE            REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_DIFFUSE
    #define NON_LINEAR_ACCUM_SPEED      nonLinearAccumSpeed.x
    #define ACCUM_SPEED                 data1.x
    #define CHECKERBOARD                gDiffCheckerboard
    #define MIN_MATERIAL                gDiffMinMaterial
    #define ROUGHNESS                   1.0
    #define INPUT                       gIn_Diff
    #define INPUT_SH                    gIn_DiffSh
    #define OUTPUT                      gOut_Diff
    #define OUTPUT_SH                   gOut_DiffSh
    #define OUTPUT_COPY                 gOut_DiffCopy
    #define OUTPUT_SH_COPY              gOut_DiffShCopy
#else
    #define USE_SCREEN_SPACE            REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_SPECULAR
    #define NON_LINEAR_ACCUM_SPEED      nonLinearAccumSpeed.y
    #define ACCUM_SPEED                 data1.y
    #define CHECKERBOARD                gSpecCheckerboard
    #define MIN_MATERIAL                gSpecMinMaterial
    #define ROUGHNESS                   roughness
    #define INPUT                       gIn_Spec
    #define INPUT_SH                    gIn_SpecSh
    #define OUTPUT                      gOut_Spec
    #define OUTPUT_SH                   gOut_SpecSh
    #define OUTPUT_COPY                 gOut_SpecCopy
    #define OUTPUT_SH_COPY              gOut_SpecShCopy
#endif

{
    int2 inputPos = pixelPos;
#if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
    inputPos.x >>= CHECKERBOARD == 2 ? 0 : 1;
#endif

    float sum = 1.0;
    REBLUR_TYPE result = NRD_SURFACE( INPUT, inputPos );
    #if( NRD_MODE == NRD_MODE_SH )
        REBLUR_SH_TYPE resultSh = NRD_SURFACE( INPUT_SH, inputPos );
    #endif

#if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
    #if( NRD_SUPPORTS_CHECKERBOARD == 1 )
        if( CHECKERBOARD != 2 && checkerboard != CHECKERBOARD )
        {
            sum = 0;
            result = 0;
            #if( NRD_MODE == NRD_MODE_SH )
                resultSh = 0;
            #endif
        }
    #endif

    if( MAX_BLUR_RADIUS != 0.0 )
    {
    #if( REBLUR_SPATIAL_LOBE == REBLUR_SPEC )
        Rng::Hash::Initialize( pixelPos, gFrameIndex );
    #endif
#endif

    #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
        float radiusScale = REBLUR_PRE_PASS_RADIUS_SCALE;
        float fractionScale = REBLUR_PRE_PASS_FRACTION_SCALE;
    #elif( REBLUR_SPATIAL_PASS == REBLUR_BLUR )
        float radiusScale = REBLUR_BLUR_RADIUS_SCALE;
        float fractionScale = REBLUR_BLUR_FRACTION_SCALE;
    #elif( REBLUR_SPATIAL_PASS == REBLUR_POST_BLUR )
        float radiusScale = REBLUR_POST_BLUR_RADIUS_SCALE;
        float fractionScale = REBLUR_POST_BLUR_FRACTION_SCALE;
    #endif

        float4 Dv = ImportanceSampling::GetSpecularDominantDirection( Nv, Vv, ROUGHNESS, ML_SPECULAR_DOMINANT_DIRECTION_G2 );
        float NoD = abs( dot( Nv, Dv.xyz ) );
        float smc = GetSpecMagicCurve( ROUGHNESS, 0.5 );

        float hitDistScale = _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, ROUGHNESS );
        float hitDist = ExtractHitDist( result ) * hitDistScale;
        float hitDistFactor = GetHitDistFactor( hitDist, frustumSize );

    #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
        float areaFactor = hitDistFactor;
    #else
        float areaFactor = hitDistFactor * NON_LINEAR_ACCUM_SPEED;
    #endif

        float blurRadius = radiusScale * Math::Sqrt01( areaFactor );
        blurRadius = saturate( blurRadius ) * MAX_BLUR_RADIUS * smc;
        blurRadius = max( blurRadius, gMinBlurRadius * smc );

    #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS && REBLUR_SPATIAL_LOBE == REBLUR_SPEC )

        float lobeTanHalfAngle = ImportanceSampling::GetSpecularLobeTanHalfAngle( ROUGHNESS, REBLUR_MAX_PERCENT_OF_LOBE_VOLUME_FOR_PRE_PASS );
        float worldLobeRadius = hitDist * NoD * lobeTanHalfAngle;
        float lobeRadius = worldLobeRadius / PixelRadiusToWorld( gUnproject, gOrthoMode, 1.0, viewZ + hitDist * Dv.w );

        blurRadius = min( blurRadius, lobeRadius );
    #endif

        float2 geometryWeightParams = GetGeometryWeightParams( gPlaneDistSensitivity, frustumSize, Xv, Nv );
        float normalWeightParam = GetNormalWeightParam( NON_LINEAR_ACCUM_SPEED, gLobeAngleFraction, ROUGHNESS ) / fractionScale;
        float2 roughnessWeightParams = GetRoughnessWeightParams( ROUGHNESS, gRoughnessFraction * fractionScale );

        float2 hitDistanceWeightParams = GetHitDistanceWeightParams( ExtractHitDist( result ), NON_LINEAR_ACCUM_SPEED );
        float minHitDistWeight = gMinHitDistanceWeight * fractionScale * smc;

    #if( REBLUR_SPATIAL_PASS != REBLUR_PRE_PASS && NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
        minHitDistWeight *= NON_LINEAR_ACCUM_SPEED;
    #endif

    #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS || USE_SCREEN_SPACE == 1 )
        #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
            float2 skew = 1.0;
        #else
            #if( REBLUR_SPATIAL_LOBE == REBLUR_DIFF )
                float2 skew = lerp( 1.0 - abs( Nv.xy ), 1.0, NoV );
                skew /= max( skew.x, skew.y );
            #else
                float2 skew = 1.0;
            #endif
        #endif
        skew *= gRectSizeInv * blurRadius;

        float4 scaledRotator = Geometry::ScaleRotator( rotator, skew );
    #else

        #if( REBLUR_SPATIAL_LOBE == REBLUR_DIFF )
            float skewFactor = 1.0;
            float3 bentDv = Nv;
        #else
            float bentFactor = sqrt( hitDistFactor );

            float skewFactor = lerp( 0.25 + 0.75 * ROUGHNESS, 1.0, NoD );
            skewFactor = lerp( skewFactor, 1.0, NON_LINEAR_ACCUM_SPEED );
            skewFactor = lerp( 1.0, skewFactor, bentFactor );

            float3 bentDv = normalize( lerp( Nv.xyz, Dv.xyz, bentFactor ) );
        #endif

        float worldRadius = PixelRadiusToWorld( gUnproject, gOrthoMode, blurRadius, viewZ );

        float2x3 TvBv = GetKernelBasis( bentDv, Nv );
        TvBv[ 0 ] *= worldRadius * skewFactor;
        TvBv[ 1 ] *= worldRadius / skewFactor;
    #endif

        float hitDistForTracking = hitDist == 0.0 ? NRD_INF : hitDist;

        [unroll]
        for( uint n = 0; n < POISSON_SAMPLE_NUM; n++ )
        {
            float3 offset = POISSON_SAMPLES( n );

        #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS || USE_SCREEN_SPACE == 1 )
            float2 uv = pixelUv + Geometry::RotateVector( scaledRotator, offset.xy );
        #else
            float2 uv = GetKernelSampleCoordinates( gViewToClip, offset, Xv, TvBv[ 0 ], TvBv[ 1 ], rotator );
        #endif

            float2 mirrorUv = MirrorUv( uv );
            float w = any( uv != mirrorUv ) ? 1.0 : GetGaussianWeight( offset.z );

            int2 pos = int2( mirrorUv * gRectSize );

            int checkerboardX = pos.x;
            #if( NRD_SUPPORTS_CHECKERBOARD == 1 && REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
                if( CHECKERBOARD != 2 )
                {
                    const int shift = ( ( n & 0x1 ) == 0 ) ? -1 : 1;

                    bool isShifted = Sequence::CheckerBoard( pos, gFrameIndex ) != CHECKERBOARD;
                    pos.x += isShifted ? shift : 0;
                    mirrorUv.x += isShifted * gRectSizeInv.x * shift;

                    checkerboardX = pos.x >> 1;
                    w = pos.x < 0.0 || pos.x > gRectSizeMinusOne.x ? 0.0 : w;
                }
            #endif

            float zs = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, pos ) );
            float3 Xvs = Geometry::ReconstructViewPosition( mirrorUv, gFrustum, zs, gOrthoMode );

            float materialIDs;
            float4 Ns = NRD_SURFACE( gIn_Normal_Roughness, pos );
            Ns = NRD_FrontEnd_UnpackNormalAndRoughness( Ns, materialIDs );

            float angle = Math::AcosApproxPositive( dot( N, Ns.xyz ) );
            float NoX = dot( Nv, Xvs );

            w *= float( CompareMaterials( materialID, materialIDs, MIN_MATERIAL ) );
            w *= ComputeWeight( angle, normalWeightParam, 0.0 );
        #if( REBLUR_SPATIAL_LOBE == REBLUR_SPEC )
            w *= ComputeWeight( Ns.w, roughnessWeightParams.x, roughnessWeightParams.y );
        #endif
            w = ApplyGeometryWeightLast( w, zs, NoX, geometryWeightParams );

            REBLUR_TYPE s = NRD_SURFACE( INPUT, int2( checkerboardX, pos.y ) );
            s = Denanify( w, s );

        #if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS && REBLUR_SPATIAL_LOBE == REBLUR_SPEC )

            float hs = ExtractHitDist( s ) * _REBLUR_GetHitDistanceNormalization( zs, gHitDistSettings.xyz, Ns.w );
            float geometryWeight = w * NoV * float( hs != 0.0 );
            if( Rng::Hash::GetFloat( ) < geometryWeight )
                hitDistForTracking = min( hitDistForTracking, hs );

            w *= gUsePrepassNotOnlyForSpecularMotionEstimation;

            float d = length( Xvs - Xv ) + NRD_EPS;
            float t = hs / ( d + hitDist );
            w *= lerp( saturate( t ), 1.0, Math::LinearStep( 0.5, 1.0, ROUGHNESS ) );
        #endif

            w *= minHitDistWeight + ComputeExponentialWeight( ExtractHitDist( s ), hitDistanceWeightParams.x, hitDistanceWeightParams.y );

            sum += w;

            result += s * w;
            #if( NRD_MODE == NRD_MODE_SH )
                REBLUR_SH_TYPE sh = NRD_SURFACE( INPUT_SH, int2( checkerboardX, pos.y ) );
                sh = Denanify( w, sh );

                resultSh += sh * w;
            #endif
        }

        float invSum = Math::PositiveRcp( sum );
        result *= invSum;
        #if( NRD_MODE == NRD_MODE_SH )
            resultSh *= invSum;
        #endif

    #if( REBLUR_SPATIAL_PASS != REBLUR_PRE_PASS && NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
        result.w = hitDist / hitDistScale;
    #endif

#if( REBLUR_SPATIAL_PASS == REBLUR_PRE_PASS )
    #if( REBLUR_SPATIAL_LOBE == REBLUR_SPEC )

        NRD_SURFACE( gOut_SpecHitDistForTracking, pixelPos ) = hitDistForTracking == NRD_INF ? 0.0 : hitDistForTracking;
    #endif
    }

    #if( NRD_SUPPORTS_CHECKERBOARD == 1 )

        [branch]
        if( sum == 0.0 )
        {
            REBLUR_TYPE s0 = NRD_SURFACE( INPUT, checkerboardPos.xz );
            REBLUR_TYPE s1 = NRD_SURFACE( INPUT, checkerboardPos.yz );

            s0 = Denanify( wc.x, s0 );
            s1 = Denanify( wc.y, s1 );

            result = s0 * wc.x + s1 * wc.y;

            #if( NRD_MODE == NRD_MODE_SH )
                REBLUR_SH_TYPE sh0 = NRD_SURFACE( INPUT_SH, checkerboardPos.xz );
                REBLUR_SH_TYPE sh1 = NRD_SURFACE( INPUT_SH, checkerboardPos.yz );

                sh0 = Denanify( wc.x, sh0 );
                sh1 = Denanify( wc.y, sh1 );

                resultSh = sh0 * wc.x + sh1 * wc.y;
            #endif
        }
    #endif
#endif

    NRD_SURFACE( OUTPUT, pixelPos ) = result;
    #if( NRD_MODE == NRD_MODE_SH )
        NRD_SURFACE( OUTPUT_SH, pixelPos ) = resultSh;
    #endif

#if( REBLUR_SPATIAL_PASS == REBLUR_POST_BLUR && TEMPORAL_STABILIZATION == 0 )
    #if( NRD_MODE != NRD_MODE_OCCLUSION && NRD_MODE != NRD_MODE_DO )
        result.w = gReturnHistoryLengthInsteadOfOcclusion != 0 ? ACCUM_SPEED : result.w;
    #endif

    NRD_SURFACE( OUTPUT_COPY, pixelPos ) = result;
    #if( NRD_MODE == NRD_MODE_SH )
        NRD_SURFACE( OUTPUT_SH_COPY, pixelPos ) = resultSh;
    #endif
#endif
}

#undef POISSON_SAMPLE_NUM
#undef POISSON_SAMPLES
#undef USE_SCREEN_SPACE
#undef NON_LINEAR_ACCUM_SPEED
#undef ACCUM_SPEED
#undef CHECKERBOARD
#undef MIN_MATERIAL
#undef ROUGHNESS
#undef INPUT
#undef INPUT_SH
#undef OUTPUT
#undef OUTPUT_SH
#undef OUTPUT_COPY
#undef OUTPUT_SH_COPY
#undef REBLUR_SPATIAL_LOBE
#undef MAX_BLUR_RADIUS
