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
#include "REBLUR_HitDistReconstruction.resources.hlsli"

#include "Common.hlsli"

#include "REBLUR_Common.hlsli"

groupshared float4 s_Normal_Roughness[ BUFFER_Y ][ BUFFER_X ];
groupshared float3 s_HitDist_ViewZ[ BUFFER_Y ][ BUFFER_X ];

void Preload( uint2 sharedPos, int2 globalPos )
{
    globalPos = clamp( globalPos, 0, gRectSizeMinusOne );

    float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, globalPos ) );

    float4 normalAndRoughness = NRD_FrontEnd_UnpackNormalAndRoughness( NRD_SURFACE( gIn_Normal_Roughness, globalPos ) );
    s_Normal_Roughness[ sharedPos.y ][ sharedPos.x ] = normalAndRoughness;

    float2 hitDist = 0.0;
    #if( NRD_HAS_DIFF )
        hitDist.x = ExtractHitDist( NRD_SURFACE( gIn_Diff, globalPos ) );

        #if( REBLUR_USE_DECOMPRESSED_HIT_DIST_IN_RECONSTRUCTION == 1 )
            hitDist.x *= _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, 1.0 );
        #endif
    #endif

    #if( NRD_HAS_SPEC )
        hitDist.y = ExtractHitDist( NRD_SURFACE( gIn_Spec, globalPos ) );

        #if( REBLUR_USE_DECOMPRESSED_HIT_DIST_IN_RECONSTRUCTION == 1 )
            hitDist.y *= _REBLUR_GetHitDistanceNormalization( viewZ, gHitDistSettings.xyz, normalAndRoughness.w );
        #endif
    #endif

    s_HitDist_ViewZ[ sharedPos.y ][ sharedPos.x ] = float3( !IsInDenoisingRange( viewZ ) ? 0.0 : hitDist, viewZ );
}

[numthreads( GROUP_X, GROUP_Y, 1 )]
NRD_EXPORT void NRD_CS_MAIN( NRD_CS_MAIN_ARGS )
{
    NRD_CTA_ORDER_DEFAULT;

    float isSky = NRD_SURFACE( gIn_Tiles, pixelPos >> 4 ).x;
    PRELOAD_INTO_SMEM_WITH_TILE_CHECK;

    if( isSky != 0.0 || any( pixelPos > gRectSizeMinusOne ) )
        return;

    int2 smemPos = threadPos + NRD_BORDER;
    float3 center = s_HitDist_ViewZ[ smemPos.y ][ smemPos.x ];
    if( !IsInDenoisingRange( center.z ) )
        return;

    float4 normalAndRoughness = s_Normal_Roughness[ smemPos.y ][ smemPos.x ];
    float3 N = normalAndRoughness.xyz;
    float roughness = normalAndRoughness.w;

    float2 pixelUv = float2( pixelPos + 0.5 ) * gRectSizeInv;
    float3 Xv = Geometry::ReconstructViewPosition( pixelUv, gFrustum, center.z, gOrthoMode );
    float3 Nv = Geometry::RotateVectorInverse( gViewToWorld, N );
    float3 Vv = GetViewVector( Xv, true );

    float frustumSize = GetFrustumSize( gMinRectDimMulUnproject, gOrthoMode, center.z );

    float2 geometryWeightParams = GetGeometryWeightParams( gPlaneDistSensitivity, frustumSize, Xv, Nv );
    float2 relaxedRoughnessWeightParams = GetRelaxedRoughnessWeightParams( roughness * roughness );
    float diffNormalWeightParam = GetNormalWeightParam( 1.0, 1.0 );
    float specNormalWeightParam = GetNormalWeightParam( 1.0, 1.0, roughness );

    float2 sum = 1000.0 * float2( center.xy != 0.0 );
    center.xy *= sum;

    [unroll]
    for( j = 0; j <= NRD_BORDER * 2; j++ )
    {
        [unroll]
        for( i = 0; i <= NRD_BORDER * 2; i++ )
        {
            float2 o = float2( i, j ) - NRD_BORDER;
            if( o.x == 0.0 && o.y == 0.0 )
                continue;

            int2 pos = threadPos + int2( i, j );
            float3 data = s_HitDist_ViewZ[ pos.y ][ pos.x ];

            float w = IsInScreenNearest( pixelUv + o * gRectSizeInv );
            w *= GetGaussianWeight( length( o ) * 0.5 );

            float2 uv = pixelUv + o * gRectSizeInv;
            float3 Xvs = Geometry::ReconstructViewPosition( uv, gFrustum, data.z, gOrthoMode );
            float NoX = dot( Nv, Xvs );

            w *= ComputeWeight( NoX, geometryWeightParams.x, geometryWeightParams.y );

            float2 ww = w;
            #if( REBLUR_PERFORMANCE_MODE == 0 )
                float4 sampleNormalAndRoughness = s_Normal_Roughness[ pos.y ][ pos.x ];

                float cosa = dot( N, sampleNormalAndRoughness.xyz );
                float angle = Math::AcosApproxPositive( cosa );

                ww.x *= ComputeExponentialWeight( angle, diffNormalWeightParam, 0.0 );
                ww.y *= ComputeExponentialWeight( angle, specNormalWeightParam, 0.0 );
                ww.y *= ComputeExponentialWeight( sampleNormalAndRoughness.w * sampleNormalAndRoughness.w, relaxedRoughnessWeightParams.x, relaxedRoughnessWeightParams.y );
            #endif

            ww.x = data.x == 0.0 ? 0.0 : ww.x;
            ww.y = data.y == 0.0 ? 0.0 : ww.y;

            center.xy += data.xy * ww;
            sum += ww;
        }
    }

    center.xy /= max( sum, NRD_EPS );

    #if( REBLUR_USE_DECOMPRESSED_HIT_DIST_IN_RECONSTRUCTION == 1 )
        center.x /= _REBLUR_GetHitDistanceNormalization( center.z, gHitDistSettings.xyz, 1.0 );
        center.y /= _REBLUR_GetHitDistanceNormalization( center.z, gHitDistSettings.xyz, roughness );
    #endif

    #if( NRD_HAS_DIFF )
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            NRD_SURFACE( gOut_Diff, pixelPos ) = center.x;
        #else
            float3 diff = NRD_SURFACE( gIn_Diff, pixelPos ).xyz;
            NRD_SURFACE( gOut_Diff, pixelPos ) = float4( diff, center.x );
        #endif
    #endif

    #if( NRD_HAS_SPEC )
        #if( NRD_MODE == NRD_MODE_OCCLUSION )
            NRD_SURFACE( gOut_Spec, pixelPos ) = center.y;
        #else
            float3 spec = NRD_SURFACE( gIn_Spec, pixelPos ).xyz;
            NRD_SURFACE( gOut_Spec, pixelPos ) = float4( spec, center.y );
        #endif
    #endif
}
