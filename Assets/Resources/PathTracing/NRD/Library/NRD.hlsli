/*
Copyright (c) 2022, NVIDIA CORPORATION. All rights reserved.

NVIDIA CORPORATION and its licensors retain all intellectual property
and proprietary rights in and to this software, related documentation
and any modifications thereto. Any use, reproduction, disclosure or
distribution of this software and related documentation without an express
license agreement from NVIDIA CORPORATION is strictly prohibited.
*/

#ifndef NRD_INCLUDED
#define NRD_INCLUDED

#include "NRDConfig.hlsli"

#define NRD_CONSTANT_BUFFER_REGISTER_INDEX                                              0

#define NRD_RESOURCES_SPACE_INDEX                                                       0
#define NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX                                    1

#ifndef NRD_CS_MAIN
    #define NRD_CS_MAIN                                                                 main
#endif

#ifndef NRD_REJITTER_VIEWZ_THRESHOLD
    #define NRD_REJITTER_VIEWZ_THRESHOLD                                                0.01
#endif

#ifndef NRD_REJITTER_AMPLITUDE
    #define NRD_REJITTER_AMPLITUDE                                                      2.0
#endif

#ifndef NRD_MATERIAL_FACTOR_MIN_SCALE
    #define NRD_MATERIAL_FACTOR_MIN_SCALE                                               0.02
#endif

#ifndef NRD_ROUGHNESS_FACTOR_MIN_SCALE
    #define NRD_ROUGHNESS_FACTOR_MIN_SCALE                                              0.1
#endif

#ifndef __cplusplus

#define NRD_MERGE_TOKENS_( _0, _1 )                                                     _0 ## _1
#define NRD_MERGE_TOKENS( _0, _1 )                                                      NRD_MERGE_TOKENS_( _0, _1 )

#if( defined( NRD_CONSTANTS_START ) && \
     defined( NRD_CONSTANT ) && \
     defined( NRD_CONSTANTS_END ) && \
     defined( NRD_INPUTS_START ) && \
     defined( NRD_INPUT ) && \
     defined( NRD_INPUTS_END ) && \
     defined( NRD_OUTPUTS_START ) && \
     defined( NRD_OUTPUT ) && \
     defined( NRD_OUTPUTS_END ) && \
     defined( NRD_SAMPLERS_START ) && \
     defined( NRD_SAMPLER ) && \
     defined( NRD_SAMPLERS_END ) )

    #define NRD_EXPORT

#elif( defined( NRD_COMPILER_DXC ) || defined( __hlsl_dx_compiler ) || defined( __SLANG__ ) )

    #ifdef __spirv__

        #define NRD_FORMAT_UNKNOWN [[vk::image_format("unknown")]]
    #else
        #define NRD_FORMAT_UNKNOWN
    #endif

    #define NRD_CONSTANTS_START( resourceName )                                         cbuffer resourceName : register( NRD_MERGE_TOKENS( b, NRD_CONSTANT_BUFFER_REGISTER_INDEX ), NRD_MERGE_TOKENS( space, NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX ) ) {
    #define NRD_CONSTANT( constantType, constantName )                                  constantType constantName;
    #define NRD_CONSTANTS_END                                                           };

    #define NRD_INPUTS_START
    #define NRD_INPUT( type, dataType, name, reg, binding, policy )                     type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ), NRD_MERGE_TOKENS( space, NRD_RESOURCES_SPACE_INDEX ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_INPUTS_END

    #define NRD_OUTPUTS_START
    #define NRD_OUTPUT( type, dataType, name, reg, binding, policy )                    NRD_FORMAT_UNKNOWN type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ), NRD_MERGE_TOKENS( space, NRD_RESOURCES_SPACE_INDEX ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_OUTPUTS_END

    #define NRD_SAMPLERS_START
    #define NRD_SAMPLER( type, name, reg, binding )                                     type name : register( NRD_MERGE_TOKENS( reg, binding ), NRD_MERGE_TOKENS( space, NRD_CONSTANT_BUFFER_AND_SAMPLERS_SPACE_INDEX ) );
    #define NRD_SAMPLERS_END

    #define NRD_EXPORT

    #ifndef NRD_COMPILER_DXC
        #define NRD_COMPILER_DXC
    #endif

