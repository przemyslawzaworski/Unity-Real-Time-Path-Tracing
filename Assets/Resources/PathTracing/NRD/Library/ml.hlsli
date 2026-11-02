// © 2021 NVIDIA Corporation

#ifndef ML_HLSLI
#define ML_HLSLI

#define compiletime

#ifndef __cplusplus
    #define ML_Unused( x )
    #define ML_INLINE
    #define ML_OUT( T )                            out T
    #define ML_INOUT( T )                          inout T
#else
    #define ML_OUT( T )                            T&
    #define ML_INOUT( T )                          T&
#endif

#ifndef ML_WINDOW_ORIGIN_OGL
    #define ML_WINDOW_ORIGIN_OGL                   0
#endif

#define ML_SIGN_DEFAULT                            ML_SIGN_FAST
#define ML_SQRT_DEFAULT                            ML_SQRT_SAFE
#define ML_RSQRT_DEFAULT                           ML_POSITIVE_RSQRT_ACCURATE_SAFE
#define ML_POSITIVE_RCP_DEFAULT                    ML_POSITIVE_RCP_ACCURATE_SAFE
#define ML_SMALL_EPS                               1e-15f
#define ML_EPS                                     1e-6f

#define ML_SPECULAR_DOMINANT_DIRECTION_DEFAULT     ML_SPECULAR_DOMINANT_DIRECTION_APPROX
#define ML_RF0_DIELECTRICS                         0.04f
#define ML_GTR_GAMMA                               1.5f
#define ML_VNDF_VERSION                            3

#define ML_TEXT_DIGIT_FORMAT                       10000
#define ML_TEXT_WITH_NICE_ONE_PIXEL_BACKGROUND     0

#define ML_RNG_NEXT_MODE                           ML_RNG_HASH
#define ML_RNG_FLOAT01_MODE                        ML_RNG_MANTISSA_BITS
#define ML_BAYER_DEFAULT                           ML_BAYER_REVERSEBITS

#ifdef ML_NAMESPACE
namespace ml
{
#endif

namespace Math
{

    #define _Pi( x ) radians( x * 180.0f )

    ML_INLINE float Pi( float x )
    { return _Pi( x ); }

    ML_INLINE float2 Pi( float2 x )
    { return _Pi( x ); }

    ML_INLINE float3 Pi( float3 x )
    { return _Pi( x ); }

    ML_INLINE float4 Pi( float4 x )
    { return _Pi( x ); }

    #define _RadToDeg( x ) ( x * 180.0f / Pi( 1.0f ) )

    ML_INLINE float RadToDeg( float x )
    { return _RadToDeg( x ); }

    ML_INLINE float2 RadToDeg( float2 x )
    { return _RadToDeg( x ); }

    ML_INLINE float3 RadToDeg( float3 x )
    { return _RadToDeg( x ); }

    ML_INLINE float4 RadToDeg( float4 x )
    { return _RadToDeg( x ); }

    #define _DegToRad( x ) ( x * Pi( 1.0f ) / 180.0f )

    ML_INLINE float DegToRad( float x )
    { return _DegToRad( x ); }

    ML_INLINE float2 DegToRad( float2 x )
    { return _DegToRad( x ); }

    ML_INLINE float3 DegToRad( float3 x )
    { return _DegToRad( x ); }

    ML_INLINE float4 DegToRad( float4 x )
    { return _DegToRad( x ); }

    #define _LinearStep( a, b, x ) saturate( ( x - a ) / ( b - a ) )

    ML_INLINE float LinearStep( float a, float b, float x )
    { return _LinearStep( a, b, x ); }

    ML_INLINE float2 LinearStep( float2 a, float2 b, float2 x )
    { return _LinearStep( a, b, x ); }

    ML_INLINE float3 LinearStep( float3 a, float3 b, float3 x )
    { return _LinearStep( a, b, x ); }

    ML_INLINE float4 LinearStep( float4 a, float4 b, float4 x )
    { return _LinearStep( a, b, x ); }

    #define _SmoothStep01( x ) ( x * x * ( 3.0f - x * 2.0f ) )

    ML_INLINE float SmoothStep01( float x )
    { return _SmoothStep01( saturate( x ) ); }

    ML_INLINE float2 SmoothStep01( float2 x )
    { return _SmoothStep01( saturate( x ) ); }

    ML_INLINE float3 SmoothStep01( float3 x )
    { return _SmoothStep01( saturate( x ) ); }

    ML_INLINE float4 SmoothStep01( float4 x )
    { return _SmoothStep01( saturate( x ) ); }

    ML_INLINE float SmoothStep( float a, float b, float x )
    { x = _LinearStep( a, b, x ); return _SmoothStep01( x ); }

    ML_INLINE float2 SmoothStep( float2 a, float2 b, float2 x )
    { x = _LinearStep( a, b, x ); return _SmoothStep01( x ); }

    ML_INLINE float3 SmoothStep( float3 a, float3 b, float3 x )
    { x = _LinearStep( a, b, x ); return _SmoothStep01( x ); }

    ML_INLINE float4 SmoothStep( float4 a, float4 b, float4 x )
    { x = _LinearStep( a, b, x ); return _SmoothStep01( x ); }

    #define _SmootherStep01( x ) ( x * x * x * ( x * ( x * 6.0f - 15.0f ) + 10.0f ) )

    ML_INLINE float SmootherStep( float a, float b, float x )
    { x = _LinearStep( a, b, x ); return _SmootherStep01( x ); }

    ML_INLINE float2 SmootherStep( float2 a, float2 b, float2 x )
    { x = _LinearStep( a, b, x ); return _SmootherStep01( x ); }

    ML_INLINE float3 SmootherStep( float3 a, float3 b, float3 x )
    { x = _LinearStep( a, b, x ); return _SmootherStep01( x ); }

    ML_INLINE float4 SmootherStep( float4 a, float4 b, float4 x )
    { x = _LinearStep( a, b, x ); return _SmootherStep01( x ); }

    #define ML_SIGN_BUILTIN 0
    #define ML_SIGN_FAST 1
    #define _Sign( x ) ( step( 0.0f, x ) * 2.0f - 1.0f )

    ML_INLINE float Sign( float x, compiletime const uint mode = ML_SIGN_DEFAULT )
    { return mode == ML_SIGN_FAST ? _Sign( x ) : sign( x ); }

    ML_INLINE float2 Sign( float2 x, compiletime const uint mode = ML_SIGN_DEFAULT )
    { return mode == ML_SIGN_FAST ? _Sign( x ) : sign( x ); }

    ML_INLINE float3 Sign( float3 x, compiletime const uint mode = ML_SIGN_DEFAULT )
    { return mode == ML_SIGN_FAST ? _Sign( x ) : sign( x ); }

    ML_INLINE float4 Sign( float4 x, compiletime const uint mode = ML_SIGN_DEFAULT )
    { return mode == ML_SIGN_FAST ? _Sign( x ) : sign( x ); }

    ML_INLINE float Pow( float x, float y )
    { return pow( abs( x ), y ); }

    ML_INLINE float2 Pow( float2 x, float y )
    { return pow( abs( x ), y ); }

    ML_INLINE float2 Pow( float2 x, float2 y )
    { return pow( abs( x ), y ); }

    ML_INLINE float3 Pow( float3 x, float y )
    { return pow( abs( x ), y ); }

    ML_INLINE float3 Pow( float3 x, float3 y )
    { return pow( abs( x ), y ); }

    ML_INLINE float4 Pow( float4 x, float y )
    { return pow( abs( x ), y ); }

    ML_INLINE float4 Pow( float4 x, float4 y )
    { return pow( abs( x ), y ); }

