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
#include "REBLUR_TemporalStabilization.resources.hlsli"

#include "Common.hlsli"

#include "REBLUR_Common.hlsli"

groupshared float s_DiffLuma[ BUFFER_Y ][ BUFFER_X ];
groupshared float s_SpecLuma[ BUFFER_Y ][ BUFFER_X ];

void Preload( uint2 sharedPos, int2 globalPos )
{
    globalPos = clamp( globalPos, 0, gRectSizeMinusOne );

    float viewZ = UnpackViewZ( NRD_SURFACE( gIn_ViewZ, globalPos ) );

    #if( NRD_HAS_DIFF )
        float diffLuma = GetLuma( NRD_SURFACE( gIn_Diff, globalPos ) );
        s_DiffLuma[ sharedPos.y ][ sharedPos.x ] = !IsInDenoisingRange( viewZ ) ? REBLUR_INVALID : diffLuma;
    #endif

    #if( NRD_HAS_SPEC )
        float specLuma = GetLuma( NRD_SURFACE( gIn_Spec, globalPos ) );
        s_SpecLuma[ sharedPos.y ][ sharedPos.x ] = !IsInDenoisingRange( viewZ ) ? REBLUR_INVALID : specLuma;
    #endif
}

[numthreads( GROUP_X, GROUP_Y, 1 )]
NRD_EXPORT void NRD_CS_MAIN( NRD_CS_MAIN_ARGS )
{
    NRD_CTA_ORDER_REVERSED;

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

    float4 inMv = NRD_SURFACE( gInOut_Mv, pixelPos );
    float3 mv = inMv.xyz * gMvScale.xyz + gMvBias.xyz;
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

    float materialID;
    float4 normalAndRoughness = NRD_FrontEnd_UnpackNormalAndRoughness( NRD_SURFACE( gIn_Normal_Roughness, pixelPos ), materialID );
    float3 N = normalAndRoughness.xyz;
    float roughness = normalAndRoughness.w;

    uint bits;
    bool smbAllowCatRom;
    REBLUR_DATA1_TYPE data1 = UnpackData1( NRD_SURFACE( gIn_Data1, pixelPos ) );
    float2 data2 = UnpackData2( NRD_SURFACE( gIn_Data2, pixelPos ), bits, smbAllowCatRom );

    Filtering::Bilinear smbBilinearFilter = Filtering::GetBilinearFilter( smbPixelUv, gRectSizePrev );
    float4 smbOcclusion = float4( ( bits & uint4( 1, 2, 4, 8 ) ) != 0 );

    float4 smbOcclusionWeights = Filtering::GetBilinearCustomWeights( smbBilinearFilter, smbOcclusion );
    float smbFootprintQuality = Filtering::ApplyBilinearFilter( smbOcclusion.x, smbOcclusion.y, smbOcclusion.z, smbOcclusion.w, smbBilinearFilter );
    smbFootprintQuality = Math::Sqrt01( smbFootprintQuality );

    int2 smemPos = threadPos + NRD_BORDER;

    #if( NRD_HAS_DIFF )
        float diffLuma = s_DiffLuma[ smemPos.y ][ smemPos.x ];
        float diffLumaM1 = diffLuma;
        float diffLumaM2 = diffLuma * diffLuma;

        [unroll]
        for( j = 0; j <= NRD_BORDER * 2; j++ )
        {
            [unroll]
            for( i = 0; i <= NRD_BORDER * 2; i++ )
            {
                if( i == NRD_BORDER && j == NRD_BORDER )
                    continue;

                int2 pos = threadPos + int2( i, j );

                float d = s_DiffLuma[ pos.y ][ pos.x ];
                d = d == REBLUR_INVALID ? diffLuma : d;

                diffLumaM1 += d;
                diffLumaM2 += d * d;
            }
        }

        diffLumaM1 /= ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 );
        diffLumaM2 /= ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 );

        float diffLumaSigma = GetStdDev( diffLumaM1, diffLumaM2 );

        if( data1.x < gHistoryFixFrameNum )
            diffLuma = min( diffLuma, diffLumaM1 * ( 1.2 + 1.0 / ( 1.0 + data1.x ) ) );

        float diffLumaHistory;

        BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights(
            NRD_PIXEL_POS( gHistory_DiffLumaStabilized, saturate( smbPixelUv ) * gRectSizePrev ), gResourceSizeInvPrev,
            smbOcclusionWeights, smbAllowCatRom,
            gHistory_DiffLumaStabilized, diffLumaHistory
        );

        diffLumaHistory = max( diffLumaHistory, 0.0 );

        float diffAntilag = ComputeAntilag( diffLumaHistory, diffLumaM1, diffLumaSigma, smbFootprintQuality * data1.x );

        float diffMinAccumSpeed = min( data1.x, gHistoryFixFrameNum ) * REBLUR_USE_ANTILAG_NOT_INVOKING_HISTORY_FIX;
        data1.x = lerp( diffMinAccumSpeed, data1.x, diffAntilag );

        float2 diffTemporalAccumulationParams = GetTemporalAccumulationParams( smbFootprintQuality, data1.x, diffAntilag );

        float diffHistoryWeight = diffTemporalAccumulationParams.x;
        diffHistoryWeight *= float( pixelUv.x >= gSplitScreen );
        diffHistoryWeight *= float( smbPixelUv.x >= gSplitScreenPrev );

        diffLumaHistory = Color::Clamp( diffLumaM1, diffLumaSigma * diffTemporalAccumulationParams.y, diffLumaHistory );

        float diffLumaStabilized = lerp( diffLuma, diffLumaHistory, min( diffHistoryWeight, gStabilizationStrength ) );

        REBLUR_TYPE diff = NRD_SURFACE( gIn_Diff, pixelPos );
        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE diffSh = NRD_SURFACE( gIn_DiffSh, pixelPos );
            diffSh *= GetLumaScale( GetLuma( diff ), diffLumaStabilized );
        #endif
        diff = ChangeLuma( diff, diffLumaStabilized );

        diff.w = gReturnHistoryLengthInsteadOfOcclusion != 0 ? data1.x : diff.w;

        NRD_SURFACE( gOut_Diff, pixelPos ) = diff;
        NRD_SURFACE( gOut_DiffLumaStabilized, pixelPos ) = diffLumaStabilized;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_DiffSh, pixelPos ) = diffSh;
        #endif
    #endif

    #if( NRD_HAS_SPEC )
        float specLuma = s_SpecLuma[ smemPos.y ][ smemPos.x ];
        float specLumaM1 = specLuma;
        float specLumaM2 = specLuma * specLuma;

        [unroll]
        for( j = 0; j <= NRD_BORDER * 2; j++ )
        {
            [unroll]
            for( i = 0; i <= NRD_BORDER * 2; i++ )
            {
                if( i == NRD_BORDER && j == NRD_BORDER )
                    continue;

                int2 pos = threadPos + int2( i, j );

                float s = s_SpecLuma[ pos.y ][ pos.x ];
                s = s == REBLUR_INVALID ? specLuma : s;

                specLumaM1 += s;
                specLumaM2 += s * s;
            }
        }

        specLumaM1 /= ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 );
        specLumaM2 /= ( NRD_BORDER * 2 + 1 ) * ( NRD_BORDER * 2 + 1 );

        float specLumaSigma = GetStdDev( specLumaM1, specLumaM2 );

        if( data1.y < gHistoryFixFrameNum )
            specLuma = min( specLuma, specLumaM1 * ( 1.2 + 1.0 / ( 1.0 + data1.y ) ) );

        float hitDistForTracking = NRD_SURFACE( gIn_SpecHitDistForTracking, pixelPos );

        float virtualHistoryAmount = data2.x;
        float curvature = data2.y;

        float3 V = GetViewVector( X );
        float NoV = abs( dot( N, V ) );
        float3 Xvirtual = GetXvirtual( hitDistForTracking, curvature, X, Xprev, N, V, roughness );

        float2 vmbPixelUv = Geometry::GetScreenUv( gWorldToClipPrev, Xvirtual );
        vmbPixelUv = materialID == gCameraAttachedReflectionMaterialID ? smbPixelUv : vmbPixelUv;

        Filtering::Bilinear vmbBilinearFilter = Filtering::GetBilinearFilter( vmbPixelUv, gRectSizePrev );
        float4 vmbOcclusion = float4( ( bits & uint4( 16, 32, 64, 128 ) ) != 0 );
        float4 vmbOcclusionWeights = Filtering::GetBilinearCustomWeights( vmbBilinearFilter, vmbOcclusion );

        bool vmbAllowCatRom = dot( vmbOcclusion, 1.0 ) > 3.5 && REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TS == 1;
        vmbAllowCatRom = vmbAllowCatRom && smbAllowCatRom;

        float vmbFootprintQuality = Filtering::ApplyBilinearFilter( vmbOcclusion.x, vmbOcclusion.y, vmbOcclusion.z, vmbOcclusion.w, vmbBilinearFilter );
        vmbFootprintQuality = Math::Sqrt01( vmbFootprintQuality );

        float2 uv = lerp( smbPixelUv, vmbPixelUv, virtualHistoryAmount );
        float4 occlusionWeights = lerp( smbOcclusionWeights, vmbOcclusionWeights, virtualHistoryAmount );
        bool allowCatRom = virtualHistoryAmount < 0.5 ? smbAllowCatRom : vmbAllowCatRom;

        float specLumaHistory;

        BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights(
            NRD_PIXEL_POS( gHistory_SpecLumaStabilized, saturate( uv ) * gRectSizePrev ), gResourceSizeInvPrev,
            occlusionWeights, allowCatRom,
            gHistory_SpecLumaStabilized, specLumaHistory
        );

        specLumaHistory = max( specLumaHistory, 0.0 );

        float footprintQuality = lerp( smbFootprintQuality, vmbFootprintQuality, virtualHistoryAmount );

        float specAntilag = ComputeAntilag( specLumaHistory, specLumaM1, specLumaSigma, footprintQuality * data1.y );

        float specMinAccumSpeed = min( data1.y, gHistoryFixFrameNum ) * REBLUR_USE_ANTILAG_NOT_INVOKING_HISTORY_FIX;
        data1.y = lerp( specMinAccumSpeed, data1.y, specAntilag );

        float2 specTemporalAccumulationParams = GetTemporalAccumulationParams( footprintQuality, data1.y, specAntilag );

        float specHistoryWeight = specTemporalAccumulationParams.x;
        specHistoryWeight *= float( pixelUv.x >= gSplitScreen );
        specHistoryWeight *= virtualHistoryAmount != 1.0 ? float( smbPixelUv.x >= gSplitScreenPrev ) : 1.0;
        specHistoryWeight *= virtualHistoryAmount != 0.0 ? float( vmbPixelUv.x >= gSplitScreenPrev ) : 1.0;

        float responsiveFactor = RemapRoughnessToResponsiveFactor( roughness );
        float smc = GetSpecMagicCurve( roughness );
        float acceleration = lerp( smc, 1.0, 0.5 + responsiveFactor * 0.5 );
        if( materialID == gStrandMaterialID )
            acceleration = min( acceleration, 0.5 );

        specHistoryWeight *= acceleration;

        specLumaHistory = Color::Clamp( specLumaM1, specLumaSigma * specTemporalAccumulationParams.y, specLumaHistory );

        float specLumaStabilized = lerp( specLuma, specLumaHistory, min( specHistoryWeight, gStabilizationStrength ) );

        REBLUR_TYPE spec = NRD_SURFACE( gIn_Spec, pixelPos );
        #if( NRD_MODE == NRD_MODE_SH )
            REBLUR_SH_TYPE specSh = NRD_SURFACE( gIn_SpecSh, pixelPos );
            specSh *= GetLumaScale( GetLuma( spec ), specLumaStabilized );
        #endif
        spec = ChangeLuma( spec, specLumaStabilized );

        spec.w = gReturnHistoryLengthInsteadOfOcclusion != 0 ? data1.y : spec.w;

        NRD_SURFACE( gOut_Spec, pixelPos ) = spec;
        NRD_SURFACE( gOut_SpecLumaStabilized, pixelPos ) = specLumaStabilized;
        #if( NRD_MODE == NRD_MODE_SH )
            NRD_SURFACE( gOut_SpecSh, pixelPos ) = specSh;
        #endif
    #endif

    NRD_SURFACE( gOut_InternalData, pixelPos ) = PackInternalData( data1.x, data1.y, materialID );
}