#elif( defined( NRD_COMPILER_PSSLC ) || defined( __PSSL__ ) )

    #define EXPAND( x )                                                                 x
    #define GET_NTH_MACRO_4_arg( a, b, c, d, NAME, ... )                                NAME
    #define GET_NTH_MACRO_3_arg( a, b, c, NAME, ... )                                   NAME
    #define SampleLevel3( a, b, c )                                                     SampleLOD( a, b, ( float )( c ) )
    #define SampleLevel4( a, b, c, d )                                                  SampleLOD( a, b, ( float )( c ), d )
    #define GatherRed3( a, b, c )                                                       GatherRed( ( a ), ( b ), int2( c ) )
    #define GatherRed2( a, b )                                                          GatherRed( ( a ), ( b ) )
    #define GatherGreen3( a, b, c )                                                     GatherGreen( ( a ), ( b ), int2( c ) )
    #define GatherGreen2( a, b )                                                        GatherGreen( ( a ), ( b ) )

    #define NRD_CONSTANTS_START( resourceName )                                         ConstantBuffer resourceName : register( NRD_MERGE_TOKENS( b, NRD_CONSTANT_BUFFER_REGISTER_INDEX ) ) {
    #define NRD_CONSTANT( constantType, constantName )                                  constantType constantName;
    #define NRD_CONSTANTS_END                                                           };

    #define NRD_INPUTS_START
    #define NRD_INPUT( type, dataType, name, reg, binding, policy )                     type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_INPUTS_END

    #define NRD_OUTPUTS_START
    #define NRD_OUTPUT( type, dataType, name, reg, binding, policy )                    type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_OUTPUTS_END

    #define NRD_SAMPLERS_START
    #define NRD_SAMPLER( type, name, reg, binding )                                     type name : register( NRD_MERGE_TOKENS( reg, binding ) );
    #define NRD_SAMPLERS_END

    #define numthreads                                                                  NUM_THREADS
    #define groupshared                                                                 thread_group_memory
    #define SV_GroupID                                                                  S_GROUP_ID
    #define SV_GroupIndex                                                               S_GROUP_INDEX
    #define SV_GroupThreadID                                                            S_GROUP_THREAD_ID
    #define SV_DispatchThreadID                                                         S_DISPATCH_THREAD_ID
    #define GroupMemoryBarrierWithGroupSync                                             ThreadGroupMemoryBarrierSync
    #define GroupMemoryBarrier                                                          ThreadGroupMemoryBarrier
    #define RWTexture2D                                                                 RW_Texture2D
    #define cbuffer                                                                     ConstantBuffer
    #define SampleLevel( ... )                                                          EXPAND( GET_NTH_MACRO_4_arg( __VA_ARGS__, SampleLevel4, SampleLevel3 )( __VA_ARGS__ ) )
    #define GatherRed( ... )                                                            EXPAND( GET_NTH_MACRO_3_arg( __VA_ARGS__, GatherRed3, GatherRed2 )( __VA_ARGS__ ) )
    #define GatherGreen( ... )                                                          EXPAND( GET_NTH_MACRO_3_arg( __VA_ARGS__, GatherGreen3, GatherGreen2 )( __VA_ARGS__ ) )
    #define reversebits                                                                 ReverseBits
    #define InterlockedAdd( ... )                                                       AtomicAdd( __VA_ARGS__ )
    #define InterlockedMax( ... )                                                       AtomicMax( __VA_ARGS__ )
    #define unorm

    #ifdef EXPORT_NAME
        #define NRD_EXPORT                                                              [ CxxSymbol( EXPORT_NAME ) ]
    #else
        #define NRD_EXPORT
    #endif

    #ifndef NRD_COMPILER_PSSLC
        #define NRD_COMPILER_PSSLC
    #endif

#elif( defined( NRD_COMPILER_UNREAL_ENGINE ) )

    #define NRD_CONSTANTS_START( resourceName )
    #define NRD_CONSTANT( constantType, constantName )                                  constantType constantName;
    #define NRD_CONSTANTS_END

    #define NRD_INPUTS_START
    #define NRD_INPUT( type, dataType, name, reg, binding, policy )                     type<dataType> name; NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_INPUTS_END

    #define NRD_OUTPUTS_START
    #define NRD_OUTPUT( type, dataType, name, reg, binding, policy )                    type<dataType> name; NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_OUTPUTS_END

    #define NRD_SAMPLERS_START
    #define NRD_SAMPLER( type, name, reg, binding )                                     type name;
    #define NRD_SAMPLERS_END

    #define NRD_EXPORT

#else

    #define NRD_CONSTANTS_START( resourceName )                                         cbuffer resourceName : register( NRD_MERGE_TOKENS( b, NRD_CONSTANT_BUFFER_REGISTER_INDEX ) ) {
    #define NRD_CONSTANT( constantType, constantName )                                  constantType constantName;
    #define NRD_CONSTANTS_END                                                           };

    #define NRD_INPUTS_START
    #define NRD_INPUT( type, dataType, name, reg, binding, policy )                     type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_INPUTS_END

    #define NRD_OUTPUTS_START
    #define NRD_OUTPUT( type, dataType, name, reg, binding, policy )                    type<dataType> name : register( NRD_MERGE_TOKENS( reg, binding ) ); NRD_DECLARE_RESOURCE( name, policy )
    #define NRD_OUTPUTS_END

    #define NRD_SAMPLERS_START
    #define NRD_SAMPLER( type, name, reg, binding )                                     type name : register( NRD_MERGE_TOKENS( reg, binding ) );
    #define NRD_SAMPLERS_END

    #define NRD_EXPORT

    #ifndef NRD_COMPILER_FXC
        #define NRD_COMPILER_FXC
    #endif

    #pragma warning( disable: 3577 )

#endif

