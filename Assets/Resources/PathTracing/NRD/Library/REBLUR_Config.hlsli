/*
Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto. Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#ifndef NRD_MODE
    #define NRD_MODE                                             NRD_MODE_RADIANCE
#endif

#ifndef NRD_SIGNAL
    #define NRD_SIGNAL                                           NRD_SIGNAL_BOTH
#endif

#ifndef REBLUR_PERFORMANCE_MODE
    #define REBLUR_PERFORMANCE_MODE                             0
#endif

#ifndef REBLUR_COPY_GBUFFER
    #define REBLUR_COPY_GBUFFER                                 1
#endif

#define REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TA              1
#define REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TA              1
#define REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TS              1
#define REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TS              1
#define REBLUR_USE_YCOCG                                        1
#define REBLUR_USE_CONFIDENCE_NON_LINEARLY                      1
#define REBLUR_USE_STF                                          1
#define REBLUR_USE_ANTILAG_NOT_INVOKING_HISTORY_FIX             1
#define REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_DIFFUSE            1

#define REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_SPECULAR           0
#define REBLUR_USE_DECOMPRESSED_HIT_DIST_IN_RECONSTRUCTION      0

#if( NRD_MODE == NRD_MODE_OCCLUSION || NRD_MODE == NRD_MODE_DO )
    #undef NRD_SUPPORTS_ANTIFIREFLY
    #define NRD_SUPPORTS_ANTIFIREFLY                            0
#endif

#define REBLUR_SHOW_FAST_HISTORY                                1
#define REBLUR_SHOW_CURVATURE                                   2
#define REBLUR_SHOW_CURVATURE_SIGN                              3
#define REBLUR_SHOW_SURFACE_HISTORY_CONFIDENCE                  4
#define REBLUR_SHOW_VIRTUAL_HISTORY_CONFIDENCE                  5
#define REBLUR_SHOW_HIT_DIST_FOR_TRACKING                       6

#define REBLUR_SHOW                                             0

#define REBLUR_PRE_PASS                                         0
#define REBLUR_BLUR                                             1
#define REBLUR_POST_BLUR                                        2

#define REBLUR_DIFF                                             0
#define REBLUR_SPEC                                             1

#define REBLUR_ACCUMSPEED_BITS                                  6
#define REBLUR_MATERIALID_BITS                                  ( 16 - REBLUR_ACCUMSPEED_BITS - REBLUR_ACCUMSPEED_BITS )
#define REBLUR_MAX_ACCUM_FRAME_NUM                              ( ( 1 << REBLUR_ACCUMSPEED_BITS ) - 1 )
#define REBLUR_MAX_MATERIALID_NUM                               ( ( 1 << REBLUR_MATERIALID_BITS ) - 1 )

#define REBLUR_PRE_PASS_POISSON_SAMPLE_NUM                      8
#define REBLUR_PRE_PASS_POISSON_SAMPLES( i )                    g_Special8[ i ]

#define REBLUR_POISSON_SAMPLE_NUM                               8
#define REBLUR_POISSON_SAMPLES( i )                             g_Special8[ i ]

#define REBLUR_PRE_PASS_ROTATOR_MODE                            NRD_FRAME
#define REBLUR_PRE_PASS_FRACTION_SCALE                          2.0
#define REBLUR_PRE_PASS_RADIUS_SCALE                            1.0
#define REBLUR_PRE_PASS_NON_LINEAR_ACCUM_SPEED                  ( 1.0 / ( 1.0 + 10.0 ) )

#define REBLUR_BLUR_ROTATOR_MODE                                NRD_FRAME
#define REBLUR_BLUR_FRACTION_SCALE                              1.0
#define REBLUR_BLUR_RADIUS_SCALE                                1.0

#define REBLUR_POST_BLUR_ROTATOR_MODE                           NRD_FRAME
#define REBLUR_POST_BLUR_FRACTION_SCALE                         0.5
#define REBLUR_POST_BLUR_RADIUS_SCALE                           2.0

#define REBLUR_FRAME_RATE_COMPENSATION                          ( gFrameRateScale * 0.75 )

#define REBLUR_NORMAL_ULP                                       0.0
#define REBLUR_ALMOST_ZERO_ANGLE                                cos( Math::DegToRad( 89.0 ) )
#define REBLUR_VIRTUAL_MOTION_PREV_PREV_WEIGHT_ITERATION_NUM    1
#define REBLUR_FIREFLY_SUPPRESSOR_MAX_RELATIVE_INTENSITY        38.0
#define REBLUR_FIREFLY_SUPPRESSOR_RADIUS_SCALE                  0.1
#define REBLUR_FIREFLY_SUPPRESSOR_FAST_RELATIVE_INTENSITY       4.0
#define REBLUR_ANTI_FIREFLY_FILTER_RADIUS                       4
#define REBLUR_FAST_HISTORY_CLAMPING_RADIUS                     2
#define REBLUR_ANTI_FIREFLY_SIGMA_SCALE                         2.0
#define REBLUR_HISTORY_FIX_FILTER_RADIUS                        2
#define REBLUR_ROUGHNESS_SENSITIVITY_IN_TA                      ( NRD_ROUGHNESS_SENSITIVITY * 0.3 )
#define REBLUR_ANTILAG_MODE                                     2
#define REBLUR_MAX_PERCENT_OF_LOBE_VOLUME_FOR_PRE_PASS          0.3
#define REBLUR_INVALID                                          -32768.0

#if( NRD_MODE == NRD_MODE_OCCLUSION )
    #define REBLUR_TYPE                                         float
#else
    #define REBLUR_TYPE                                         float4
#endif

#define REBLUR_SH_TYPE                                          float3
#define REBLUR_FAST_TYPE                                        float
#define REBLUR_DATA1_TYPE                                       float2
#define REBLUR_TILE_TYPE                                        float

#define REBLUR_SHARED_CONSTANTS \
    NRD_CONSTANT( float4x4, gWorldToClip ) \
    NRD_CONSTANT( float4x4, gViewToClip ) \
    NRD_CONSTANT( float4x4, gViewToWorld ) \
    NRD_CONSTANT( float4x4, gWorldToViewPrev ) \
    NRD_CONSTANT( float4x4, gWorldToClipPrev ) \
    NRD_CONSTANT( float4x4, gWorldPrevToWorld ) \
    NRD_CONSTANT( float4, gRotatorPre ) \
    NRD_CONSTANT( float4, gRotator ) \
    NRD_CONSTANT( float4, gRotatorPost ) \
    NRD_CONSTANT( float4, gFrustum ) \
    NRD_CONSTANT( float4, gFrustumPrev ) \
    NRD_CONSTANT( float4, gCameraDelta ) \
    NRD_CONSTANT( float4, gHitDistSettings ) \
    NRD_CONSTANT( float4, gViewVectorWorld ) \
    NRD_CONSTANT( float4, gViewVectorWorldPrev ) \
    NRD_CONSTANT( float4, gMvScale ) \
    NRD_CONSTANT( float4, gMvBias ) \
    NRD_CONSTANT( float4, gConvergenceSettings ) \
    NRD_CONSTANT( float2, gAntilagSettings ) \
    NRD_CONSTANT( float2, gResourceSize ) \
    NRD_CONSTANT( float2, gResourceSizeInv ) \
    NRD_CONSTANT( float2, gResourceSizeInvPrev ) \
    NRD_CONSTANT( float2, gRectSize ) \
    NRD_CONSTANT( float2, gRectSizeInv ) \
    NRD_CONSTANT( float2, gRectSizePrev ) \
    NRD_CONSTANT( float2, gResolutionScale ) \
    NRD_CONSTANT( float2, gResolutionScalePrev ) \
    NRD_CONSTANT( float2, gJitter ) \
    NRD_CONSTANT( uint2, gPrintfAt ) \
    NRD_CONSTANT( int2, gInputRectOrigin ) \
    NRD_CONSTANT( int2, gOutputRectOrigin ) \
    NRD_CONSTANT( int2, gDispatchInputRectOrigin ) \
    NRD_CONSTANT( int2, gDispatchOutputRectOrigin ) \
    NRD_CONSTANT( int2, gRectSizeMinusOne ) \
    NRD_CONSTANT( float, gDisocclusionThreshold ) \
    NRD_CONSTANT( float, gDisocclusionThresholdAlternate ) \
    NRD_CONSTANT( float, gCameraAttachedReflectionMaterialID ) \
    NRD_CONSTANT( float, gStrandMaterialID ) \
    NRD_CONSTANT( float, gStrandThickness ) \
    NRD_CONSTANT( float, gStabilizationStrength ) \
    NRD_CONSTANT( float, gDebug ) \
    NRD_CONSTANT( float, gOrthoMode ) \
    NRD_CONSTANT( float, gUnproject ) \
    NRD_CONSTANT( float, gDenoisingRange ) \
    NRD_CONSTANT( float, gPlaneDistSensitivity ) \
    NRD_CONSTANT( float, gFrameRateScale ) \
    NRD_CONSTANT( float, gFrameRateScaleSmoothed ) \
    NRD_CONSTANT( float, gMinBlurRadius ) \
    NRD_CONSTANT( float, gMaxBlurRadius ) \
    NRD_CONSTANT( float, gDiffPrepassBlurRadius ) \
    NRD_CONSTANT( float, gSpecPrepassBlurRadius ) \
    NRD_CONSTANT( float, gMaxAccumulatedFrameNum ) \
    NRD_CONSTANT( float, gMaxFastAccumulatedFrameNum ) \
    NRD_CONSTANT( float, gAntiFirefly ) \
    NRD_CONSTANT( float, gLobeAngleFraction ) \
    NRD_CONSTANT( float, gRoughnessFraction ) \
    NRD_CONSTANT( float, gHistoryFixFrameNum ) \
    NRD_CONSTANT( float, gHistoryFixBasePixelStride ) \
    NRD_CONSTANT( float, gHistoryFixAlternatePixelStride ) \
    NRD_CONSTANT( float, gHistoryFixAlternatePixelStrideMaterialID ) \
    NRD_CONSTANT( float, gFastHistoryClampingSigmaScale ) \
    NRD_CONSTANT( float, gMinRectDimMulUnproject ) \
    NRD_CONSTANT( float, gUsePrepassNotOnlyForSpecularMotionEstimation ) \
    NRD_CONSTANT( float, gSplitScreen ) \
    NRD_CONSTANT( float, gSplitScreenPrev ) \
    NRD_CONSTANT( float, gCheckerboardResolveAccumSpeed ) \
    NRD_CONSTANT( float, gViewZScale ) \
    NRD_CONSTANT( float, gFireflySuppressorMinRelativeScale ) \
    NRD_CONSTANT( float, gMinHitDistanceWeight ) \
    NRD_CONSTANT( float, gDiffMinMaterial ) \
    NRD_CONSTANT( float, gSpecMinMaterial ) \
    NRD_CONSTANT( float, gResponsiveAccumulationInvRoughnessThreshold ) \
    NRD_CONSTANT( uint, gResponsiveAccumulationMinAccumulatedFrameNum ) \
    NRD_CONSTANT( uint, gHasHistoryConfidence ) \
    NRD_CONSTANT( uint, gHasDisocclusionThresholdMix ) \
    NRD_CONSTANT( uint, gDiffCheckerboard ) \
    NRD_CONSTANT( uint, gSpecCheckerboard ) \
    NRD_CONSTANT( uint, gFrameIndex ) \
    NRD_CONSTANT( uint, gIsRectChanged ) \
    NRD_CONSTANT( uint, gResetHistory ) \
    NRD_CONSTANT( uint, gReturnHistoryLengthInsteadOfOcclusion )

#if( REBLUR_PERFORMANCE_MODE == 1 )
    #undef REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TA
    #define REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TA          0

    #undef REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TA
    #define REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TA          0

    #undef REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TS
    #define REBLUR_USE_CATROM_FOR_SURFACE_MOTION_IN_TS          0

    #undef REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TS
    #define REBLUR_USE_CATROM_FOR_VIRTUAL_MOTION_IN_TS          0

    #undef REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_DIFFUSE
    #define REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_DIFFUSE        1

    #undef REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_SPECULAR
    #define REBLUR_USE_SCREEN_SPACE_SAMPLING_FOR_SPECULAR       1

    #undef REBLUR_POISSON_SAMPLE_NUM
    #define REBLUR_POISSON_SAMPLE_NUM                           6

    #undef REBLUR_POISSON_SAMPLES
    #define REBLUR_POISSON_SAMPLES( i )                         g_Special6[ i ]

    #undef REBLUR_PRE_PASS_POISSON_SAMPLE_NUM
    #define REBLUR_PRE_PASS_POISSON_SAMPLE_NUM                  6

    #undef REBLUR_PRE_PASS_POISSON_SAMPLES
    #define REBLUR_PRE_PASS_POISSON_SAMPLES( i )                g_Special6[ i ]

    #undef REBLUR_PRE_PASS_ROTATOR_MODE
    #define REBLUR_PRE_PASS_ROTATOR_MODE                        NRD_FRAME

    #undef REBLUR_BLUR_ROTATOR_MODE
    #define REBLUR_BLUR_ROTATOR_MODE                            NRD_FRAME

    #undef REBLUR_POST_BLUR_ROTATOR_MODE
    #define REBLUR_POST_BLUR_ROTATOR_MODE                       NRD_FRAME

    #undef REBLUR_ANTI_FIREFLY_FILTER_RADIUS
    #define REBLUR_ANTI_FIREFLY_FILTER_RADIUS                   3
#endif