    ML_INLINE float Pow01( float x, float y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float2 Pow01( float2 x, float y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float2 Pow01( float2 x, float2 y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float3 Pow01( float3 x, float y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float3 Pow01( float3 x, float3 y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float4 Pow01( float4 x, float y )
    { return pow( saturate( x ), y ); }

    ML_INLINE float4 Pow01( float4 x, float4 y )
    { return pow( saturate( x ), y ); }

    #define ML_SQRT_BUILTIN 0
    #define ML_SQRT_SAFE 1

    ML_INLINE float Sqrt( float x, compiletime const uint mode = ML_SQRT_DEFAULT )
    { return sqrt( mode == ML_SQRT_SAFE ? max( x, 0.0f ) : x ); }

    ML_INLINE float2 Sqrt( float2 x, compiletime const uint mode = ML_SQRT_DEFAULT )
    { return sqrt( mode == ML_SQRT_SAFE ? max( x, 0.0f ) : x ); }

    ML_INLINE float3 Sqrt( float3 x, compiletime const uint mode = ML_SQRT_DEFAULT )
    { return sqrt( mode == ML_SQRT_SAFE ? max( x, 0.0f ) : x ); }

    ML_INLINE float4 Sqrt( float4 x, compiletime const uint mode = ML_SQRT_DEFAULT )
    { return sqrt( mode == ML_SQRT_SAFE ? max( x, 0.0f ) : x ); }

    ML_INLINE float Sqrt01( float x )
    { return sqrt( saturate( x ) ); }

    ML_INLINE float2 Sqrt01( float2 x )
    { return sqrt( saturate( x ) ); }

    ML_INLINE float3 Sqrt01( float3 x )
    { return sqrt( saturate( x ) ); }

    ML_INLINE float4 Sqrt01( float4 x )
    { return sqrt( saturate( x ) ); }

    #define ML_POSITIVE_RSQRT_BUILTIN 0
    #define ML_POSITIVE_RSQRT_BUILTIN_SAFE 1
    #define ML_POSITIVE_RSQRT_ACCURATE 2
    #define ML_POSITIVE_RSQRT_ACCURATE_SAFE 3

    ML_INLINE float Rsqrt( float x, compiletime const uint mode = ML_RSQRT_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RSQRT_BUILTIN_SAFE )
            return rsqrt( mode == ML_POSITIVE_RSQRT_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / sqrt( mode == ML_POSITIVE_RSQRT_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float2 Rsqrt( float2 x, compiletime const uint mode = ML_RSQRT_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RSQRT_BUILTIN_SAFE )
            return rsqrt( mode == ML_POSITIVE_RSQRT_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / sqrt( mode == ML_POSITIVE_RSQRT_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float3 Rsqrt( float3 x, compiletime const uint mode = ML_RSQRT_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RSQRT_BUILTIN_SAFE )
            return rsqrt( mode == ML_POSITIVE_RSQRT_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / sqrt( mode == ML_POSITIVE_RSQRT_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float4 Rsqrt( float4 x, compiletime const uint mode = ML_RSQRT_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RSQRT_BUILTIN_SAFE )
            return rsqrt( mode == ML_POSITIVE_RSQRT_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / sqrt( mode == ML_POSITIVE_RSQRT_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    #if 0

        #define _AcosApproxPositive( x ) ( lerp( 1.570796f, 1.395402f, saturate( x ) ) * sqrt( saturate( 1.0f - x ) ) )
    #else

        #define _AcosApproxPositive( x ) ( lerp( 1.567589f, 1.399331f, saturate( x ) ) * sqrt( saturate( 1.0f - x ) ) )
    #endif

    ML_INLINE float AcosApproxPositive( float x )
    { return _AcosApproxPositive( x ); }

    ML_INLINE float2 AcosApproxPositive( float2 x )
    { return _AcosApproxPositive( x ); }

    ML_INLINE float3 AcosApproxPositive( float3 x )
    { return _AcosApproxPositive( x ); }

    ML_INLINE float4 AcosApproxPositive( float4 x )
    { return _AcosApproxPositive( x ); }

    ML_INLINE float AcosApprox( float x )
    {

        float a = saturate( abs( x ) );
        float b = ( Math::Pi( 0.5f ) - 0.156583f * a ) * sqrt( 1.0f - a );
        float r = x >= 0.0f ? b : ( Math::Pi( 1.0f ) - b );

        return r;
    }

    ML_INLINE float2 AcosApprox( float2 x )
    { return float2( AcosApprox( x.x ), AcosApprox( x.y ) ); }

    ML_INLINE float3 AcosApprox( float3 x )
    { return float3( AcosApprox( x.x ), AcosApprox( x.y ), AcosApprox( x.z ) ); }

    ML_INLINE float4 AcosApprox( float4 x )
    { return float4( AcosApprox( x.x ), AcosApprox( x.y ), AcosApprox( x.z ), AcosApprox( x.w ) ); }

    #define _AtanApprox( x ) ( Math::Pi( 0.25f ) * x - ( abs( x ) * x - x ) * ( 0.2447f + 0.0663f * abs( x ) ) )

    ML_INLINE float AtanApprox( float x )
    { return _AtanApprox( x ); }

    ML_INLINE float2 AtanApprox( float2 x )
    { return _AtanApprox( x ); }

    ML_INLINE float3 AtanApprox( float3 x )
    { return _AtanApprox( x ); }

    ML_INLINE float4 AtanApprox( float4 x )
    { return _AtanApprox( x ); }

    #define ML_POSITIVE_RCP_BUILTIN 0
    #define ML_POSITIVE_RCP_BUILTIN_SAFE 1
    #define ML_POSITIVE_RCP_ACCURATE 2
    #define ML_POSITIVE_RCP_ACCURATE_SAFE 3

    ML_INLINE float PositiveRcp( float x, compiletime const uint mode = ML_POSITIVE_RCP_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RCP_BUILTIN_SAFE )
            return rcp( mode == ML_POSITIVE_RCP_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / ( mode == ML_POSITIVE_RCP_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float2 PositiveRcp( float2 x, compiletime const uint mode = ML_POSITIVE_RCP_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RCP_BUILTIN_SAFE )
            return rcp( mode == ML_POSITIVE_RCP_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / ( mode == ML_POSITIVE_RCP_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float3 PositiveRcp( float3 x, compiletime const uint mode = ML_POSITIVE_RCP_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RCP_BUILTIN_SAFE )
            return rcp( mode == ML_POSITIVE_RCP_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / ( mode == ML_POSITIVE_RCP_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float4 PositiveRcp( float4 x, compiletime const uint mode = ML_POSITIVE_RCP_DEFAULT )
    {
        if( mode <= ML_POSITIVE_RCP_BUILTIN_SAFE )
            return rcp( mode == ML_POSITIVE_RCP_BUILTIN ? x : max( x, ML_SMALL_EPS ) );

        return 1.0f / ( mode == ML_POSITIVE_RCP_ACCURATE ? x : max( x, ML_SMALL_EPS ) );
    }

    ML_INLINE float LengthSquared( float2 v )
    { return dot( v, v ); }

    ML_INLINE float LengthSquared( float3 v )
    { return dot( v, v ); }

    ML_INLINE float LengthSquared( float4 v )
    { return dot( v, v ); }

    ML_INLINE float Distance( float2 a, float2 b )
    { return length( a - b ); }

    ML_INLINE float Distance( float3 a, float3 b )
    { return length( a - b ); }

    ML_INLINE float ManhattanDistance( float2 a, float2 b )
    { return dot( abs( a - b ), 1.0f ); }

    ML_INLINE float ManhattanDistance( float3 a, float3 b )
    { return dot( abs( a - b ), 1.0f ); }

    ML_INLINE uint ReverseBits2( uint x )
    {
        return ( ( x & 0x1 ) << 1 ) | ( ( x & 0x2 ) >> 1 );
    }

    ML_INLINE uint ReverseBits4( uint x )
    {
        x = ( ( x & 0x5 ) << 1 ) | ( ( x & 0xA ) >> 1 );
        x = ( ( x & 0x3 ) << 2 ) | ( ( x & 0xC ) >> 2 );

        return x;
    }

    ML_INLINE uint ReverseBits8( uint x )
    {
        x = ( ( x & 0x55 ) << 1 ) | ( ( x & 0xAA ) >> 1 );
        x = ( ( x & 0x33 ) << 2 ) | ( ( x & 0xCC ) >> 2 );
        x = ( ( x & 0x0F ) << 4 ) | ( ( x & 0xF0 ) >> 4 );

        return x;
    }

    ML_INLINE uint ReverseBits16( uint x )
    {
        x = ( ( x & 0x5555 ) << 1 ) | ( ( x & 0xAAAA ) >> 1 );
        x = ( ( x & 0x3333 ) << 2 ) | ( ( x & 0xCCCC ) >> 2 );
        x = ( ( x & 0x0F0F ) << 4 ) | ( ( x & 0xF0F0 ) >> 4 );
        x = ( ( x & 0x00FF ) << 8 ) | ( ( x & 0xFF00 ) >> 8 );

        return x;
    }

    ML_INLINE uint ReverseBits32( uint x )
    {
    #ifndef __cplusplus
        x = reversebits( x );
    #else
        x = ( x << 16 ) | ( x >> 16 );
        x = ( ( x & 0x55555555 ) << 1 ) | ( ( x & 0xAAAAAAAA ) >> 1 );
        x = ( ( x & 0x33333333 ) << 2 ) | ( ( x & 0xCCCCCCCC ) >> 2 );
        x = ( ( x & 0x0F0F0F0F ) << 4 ) | ( ( x & 0xF0F0F0F0 ) >> 4 );
        x = ( ( x & 0x00FF00FF ) << 8 ) | ( ( x & 0xFF00FF00 ) >> 8 );
    #endif

        return x;
    }

    ML_INLINE uint CompactBits( uint x )
    {
        x &= 0x55555555;
        x = ( x ^ ( x >> 1 ) ) & 0x33333333;
        x = ( x ^ ( x >> 2 ) ) & 0x0F0F0F0F;
        x = ( x ^ ( x >> 4 ) ) & 0x00FF00FF;
        x = ( x ^ ( x >> 8 ) ) & 0x0000FFFF;

        return x;
    }
}

namespace Geometry
{
    ML_INLINE float4 GetRotator( float angle )
    {
        float ca = cos( angle );
        float sa = sin( angle );

        return float4( ca, sa, -sa, ca );
    }

#ifndef __cplusplus
    ML_INLINE float3x3 GetRotator( float3 axis, float angle )
    {
        float sa = sin( angle );
        float ca = cos( angle );
        float one_ca = 1.0f - ca;

        float3 a = sa * axis;
        float3 b = one_ca * axis.xyx * axis.yzz;

        float3 t1 = one_ca * ( axis * axis ) + ca;
        float3 t2 = b.xyz - a.zxy;
        float3 t3 = b.zxy + a.yzx;

        return float3x3
        (
            t1.x, t2.x, t3.x,
            t3.y, t1.y, t2.y,
            t2.z, t3.z, t1.z
        );
    }
#endif

    ML_INLINE float4 GetRotator( float sa, float ca )
    { return float4( ca, sa, -sa, ca ); }

    ML_INLINE float4 CombineRotators( float4 r1, float4 r2 )
    { return float4( r1.xyxy ) * r2.xxzz + float4( r1.zwzw ) * r2.yyww; }

    ML_INLINE float4 ScaleRotator( float4 r, float scale )
    { return r * scale; }

    ML_INLINE float4 ScaleRotator( float4 r, float2 scale )
    { return float4( scale.x * r.xz, scale.y * r.yw ); }

    ML_INLINE float2 RotateVector( float4 rotator, float2 v )
    { return v.x * rotator.xz + v.y * rotator.yw; }

#ifndef __cplusplus
    ML_INLINE float3 RotateVector( float4x4 m, float3 v )
    { return mul( ( float3x3 )m, v ); }

    ML_INLINE float3 RotateVector( float3x3 m, float3 v )
    { return mul( m, v ); }
#endif

    ML_INLINE float2 RotateVectorInverse( float4 rotator, float2 v )
    { return v.x * rotator.xy + v.y * rotator.zw; }

#ifndef __cplusplus
    ML_INLINE float3 RotateVectorInverse( float4x4 m, float3 v )
    { return mul( ( float3x3 )transpose( m ), v ); }

    ML_INLINE float3 RotateVectorInverse( float3x3 m, float3 v )
    { return mul( transpose( m ), v ); }
#endif

    ML_INLINE float3 AffineTransform( float4x4 m, float3 p )
    { return mul( m, float4( p, 1.0f ) ).xyz; }

#ifndef __cplusplus
    ML_INLINE float3 AffineTransform( float3x4 m, float3 p )
    { return mul( m, float4( p, 1.0f ) ); }
#endif

    ML_INLINE float3 AffineTransform( float4x4 m, float4 p )
    { return mul( m, p ).xyz; }

    ML_INLINE float4 ProjectiveTransform( float4x4 m, float3 p )
    { return mul( m, float4( p, 1.0f ) ); }

    ML_INLINE float4 ProjectiveTransform( float4x4 m, float4 p )
    { return mul( m, p ); }

    ML_INLINE float2 GetPerpendicular( float2 v )
    { return float2( -v.y, v.x ); }

    ML_INLINE float3 GetPerpendicularVector( float3 N )
    {
        float3 T = float3( N.z, -N.x, N.y );
        T -= N * dot( T, N );

        return normalize( T );
    }

#ifndef __cplusplus

    ML_INLINE float3x3 GetBasis( float3 N )
    {
        float sz = Math::Sign( N.z );
        float a  = 1.0f / ( sz + N.z );
        float ya = N.y * a;
        float b  = N.x * ya;
        float c  = N.x * sz;

        float3 T = float3( c * N.x * a - 1.0f, sz * b, c );
        float3 B = float3( b, N.y * ya - sz, N.y );

        return float3x3( T, B, N );
    }
#endif

    ML_INLINE float2 GetBarycentricCoords( float3 p, float3 a, float3 b, float3 c )
    {
        float3 v0 = b - a;
        float3 v1 = c - a;
        float3 v2 = p - a;

        float d00 = dot( v0, v0 );
        float d01 = dot( v0, v1 );
        float d11 = dot( v1, v1 );
        float d20 = dot( v2, v0 );
        float d21 = dot( v2, v1 );

        float2 barys;
        barys.x = d11 * d20 - d01 * d21;
        barys.y = d00 * d21 - d01 * d20;

        float invDenom = 1.0f / ( d00 * d11 - d01 * d01 );

        return barys * invDenom;
    }

    ML_INLINE float DistanceAttenuation( float dist, float Rmax )
    {

        float falloff = dist / Rmax;
        falloff *= falloff;
        falloff = saturate( 1.0f - falloff * falloff );
        falloff *= falloff;

        float atten = falloff;
        atten *= Math::PositiveRcp( dist * dist + 1.0f );

        return atten;
    }

    ML_INLINE float3 UnpackLocalNormal( float2 localNormal, bool isUnorm = true )
    {
        float3 n;
        n.xy = isUnorm ? min( localNormal * ( 255.0f / 127.0f ) - 1.0f, 1.0f ) : localNormal;
        n.z = Math::Sqrt01( 1.0f - Math::LengthSquared( n.xy ) );

        return n;
    }

    ML_INLINE float3 TransformLocalNormal( float2 localNormal, float4 T, float3 N )
    {
        float3 n = UnpackLocalNormal( localNormal );
        float3 B = cross( N, T.xyz );

        return normalize( n.x * T.xyz + T.w * n.y * B + n.z * N );
    }

    ML_INLINE float SolidAngle( float cosHalfAngle )
    {
        return Math::Pi( 2.0f ) * ( 1.0f - cosHalfAngle );
    }

    ML_INLINE float3 ReconstructViewPosition( float2 uv, float4 cameraFrustum, float viewZ = 1.0, float orthoMode = 0.0f )
    {
        float3 p;
        p.xy = uv * cameraFrustum.zw + cameraFrustum.xy;
        p.xy *= orthoMode == 0.0f ? viewZ : orthoMode;
        p.z = viewZ;

        return p;
    }

    ML_INLINE float2 GetScreenUv( float4x4 worldToClip, float3 X, bool killBackprojection = false )
    {
        float4 clip = Geometry::ProjectiveTransform( worldToClip, X );

        #if( ML_WINDOW_ORIGIN_OGL == 1 )
            float2 uv = ( clip.xy / clip.w ) * 0.5f + 0.5f;
        #else
            float2 uv = ( float2( clip.xy ) / clip.w ) * float2( 0.5f, -0.5f ) + 0.5f;
        #endif

        if( killBackprojection )
            uv = clip.w < 0.0 ? 99999.0f : uv;

        return uv;
    }

    #define ML_SCREEN_MOTION 0
    #define ML_WORLD_MOTION 1

    ML_INLINE float2 GetPrevUvFromMotion( float2 uv, float3 X, float4x4 worldToClipPrev, float3 motionVector, compiletime const uint motionType = ML_WORLD_MOTION )
    {
        float3 Xprev = X + motionVector;
        float2 uvPrev = GetScreenUv( worldToClipPrev, Xprev );

        if( motionType == ML_SCREEN_MOTION )
            uvPrev = uv + motionVector.xy;

        return uvPrev;
    }

#ifndef __cplusplus
    ML_INLINE float3x3 GetMirrorMatrix( float3 n )
    {
        float3x3 m;
        m[ 0 ] = float3( 1.0f - 2.0f * n.x * n.x, 0.0f - 2.0f * n.y * n.x, 0.0f - 2.0f * n.z * n.x );
        m[ 1 ] = float3( 0.0f - 2.0f * n.x * n.y, 1.0f - 2.0f * n.y * n.y, 0.0f - 2.0f * n.z * n.y );
        m[ 2 ] = float3( 0.0f - 2.0f * n.x * n.z, 0.0f - 2.0f * n.y * n.z, 1.0f - 2.0f * n.z * n.z );

        return m;
    }
#endif
}

namespace Color
{
    ML_INLINE float Luminance( float3 x )
    {

        return dot( x, float3( 0.2126f, 0.7152f, 0.0722f ) );
    }

    ML_INLINE float3 Saturation( float3 x, float amount )
    {
        float luma = Luminance( x );

        return lerp( x, luma, amount );
    }

    ML_INLINE float3 ToGamma( float3 x, float gamma = 2.2f )
    { return Math::Pow01( x, 1.0f / gamma ); }

    ML_INLINE float3 FromGamma( float3 x, float gamma = 2.2f )
    { return Math::Pow01( x, gamma ); }

    ML_INLINE float3 ToSrgb( float3 x )
    {
        const float4 consts = float4( 1.055f, 0.41666f, -0.055f, 12.92f );
        return lerp( x * consts.w, consts.x * Math::Pow( x, consts.yyy ) + consts.z, step( 0.0031308f, x ) );
    }

    ML_INLINE float3 FromSrgb( float3 x )
    {
        const float4 consts = float4( 1.0f / 12.92f, 1.0f / 1.055f, 0.055f / 1.055f, 1.0f / 0.41666f );
        return lerp( x * consts.x, Math::Pow( x * consts.y + consts.z, consts.www ), step( 0.04045f, x ) );
    }

    ML_INLINE float3 ToRec709( float3 x )
    {
        const float4 consts = float4( 1.0993f, 0.45f, -0.0993f, 4.5f );
        return lerp( x * consts.w, consts.x * Math::Pow( x, consts.yyy ) + consts.zzz, step( 0.0181f, x ) );
    }

    ML_INLINE float3 FromRec709( float3 x )
    {
        const float4 consts = float4( 1.0f / 4.5f, 1.0f / 1.0993f, 0.0993f / 1.0993f, 1.0f / 0.45f );
        return lerp( x * consts.x, Math::Pow( x * consts.y + consts.z, consts.www ), step( 0.08145f, x ) );
    }

    ML_INLINE float3 ToRec2084( float3 x )
    {
        const float m1 = 2610.0f / 4096.0f / 4.0f;
        const float m2 = 2523.0f / 4096.0f * 128.0f;
        const float c1 = 3424.0f / 4096.0f;
        const float c2 = 2413.0f / 4096.0f * 32.0f;
        const float c3 = 2392.0f / 4096.0f * 32.0f;

        float3 Lp = pow( x, m1 );

        return pow( ( c1 + c2 * Lp ) / ( 1.0f + c3 * Lp ), m2 );
    }

    ML_INLINE float3 FromRec2084( float3 x )
    {
        const float m1 = 2610.0f / 4096.0f / 4.0f;
        const float m2 = 2523.0f / 4096.0f * 128.0f;
        const float c1 = 3424.0f / 4096.0f;
        const float c2 = 2413.0f / 4096.0f * 32.0f;
        const float c3 = 2392.0f / 4096.0f * 32.0f;

        float3 Np = pow( x, 1.0f / m2 );

        return pow( max( Np - c1, 0.0f ) / ( c2 - c3 * Np ), 1.0f / m1 );
    }

    ML_INLINE float3 RgbToYCoCg( float3 x )
    {
        float Y = dot( x, float3( 0.25, 0.5, 0.25 ) );
        float Co = dot( x, float3( 0.5, 0.0, -0.5 ) );
        float Cg = dot( x, float3( -0.25, 0.5, -0.25 ) );

        return float3( Y, Co, Cg );
    }

    ML_INLINE float3 YCoCgToRgb( float3 x )
    {
        float t = x.x - x.z;

        float3 r;
        r.y = x.x + x.z;
        r.x = t + x.y;
        r.z = t - x.y;

        return r;
    }

#ifndef __cplusplus

    ML_INLINE float3 RgbToRec2020( float3 x )
    {
        static const float3x3 M =
        {
            0.627402, 0.329292, 0.043306,
            0.069095, 0.919544, 0.011360,
            0.016394, 0.088028, 0.895578
        };

        return mul( M, x );
    }

    ML_INLINE float3 Rec2020ToRgb( float3 x )
    {
        static const float3x3 M =
        {
            1.660496, -0.587656, -0.072840,
            -0.124547, 1.132895, -0.008348,
            -0.018154, -0.100597, 1.118751
        };

        return mul( M, x );
    }

    ML_INLINE float3 RgbToDcip3( float3 x )
    {
        static const float3x3 M =
        {
            0.822458, 0.177542, 0.000000,
            0.033193, 0.966807, 0.000000,
            0.017085, 0.072410, 0.910505
        };

        return mul( M, x );
    }

    ML_INLINE float3 Dcip3ToRgb( float3 x )
    {
        static const float3x3 M =
        {
            1.224947, -0.224947, 0.000000,
            -0.042056, 1.042056, 0.000000,
            -0.019641, -0.078651, 1.098291
        };

        return mul( M, x );
    }

    ML_INLINE float3 RgbToXyz( float3 x )
    {
        static const float3x3 M =
        {
            0.4123907992659595, 0.3575843393838780, 0.1804807884018343,
            0.2126390058715104, 0.7151686787677559, 0.0721923153607337,
            0.0193308187155918, 0.1191947797946259, 0.9505321522496608
        };

        return mul( M, x );
    }

    ML_INLINE float3 XyzToRgb( float3 x )
    {
        static const float3x3 M =
        {
            3.240969941904522, -1.537383177570094, -0.4986107602930032,
            -0.9692436362808803, 1.875967501507721, 0.04155505740717569,
            0.05563007969699373, -0.2039769588889765, 1.056971514242878
        };

        return mul( M, x );
    }

    ML_INLINE uint ToLogLuv( float3 x )
    {

        float3 XYZ = RgbToXyz( x );

        float logY = 409.6f * ( log2( XYZ.y ) + 20.0f );
        uint Le = uint( clamp( logY, 0.0f, 16383.0f ) );

        if( Le == 0 )
            return 0;

        float invDenom = 1.0f / ( -2.0f * XYZ.x + 12.0f * XYZ.y + 3.0f * ( XYZ.x + XYZ.y + XYZ.z ) );
        float2 uv = float2( 4.0f, 9.0f ) * XYZ.xy * invDenom;

        uint2 uve = uint2( clamp( 820.0f * uv, 0.0, 511.0f ) );

        return ( Le << 18 ) | ( uve.x << 9 ) | uve.y;
    }

    ML_INLINE float3 FromLogLuv( uint x )
    {

        uint Le = x >> 18;
        if( Le == 0 )
            return 0;

        float logY = ( float( Le ) + 0.5f ) / 409.6f - 20.0f;
        float Y = exp2( logY );

        uint2 uve = uint2( x >> 9, x ) & 0x1ff;
        float2 uv = ( float2( uve ) + 0.5f ) / 820.0f;

        float invDenom = 1.0f / ( 6.0f * uv.x - 16.0f * uv.y + 12.0f );
        float2 xy = float2( 9.0f, 4.0f ) * uv * invDenom;

        float s = Y / xy.y;
        float3 XYZ = float3( s * xy.x, Y, s * ( 1.0f - xy.x - xy.y ) );

        float3 color = max( XyzToRgb( XYZ ), 0.0f );

        return color;
    }
#endif

    ML_INLINE float3 HdrToLinear( float3 colorMulExposure )
    {
        float3 x0 = colorMulExposure * 0.38317f;
        float3 x1 = FromGamma( 1.0f - exp( -colorMulExposure ) );
        float3 color = lerp( x0, x1, step( 1.413f, colorMulExposure ) );

        return color;
    }

    ML_INLINE float3 HdrToLinear_Reinhard( float3 color, float exposure = 1.0f )
    {
        float luma = Luminance( color );

        return color * Math::PositiveRcp( 1.0f + luma * exposure );
    }

    ML_INLINE float3 _UnchartedCurve( float3 x )
    {
        float A = 0.22f;
        float B = 0.3f;
        float C = 0.1f;
        float D = 0.2f;
        float E = 0.01f;
        float F = 0.3f;

        return ( ( x * ( A * x + C * B ) + D * E ) / ( x * ( A * x + B ) + D * F ) ) - ( E / F );
    }

    ML_INLINE float3 HdrToLinear_Uncharted( float3 colorMulExposure, float whitePoint = 11.2f )
    {

        return _UnchartedCurve( colorMulExposure ) / _UnchartedCurve( whitePoint ).x;
    }

    ML_INLINE float3 HdrToLinear_Aces( float3 colorMulExposure )
    {

        colorMulExposure *= 0.6f;

        float A = 2.51f;
        float B = 0.03f;
        float C = 2.43f;
        float D = 0.59f;
        float E = 0.14f;

        return ( ( colorMulExposure * ( A * colorMulExposure + B ) ) * Math::PositiveRcp( colorMulExposure * ( C * colorMulExposure + D ) + E ) );
    }

    ML_INLINE float3 LinearToHdr( float3 color )
    {
        float3 x0 = color / 0.38317f;
        float3 x1 = -log( max( 1.0f - ToGamma( color ), ML_EPS ) );
        float3 colorMulExposure = lerp( x0, x1, step( 1.413f, x0 ) );

        return colorMulExposure;
    }

    ML_INLINE float3 LinearToHdr_Reinhard( float3 color, float exposure = 1.0f )
    {
        float luma = Luminance( color );

        return color * Math::PositiveRcp( 1.0f - luma * exposure );
    }

    ML_INLINE float4 BlendSoft( float4 a, float4 b )
    {
        float4 t = 1.0f - 2.0f * b;
        float4 c = ( 2.0f * b + a * t ) * a;
        float4 d = 2.0f * a * ( 1.0f - b ) - Math::Sqrt( a ) * t;

        return lerp( c, d, step( 0.5f, b ) );
    }

    ML_INLINE float4 BlendDarken( float4 a, float4 b )
    { return lerp( a, b, step( b, a ) ); }

    ML_INLINE float4 BlendDifference( float4 a, float4 b )
    { return abs( a - b ); }

    ML_INLINE float4 BlendScreen( float4 a, float4 b )
    { return a + b * ( 1.0f - a ); }

    ML_INLINE float4 BlendOverlay( float4 a, float4 b )
    {
        float4 c = 2.0f * a * b;
        float4 d = 2.0f * BlendScreen( a, b ) - 1.0f;

        return lerp( c, d, step( 0.5f, a ) );
    }

    #define _Clamp( m1, sigma, input ) clamp( input, m1 - sigma, m1 + sigma )

    ML_INLINE float4 Clamp( float4 m1, float4 sigma, float4 color )
    { return _Clamp( m1, sigma, color ); }

    ML_INLINE float3 Clamp( float3 m1, float3 sigma, float3 color )
    { return _Clamp( m1, sigma, color ); }

    ML_INLINE float2 Clamp( float2 m1, float2 sigma, float2 color )
    { return _Clamp( m1, sigma, color ); }

    ML_INLINE float Clamp( float m1, float sigma, float color )
    { return _Clamp( m1, sigma, color ); }

    ML_INLINE float3 ClampAabb( float3 m1, float3 sigma, float3 color )
    {
        float3 center = m1;
        float3 extents = sigma;

        float3 d = color - center;
        float3 ts = abs( extents / ( d + 0.0001f ) );
        float t = min( ts.x, min( ts.y, ts.z ) );

        return center + d * saturate( t );
    }

    ML_INLINE float3 ColorizeLinear( float x )
    {
        x = saturate( x );

        float3 color;
        if( x < 0.25f )
            color = lerp( float3( 0, 0, 0 ), float3( 0, 0, 1 ), Math::SmoothStep( 0.00f, 0.25f, x ) );
        else if( x < 0.50f )
            color = lerp( float3( 0, 0, 1 ), float3( 0, 1, 0 ), Math::SmoothStep( 0.25f, 0.50f, x ) );
        else if( x < 0.75f )
            color = lerp( float3( 0, 1, 0 ), float3( 1, 1, 0 ), Math::SmoothStep( 0.50f, 0.75f, x ) );
        else
            color = lerp( float3( 1, 1, 0 ), float3( 1, 0, 0 ), Math::SmoothStep( 0.75f, 1.00f, x ) );

        return color;
    }

    ML_INLINE float3 ColorizeZucconi( float x )
    {

        x = saturate( x ) * 0.85f;

        const float3 c1 = float3( 3.54585104f, 2.93225262f, 2.41593945f );
        const float3 x1 = float3( 0.69549072f, 0.49228336f, 0.27699880f );
        const float3 y1 = float3( 0.02312639f, 0.15225084f, 0.52607955f );

        float3 t = c1 * ( x - x1 );
        float3 a = saturate( 1.0f - t * t - y1 );

        const float3 c2 = float3( 3.90307140f, 3.21182957f, 3.96587128f );
        const float3 x2 = float3( 0.11748627f, 0.86755042f, 0.66077860f );
        const float3 y2 = float3( 0.84897130f, 0.88445281f, 0.73949448f );

        float3 k = c2 * ( x - x2 );
        float3 b = saturate( 1.0f - k * k - y2 );

        return saturate( a + b );
    }
}

namespace Packing
{

    ML_INLINE uint RgbaToUint( float4 c, compiletime const uint Rbits, compiletime const uint Gbits = 0, compiletime const uint Bbits = 0, compiletime const uint Abits = 0 )
    {
        const uint Rmask = ( 1u << Rbits ) - 1u;
        const uint Gmask = ( 1u << Gbits ) - 1u;
        const uint Bmask = ( 1u << Bbits ) - 1u;
        const uint Amask = ( 1u << Abits ) - 1u;
        const uint Gshift = Rbits;
        const uint Bshift = Gshift + Gbits;
        const uint Ashift = Bshift + Bbits;
        const float4 scale = float4( float( Rmask ), float( Gmask ), float( Bmask ), float( Amask ) );

        uint4 p = uint4( saturate( c ) * scale + 0.5 );
        p.yzw <<= uint3( Gshift, Bshift, Ashift );
        p.xy |= p.zw;

        return p.x | p.y;
    }

    ML_INLINE float4 UintToRgba( uint p, compiletime const uint Rbits, compiletime const uint Gbits = 0, compiletime const uint Bbits = 0, compiletime const uint Abits = 0 )
    {
        const uint Rmask = ( 1u << Rbits ) - 1u;
        const uint Gmask = ( 1u << Gbits ) - 1u;
        const uint Bmask = ( 1u << Bbits ) - 1u;
        const uint Amask = ( 1u << Abits ) - 1u;
        const uint Gshift = Rbits;
        const uint Bshift = Gshift + Gbits;
        const uint Ashift = Bshift + Bbits;
        const float4 scale = 1.0f / max( float4( float( Rmask ), float( Gmask ), float( Bmask ), float( Amask ) ), 1.0f );

        uint4 c = p >> uint4( 0, Gshift, Bshift, Ashift );
        c &= uint4( Rmask, Gmask, Bmask, Amask );

        return float4( c ) * scale;
    }

    ML_INLINE uint Rg16fToUint( float2 c )
    {
        return ( f32tof16( c.y ) << 16 ) | ( f32tof16( c.x ) & 0xFFFF );
    }

    ML_INLINE float2 UintToRg16f( uint p )
    {
        float2 c;
        c.x = f16tof32( p );
        c.y = f16tof32( p >> 16 );

        return c;
    }

    ML_INLINE uint EncodeRgbe( float3 c )
    {
        float sharedExp = ceil( log2( max( max( c.x, c.y ), c.z ) ) );
        float4 p = float4( c * exp2( -sharedExp ), ( sharedExp + 128.0f ) / 255.0f );

        return RgbaToUint( p, 8, 8, 8, 8 );
    }

    ML_INLINE float3 DecodeRgbe( uint p )
    {
        float4 c = UintToRgba( p, 8, 8, 8, 8 );

        return exp2( c.w * 255.0f - 128.0f ) * c.xyz;
    }

    ML_INLINE float2 EncodeUnitVector( float3 v, compiletime const bool bSigned = false )
    {
        v /= dot( abs( v ), 1.0f );

        float2 octWrap = ( 1.0f - abs( v.yx ) ) * Math::Sign( v.xy );
        v.xy = v.z >= 0.0f ? v.xy : octWrap;

        return bSigned ? v.xy : 0.5f * v.xy + 0.5f;
    }

    ML_INLINE float3 DecodeUnitVector( float2 p, compiletime const bool bSigned = false, compiletime const bool bNormalize = true )
    {
        p = bSigned ? p : ( p * 2.0 - 1.0f );

        float3 n = float3( p.xy, 1.0f - abs( p.x ) - abs( p.y ) );
        float t = saturate( -n.z );
        n.xy -= t * Math::Sign( n.xy );

        return bNormalize ? normalize( n ) : n;
    }
}

namespace Filtering
{
    ML_INLINE float GetModifiedRoughnessFromNormalVariance( float linearRoughness, float3 nonNormalizedAverageNormal )
    {

        float l = length( nonNormalizedAverageNormal );
        float kappa = saturate( 1.0f - l * l ) * Math::PositiveRcp( l * ( 3.0f - l * l ) );

        return Math::Sqrt01( linearRoughness * linearRoughness + kappa );
    }

    ML_INLINE float GetMipmapLevel( float duvdxMulTexSizeSq, float duvdyMulTexSizeSq, compiletime const float maxAnisotropy = 1.0f )
    {

        float Pmax = max( duvdxMulTexSizeSq, duvdyMulTexSizeSq );

        if( maxAnisotropy > 1.0f )
        {
            float Pmin = min( duvdxMulTexSizeSq, duvdyMulTexSizeSq );
            float N = min( Pmax * Math::PositiveRcp( Pmin ), maxAnisotropy );
            Pmax *= Math::PositiveRcp( N );
        }

        float mip = 0.5f * log2( Pmax );

        return mip;
    }

    struct Nearest
    {
        float2 origin;
    };

    ML_INLINE Nearest GetNearestFilter( float2 uv, float2 texSize )
    {
        float2 t = uv * texSize;

        Nearest result;
        result.origin = floor( t );

        return result;
    }

    struct Bilinear
    {
        float2 origin;
        float2 weights;
    };

    ML_INLINE Bilinear GetBilinearFilter( float2 uv, float2 texSize )
    {
        float2 t = uv * texSize - 0.5;

        Bilinear result;
        result.origin = floor( t );
        result.weights = saturate( t - result.origin );

        return result;
    }

    ML_INLINE float ApplyBilinearFilter( float s00, float s10, float s01, float s11, Bilinear f )
    { return lerp( lerp( s00, s10, f.weights.x ), lerp( s01, s11, f.weights.x ), f.weights.y ); }

    ML_INLINE float2 ApplyBilinearFilter( float2 s00, float2 s10, float2 s01, float2 s11, Bilinear f )
    { return lerp( lerp( s00, s10, f.weights.x ), lerp( s01, s11, f.weights.x ), f.weights.y ); }

    ML_INLINE float3 ApplyBilinearFilter( float3 s00, float3 s10, float3 s01, float3 s11, Bilinear f )
    { return lerp( lerp( s00, s10, f.weights.x ), lerp( s01, s11, f.weights.x ), f.weights.y ); }

    ML_INLINE float4 ApplyBilinearFilter( float4 s00, float4 s10, float4 s01, float4 s11, Bilinear f )
    { return lerp( lerp( s00, s10, f.weights.x ), lerp( s01, s11, f.weights.x ), f.weights.y ); }

    ML_INLINE float4 GetBilinearCustomWeights( Bilinear f, float4 customWeights )
    {
        float2 oneMinusWeights = saturate( 1.0f - f.weights );

        float4 weights = customWeights;
        weights.x *= oneMinusWeights.x * oneMinusWeights.y;
        weights.y *= f.weights.x * oneMinusWeights.y;
        weights.z *= oneMinusWeights.x * f.weights.y;
        weights.w *= f.weights.x * f.weights.y;

        return weights;
    }

    #define _ApplyBilinearCustomWeights( s00, s10, s01, s11, w, normalize ) \
        ( ( s00 * w.x + s10 * w.y + s01 * w.z + s11 * w.w ) * ( normalize ? ( dot( w, 1.0f ) < 0.0001f ? 0.0f : rcp( dot( w, 1.0f ) ) ) : 1.0f ) )

    ML_INLINE float ApplyBilinearCustomWeights( float s00, float s10, float s01, float s11, float4 w, compiletime const bool normalize = true )
    { return _ApplyBilinearCustomWeights( s00, s10, s01, s11, w, normalize ); }

    ML_INLINE float2 ApplyBilinearCustomWeights( float2 s00, float2 s10, float2 s01, float2 s11, float4 w, compiletime const bool normalize = true )
    { return _ApplyBilinearCustomWeights( s00, s10, s01, s11, w, normalize ); }

    ML_INLINE float3 ApplyBilinearCustomWeights( float3 s00, float3 s10, float3 s01, float3 s11, float4 w, compiletime const bool normalize = true )
    { return _ApplyBilinearCustomWeights( s00, s10, s01, s11, w, normalize ); }

    ML_INLINE float4 ApplyBilinearCustomWeights( float4 s00, float4 s10, float4 s01, float4 s11, float4 w, compiletime const bool normalize = true )
    { return _ApplyBilinearCustomWeights( s00, s10, s01, s11, w, normalize ); }

    struct CatmullRom
    {
        float2 origin;
        float2 weights[4];
    };

    ML_INLINE CatmullRom GetCatmullRomFilter( float2 uv, float2 texSize, float sharpness = 0.5 )
    {
        float2 tci = uv * texSize;
        float2 tc = floor( tci - 0.5f ) + 0.5f;
        float2 f = saturate( tci - tc );
        float2 f2 = f * f;
        float2 f3 = f2 * f;

        CatmullRom result;
        result.origin = tc - 1.5f;
        result.weights[ 0 ] = -sharpness * f3 + 2.0f * sharpness * f2 - sharpness * f;
        result.weights[ 1 ] = ( 2.0f - sharpness ) * f3 - ( 3.0f - sharpness ) * f2 + 1.0f;
        result.weights[ 2 ] = -( 2.0f - sharpness ) * f3 + ( 3.0f - 2.0f * sharpness ) * f2 + sharpness * f;
        result.weights[ 3 ] = sharpness * f3 - sharpness * f2;

        return result;
    }

    ML_INLINE float4 ApplyCatmullRomFilterNoCorners( CatmullRom filter, float4 s10, float4 s20, float4 s01, float4 s11, float4 s21, float4 s31, float4 s02, float4 s12, float4 s22, float4 s32, float4 s13, float4 s23 )
    {

        float w = filter.weights[ 1 ].x * filter.weights[ 0 ].y;
        float4 color = s10 * w;
        float sum = w;

        w = filter.weights[ 2 ].x * filter.weights[ 0 ].y;
        color += s20 * w;
        sum += w;

        w = filter.weights[ 0 ].x * filter.weights[ 1 ].y;
        color += s01 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 1 ].y;
        color += s11 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 1 ].y;
        color += s21 * w;
        sum += w;

        w = filter.weights[ 3 ].x * filter.weights[ 1 ].y;
        color += s31 * w;
        sum += w;

        w = filter.weights[ 0 ].x * filter.weights[ 2 ].y;
        color += s02 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 2 ].y;
        color += s12 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 2 ].y;
        color += s22 * w;
        sum += w;

        w = filter.weights[ 3 ].x * filter.weights[ 2 ].y;
        color += s32 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 3 ].y;
        color += s13 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 3 ].y;
        color += s23 * w;
        sum += w;

        return color * Math::PositiveRcp( sum );
    }

    ML_INLINE float ApplyCatmullRomFilterNoCorners( CatmullRom filter, float s10, float s20, float s01, float s11, float s21, float s31, float s02, float s12, float s22, float s32, float s13, float s23 )
    {

        float w = filter.weights[ 1 ].x * filter.weights[ 0 ].y;
        float color = s10 * w;
        float sum = w;

        w = filter.weights[ 2 ].x * filter.weights[ 0 ].y;
        color += s20 * w;
        sum += w;

        w = filter.weights[ 0 ].x * filter.weights[ 1 ].y;
        color += s01 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 1 ].y;
        color += s11 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 1 ].y;
        color += s21 * w;
        sum += w;

        w = filter.weights[ 3 ].x * filter.weights[ 1 ].y;
        color += s31 * w;
        sum += w;

        w = filter.weights[ 0 ].x * filter.weights[ 2 ].y;
        color += s02 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 2 ].y;
        color += s12 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 2 ].y;
        color += s22 * w;
        sum += w;

        w = filter.weights[ 3 ].x * filter.weights[ 2 ].y;
        color += s32 * w;
        sum += w;

        w = filter.weights[ 1 ].x * filter.weights[ 3 ].y;
        color += s13 * w;
        sum += w;

        w = filter.weights[ 2 ].x * filter.weights[ 3 ].y;
        color += s23 * w;
        sum += w;

        return color * Math::PositiveRcp( sum );
    }

    ML_INLINE float4 GetBlurOffsets1D( float2 directionDivTexSize )
    { return float4( 1.7229f, 1.7229f, 3.8697f, 3.8697f ) * float4( directionDivTexSize.xy, directionDivTexSize.xy ); }

    ML_INLINE float4 GetBlurOffsets2D( float2 invTexSize )
    { return float4( 0.4f, 0.9f, -0.4f, -0.9f ) * float4( invTexSize.xy, invTexSize.xy ); }
}

namespace Sequence
{

    #define ML_BAYER_LINEAR 0
    #define ML_BAYER_REVERSEBITS 1

    ML_INLINE uint Bayer2x2ui( uint2 samplePos, uint frameIndex, compiletime const uint mode = ML_BAYER_DEFAULT )
    {
        uint2 p = samplePos & 1;
        uint b = ( p.y << 1 ) | ( p.y ^ p.x );

        uint sampleOffset = mode == ML_BAYER_REVERSEBITS ? Math::ReverseBits2( frameIndex ) : frameIndex;

        return ( b + sampleOffset ) & 0x3;
    }

    ML_INLINE uint Bayer4x4ui( uint2 samplePos, uint frameIndex, compiletime const uint mode = ML_BAYER_DEFAULT )
    {
        uint2 p = samplePos & 3;
        uint b = ( ( p.y & 1 ) << 2 ) | ( ( p.x & 1 ) << 3 ) | ( ( p.y & 2 ) >> 1 ) | ( p.x & 2 );

        uint sampleOffset = mode == ML_BAYER_REVERSEBITS ? Math::ReverseBits4( frameIndex ) : frameIndex;

        return ( b + sampleOffset ) & 0xF;
    }

    ML_INLINE float Bayer2x2( uint2 samplePos, uint frameIndex, compiletime const uint mode = ML_BAYER_DEFAULT )
    {
        uint bayer = Bayer2x2ui( samplePos, frameIndex, mode );

        return ( bayer + 0.5f ) / 4.0f;
    }

    ML_INLINE float Bayer4x4( uint2 samplePos, uint frameIndex, compiletime const uint mode = ML_BAYER_DEFAULT )
    {
        uint bayer = Bayer4x4ui( samplePos, frameIndex, mode );

        return ( bayer + 0.5f ) / 16.0f;
    }

    ML_INLINE float2 Hammersley2D( uint index, float sampleCount )
    {
        float x = float( index ) / sampleCount;
        float y = float( Math::ReverseBits32( index ) ) * 2.3283064365386963e-10f;

        return float2( x, y );
    }

    ML_INLINE uint2 Morton2D( uint index )
    {
        return uint2( Math::CompactBits( index ), Math::CompactBits( index >> 1 ) );
    }

    ML_INLINE uint CheckerBoard( uint2 samplePos, uint frameIndex )
    {
        uint a = samplePos.x ^ samplePos.y;

        return ( a ^ frameIndex ) & 0x1;
    }

    ML_INLINE uint IntegerExplode( uint x )
    {
        x = ( x | ( x << 8 ) ) & 0x00FF00FF;
        x = ( x | ( x << 4 ) ) & 0x0F0F0F0F;
        x = ( x | ( x << 2 ) ) & 0x33333333;
        x = ( x | ( x << 1 ) ) & 0x55555555;

        return x;
    }

    ML_INLINE uint Zorder( uint2 xy )
    { return IntegerExplode( xy.x ) | ( IntegerExplode( xy.y ) << 1 ); }

    ML_INLINE uint Lcg( uint x )
    {

        return 1664525u * x + 1013904223u;
    }

    ML_INLINE uint XorShift( uint x )
    {

        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;

        return x;
    }

    ML_INLINE uint Hash( uint x )
    {

        #if 1
            x ^= x >> 16;
            x *= 0x7FEB352D;
            x ^= x >> 15;
            x *= 0x846CA68B;
            x ^= x >> 16;
        #else
            x ^= x >> 17;
            x *= 0xED5AD4BB;
            x ^= x >> 11;
            x *= 0xAC4C1B51;
            x ^= x >> 15;
            x *= 0x31848BAB;
            x ^= x >> 14;
        #endif

        return x;
    }

    ML_INLINE uint HashCombine( uint seed, uint value )
    { return seed ^ ( Hash( value ) + 0x9E3779B9 + ( seed << 6 ) + ( seed >> 2 ) ); }

    ML_INLINE float Halton( uint n, uint base )
    {
        float a = 1.0f;
        float b = 0.0f;
        float baseInv = 1.0f / ( float )base;

        while( n != 0 )
        {
            a *= baseInv;
            b += a * float( n % base );
            n = uint( n * baseInv );
        }

        return b;
    }

    ML_INLINE float Halton2( uint n )
    { return Math::ReverseBits32( n ) * 2.3283064365386963e-10f; }

    ML_INLINE float Halton1D( uint n )
    { return Halton2( n ); }

    ML_INLINE float2 Halton2D( uint n )
    { return float2( Halton2( n ), Halton( n, 3 ) ); }

    ML_INLINE float3 Halton3D( uint n )
    { return float3( Halton2( n ), Halton( n, 3 ), Halton( n, 5 ) ); }

    ML_INLINE float Weyl1D( float p, uint n )
    { return frac( p + float( n * 10368889 ) / exp2( 24.0f ) ); }

    ML_INLINE float2 Weyl2D( float2 p, uint n )
    { return frac( p + float2( float( n * 12664745 ), float( n * 9560333 ) ) / exp2( 24.0f ) ); }

    ML_INLINE float3 Weyl3D( float3 p, uint n )
    { return frac( p + float3( float( n * 13743434 ), float( n * 11258243 ), float( n * 9222443 ) ) / exp2( 24.0f ) ); }
}

namespace Rng
{
    #define ML_RNG_LCG 0
    #define ML_RNG_XORSHIFT 1
    #define ML_RNG_HASH 2

    ML_INLINE uint _Next( uint seed )
    {
        #if( ML_RNG_NEXT_MODE == ML_RNG_LCG )
            seed = Sequence::Lcg( seed );
        #elif( ML_RNG_NEXT_MODE == ML_RNG_XORSHIFT )
            seed = Sequence::XorShift( seed );
        #else
            seed = Sequence::Hash( seed );
        #endif

        return seed;
    }

    #define ML_RNG_UTOF 0
    #define ML_RNG_MANTISSA_BITS 1

    #if( ML_RNG_FLOAT01_MODE == ML_RNG_UTOF )
        #define _UintToFloat01( x ) ( ( x >> 8 ) * ( 1.0f / float( 1 << 24 ) ) )
    #else
        #define _UintToFloat01( x ) ( asfloat( ( x >> 9 ) | 0x3F800000 ) - 1.0f )
    #endif

    namespace Tea
    {
#ifndef __cplusplus
        static uint2 rngTeaState;

        #define RNG_TEA_ARG
        #define RNG_TEA_INPUT
        #define RNG_TEA_ARG_COMMA
        #define RNG_TEA_INPUT_COMMA
#else
        #define RNG_TEA_ARG rngTeaState
        #define RNG_TEA_INPUT uint2& rngTeaState
        #define RNG_TEA_ARG_COMMA RNG_TEA_ARG,
        #define RNG_TEA_INPUT_COMMA RNG_TEA_INPUT,
#endif

        ML_INLINE void Initialize( RNG_TEA_INPUT_COMMA uint linearIndex, uint frameIndex, uint spinNum = 16 )
        {
            rngTeaState.x = linearIndex;
            rngTeaState.y = frameIndex;

            uint s = 0;
            for( uint n = 0; n < spinNum; n++ )
            {
                s += 0x9E3779B9;
                rngTeaState.x += ( ( rngTeaState.y << 4 ) + 0xA341316C ) ^ ( rngTeaState.y + s ) ^ ( ( rngTeaState.y >> 5 ) + 0xC8013EA4 );
                rngTeaState.y += ( ( rngTeaState.x << 4 ) + 0xAD90777D ) ^ ( rngTeaState.x + s ) ^ ( ( rngTeaState.x >> 5 ) + 0x7E95761E );
            }
        }

        ML_INLINE void Initialize( RNG_TEA_INPUT_COMMA uint2 samplePos, uint frameIndex, uint spinNum = 16 )
        { Initialize( RNG_TEA_ARG_COMMA Sequence::Zorder( samplePos ), frameIndex, spinNum ); }

        ML_INLINE uint GetUint( RNG_TEA_INPUT )
        {
            rngTeaState.x = _Next( rngTeaState.x );

            return rngTeaState.x;
        }

        ML_INLINE uint2 GetUint2( RNG_TEA_INPUT )
        {
            rngTeaState.x = _Next( rngTeaState.x );
            rngTeaState.y = _Next( rngTeaState.y );

            return rngTeaState;
        }

        ML_INLINE uint4 GetUint4( RNG_TEA_INPUT )
        { return uint4( GetUint2( RNG_TEA_ARG ), GetUint2( RNG_TEA_ARG ) ); }

        ML_INLINE float GetFloat( RNG_TEA_INPUT )
        { uint x = GetUint( RNG_TEA_ARG ); return _UintToFloat01( x ); }

        ML_INLINE float2 GetFloat2( RNG_TEA_INPUT )
        { uint2 x = GetUint2( RNG_TEA_ARG ); return _UintToFloat01( x ); }

        ML_INLINE float4 GetFloat4( RNG_TEA_INPUT )
        { uint4 x = GetUint4( RNG_TEA_ARG ); return _UintToFloat01( x ); }
    }

    namespace Hash
    {
#ifndef __cplusplus
        static uint rngHashState;

        #define RNG_HASH_ARG
        #define RNG_HASH_INPUT
        #define RNG_HASH_ARG_COMMA
        #define RNG_HASH_INPUT_COMMA
#else
        #define RNG_HASH_ARG rngHashState
        #define RNG_HASH_INPUT uint& rngHashState
        #define RNG_HASH_ARG_COMMA RNG_HASH_ARG,
        #define RNG_HASH_INPUT_COMMA RNG_HASH_INPUT,
#endif

        ML_INLINE void Initialize( RNG_HASH_INPUT_COMMA uint linearIndex, uint frameIndex )
        { rngHashState = Sequence::HashCombine( Sequence::Hash( frameIndex + 0x035F9F29 ), linearIndex ); }

        ML_INLINE void Initialize( RNG_HASH_INPUT_COMMA uint2 samplePos, uint frameIndex )
        { Initialize( RNG_HASH_ARG_COMMA Sequence::Zorder( samplePos ), frameIndex ); }

        ML_INLINE uint GetUint( RNG_HASH_INPUT )
        {
            rngHashState = _Next( rngHashState );

            return rngHashState;
        }

        ML_INLINE uint2 GetUint2( RNG_HASH_INPUT )
        { return uint2( GetUint( RNG_HASH_ARG ), GetUint( RNG_HASH_ARG ) ); }

        ML_INLINE uint4 GetUint4( RNG_HASH_INPUT )
        { return uint4( GetUint2( RNG_HASH_ARG ), GetUint2( RNG_HASH_ARG ) ); }

        ML_INLINE float GetFloat( RNG_HASH_INPUT )
        { uint x = GetUint( RNG_HASH_ARG ); return _UintToFloat01( x ); }

        ML_INLINE float2 GetFloat2( RNG_HASH_INPUT )
        { uint2 x = GetUint2( RNG_HASH_ARG ); return _UintToFloat01( x ); }

        ML_INLINE float4 GetFloat4( RNG_HASH_INPUT )
        { uint4 x = GetUint4( RNG_HASH_ARG ); return _UintToFloat01( x ); }
    }
}

namespace BRDF
{

    namespace IOR
    {
        static const float Vacuum      = 1.0f;
        static const float Air         = 1.00029f;
        static const float Ice         = 1.31f;
        static const float Water       = 1.333f;
        static const float Quartz      = 1.46f;
        static const float Glass       = 1.55f;
        static const float Sapphire    = 1.77f;
        static const float Diamond     = 2.42f;
    };

    ML_INLINE float Pow5( float x )
    { return Math::Pow01( 1.0f - x, 5.0f ); }

    ML_INLINE void ConvertBaseColorMetalnessToAlbedoRf0( float3 baseColor, float metalness, ML_OUT(float3) albedo, ML_OUT(float3) Rf0 )
    {

        albedo = baseColor * saturate( 1.0f - metalness );
        Rf0 = lerp( ML_RF0_DIELECTRICS, baseColor, metalness );
    }

    ML_INLINE float FresnelTerm_Shadowing( float3 Rf0 )
    {

        return saturate( Color::Luminance( Rf0 ) / 0.02f );
    }

    ML_INLINE float DiffuseTerm_Lambert( float linearRoughness, float NoL, float NoV, float VoH )
    {
        ML_Unused( linearRoughness );
        ML_Unused( NoL );
        ML_Unused( NoV );
        ML_Unused( VoH );

        float d = 1.0f;

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DiffuseTerm_Burley( float linearRoughness, float NoL, float NoV, float VoH )
    {
        linearRoughness = saturate( linearRoughness );

        float energyBias = 0.5f;
        float energyFactor = 1.0f;

        float f = 2.0f * VoH * VoH * linearRoughness + energyBias - 1.0f;
        float FdV = 1.0f + f * Pow5( NoV );
        float FdL = 1.0f + f * Pow5( NoL );
        float d = FdV * FdL * energyFactor;

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DiffuseTerm_BurleyFrostbite( float linearRoughness, float NoL, float NoV, float VoH )
    {
        linearRoughness = saturate( linearRoughness );

        float energyBias = lerp( 0.0f, 0.5f, linearRoughness );
        float energyFactor = lerp( 1.0f, 1.0f / 1.51f, linearRoughness );

        float f = 2.0f * VoH * VoH * linearRoughness + energyBias - 1.0f;
        float FdV = 1.0f + f * Pow5( NoV );
        float FdL = 1.0f + f * Pow5( NoL );
        float d = FdV * FdL * energyFactor;

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DiffuseTerm_OrenNayar( float linearRoughness, float NoL, float NoV, float VoH )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float VoL = 2.0f * VoH - 1.0f;
        float c1 = 1.0f - 0.5f * m2 / ( m2 + 0.33f );
        float cosri = VoL - NoV * NoL;
        float a = cosri >= 0.0f ? saturate( NoL * Math::PositiveRcp( NoV ) ) : NoL;
        float c2 = 0.45f * m2 / ( m2 + 0.09f ) * cosri * a;
        float d = NoL * c1 + c2;

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DiffuseTerm( float linearRoughness, float NoL, float NoV, float VoH )
    {

        return DiffuseTerm_BurleyFrostbite( linearRoughness, NoL, NoV, VoH );
    }

    ML_INLINE float DistributionTerm_Blinn( float linearRoughness, float NoH )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float alpha = 2.0f * Math::PositiveRcp( m2 ) - 2.0f;
        float norm = ( alpha + 2.0f ) / 2.0f;
        float d = norm * Math::Pow01( NoH, alpha );

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DistributionTerm_Beckmann( float linearRoughness, float NoH )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float b = NoH * NoH;
        float a = m2 * b;
        float d = exp( ( b - 1.0f ) * Math::PositiveRcp( a ) ) * Math::PositiveRcp( a * b );

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DistributionTerm_GGX( float linearRoughness, float NoH )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;

        #if 1
            float t = 1.0f - NoH * NoH * ( 0.99999994f - m2 );
            float a = max( m, ML_EPS ) / t;
        #else
            float t = ( NoH * m2 - NoH ) * NoH + 1.0f;
            float a = m * Math::PositiveRcp( t );
        #endif

        float d = a * a;

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DistributionTerm_GTR( float linearRoughness, float NoH )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float t = ( NoH * m2 - NoH ) * NoH + 1.0f;

        float t1 = Math::Pow01( t, -ML_GTR_GAMMA );
        float t2 = 1.0f - Math::Pow01( m2, -( ML_GTR_GAMMA - 1.0f ) );
        float d = ( ML_GTR_GAMMA - 1.0f ) * ( m2 * t1 - t1 ) * Math::PositiveRcp( t2 );

        return d / Math::Pi( 1.0f );
    }

    ML_INLINE float DistributionTerm( float linearRoughness, float NoH )
    {

        return DistributionTerm_GGX( linearRoughness, NoH );
    }

    ML_INLINE float GeometryTerm_Smith( float linearRoughness, float NoVL )
    {
        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float a = NoVL + Math::Sqrt01( ( NoVL - m2 * NoVL ) * NoVL + m2 );

        return 2.0f * NoVL * Math::PositiveRcp( a );
    }

    ML_INLINE float GeometryTermMod_Implicit( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( linearRoughness );
        ML_Unused( NoL );
        ML_Unused( NoV );
        ML_Unused( VoH );
        ML_Unused( NoH );

        return 0.25f;
    }

    ML_INLINE float GeometryTermMod_Neumann( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( linearRoughness );
        ML_Unused( VoH );
        ML_Unused( NoH );

        return 0.25f * Math::PositiveRcp( max( NoL, NoV ) );
    }

    ML_INLINE float GeometryTermMod_Schlick( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( VoH );
        ML_Unused( NoH );

        float m = saturate( linearRoughness * linearRoughness );

        float k = m * 0.5f;

        float a = NoL * ( 1.0f - k ) + k;
        float b = NoV * ( 1.0f - k ) + k;

        return 0.25f / max( a * b, ML_EPS );
    }

    ML_INLINE float GeometryTermMod_SmithCorrelated( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( VoH );
        ML_Unused( NoH );

        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float a = NoV * Math::Sqrt01( ( NoL - m2 * NoL ) * NoL + m2 );
        float b = NoL * Math::Sqrt01( ( NoV - m2 * NoV ) * NoV + m2 );

        return 0.5f * Math::PositiveRcp( a + b );
    }

    ML_INLINE float GeometryTermMod_SmithUncorrelated( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( VoH );
        ML_Unused( NoH );

        float m = saturate( linearRoughness * linearRoughness );
        float m2 = m * m;
        float a = NoL + Math::Sqrt01( ( NoL - m2 * NoL ) * NoL + m2 );
        float b = NoV + Math::Sqrt01( ( NoV - m2 * NoV ) * NoV + m2 );

        return Math::PositiveRcp( a * b );
    }

    ML_INLINE float GeometryTermMod_CookTorrance( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {
        ML_Unused( linearRoughness );

        float k = 2.0f * NoH / VoH;
        float a = min( k * NoV, k * NoL );

        return saturate( a ) * 0.25f * Math::PositiveRcp( NoV * NoL );
    }

    ML_INLINE float GeometryTermMod( float linearRoughness, float NoL, float NoV, float VoH, float NoH )
    {

        return GeometryTermMod_SmithCorrelated( linearRoughness, NoL, NoV, VoH, NoH );
    }

    ML_INLINE float3 FresnelTerm_None( float3 Rf0, float VoNH )
    {
        ML_Unused( VoNH );

        return Rf0;
    }

    ML_INLINE float3 FresnelTerm_Schlick( float3 Rf0, float VoNH )
    { return Rf0 + ( 1.0f - Rf0 ) * Pow5( VoNH ); }

    ML_INLINE float3 FresnelTerm_Fresnel( float3 Rf0, float VoNH )
    {
        float3 nu = Math::Sqrt01( Rf0 );
        nu = ( 1.0f + nu ) * Math::PositiveRcp( 1.0f - nu );

        float k = VoNH * VoNH - 1.0f;
        float3 g = sqrt( nu * nu + k );
        float3 a = ( g - VoNH ) / ( g + VoNH );
        float3 c = ( g * VoNH + k ) / ( g * VoNH - k );

        return 0.5 * a * a * ( c * c + 1.0f );
    }

    ML_INLINE float FresnelTerm_Dielectric( float eta, float VoN )
    {
        float saSq = eta * eta * ( 1.0f - VoN * VoN );

        float ca = Math::Sqrt01( 1.0f - saSq );

        float Rs = ( eta * VoN - ca ) * Math::PositiveRcp( eta * VoN + ca );
        float Rp = ( eta * ca - VoN ) * Math::PositiveRcp( eta * ca + VoN );

        return 0.5f * ( Rs * Rs + Rp * Rp );
    }

    ML_INLINE float3 FresnelTerm( float3 Rf0, float VoNH )
    {

        return FresnelTerm_Schlick( Rf0, VoNH ) * FresnelTerm_Shadowing( Rf0 );
    }

    ML_INLINE float3 EnvironmentTerm_Pesce( float3 Rf0, float NoV, float linearRoughness )
    {
        float m = saturate( linearRoughness * linearRoughness );

        float a = 7.0f * NoV + 4.0f * m;
        float bias = exp2( -a );

        float b = min( linearRoughness, 0.739f + 0.323f * NoV ) - 0.434f;
        float scale = 1.0f - bias - m * max( bias, b );

        return saturate( Rf0 * scale + bias );
    }

    ML_INLINE float3 EnvironmentTerm_Ross( float3 Rf0, float NoV, float linearRoughness )
    {
        float m = saturate( linearRoughness * linearRoughness );

        float f = Math::Pow01( 1.0f - NoV, 5.0f * exp( -2.69f * m ) ) / ( 1.0f + 22.7f * Math::Pow01( m, 1.5f ) );

        float scale = 1.0f - f;
        float bias = f;

        return saturate( Rf0 * scale + bias );
    }

#ifndef __cplusplus

    ML_INLINE float3 EnvironmentTerm_Rtg( float3 Rf0, float NoV, float linearRoughness )
    {
        float m = saturate( linearRoughness * linearRoughness );

        float4 X;
        X.x = 1.0f;
        X.y = NoV;
        X.z = NoV * NoV;
        X.w = NoV * X.z;

        float4 Y;
        Y.x = 1.0f;
        Y.y = m;
        Y.z = m * m;
        Y.w = m * Y.z;

        float2x2 M1 = float2x2( 0.99044f, -1.28514f, 1.29678f, -0.755907f );
        float3x3 M2 = float3x3( 1.0f, 2.92338f, 59.4188f, 20.3225f, -27.0302f, 222.592f, 121.563f, 626.13f, 316.627f );

        float2x2 M3 = float2x2( 0.0365463f, 3.32707f, 9.0632f, -9.04756f );
        float3x3 M4 = float3x3( 1.0f, 3.59685f, -1.36772f, 9.04401f, -16.3174f, 9.22949f, 5.56589f, 19.7886f, -20.2123f );

        float bias = dot( mul( M1, X.xy ), Y.xy ) * Math::PositiveRcp( dot( mul( M2, X.xyw ), Y.xyw ) );
        float scale = dot( mul( M3, X.xy ), Y.xy ) * Math::PositiveRcp( dot( mul( M4, X.xzw ), Y.xyw ) );

        return saturate( Rf0 * scale + bias );
    }
#endif

    ML_INLINE float3 EnvironmentTerm( float3 Rf0, float NoV, float linearRoughness )
    {

        return EnvironmentTerm_Ross( Rf0, NoV, linearRoughness ) * FresnelTerm_Shadowing( Rf0 );
    }

    ML_INLINE void DirectLighting( float3 N, float3 L, float3 V, float3 Rf0, float linearRoughness, ML_OUT(float3) Cdiff, ML_OUT(float3) Cspec )
    {
        float3 H = normalize( L + V );

        float NoL = saturate( dot( N, L ) );
        float NoH = saturate( dot( N, H ) );
        float VoH = saturate( dot( V, H ) );

        float NoV = abs( dot( N, V ) );

        float D = DistributionTerm( linearRoughness, NoH );
        float G = GeometryTermMod( linearRoughness, NoL, NoV, VoH, NoH );
        float3 F = FresnelTerm( Rf0, VoH );
        float Kdiff = DiffuseTerm( linearRoughness, NoL, NoV, VoH );

        Cspec = F * D * G * NoL;
        Cdiff = ( 1.0f - F ) * Kdiff * NoL;

        Cspec = saturate( Cspec );
    }
}

namespace ImportanceSampling
{

    ML_INLINE float GetSpecularLobeTanHalfAngle( float linearRoughness, float percentOfVolume = 0.75 )
    {
        percentOfVolume = saturate( percentOfVolume );

        return saturate( linearRoughness ) * sqrt( percentOfVolume / ( 1.0f - percentOfVolume + ML_EPS ) );
    }

    ML_INLINE float3 CorrectDirectionToInfiniteSource( float3 N, float3 L, float3 V, float tanOfAngularSize )
    {
        float3 R = reflect( -V, N );
        float3 centerToRay = L - dot( L, R ) * R;
        float3 closestPoint = centerToRay * saturate( tanOfAngularSize * Math::Rsqrt( Math::LengthSquared( centerToRay ) ) );

        return normalize( L - closestPoint );
    }

    #define ML_SPECULAR_DOMINANT_DIRECTION_G1      0
    #define ML_SPECULAR_DOMINANT_DIRECTION_G2      1
    #define ML_SPECULAR_DOMINANT_DIRECTION_APPROX  2

    ML_INLINE float GetSpecularDominantFactor( float NoV, float linearRoughness, compiletime const uint mode = ML_SPECULAR_DOMINANT_DIRECTION_DEFAULT )
    {
        linearRoughness = saturate( linearRoughness );

        float dominantFactor;
        if( mode == ML_SPECULAR_DOMINANT_DIRECTION_G2 )
        {
            float a = 0.298475f * log( 39.4115f - 39.0029f * linearRoughness );
            dominantFactor = Math::Pow01( 1.0f - NoV, 10.8649f ) * ( 1.0f - a ) + a;
        }
        else if( mode == ML_SPECULAR_DOMINANT_DIRECTION_G1 )
            dominantFactor = 0.298475f * NoV * log( 39.4115f - 39.0029f * linearRoughness ) + ( 0.385503f - 0.385503f * NoV ) * log( 13.1567f - 12.2848f * linearRoughness );
        else
        {
            float s = 1.0f - linearRoughness;
            dominantFactor = s * ( Math::Sqrt01( s ) + linearRoughness );
        }

        return saturate( dominantFactor );
    }

    ML_INLINE float3 GetSpecularDominantDirectionWithFactor( float3 N, float3 V, float dominantFactor )
    {
        float3 R = reflect( -V, N );
        float3 D = lerp( N, R, dominantFactor );

        return normalize( D );
    }

    ML_INLINE float4 GetSpecularDominantDirection( float3 N, float3 V, float linearRoughness, compiletime const uint mode = ML_SPECULAR_DOMINANT_DIRECTION_DEFAULT )
    {
        float NoV = abs( dot( N, V ) );
        float dominantFactor = GetSpecularDominantFactor( NoV, linearRoughness, mode );

        return float4( GetSpecularDominantDirectionWithFactor( N, V, dominantFactor ), dominantFactor );
    }

    namespace Uniform
    {
        ML_INLINE float GetPDF( )
        { return 1.0f / Math::Pi( 2.0 ); }

        ML_INLINE float3 GetRay( float2 rnd )
        {
            float phi = rnd.x * Math::Pi( 2.0 );

            float cosTheta = rnd.y;
            float sinTheta = Math::Sqrt01( 1.0f - cosTheta * cosTheta );

            float3 ray;
            ray.x = sinTheta * cos( phi );
            ray.y = sinTheta * sin( phi );
            ray.z = cosTheta;

            return ray;
        }
    }

    namespace Cosine
    {
        ML_INLINE float GetPDF( float NoL = 1.0f )
        {
            float pdf = NoL / Math::Pi( 1.0f );

            return max( pdf, ML_EPS );
        }

        ML_INLINE float3 GetRay( float2 rnd )
        {
            float phi = rnd.x * Math::Pi( 2.0f );

            float cosTheta = Math::Sqrt01( rnd.y );
            float sinTheta = Math::Sqrt01( 1.0f - cosTheta * cosTheta );

            float3 ray;
            ray.x = sinTheta * cos( phi );
            ray.y = sinTheta * sin( phi );
            ray.z = cosTheta;

            return ray;
        }
    }

    namespace NDF
    {
        ML_INLINE float GetPDF( float linearRoughness, float NoH, float VoH )
        {
            float pdf = BRDF::DistributionTerm_GGX( linearRoughness, NoH );
            pdf *= NoH;
            pdf *= Math::PositiveRcp( 4.0f * VoH );

            return max( pdf, ML_EPS );
        }

        ML_INLINE float3 GetRay( float2 rnd, float linearRoughness )
        {
            float m = saturate( linearRoughness * linearRoughness );
            float m2 = m * m;
            float t = ( m2 - 1.0f ) * rnd.y + 1.0f;
            float cosThetaSq = ( 1.0f - rnd.y ) * Math::PositiveRcp( t );
            float sinTheta = Math::Sqrt01( 1.0f - cosThetaSq );
            float phi = rnd.x * Math::Pi( 2.0f );

            float3 ray;
            ray.x = sinTheta * cos( phi );
            ray.y = sinTheta * sin( phi );
            ray.z = Math::Sqrt01( cosThetaSq );

            return ray;
        }
    }

    namespace VNDF
    {
        ML_INLINE float GetPDF( float3 Vlocal, float NoH, float linearRoughness )
        {
            float2 m = saturate( linearRoughness * linearRoughness );

            float a = min( m.x, m.y );
            float a2 = a * a;

            float D = BRDF::DistributionTerm_GGX( linearRoughness, NoH );

            #if( ML_VNDF_VERSION == 1 )

                float G1mod = Math::PositiveRcp( Vlocal.z + Math::Sqrt01( ( Vlocal.z - a2 * Vlocal.z ) * Vlocal.z + a2 ) );

                return 0.5 * G1mod * D;
            #else
                float2 wi = m * Vlocal.xy;
                float lenSq = dot(wi, wi);
                float t = sqrt(lenSq + Vlocal.z * Vlocal.z);

                if( Vlocal.z < 0.0f )
                    return 0.5f * D * ( t - Vlocal.z ) / lenSq;

                #if( ML_VNDF_VERSION == 3 )
                    float s = 1.0f + length( Vlocal.xy );
                    float s2 = s * s;
                    float k = ( 1.0f - a2 ) * s2 / ( s2 + a2 * Vlocal.z * Vlocal.z );
                #else
                    float k = 1.0f;
                #endif

                return 0.5f * D / ( k * Vlocal.z + t );
            #endif
        }

        ML_INLINE float3 GetRay( float2 rnd, float2 linearRoughness, float3 Vlocal, float trimFactor = 1.0f )
        {

            rnd.y *= trimFactor;

            float2 m = saturate( linearRoughness * linearRoughness );

            float3 wi = normalize( float3( m * Vlocal.xy, Vlocal.z ) );

            float phi = Math::Pi( 2.0f ) * rnd.x;
            #if( ML_VNDF_VERSION == 1 )
                float lenSq = dot( wi.xy, wi.xy );
                float3 X = lenSq > ML_EPS ? float3( -wi.y, wi.x, 0.0 ) * rsqrt( lenSq ) : float3( 1.0, 0.0, 0.0 );
                float3 Y = cross( wi, X );

                float z = 0.5 * ( 1.0f + wi.z );
                float r = Math::Sqrt01( rnd.y );
                float x = r * cos( phi );
                float y = lerp( Math::Sqrt01( 1.0f - x * x ), r * sin( phi ), z );

                float3 h = x * X + y * Y + Math::Sqrt01( 1.0f - x * x - y * y ) * wi;
            #else
                #if( ML_VNDF_VERSION == 2 )
                    float b = wi.z;
                #elif( ML_VNDF_VERSION == 3 )
                    float a = min( m.x, m.y );
                    float s = 1.0f + length( Vlocal.xy );
                    float a2 = a * a;
                    float s2 = s * s;
                    float k = ( 1.0f - a2 ) * s2 / ( s2 + a2 * Vlocal.z * Vlocal.z );
                    float b = Vlocal.z > 0.0f ? k * wi.z : wi.z;
                #endif

                float z = 1.0f - rnd.y * ( 1.0f + b );
                float r = Math::Sqrt01( 1.0f - z * z );
                float x = r * cos( phi );
                float y = r * sin( phi );

                float3 h = float3( x, y, z ) + wi;
            #endif

            return normalize( float3( m * h.xy, max( h.z, ML_EPS ) ) );
        }
    }
}

struct SH1
{
    float3 c0_chroma;
    float3 c1;
};

namespace SphericalHarmonics
{
    ML_INLINE SH1 ConvertToSecondOrder( float3 color, float3 direction )
    {
        float3 YCoCg = Color::RgbToYCoCg( color );

        SH1 sh;
        sh.c0_chroma = YCoCg;
        sh.c1 = YCoCg.x * direction;

        return sh;
    }

    ML_INLINE float3 ExtractColor( SH1 sh )
    {
        return Color::YCoCgToRgb( sh.c0_chroma );
    }

    ML_INLINE float3 ExtractDirection( SH1 sh )
    {
        return sh.c1 * Math::Rsqrt( Math::LengthSquared( sh.c1 ) );
    }

    ML_INLINE void Add( ML_INOUT( SH1 ) result, SH1 x )
    {
        result.c0_chroma += x.c0_chroma;
        result.c1 += x.c1;
    }

    ML_INLINE void Mul( ML_INOUT( SH1 ) result, float x )
    {
        result.c0_chroma *= x;
        result.c1 *= x;
    }

    ML_INLINE float3 ResolveColor( SH1 sh, float3 N )
    {
        float Y = 0.5f * dot( N, sh.c1 ) + 0.25f * sh.c0_chroma.x;

        Y *= 2.0f;

        Y = max( Y, 0.0f );

        float modifier = ( Y + ML_EPS ) / ( sh.c0_chroma.x + ML_EPS );
        float2 CoCg = modifier * sh.c0_chroma.yz;

        return Color::YCoCgToRgb( float3( Y, CoCg ) );
    }
}

#ifndef __cplusplus
namespace Text
{

    static const uint Char_0            = 0;
    static const uint Char_Minus        = 10;
    static const uint Char_Dot          = 11;
    static const uint Char_Space        = 12;
    static const uint Char_Ampersand    = 13;
    static const uint Char_A            = 14;

    static const uint CHAR_W            = 5;
    static const uint CHAR_H            = 6;

    static const uint BACKGROUND        = 1;
    static const uint FOREGROUND        = 2;

    #define X                           1
    #define _                           0

#if( ML_WINDOW_ORIGIN_OGL == 1 )
    #define CHAR( a1, a2, a3, a4, a5, \
                  b1, b2, b3, b4, b5, \
                  c1, c2, c3, c4, c5, \
                  d1, d2, d3, d4, d5, \
                  e1, e2, e3, e4, e5, \
                  f1, f2, f3, f4, f5 )      ( ( f1 <<  0 ) | ( f2 <<  1 ) | ( f3 <<  2 ) | ( f4 <<  3 ) | ( f5 <<  4 ) | \
                                              ( e1 <<  5 ) | ( e2 <<  6 ) | ( e3 <<  7 ) | ( e4 <<  8 ) | ( e5 <<  9 ) | \
                                              ( d1 << 10 ) | ( d2 << 11 ) | ( d3 << 12 ) | ( d4 << 13 ) | ( d5 << 14 ) | \
                                              ( c1 << 15 ) | ( c2 << 16 ) | ( c3 << 17 ) | ( c4 << 18 ) | ( c5 << 19 ) | \
                                              ( b1 << 20 ) | ( b2 << 21 ) | ( b3 << 22 ) | ( b4 << 23 ) | ( b5 << 24 ) | \
                                              ( a1 << 25 ) | ( a2 << 26 ) | ( a3 << 27 ) | ( a4 << 28 ) | ( a5 << 29 ) )
#else
    #define CHAR( a1, a2, a3, a4, a5, \
                  b1, b2, b3, b4, b5, \
                  c1, c2, c3, c4, c5, \
                  d1, d2, d3, d4, d5, \
                  e1, e2, e3, e4, e5, \
                  f1, f2, f3, f4, f5 )      ( ( a1 <<  0 ) | ( a2 <<  1 ) | ( a3 <<  2 ) | ( a4 <<  3 ) | ( a5 <<  4 ) | \
                                              ( b1 <<  5 ) | ( b2 <<  6 ) | ( b3 <<  7 ) | ( b4 <<  8 ) | ( b5 <<  9 ) | \
                                              ( c1 << 10 ) | ( c2 << 11 ) | ( c3 << 12 ) | ( c4 << 13 ) | ( c5 << 14 ) | \
                                              ( d1 << 15 ) | ( d2 << 16 ) | ( d3 << 17 ) | ( d4 << 18 ) | ( d5 << 19 ) | \
                                              ( e1 << 20 ) | ( e2 << 21 ) | ( e3 << 22 ) | ( e4 << 23 ) | ( e5 << 24 ) | \
                                              ( f1 << 25 ) | ( f2 << 26 ) | ( f3 << 27 ) | ( f4 << 28 ) | ( f5 << 29 ) )
#endif

    static const uint font[ ] =
    {
        CHAR( _, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                _, X, X, X, _ ),

        CHAR( _, _, _, _, X,
                _, _, _, X, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X ),

        CHAR( X, X, X, X, _,
                _, _, _, _, X,
                X, X, X, X, X,
                X, _, _, _, _,
                X, _, _, _, _,
                X, X, X, X, X ),

        CHAR( X, X, X, X, _,
                _, _, _, _, X,
                _, X, X, X, X,
                _, _, _, _, X,
                _, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X ),

        CHAR( X, X, X, X, _,
                X, _, _, _, _,
                X, X, X, X, X,
                _, _, _, _, X,
                _, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( _, X, X, X, X,
                X, _, _, _, _,
                X, X, X, X, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( _, X, X, X, _,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X ),

        CHAR( _, X, X, X, _,
                X, _, _, _, X,
                X, X, X, X, X,
                X, _, _, _, X,
                X, _, _, _, X,
                _, X, X, X, _ ),

        CHAR( _, X, X, X, _,
                X, _, _, _, X,
                X, X, X, X, X,
                _, _, _, _, X,
                _, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( _, _, _, _, _,
                _, _, _, _, _,
                X, X, X, X, X,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _ ),

        CHAR( _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, X, _, _ ),

        CHAR( _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _,
                _, _, _, _, _ ),

        CHAR( _, _, X, _, _,
                _, X, _, X, _,
                _, _, X, _, _,
                _, X, _, X, _,
                X, _, _, X, _,
                _, X, X, _, X ),

        CHAR( _, _, X, X, X,
                _, X, _, _, X,
                X, _, _, _, X,
                X, X, X, X, X,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( X, X, X, X, _,
                X, _, _, _, X,
                X, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( _, X, X, X, X,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _,
                _, X, X, X, X ),

        CHAR( X, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( X, X, X, X, X,
                X, _, _, _, _,
                X, X, X, X, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, X, X, X, X ),

        CHAR( X, X, X, X, X,
                X, _, _, _, _,
                X, X, X, X, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _ ),

        CHAR( _, X, X, X, X,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, X, X,
                X, _, _, _, X,
                _, X, X, X, X ),

        CHAR( X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( _, X, X, X, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, X, X, X, _ ),

        CHAR( _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X,
                _, _, _, _, X,
                X, _, _, _, X,
                _, X, X, X, _ ),

        CHAR( X, _, _, _, X,
                X, _, _, X, _,
                X, X, X, _, _,
                X, _, _, X, _,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, _, _, _, _,
                X, X, X, X, X ),

        CHAR( X, _, _, _, X,
                X, X, _, X, X,
                X, _, X, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( X, _, _, _, X,
                X, X, _, _, X,
                X, _, X, _, X,
                X, _, _, X, X,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( _, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                _, X, X, X, _ ),

        CHAR( X, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, _,
                X, _, _, _, _,
                X, _, _, _, _ ),

        CHAR( _, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, X, _, X,
                X, _, _, X, _,
                _, X, X, _, X ),

        CHAR( X, X, X, X, _,
                X, _, _, _, X,
                X, _, _, _, X,
                X, X, X, X, _,
                X, _, _, X, _,
                X, _, _, _, X ),

        CHAR( _, X, X, X, X,
                X, _, _, _, _,
                _, X, X, X, _,
                _, _, _, _, X,
                _, _, _, _, X,
                X, X, X, X, _ ),

        CHAR( X, X, X, X, X,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _ ),

        CHAR( X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                _, X, X, X, _ ),

        CHAR( X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                X, _, _, _, X,
                _, X, _, X, _,
                _, _, X, _, _ ),

        CHAR( X, _, _, _, X,
                X, _, _, _, X,
                X, _, X, _, X,
                X, _, X, _, X,
                X, X, X, X, X,
                _, X, _, X, _ ),

        CHAR( X, _, _, _, X,
                _, X, _, X, _,
                _, _, X, _, _,
                _, X, _, X, _,
                X, _, _, _, X,
                X, _, _, _, X ),

        CHAR( X, _, _, _, X,
                _, X, _, X, _,
                _, X, _, X, _,
                _, _, X, _, _,
                _, _, X, _, _,
                _, _, X, _, _ ),

        CHAR( X, X, X, X, X,
                _, _, _, X, _,
                _, _, X, _, _,
                _, X, _, _, _,
                X, _, _, _, _,
                X, X, X, X, X ),
    };

    #undef CHAR
    #undef _
    #undef X

    #if( ML_TEXT_WITH_NICE_ONE_PIXEL_BACKGROUND == 1 )

        #define _RenderChar( ch )  \
            if( all( int2( state.xy ) >= -int( state.z ) && int2( state.xy ) < int2( CHAR_W + 1, CHAR_H + 1 ) * int( state.z ) ) ) \
            { \
                state.w = BACKGROUND; \
                if( all( state.xy < uint2( CHAR_W, CHAR_H ) * state.z ) ) \
                { \
                    uint2 p = state.xy / state.z; \
                    uint bits = font[ ch ]; \
                    uint bit = bits & ( 1u << ( p.y * CHAR_W + p.x ) ); \
                    state.w = bit ? FOREGROUND : BACKGROUND; \
                } \
            }

    #else

        #define _RenderChar( ch )  \
            if( all( state.xy < uint2( CHAR_W, CHAR_H ) * state.z ) ) \
            { \
                uint2 p = state.xy / state.z; \
                uint bits = font[ ch ]; \
                uint bit = bits & ( 1u << ( p.y * CHAR_W + p.x ) ); \
                state.w = ( bit != 0 ) ? FOREGROUND : BACKGROUND; \
            }

    #endif

    ML_INLINE uint4 Init( uint2 pixelPos, uint2 origin, uint scale )
    {
        uint4 state;
        state.xy = pixelPos - origin;
        state.z = scale;
        state.w = 0;

        return state;
    }

    ML_INLINE bool IsBackground( uint4 state )
    { return state.w == BACKGROUND; }

    ML_INLINE bool IsForeground( uint4 state )
    { return state.w == FOREGROUND; }

    ML_INLINE void NextChar( ML_INOUT( uint4 ) state )
    { state.x -= ( CHAR_W + 1 ) * state.z; }

    ML_INLINE void NextDigit( ML_INOUT( uint4 ) state )
    { state.x += ( CHAR_W + 1 ) * state.z; }

    ML_INLINE void Print_ui( uint x, ML_INOUT( uint4 ) state )
    {
        [unroll]
        while( x != 0 )
        {
            uint a = x / 10;
            uint digit = x - a * 10;

            NextDigit( state );
            _RenderChar( digit );

            x = a;
        }
    }

    ML_INLINE void Print_i( int x, ML_INOUT( uint4 ) state )
    {

        Print_ui( abs( x ), state );

        if( x < 0 )
        {
            NextDigit( state );
            _RenderChar( Char_Minus );
        }
    }

    ML_INLINE void Print_f( float x, ML_INOUT( uint4 ) state )
    {

        uint f = uint( frac( abs( x ) ) * ML_TEXT_DIGIT_FORMAT + 0.5 );
        Print_ui( f, state );

        [unroll]
        for( uint n = 10; n < ML_TEXT_DIGIT_FORMAT; n *= 10 )
        {
            if( f < n )
            {
                NextDigit( state );
                _RenderChar( Char_0 );
            }
        }

        NextDigit( state );
        _RenderChar( Char_Dot );

        int i = int( floor( x ) + 0.5 );
        Print_i( i, state );
    }

    ML_INLINE void Print_ch( uint ch, ML_INOUT( uint4 ) state )
    {
        if( ch == Char_Minus || ch == '-' )
            ch = Char_Minus;
        else if( ch == Char_Dot || ch == '.' )
            ch = Char_Dot;
        else if( ch == Char_Space || ch == ' ' )
            ch = Char_Space;
        else if( ch == Char_Ampersand || ch == '&' )
            ch = Char_Ampersand;
        else
            ch = Char_A + ch - 'A';

        _RenderChar( ch );
        NextChar( state );
    }
}
#endif

#ifdef ML_NAMESPACE
}
#endif

#endif