#ifdef NRD_GLSL
    #ifndef float4
        #define float4                                                                  vec4
    #endif
    #ifndef float3
        #define float3                                                                  vec3
    #endif
    #ifndef float2
        #define float2                                                                  vec2
    #endif
    #ifndef float2x2
        #define float2x2                                                                mat2x2
    #endif
    #ifndef float2x3
        #define float2x3                                                                mat2x3
    #endif
    #ifndef float3x3
        #define float3x3                                                                mat3x3
    #endif
    #ifndef rsqrt
        #define rsqrt                                                                   inversesqrt
    #endif
    #ifndef saturate
        #define saturate( x )                                                           clamp( x, 0.0, 1.0 )
    #endif
    #ifndef lerp
        #define lerp                                                                    mix
    #endif
    #ifndef mul
        #define mul( x, y )                                                             ( ( x ) * ( y ) )
    #endif
    #ifndef rcp
        #define rcp( x )                                                                ( 1.0 / ( x ) )
    #endif
    #ifndef any
        bool any( bool value )                                                          { return value; }
    #endif
#endif

#ifdef NRD_INTERNAL

    #if( NRD_SUPPORTS_VIEWPORT_OFFSET == 1 )
        #define NRD_RESOURCE_TRANSIENT                                                  int2( 0, 0 )
        #define NRD_RESOURCE_IN_ZERO_OFFSET                                             int2( 0, 0 )
        #define NRD_RESOURCE_IN                                                         gInputRectOrigin
        #define NRD_RESOURCE_OUT                                                        gOutputRectOrigin
        #define NRD_RESOURCE_PERMANENT                                                  gOutputRectOrigin
        #define NRD_RESOURCE_IN_DISPATCH                                                gDispatchInputRectOrigin
        #define NRD_RESOURCE_OUT_DISPATCH                                               gDispatchOutputRectOrigin

        #define NRD_DECLARE_RESOURCE( resourceName, resourcePolicy )                    int2 NRD_MERGE_TOKENS( GetResourceOrigin_, resourceName )( ) { return resourcePolicy; }
        #define NRD_PIXEL_POS( resourceName, pos )                                      ( ( pos ) + NRD_MERGE_TOKENS( GetResourceOrigin_, resourceName )() )
    #else
        #define NRD_RESOURCE_TRANSIENT                                                  0
        #define NRD_RESOURCE_IN_ZERO_OFFSET                                             0
        #define NRD_RESOURCE_IN                                                         0
        #define NRD_RESOURCE_OUT                                                        0
        #define NRD_RESOURCE_PERMANENT                                                  0
        #define NRD_RESOURCE_IN_DISPATCH                                                0
        #define NRD_RESOURCE_OUT_DISPATCH                                               0

        #define NRD_DECLARE_RESOURCE( resourceName, resourcePolicy )
        #define NRD_PIXEL_POS( resourceName, pos )                                      ( pos )
    #endif

    #define NRD_SURFACE( resourceName, pos )                                            resourceName[ NRD_PIXEL_POS( resourceName, pos ) ]

    #ifndef __SLANG__
        #pragma pack_matrix( column_major )
    #endif
#endif

#ifndef __cplusplus
    #define NRD_MODE_RADIANCE                                                           0
    #define NRD_MODE_SH                                                                 1
    #define NRD_MODE_OCCLUSION                                                          2
    #define NRD_MODE_DO                                                                 3

    #define NRD_SIGNAL_DIFF                                                             0x1
    #define NRD_SIGNAL_SPEC                                                             0x2
    #define NRD_SIGNAL_BOTH                                                             ( NRD_SIGNAL_DIFF | NRD_SIGNAL_SPEC )

    #define NRD_HAS_DIFF                                                                ( ( NRD_SIGNAL & NRD_SIGNAL_DIFF ) != 0 )
    #define NRD_HAS_SPEC                                                                ( ( NRD_SIGNAL & NRD_SIGNAL_SPEC ) != 0 )
#endif

#define NRD_NORMAL_ENCODING_RGBA8_UNORM                                                 0
#define NRD_NORMAL_ENCODING_RGBA8_SNORM                                                 1
#define NRD_NORMAL_ENCODING_R10G10B10A2_UNORM                                           2
#define NRD_NORMAL_ENCODING_RGBA16_UNORM                                                3
#define NRD_NORMAL_ENCODING_RGBA16_SNORM                                                4

#define NRD_ROUGHNESS_ENCODING_SQ_LINEAR                                                0
#define NRD_ROUGHNESS_ENCODING_LINEAR                                                   1
#define NRD_ROUGHNESS_ENCODING_SQRT_LINEAR                                              2

#define NRD_FP16_MAX                                                                    65504.0
#define NRD_PI                                                                          3.14159265358979323846
#define NRD_EPS                                                                         1e-6
#define NRD_INF                                                                         1e6

float3 _NRD_SafeNormalize( float3 v )
{
    return v * rsqrt( max( dot( v, v ), 1e-9 ) );
}

float3 _NRD_EncodeNormalRoughness101010( float3 n, float roughness )
{
    n /= abs( n.x ) + abs( n.y ) + abs( n.z );

    float3 r;
    r.y = n.y * 0.5 + 0.5;
    r.x = n.x * 0.5 + r.y;
    r.y -= n.x * 0.5;

    roughness = max( roughness, 1.5 / 512.0 );
    float s = n.z < 0 ? -roughness : roughness;
    r.z = s * 0.5 + 0.5;

    return r;
}

float4 _NRD_DecodeNormalRoughness101010( float3 p )
{
    float t = p.z * 2.0 - 1.0;

    float4 r;
    r.x = p.x - p.y;
    r.y = p.x + p.y - 1.0;
    r.z = t < 0 ? -1 : 1;
    r.z *= 1.0 - abs( r.x ) - abs( r.y );

    r.w = abs( t );

    return r;
}

