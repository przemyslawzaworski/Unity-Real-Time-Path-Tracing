/*
Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto. Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#ifndef NRD_INTERNAL
    #error "'NRD_INTERNAL' is not defined, but expected!"
#endif

#ifndef NRD_SUPPORTS_VIEWPORT_OFFSET
    #define NRD_SUPPORTS_VIEWPORT_OFFSET                        0
#endif

#ifndef NRD_SUPPORTS_CHECKERBOARD
    #define NRD_SUPPORTS_CHECKERBOARD                           1
#endif

#ifndef NRD_SUPPORTS_HISTORY_CONFIDENCE
    #define NRD_SUPPORTS_HISTORY_CONFIDENCE                     1
#endif

#ifndef NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX
    #define NRD_SUPPORTS_DISOCCLUSION_THRESHOLD_MIX             1
#endif

#ifndef NRD_SUPPORTS_ANTIFIREFLY
    #define NRD_SUPPORTS_ANTIFIREFLY                            1
#endif

#ifndef NRD_SUPPORTS_QUAD_INTRINSICS
    #if( defined( NRD_COMPILER_DXC ) || defined( NRD_COMPILER_PSSLC ) )
        #define NRD_SUPPORTS_QUAD_INTRINSICS                    1
    #else
        #define NRD_SUPPORTS_QUAD_INTRINSICS                    0
    #endif
#else
    #if( defined( NRD_COMPILER_FXC ) )
        #undef NRD_SUPPORTS_QUAD_INTRINSICS
        #define NRD_SUPPORTS_QUAD_INTRINSICS                    0
    #endif
#endif

#define NRD_USE_TILE_CHECK                                      1
#define NRD_USE_DENANIFICATION                                  1

#define NRD_USE_QUADRATIC_DISTRIBUTION                          0
#define NRD_USE_EXPONENTIAL_WEIGHTS                             0
#define NRD_USE_PREV_WORLD_SPACE_MATRIX                         0

#define NRD_DISOCCLUSION_THRESHOLD                              0.02
#define NRD_CATROM_SHARPNESS                                    0.5
#define NRD_RADIANCE_COMPRESSION_MODE                           3
#define NRD_EXP_WEIGHT_DEFAULT_SCALE                            3.0
#define NRD_ROUGHNESS_SENSITIVITY                               0.01
#define NRD_CURVATURE_HIGH_PARALLAX_DISOCCLUSION_THRESHOLD      0.04
#define NRD_MAX_ALLOWED_VIRTUAL_MOTION_ACCELERATION             5.0
#define NRD_MAX_PERCENT_OF_LOBE_VOLUME                          0.75
#define NRD_STRAND_RELAXED_DISOCCLUSION_THRESHOLD               0.25

#if( NRD_NORMAL_ENCODING < NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
    #define NRD_NORMAL_ENCODING_ERROR                           ( 1.50 / 255.0 )
    #define STOCHASTIC_BILINEAR_FILTER                          gLinearClamp
#elif( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
    #define NRD_NORMAL_ENCODING_ERROR                           ( 0.75 / 255.0 )
    #define STOCHASTIC_BILINEAR_FILTER                          gNearestClamp
#else
    #define NRD_NORMAL_ENCODING_ERROR                           ( 0.40 / 255.0 )
    #define STOCHASTIC_BILINEAR_FILTER                          gLinearClamp
#endif

#define NRD_NONE                                                0
#define NRD_FRAME                                               1
#define NRD_PIXEL                                               2
#define NRD_RANDOM                                              3

#ifdef __hlsl_dx_compiler
    #define half_float float16_t
    #define half_float2 float16_t2
    #define half_float3 float16_t3
    #define half_float4 float16_t4
#else
    #define half_float float
    #define half_float2 float2
    #define half_float3 float3
    #define half_float4 float4
#endif

#define NRD_CS_MAIN_ARGS                                        int2 threadPos : SV_GroupThreadID, uint2 groupPos : SV_GroupID, int2 _pixelPos : SV_DispatchThreadID, uint threadIndex : SV_GroupIndex

#if 1

    #define NRD_CTA_ORDER_REVERSED \
        const uint2 numGroups = ( uint2( gRectSize ) + uint2( GROUP_X, GROUP_Y ) - 1 ) / uint2( GROUP_X, GROUP_Y ); \
        const int2 pixelPos = ( numGroups - 1 - groupPos ) * uint2( GROUP_X, GROUP_Y ) + threadPos
#else
    #define NRD_CTA_ORDER_REVERSED \
        const int2 pixelPos = _pixelPos
#endif

#define NRD_CTA_ORDER_DEFAULT \
    const int2 pixelPos = _pixelPos

#define BUFFER_X ( GROUP_X + NRD_BORDER * 2 )
#define BUFFER_Y ( GROUP_Y + NRD_BORDER * 2 )

#define PRELOAD_INTO_SMEM_WITH_TILE_CHECK \
    isSky *= NRD_USE_TILE_CHECK; \
    if( isSky == 0.0 ) \
    { \
        int2 groupBase = pixelPos - threadPos - NRD_BORDER; \
        uint stageNum = ( BUFFER_X * BUFFER_Y + GROUP_X * GROUP_Y - 1 ) / ( GROUP_X * GROUP_Y ); \
        [unroll] \
        for( uint stage = 0; stage < stageNum; stage++ ) \
        { \
            uint virtualIndex = threadIndex + stage * GROUP_X * GROUP_Y; \
            uint2 newId = uint2( virtualIndex % BUFFER_X, virtualIndex / BUFFER_X ); \
            if( stage == 0 || virtualIndex < BUFFER_X * BUFFER_Y ) \
                Preload( newId, groupBase + newId ); \
        } \
    } \
    GroupMemoryBarrierWithGroupSync( ); \
                                                                                     \
    int i, j

#define PRELOAD_INTO_SMEM \
    int2 groupBase = pixelPos - threadPos - NRD_BORDER; \
    uint stageNum = ( BUFFER_X * BUFFER_Y + GROUP_X * GROUP_Y - 1 ) / ( GROUP_X * GROUP_Y ); \
    [unroll] \
    for( uint stage = 0; stage < stageNum; stage++ ) \
    { \
        uint virtualIndex = threadIndex + stage * GROUP_X * GROUP_Y; \
        uint2 newId = uint2( virtualIndex % BUFFER_X, virtualIndex / BUFFER_X ); \
        if( stage == 0 || virtualIndex < BUFFER_X * BUFFER_Y ) \
            Preload( newId, groupBase + newId ); \
    } \
    GroupMemoryBarrierWithGroupSync( ); \
                                                                                     \
    int i, j

#if( defined( __hlsl_dx_compiler ) && defined( __spirv__ ) )
    #define PRINTF_AVAILABLE
    #define PrintfAt(...) \
        if( uint( pixelPos.x ) == gPrintfAt.x && uint( pixelPos.y ) == gPrintfAt.y ) \
            printf(__VA_ARGS__)
#endif

#include "Poisson.hlsli"

static const float3 g_Special6[ 6 ] =
{

    float3( -0.50 * sqrt( 3.0 ) , -0.50             , 1.0 ),
    float3(  0.00               ,  1.00             , 1.0 ),
    float3(  0.50 * sqrt( 3.0 ) , -0.50             , 1.0 ),
    float3(  0.00               , -0.30             , 0.3 ),
    float3(  0.15 * sqrt( 3.0 ) ,  0.15             , 0.3 ),
    float3( -0.15 * sqrt( 3.0 ) ,  0.15             , 0.3 ),
};

static const float3 g_Special8[ 8 ] =
{

    float3( -1.00               ,  0.00               , 1.0 ),
    float3(  0.00               ,  1.00               , 1.0 ),
    float3(  1.00               ,  0.00               , 1.0 ),
    float3(  0.00               , -1.00               , 1.0 ),
    float3( -0.25 * sqrt( 2.0 ) ,  0.25 * sqrt( 2.0 ) , 0.5 ),
    float3(  0.25 * sqrt( 2.0 ) ,  0.25 * sqrt( 2.0 ) , 0.5 ),
    float3(  0.25 * sqrt( 2.0 ) , -0.25 * sqrt( 2.0 ) , 0.5 ),
    float3( -0.25 * sqrt( 2.0 ) , -0.25 * sqrt( 2.0 ) , 0.5 )
};

#if( NRD_USE_DENANIFICATION == 1 )

    #if( NRD_SUPPORTS_VIEWPORT_OFFSET == 1 )
        #define ClampUvToViewport( uv )         clamp( uv * gResolutionScale, 0.0, gResolutionScale - 0.5 * gResourceSizeInv )
    #else
        #define ClampUvToViewport( uv )         min( uv * gResolutionScale, gResolutionScale - 0.5 * gResourceSizeInv )
    #endif
    #define Denanify( w, x )                    ( ( w ) == 0.0 ? 0.0 : ( x ) )
#else
    #define ClampUvToViewport( uv )             ( uv * gResolutionScale )
    #define Denanify( w, x )                    ( x )
#endif

#define GetStdDev( m1, m2 )                     sqrt( abs( ( m2 ) - ( m1 ) * ( m1 ) ) )

#if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
    #define CompareMaterials( m0, m, minm )     ( max( m0, minm ) == max( m, minm ) )
#else
    #define CompareMaterials( m0, m, minm )     true
#endif

#define UnpackViewZ( z )                        abs( z * gViewZScale )
#define IsInDenoisingRange( z )                 ( z < gDenoisingRange )

float PixelRadiusToWorld( float unproject, float orthoMode, float pixelRadius, float viewZ )
{
     return pixelRadius * unproject * lerp( viewZ, 1.0, abs( orthoMode ) );
}

float GetFrustumSize( float minRectDimMulUnproject, float orthoMode, float viewZ )
{

    return minRectDimMulUnproject * lerp( viewZ, 1.0, abs( orthoMode ) );
}

float GetHitDistFactor( float hitDist, float frustumSize )
{
    return saturate( hitDist / frustumSize );
}

float4 GetBlurKernelRotation( compiletime const uint mode, uint2 pixelPos, float4 baseRotator, uint frameIndex )
{
    if( mode == NRD_NONE )
        return Geometry::GetRotator( 0.0 );
    else if( mode == NRD_PIXEL )
    {
        float angle = Sequence::Bayer4x4( pixelPos, frameIndex );
        float4 rotator = Geometry::GetRotator( angle * Math::Pi( 2.0 ) );

        baseRotator = Geometry::CombineRotators( baseRotator, rotator );
    }
    else if( mode == NRD_RANDOM )
    {
        Rng::Hash::Initialize( pixelPos, frameIndex );

        float2 rnd = Rng::Hash::GetFloat2( );
        float4 rotator = Geometry::GetRotator( rnd.x * Math::Pi( 2.0 ) );
        rotator *= 1.0 + ( rnd.y * 2.0 - 1.0 ) * 0.5;

        baseRotator = Geometry::CombineRotators( baseRotator, rotator );
    }

    return baseRotator;
}

float IsInScreenNearest( float2 uv )
{
    return float( all( uv > 0.0 ) && all( uv < 1.0 ) );
}

float2 MirrorUv( float2 uv )
{

    float2 mirrorUv = 1.0 - abs( 1.0 - frac( uv * 0.5 ) * 2.0 );

    return min( mirrorUv, 0.99999 );
}

float4 IsInScreenBilinear( float2 footprintOrigin, float2 rectSize )
{
    float4 p = footprintOrigin.xyxy + float4( 0, 0, 1, 1 );
    bool4 r = ( p >= 0.0 ) & ( p < rectSize.xyxy );

    return float4( r.xzxz & r.yyww );
}

float2 ApplyCheckerboardShift( float2 pos, uint mode, uint counter, uint frameIndex )
{

    float2 posPositive = pos + 16384.0;
    uint checkerboard = Sequence::CheckerBoard( uint2( posPositive ), frameIndex );
    float shift = ( ( counter & 0x1 ) == 0 ) ? -1.0 : 1.0;

    pos.x += shift * float( checkerboard != mode && mode != 2 );

    return pos;
}

float GetSpecMagicCurve( float roughness, float power = 0.25 )
{
    return _NRD_GetSpecMagicCurve( roughness, power );
}

float ComputeParallaxInPixels( float3 X, float2 uvForZeroParallax, float4x4 mWorldToClip, float2 rectSize )
{

    float2 uv = Geometry::GetScreenUv( mWorldToClip, X );
    float2 parallaxInUv = uv - uvForZeroParallax;
    float parallaxInPixels = length( parallaxInUv * rectSize );

    return parallaxInPixels;
}

float GetColorCompressionExposureForSpatialPasses( float roughness )
{

    #if( NRD_RADIANCE_COMPRESSION_MODE == 1 )
        return 0.5 / ( 1.0 + 50.0 * roughness );

    #elif( NRD_RADIANCE_COMPRESSION_MODE == 2 )
        return 0.5 * ( 1.0 - roughness ) / ( 1.0 + 60.0 * roughness );

    #elif( NRD_RADIANCE_COMPRESSION_MODE == 3 )
        return 0.5 * ( 1.0 - roughness ) / ( 1.0 + 1000.0 * roughness * roughness ) + ( 1.0 - sqrt( saturate( roughness ) ) ) * 0.03;

    #elif( NRD_RADIANCE_COMPRESSION_MODE == 4 )
        return 0.6 * ( 1.0 - roughness * roughness ) / ( 1.0 + 400.0 * roughness * roughness );

    #else
        return 0;
    #endif
}

float3 GetXvirtual( float hitDist, float curvature, float3 X, float3 Xprev, float3 N, float3 V, float roughness )
{

    float4 D = ImportanceSampling::GetSpecularDominantDirection( N, V, roughness, ML_SPECULAR_DOMINANT_DIRECTION_G2 );

    float3 reflectionRay = D.xyz * hitDist;

    float3x3 reflectorBasis = Geometry::GetBasis( N );

    float3 O = Geometry::RotateVector( reflectorBasis, reflectionRay );
    O.z = -O.z;

    float mag = 1.0 / ( 2.0 * curvature * O.z - 1.0 );

    float NoV = abs( dot( N, V ) );
    float f = length( X );
    f *= saturate( 1.0 - NoV );
    f *= max( curvature, 0.0 );
    f = 1.0 / ( 1.0 + f );
    mag *= f;

    float3 I = O * mag;

    D.w *= length( I );

    float closenessToSurface = saturate( D.w / ( hitDist + NRD_EPS ) );
    float3 x = lerp( Xprev, X, closenessToSurface );

    return x + V * D.w * Math::Sign( mag );
}

float2 GetKernelSampleCoordinates( float4x4 mToClip, float3 offset, float3 X, float3 T, float3 B, float4 rotator = float4( 1, 0, 0, 1 ) )
{
    #if( NRD_USE_QUADRATIC_DISTRIBUTION == 1 )
        offset.xy *= offset.z;
    #endif

    offset.xy = Geometry::RotateVector( rotator, offset.xy );

    float3 p = X + T * offset.x + B * offset.y;
    float3 clip = Geometry::ProjectiveTransform( mToClip, p ).xyw;
    clip.xy /= clip.z;
    clip.y = -clip.y;

    float2 uv = clip.xy * 0.5 + 0.5;

    return uv;
}

float GetNormalWeightParam( float nonLinearAccumSpeed, float lobeAngleFraction, float roughness = 1.0 )
{
    float percentOfVolume = NRD_MAX_PERCENT_OF_LOBE_VOLUME * lerp( saturate( lobeAngleFraction ), 1.0, nonLinearAccumSpeed );
    float tanHalfAngle = ImportanceSampling::GetSpecularLobeTanHalfAngle( roughness, percentOfVolume );

    float angle = max( atan( tanHalfAngle ), NRD_NORMAL_ENCODING_ERROR );

    return 1.0 / angle;
}

float2 GetGeometryWeightParams( float planeDistSensitivity, float frustumSize, float3 Xv, float3 Nv )
{

    float norm = planeDistSensitivity * frustumSize;
    float a = 1.0 / norm;
    float b = dot( Nv, Xv ) * a;

    return float2( a, -b );
}

float2 GetHitDistanceWeightParams( float hitDist, float nonLinearAccumSpeed )
{

    float a = 1.0 / nonLinearAccumSpeed;
    float b = hitDist * a;

    return float2( a, -b );
}

float2 GetRoughnessWeightParams( float roughness, float fraction, float sensitivity = NRD_ROUGHNESS_SENSITIVITY )
{
    float a = 1.0 / lerp( sensitivity, 1.0, saturate( roughness * fraction ) );
    float b = roughness * a;

    return float2( a, -b );
}

float2 GetRelaxedRoughnessWeightParams( float m, float fraction = 1.0, float sensitivity = NRD_ROUGHNESS_SENSITIVITY )
{

    float a = 1.0 / lerp( sensitivity, 1.0, lerp( m * m, m, saturate( fraction ) ) );
    float b = m * a;

    return float2( a, -b );
}

#define ExpApprox( x ) \
    rcp( ( x ) * ( x ) - ( x ) + 1.0 )

#define ComputeExponentialWeight( x, px, py ) \
    ExpApprox( -NRD_EXP_WEIGHT_DEFAULT_SCALE * abs( ( x ) * px + py ) )

#define ComputeNonExponentialWeight( x, px, py ) \
    Math::SmoothStep( 1.0, 0.0, abs( ( x ) * px + py ) )

#define ComputeNonExponentialWeightWithSigma( x, px, py, sigma ) \
    Math::SmoothStep( 1.0, 0.0, abs( ( x ) * px + py ) - sigma * px )

#if( NRD_USE_EXPONENTIAL_WEIGHTS == 1 )
    #define ComputeWeight( x, px, py )     ComputeExponentialWeight( x, px, py )
#else
    #define ComputeWeight( x, px, py )     ComputeNonExponentialWeight( x, px, py )
#endif

float ApplyGeometryWeightLast( float w, float z, float NoX, float2 geometryWeightParams )
{
    w *= ComputeWeight( NoX, geometryWeightParams.x, geometryWeightParams.y );

    return !IsInDenoisingRange( z ) ? 0.0 : w;
}

float GetGaussianWeight( float r )
{
    return exp( -0.66 * r * r );
}

float GetEncodingAwareNormalWeight( float3 Ncurr, float3 Nprev, float maxAngle, float curvatureAngle, float thresholdAngle )
{
    float cosa = dot( Ncurr, Nprev );
    float angle = Math::AcosApproxPositive( cosa );
    float w = Math::SmoothStep01( 1.0 - ( angle - curvatureAngle - thresholdAngle ) / maxAngle );

    w = Math::SmoothStep( 0.05, 0.95, w );

    return w;
}

float GetDisocclusionThreshold( float disocclusionThreshold, float frustumSize, float NoV )
{
    return frustumSize * saturate( disocclusionThreshold / max( 0.05, NoV ) );
}

#define GetDisocclusionWeight( z, z0, disocclusionThreshold ) step( abs( z - z0 ), disocclusionThreshold )

#define _BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights_Init \
                                                        \
    float2 centerPos = floor( samplePos - 0.5 ) + 0.5; \
    float2 f = saturate( samplePos - centerPos ); \
    float2 w0 = f * ( f * ( -NRD_CATROM_SHARPNESS * f + 2.0 * NRD_CATROM_SHARPNESS ) - NRD_CATROM_SHARPNESS ); \
    float2 w1 = f * ( f * ( ( 2.0 - NRD_CATROM_SHARPNESS ) * f - ( 3.0 - NRD_CATROM_SHARPNESS ) ) ) + 1.0; \
    float2 w2 = f * ( f * ( -( 2.0 - NRD_CATROM_SHARPNESS ) * f + ( 3.0 - 2.0 * NRD_CATROM_SHARPNESS ) ) + NRD_CATROM_SHARPNESS ); \
    float2 w3 = f * ( f * ( NRD_CATROM_SHARPNESS * f - NRD_CATROM_SHARPNESS ) ); \
    float2 w12 = w1 + w2; \
    float2 tc = w2 / w12; \
    float4 w; \
    w.x = w12.x * w0.y; \
    w.y = w0.x * w12.y; \
    w.z = w12.x * w12.y; \
    w.w = w3.x * w12.y; \
    float w4 = w12.x * w3.y; \
                                      \
    w = useBicubic ? w : bilinearCustomWeights; \
    w4 = useBicubic ? w4 : 0.0; \
    float sum = dot( w, 1.0 ) + w4; \
                              \
    float4 uv01 = centerPos.xyxy + ( useBicubic ? float4( tc.x, -1.0, -1.0, tc.y ) : float4( 0, 0, 1, 0 ) ); \
    float4 uv23 = centerPos.xyxy + ( useBicubic ? float4( tc.x, tc.y, 2.0, tc.y ) : float4( 0, 1, 1, 1 ) ); \
    float2 uv4 = centerPos + ( useBicubic ? float2( tc.x, 2.0 ) : f ); \
    uv01 *= invResourceSize.xyxy; \
    uv23 *= invResourceSize.xyxy; \
    uv4 *= invResourceSize; \
    int3 bilinearOrigin = int3( int2( centerPos ), 0 );

#define _BicubicFilterNoCornersWithFallbackToBilinearFilterWithCustomWeights_Color( color, tex ) \
                   \
    color = tex.SampleLevel( gLinearClamp, uv01.xy, 0 ) * w.x; \
    color += tex.SampleLevel( gLinearClamp, uv01.zw, 0 ) * w.y; \
    color += tex.SampleLevel( gLinearClamp, uv23.xy, 0 ) * w.z; \
    color += tex.SampleLevel( gLinearClamp, uv23.zw, 0 ) * w.w; \
    color += tex.SampleLevel( gLinearClamp, uv4, 0 ) * w4; \
                                                                           \
    color = sum < 0.0001 ? 0 : color / sum;

#define _BilinearFilterWithCustomWeights_Color( color, tex ) \
                   \
    color = tex.Load( bilinearOrigin ) * bilinearCustomWeights.x; \
    color += tex.Load( bilinearOrigin, int2( 1, 0 ) ) * bilinearCustomWeights.y; \
    color += tex.Load( bilinearOrigin, int2( 0, 1 ) ) * bilinearCustomWeights.z; \
    color += tex.Load( bilinearOrigin, int2( 1, 1 ) ) * bilinearCustomWeights.w; \
                                                                           \
    sum = dot( bilinearCustomWeights, 1.0 ); \
    color = sum < 0.0001 ? 0 : color / sum;