float _NRD_Luminance( float3 linearColor )
{

    return dot( linearColor, float3( 0.2126, 0.7152, 0.0722 ) );
}

float3 _NRD_LinearToYCoCg( float3 color )
{
    float Y = dot( color, float3( 0.25, 0.5, 0.25 ) );
    float Co = dot( color, float3( 0.5, 0.0, -0.5 ) );
    float Cg = dot( color, float3( -0.25, 0.5, -0.25 ) );

    return float3( Y, Co, Cg );
}

float3 _NRD_YCoCgToLinear( float3 color )
{
    float t = color.x - color.z;

    float3 r;
    r.y = color.x + color.z;
    r.x = t + color.y;
    r.z = t - color.y;

    return max( r, 0.0 );
}

float3 _NRD_YCoCgToLinear_Corrected( float Y, float Y0, float2 CoCg )
{
    Y = max( Y, 0.0 );
    CoCg *= ( Y + NRD_EPS ) / ( Y0 + NRD_EPS );

    return _NRD_YCoCgToLinear( float3( Y, CoCg ) );
}

float _NRD_GetSpecularDominantFactor( float NoV, float roughness )
{
    float a = 0.298475 * log( 39.4115 - 39.0029 * roughness );
    float dominantFactor = pow( saturate( 1.0 - NoV ), 10.8649 ) * ( 1.0 - a ) + a;

    return saturate( dominantFactor );
}

float3 _NRD_GetSpecularDominantDirection( float3 N, float3 V, float dominantFactor )
{
    float3 R = reflect( -V, N );
    float3 D = lerp( N, R, dominantFactor );

    return normalize( D );
}

float _NRD_Pow5( float x )
{
    return pow( saturate( 1.0 - x ), 5.0 );
}

float _NRD_DistributionTerm( float roughness, float NoH )
{

    float m = roughness * roughness;
    float m2 = m * m;

    float t = ( NoH * m2 - NoH ) * NoH + 1.0;
    float a = m / t;
    float d = a * a;

    return d / NRD_PI;
}

float _NRD_GeometryTerm( float roughness, float NoL, float NoV )
{

    float m = roughness * roughness;
    float m2 = m * m;

    float a = NoV * sqrt( ( NoL - m2 * NoL ) * NoL + m2 );
    float b = NoL * sqrt( ( NoV - m2 * NoV ) * NoV + m2 );

    return 0.5 / max( a + b, NRD_EPS );
}

float _NRD_DiffuseTerm( float roughness, float NoL, float NoV, float VoH )
{

    float f = 2.0 * VoH * VoH * roughness - 0.5;
    float FdV = f * _NRD_Pow5( NoV ) + 1.0;
    float FdL = f * _NRD_Pow5( NoL ) + 1.0;
    float d = FdV * FdL;

    return d / NRD_PI;
}

float2 _NRD_ComputeBrdfs( float3 Ld, float3 Ls, float3 N, float3 V, float roughness )
{
    float2 result;
    float NoV = abs( dot( N, V ) );

    {
        float3 H = _NRD_SafeNormalize( Ld + V );

        float NoL = saturate( dot( N, Ld ) );
        float VoH = abs( dot( V, H ) );

        float Kdiff = _NRD_DiffuseTerm( roughness, NoL, NoV, VoH );

        result.x = Kdiff * NoL;
    }

    {
        float3 H = _NRD_SafeNormalize( Ls + V );

        float NoL = saturate( dot( N, Ls ) );
        float NoH = saturate( dot( N, H ) );

        float D = _NRD_DistributionTerm( roughness, NoH );
        float Gmod = _NRD_GeometryTerm( roughness, NoL, NoV );
        float Kspec = D * Gmod;

        result.y = Kspec * NoL;
    }

    return result;
}

float3 _NRD_EnvironmentTerm_Rtg( float3 Rf0, float NoV, float roughness )
{

    float m = saturate( roughness * roughness );

    float4 X;
    X.x = 1.0;
    X.y = NoV;
    X.z = NoV * NoV;
    X.w = NoV * X.z;

    float4 Y;
    Y.x = 1.0;
    Y.y = m;
    Y.z = m * m;
    Y.w = m * Y.z;

    const float2x2 M1 = float2x2( 0.99044, -1.28514, 1.29678, -0.755907 );
    const float3x3 M2 = float3x3( 1.0, 2.92338, 59.4188, 20.3225, -27.0302, 222.592, 121.563, 626.13, 316.627 );

    const float2x2 M3 = float2x2( 0.0365463, 3.32707, 9.0632, -9.04756 );
    const float3x3 M4 = float3x3( 1.0, 3.59685, -1.36772, 9.04401, -16.3174, 9.22949, 5.56589, 19.7886, -20.2123 );

    float bias = dot( mul( M1, X.xy ), Y.xy ) * rcp( max( dot( mul( M2, X.xyw ), Y.xyw ), NRD_EPS ) );
    float scale = dot( mul( M3, X.xy ), Y.xy ) * rcp( max( dot( mul( M4, X.xzw ), Y.xyw ), NRD_EPS ) );

    return saturate( Rf0 * scale + bias );
}

float _NRD_GetSpecMagicCurve( float roughness, float power )
{

    float f = 1.0 - exp2( -200.0 * roughness * roughness );
    f *= pow( saturate( roughness ), power );

    return f;
}

float _REBLUR_GetHitDistanceNormalization( float viewZ, float3 hitDistParams, float roughness )
{
    float smc = _NRD_GetSpecMagicCurve( roughness, 0.5 );

    return ( hitDistParams.x + abs( viewZ ) * hitDistParams.y ) * lerp( hitDistParams.z, 1.0, smc );
}

#define _NRD_IsInvalid( x ) ( any( isnan( x ) ) || any( isinf( x ) ) )

struct NRD_SG
{
    float c0;
    float2 chroma;
    float normHitDist;

    float3 c1;
    float sharpness;
};

NRD_SG _NRD_SG_Create( float3 radiance, float3 direction, float normHitDist )
{
    float3 YCoCg = _NRD_LinearToYCoCg( radiance );

    NRD_SG sg;
    sg.c0 = YCoCg.x;
    sg.chroma = YCoCg.yz;
    sg.c1 = direction * YCoCg.x;
    sg.normHitDist = normHitDist;
    sg.sharpness = 0.0;

    return sg;
}

float _NRD_SG_IntegralApprox( NRD_SG sg )
{
    return 2.0 * NRD_PI * ( sg.c0 / sg.sharpness );
}

float _NRD_SG_Integral( NRD_SG sg )
{
    float expTerm = 1.0 - exp( -2.0 * sg.sharpness );

    return _NRD_SG_IntegralApprox( sg ) * expTerm;
}

float _NRD_SG_InnerProduct( NRD_SG a, NRD_SG b )
{

    float3 dir = a.sharpness * a.c1 + b.sharpness * b.c1;
    float d = length( dir );

    float integralFactor;
    [flatten]
    if( d < 0.001 )
        integralFactor = 2.0 - 2.0 * d + ( 4.0 / 3.0 ) * d * d;
    else
        integralFactor = ( 1.0 - exp( -2.0 * d ) ) / d;

    float c = exp( d - a.sharpness - b.sharpness ) * integralFactor;

    return 2.0 * NRD_PI * c * a.c0 * b.c0;
}

float4 NRD_FrontEnd_UnpackNormalAndRoughness( float4 p, out float materialID )
{
    float4 r;
    #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
        r = _NRD_DecodeNormalRoughness101010( p.xyz );

        materialID = p.w * 3.0;
    #else
        #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_RGBA8_UNORM || NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_RGBA16_UNORM )
            p.xyz = p.xyz * 2.0 - 1.0;
        #endif

        r.xyz = p.xyz;
        r.w = p.w;

        materialID = 0.0;
    #endif

    r.xyz = _NRD_SafeNormalize( r.xyz );

    #if( NRD_ROUGHNESS_ENCODING == NRD_ROUGHNESS_ENCODING_SQRT_LINEAR )
        r.w = saturate( r.w * r.w );
    #elif( NRD_ROUGHNESS_ENCODING == NRD_ROUGHNESS_ENCODING_SQ_LINEAR )
        r.w = sqrt( saturate( r.w ) );
    #endif

    return r;
}

float4 NRD_FrontEnd_UnpackNormalAndRoughness( float4 p )
{
    float unused;

    return NRD_FrontEnd_UnpackNormalAndRoughness( p, unused );
}

float4 NRD_FrontEnd_PackNormalAndRoughness( float3 N, float roughness, float materialID )
{
    float4 p;

    #if( NRD_ROUGHNESS_ENCODING == NRD_ROUGHNESS_ENCODING_SQRT_LINEAR )
        roughness = sqrt( saturate( roughness ) );
    #elif( NRD_ROUGHNESS_ENCODING == NRD_ROUGHNESS_ENCODING_SQ_LINEAR )
        roughness *= roughness;
    #endif

    #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_R10G10B10A2_UNORM )
        p.xyz = _NRD_EncodeNormalRoughness101010( N, roughness );
        p.w = saturate( materialID / 3.0 );
    #else

        N /= max( abs( N.x ), max( abs( N.y ), abs( N.z ) ) );

        #if( NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_RGBA8_UNORM || NRD_NORMAL_ENCODING == NRD_NORMAL_ENCODING_RGBA16_UNORM )
            N = N * 0.5 + 0.5;
        #endif

        p.xyz = N;
        p.w = roughness;
    #endif

    return p;
}

void NRD_MaterialFactors( float3 N, float3 V, float3 albedo, float3 Rf0, float roughness, out float3 diffFactor, out float3 specFactor )
{
    float NoV = abs( dot( N, V ) );
    float3 Fenv = _NRD_EnvironmentTerm_Rtg( Rf0, NoV, roughness );

    diffFactor = ( 1.0 - Fenv ) * albedo;
    diffFactor = lerp( NRD_MATERIAL_FACTOR_MIN_SCALE.xxx, float3( 1.0, 1.0, 1.0 ), diffFactor );

    specFactor = Fenv;
    specFactor *= lerp( NRD_ROUGHNESS_FACTOR_MIN_SCALE.xxx, float3( 1.0, 1.0, 1.0 ), roughness );
    specFactor = lerp( NRD_MATERIAL_FACTOR_MIN_SCALE.xxx, float3( 1.0, 1.0, 1.0 ), specFactor );
}

#define _NRD_INF_INTERNAL 3.40282347e+38

float NRD_FrontEnd_SpecHitDistAveraging_Begin( )
{
    return _NRD_INF_INTERNAL;
}

float NRD_FrontEnd_TrimHitDistance( float hitDist, float threshold )
{

    return hitDist < threshold ? 0.0 : hitDist;
}

void NRD_FrontEnd_SpecHitDistAveraging_Add( inout float accumulatedSpecHitDist, float hitDist )
{

    accumulatedSpecHitDist = min( accumulatedSpecHitDist, hitDist == 0.0 ? _NRD_INF_INTERNAL : hitDist );
}

void NRD_FrontEnd_SpecHitDistAveraging_End( inout float accumulatedSpecHitDist )
{
    accumulatedSpecHitDist = accumulatedSpecHitDist == _NRD_INF_INTERNAL ? 0.0 : accumulatedSpecHitDist;
}

float REBLUR_FrontEnd_GetNormHitDist( float hitDist, float viewZ, float3 hitDistParams, float roughness )
{
    float f = _REBLUR_GetHitDistanceNormalization( viewZ, hitDistParams, roughness );

    return saturate( hitDist / f );
}

float4 REBLUR_FrontEnd_PackRadianceAndNormHitDist( float3 radiance, float normHitDist, bool sanitize )
{
    if( sanitize )
    {
        radiance = _NRD_IsInvalid( radiance ) ? float3( 0, 0, 0 ) : clamp( radiance, 0, NRD_FP16_MAX );
        normHitDist = _NRD_IsInvalid( normHitDist ) ? 0 : saturate( normHitDist );
    }

    radiance = _NRD_LinearToYCoCg( radiance );

    return float4( radiance, normHitDist );
}

float4 REBLUR_FrontEnd_PackSh( float3 radiance, float normHitDist, float3 direction, out float4 out1, bool sanitize )
{
    if( sanitize )
    {
        radiance = _NRD_IsInvalid( radiance ) ? float3( 0, 0, 0 ) : clamp( radiance, 0, NRD_FP16_MAX );
        normHitDist = _NRD_IsInvalid( normHitDist ) ? 0 : saturate( normHitDist );
        direction = _NRD_IsInvalid( direction ) ? float3( 0, 0, 0 ) : clamp( direction, -1.0, 1.0 );
    }

    NRD_SG sg = _NRD_SG_Create( radiance, direction, normHitDist );

    float4 out0 = float4( sg.c0, sg.chroma, sg.normHitDist );

    out1 = float4( sg.c1, sg.sharpness );

    return out0;
}

float4 REBLUR_FrontEnd_PackDirectionalOcclusion( float3 direction, float normHitDist, bool sanitize )
{
    if( sanitize )
    {
        direction = _NRD_IsInvalid( direction ) ? float3( 0, 0, 0 ) : clamp( direction, -1.0, 1.0 );
        normHitDist = _NRD_IsInvalid( normHitDist ) ? 0 : saturate( normHitDist );
    }

    NRD_SG sg = _NRD_SG_Create( normHitDist.xxx, direction, normHitDist );

    return float4( sg.c1, sg.c0 );
}

float4 REBLUR_BackEnd_UnpackRadianceAndNormHitDist( float4 data )
{
    data.xyz = _NRD_YCoCgToLinear( data.xyz );

    return data;
}

NRD_SG REBLUR_BackEnd_UnpackSh( float4 sh0, float3 sh1 )
{
    NRD_SG sg;
    sg.c0 = sh0.x;
    sg.chroma = sh0.yz;
    sg.normHitDist = sh0.w;
    sg.c1 = sh1;
    sg.sharpness = 0.0;

    return sg;
}

NRD_SG REBLUR_BackEnd_UnpackDirectionalOcclusion( float4 data )
{
    NRD_SG sg;
    sg.c0 = data.w;
    sg.chroma = float2( 0, 0 );
    sg.normHitDist = data.w;
    sg.c1 = data.xyz;
    sg.sharpness = 0.0;

    return sg;
}

float4 RELAX_FrontEnd_PackRadianceAndHitDist( float3 radiance, float hitDist, bool sanitize )
{
    if( sanitize )
    {
        radiance = _NRD_IsInvalid( radiance ) ? float3( 0, 0, 0 ) : clamp( radiance, 0, NRD_FP16_MAX );
        hitDist = _NRD_IsInvalid( hitDist ) ? 0 : clamp( hitDist, 0, NRD_FP16_MAX );
    }

    return float4( radiance, hitDist );
}

float4 RELAX_FrontEnd_PackSh( float3 radiance, float hitDist, float3 direction, out float4 out1, bool sanitize )
{
    if( sanitize )
    {
        radiance = _NRD_IsInvalid( radiance ) ? float3( 0, 0, 0 ) : clamp( radiance, 0, NRD_FP16_MAX );
        hitDist = _NRD_IsInvalid( hitDist ) ? 0 : clamp( hitDist, 0, NRD_FP16_MAX );
        direction = _NRD_IsInvalid( direction ) ? float3( 0, 0, 0 ) : clamp( direction, -1.0, 1.0 );
    }

    float4 out0 = float4( radiance, hitDist );

    out1 = float4( direction * _NRD_Luminance( radiance ), 0 );

    return out0;
}

float4 RELAX_BackEnd_UnpackRadiance( float4 color )
{
    return color;
}

NRD_SG RELAX_BackEnd_UnpackSh( float4 sh0, float3 sh1 )
{
    NRD_SG sg;
    sg.c0 = sh0.x;
    sg.chroma = sh0.yz;
    sg.normHitDist = sh0.w;
    sg.c1 = sh1;
    sg.sharpness = 0.0;

    return sg;
}

float SIGMA_FrontEnd_PackPenumbra( float distanceToOccluder, float tanOfLightAngularRadius )
{
    float penumbraSize = distanceToOccluder * tanOfLightAngularRadius;
    float penumbraRadius = penumbraSize * 0.5;

    return distanceToOccluder >= NRD_FP16_MAX ? NRD_FP16_MAX : min( penumbraRadius, 32768.0 );
}

float SIGMA_FrontEnd_PackPenumbra( float distanceToOccluder, float distanceToLight, float lightSize )
{
    float penumbraSize = lightSize * distanceToOccluder / max( distanceToLight - distanceToOccluder, NRD_EPS );
    float penumbraRadius = penumbraSize * 0.5;

    return distanceToOccluder >= NRD_FP16_MAX ? NRD_FP16_MAX : min( penumbraRadius, 32768.0 );
}

float4 SIGMA_FrontEnd_PackTranslucency( float distanceToOccluder, float3 translucency )
{
    float4 r;
    r.x = float( distanceToOccluder >= NRD_FP16_MAX );
    r.yzw = saturate( translucency );

    return r;
}

#define SIGMA_BackEnd_UnpackShadow( shadow ) ( shadow * shadow )

float3 NRD_SG_ExtractColor( NRD_SG sg )
{
    return _NRD_YCoCgToLinear( float3( sg.c0, sg.chroma ) );
}

float3 NRD_SG_ExtractDirection( NRD_SG sg )
{
    return _NRD_SafeNormalize( sg.c1 );
}

void NRD_SG_Rotate( inout NRD_SG sg, float3x3 rotation )
{
    sg.c1 = mul( rotation, sg.c1 );
}

float3 NRD_SG_ResolveDiffuse( NRD_SG sg, float3 N, float3 V, float roughness )
{
    float3 L = NRD_SG_ExtractDirection( sg );
    float NoL = saturate( dot( N, L ) );

    NRD_SG ndf;
    ndf.c0 = 1.0;
    ndf.c1 = N;
    ndf.sharpness = 1.0;

    NRD_SG light;
    light.sharpness = 2.0;
    light.c1 = L;

    float sharpnessSum = light.sharpness + ndf.sharpness;
    light.c0 = sg.c0 * sharpnessSum / ( 2.0 * ( 1.0 - exp( -2.0 * sharpnessSum ) ) );

    float Y = _NRD_SG_InnerProduct( ndf, light );

#if 0

    float3 H = normalize( L + V );
    float NoV = abs( dot( N, V ) );
    float VoH = abs( dot( V, H ) );
    float Kdiff = _NRD_DiffuseTerm( roughness, NoL, NoV, VoH );

    Y *= Kdiff;

    Y /= 1.0 + ( roughness * ( 1.0 + NoV ) - 0.5 ) * _NRD_Pow5( NoV );
#else
    Y /= NRD_PI;
#endif

    Y = max( Y, sg.c0 / NRD_PI );

    return _NRD_YCoCgToLinear_Corrected( Y, sg.c0, sg.chroma );
}

float3 NRD_SG_ResolveSpecular( NRD_SG sg, float3 N, float3 V, float roughness )
{
    float m = roughness * roughness;
    float m2 = m * m;

    float3 L = NRD_SG_ExtractDirection( sg );
    float NoL = saturate( dot( N, L ) );

    float NoV = abs( dot( N, V ) );

    float projectedNoV = sqrt( lerp( NoV * NoV, 1.0, m2 ) );
    float Gmod = _NRD_GeometryTerm( roughness, NoL, NoV );
    float Y = sg.c0 * 2.0 * ( NoV + projectedNoV ) * Gmod * NoL;

    Y = max( Y, sg.c0 / NRD_PI );

    return _NRD_YCoCgToLinear_Corrected( Y, sg.c0, sg.chroma );
}

float2 NRD_SG_ReJitter(
    NRD_SG diffSg, NRD_SG specSg,
    float3 V, float roughness,
    float Z, float Ze, float Zw, float Zn, float Zs,
    float3 N, float3 Ne, float3 Nw, float3 Nn, float3 Ns
)
{

    roughness = max( roughness, 0.05 );

    float3 Ld = NRD_SG_ExtractDirection( diffSg );
    float3 Ls = NRD_SG_ExtractDirection( specSg );

    float smc = _NRD_GetSpecMagicCurve( roughness, 0.5 );
    Ls = _NRD_SafeNormalize( lerp( V, Ls, smc ) );

    float2 brdfCenter = _NRD_ComputeBrdfs( Ld, Ls, N, V, roughness );

    float3 Navg = _NRD_SafeNormalize( Ne + Nw + Nn + Ns );
    float2 brdfAverage = _NRD_ComputeBrdfs( Ld, Ls, Navg, V, roughness );

    float2 j = ( brdfCenter + NRD_EPS ) / ( brdfAverage + NRD_EPS );
    j = clamp( j, 1.0 / NRD_REJITTER_AMPLITUDE, NRD_REJITTER_AMPLITUDE );

    float NoV = abs( dot( N, V ) );
    float zThreshold = NRD_REJITTER_VIEWZ_THRESHOLD * abs( Z ) / ( NoV * 0.95 + 0.05 );
    float4 w = step( abs( float4( Ze, Zw, Zn, Zs ) - Z ), zThreshold.xxxx );

    float4 NoN;
    NoN.x = dot( Ne, N );
    NoN.y = dot( Nw, N );
    NoN.z = dot( Nn, N );
    NoN.w = dot( Ns, N );

    w *= step( 0.01, NoN );

    bool isSymmetrical = dot( w, float4( 1.0, 1.0, 1.0, 1.0 ) ) > 3.5;

    return isSymmetrical ? j : float2( 1.0, 1.0 );
}

float3 NRD_SH_ResolveDiffuse( NRD_SG sh, float3 N )
{
    const float k0 = 1.0 / 3.0;
    const float k1 = 1.0;

    float Y = sh.c0 * k0 + dot( sh.c1, N ) * k1;

    return _NRD_YCoCgToLinear_Corrected( Y, sh.c0, sh.chroma );
}

float _NRD_SolidAngle( float coneCosAngle )
{
    return 2.0 * NRD_PI * ( 1.0 - coneCosAngle );
}

float _NRD_AcosApproxSphere( float x )
{
    float a = saturate( abs( x ) );
    float b = ( 0.5 * NRD_PI - 0.156583 * a ) * sqrt( 1.0 - a );

    return x >= 0 ? b : ( NRD_PI - b );
}

float _NRD_CosDifference( float cosA, float cosB )
{
    float sqSinA = saturate( 1.0 - cosA * cosA );
    float sqSinB = saturate( 1.0 - cosB * cosB );

    return cosA * cosB + sqrt( sqSinA * sqSinB );
}

float3 _NRD_RotateTowards( float3 a, float3 b, float cosAngle )
{
    float cosTheta = dot( a, b );
    float sinAngle = sqrt( saturate( 1.0 - cosAngle * cosAngle ) );
    float sinTheta = sqrt( saturate( 1.0 - cosTheta * cosTheta ) );
    float sinDiff = sinTheta * cosAngle - sinAngle * cosTheta;
    float3 rotated = ( sinDiff * a + sinAngle * b ) * rcp( sinTheta );

    return sinTheta < NRD_EPS ? a : rotated;
}

float4 _NRD_GetSphericalCapIntersection( float3 axisA, float cosA, float3 axisB, float cosB )
{
    float radiusA = _NRD_AcosApproxSphere( cosA );
    float radiusB = _NRD_AcosApproxSphere( cosB );

    float cosDist = dot( axisA, axisB );
    float dist = _NRD_AcosApproxSphere( cosDist );

    if( dist > radiusA + radiusB )
        return float4( axisA, 1.0 );

    if( radiusB > radiusA + dist )
        return float4( axisA, cosA );

    if( radiusA > radiusB + dist )
        return float4( axisB, cosB );

    float diff = abs( radiusA - radiusB );
    float x = 1.0 - saturate( ( dist - diff ) * rcp( radiusA + radiusB - diff ) );
    float area = x * x * ( 3.0 - 2.0 * x );
    float intersectionAngle = 1.0 - area * ( 1.0 - max( cosA, cosB ) );

    float cosDelta = _NRD_CosDifference( cosA, cosB );
    float cosAngle = sqrt( 0.5 * _NRD_CosDifference( cosDist, cosDelta ) + 0.5 );
    float3 L = _NRD_RotateTowards( axisB, axisA, cosAngle );

    return float4( L, intersectionAngle );
}

float NRD_ComputeCavityShadow( NRD_SG sg, float3 N, float cavity, float cosLightAngle, float shadowStrength )
{
    float coneCosAngle = sqrt( saturate( 1.0 - cavity ) );
    float3 lightDir = NRD_SG_ExtractDirection( sg );
    float4 coneIntersection = _NRD_GetSphericalCapIntersection( N, coneCosAngle, lightDir, cosLightAngle );

    float lightSolidAngle = _NRD_SolidAngle( cosLightAngle );
    float shadow = saturate( _NRD_SolidAngle( coneIntersection.w ) / max( lightSolidAngle, NRD_EPS ) );

    return lerp( 1.0, shadow, shadowStrength );
}

bool NRD_IsValidRadiance( float3 radiance )
{
    return !_NRD_IsInvalid( radiance );
}

float REBLUR_GetHitDist( float normHitDist, float viewZ, float3 hitDistParams, float roughness )
{
    float scale = _REBLUR_GetHitDistanceNormalization( viewZ, hitDistParams, roughness );

    return normHitDist * scale;
}

float NRD_GetNormalizedStrandThickness( float strandThickness, float pixelSize )
{
    return saturate( 0.5 * pixelSize / ( strandThickness + NRD_EPS ) );
}

#endif

#endif
