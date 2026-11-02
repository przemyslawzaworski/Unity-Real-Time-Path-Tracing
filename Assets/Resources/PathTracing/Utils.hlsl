#ifndef UTILS_HLSL
#define UTILS_HLSL

#include "RayPayload.hlsl"

#define K_PI                    3.1415926535f
#define K_HALF_PI               1.5707963267f
#define K_QUARTER_PI            0.7853981633f
#define K_TWO_PI                6.283185307f
#define K_T_MAX                 10000
#define K_SHADOW_RAY_T_EPSILON  1e-3

#define K_RAY_OFFSET_ORIGIN      1.0
#define K_RAY_OFFSET_FLOAT_SCALE (1.0 / 256.0)
#define K_RAY_OFFSET_INT_SCALE   16384.0

#define K_SHADOW_RAY_OFFSET_SCALE 0.25

#define ENABLE_RUSSIAN_ROULETTE 1

uint WangHash(inout uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

float RandomFloat01(inout uint seed)
{
    return float(WangHash(seed)) / float(0xFFFFFFFF);
}

float3 RandomUnitVector(inout uint state)
{
    float z = RandomFloat01(state) * 2.0f - 1.0f;
    float a = RandomFloat01(state) * K_TWO_PI;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return float3(x, y, z);
}



float FresnelReflectAmountTransparent(float n1, float n2, float3 incident, float3 normal)
{

    float r0 = (n1 - n2) / (n1 + n2);
    r0 *= r0;
    float cosX = -dot(normal, incident);

    if (n1 > n2)
    {
        float n = n1 / n2;
        float sinT2 = n * n*(1.0 - cosX * cosX);

        if (sinT2 >= 1.0)
            return 1;
        cosX = sqrt(1.0 - sinT2);
    }

    float x = 1.0 - cosX;
    float xx = x*x;
    return r0 + (1.0 - r0)*xx*xx*x;
}

void BuildOrthonormalBasis(float3 n, out float3 b1, out float3 b2)
{
    float sgn = n.z >= 0.0 ? 1.0 : -1.0;
    float a = -1.0 / (sgn + n.z);
    float b = n.x * n.y * a;
    b1 = float3(1.0 + sgn * n.x * n.x * a, sgn * b, -sgn * n.x);
    b2 = float3(b, sgn + n.y * n.y * a, -n.y);
}

float3 UnpackNormalMapScaled(float4 packedNormal, float scale)
{
    packedNormal.x *= packedNormal.w;
    float2 xy = (packedNormal.xy * 2.0 - 1.0) * scale;
    return float3(xy, sqrt(saturate(1.0 - dot(xy, xy))));
}

float3 InterpolatePositionPrecise(float3 p0, float3 p1, float3 p2, float3 barycentrics)
{
    precise float3 edge0 = p1 - p0;
    precise float3 edge1 = p2 - p0;
    precise float3 position = p0 + mad(barycentrics.y, edge0, mul(barycentrics.z, edge1));
    return position;
}

float3 TransformObjectToWorldPositionPrecise(float3 objectPosition)
{
    const float3x4 o2w = ObjectToWorld();

    precise float3 worldPosition;
    worldPosition.x = o2w._m03 + mad(o2w._m00, objectPosition.x, mad(o2w._m01, objectPosition.y, mul(o2w._m02, objectPosition.z)));
    worldPosition.y = o2w._m13 + mad(o2w._m10, objectPosition.x, mad(o2w._m11, objectPosition.y, mul(o2w._m12, objectPosition.z)));
    worldPosition.z = o2w._m23 + mad(o2w._m20, objectPosition.x, mad(o2w._m21, objectPosition.y, mul(o2w._m22, objectPosition.z)));
    return worldPosition;
}

float3 OffsetRayOrigin(float3 p, float3 n, float scale = 1.0)
{
    const float origin     = K_RAY_OFFSET_ORIGIN;
    const float floatScale = K_RAY_OFFSET_FLOAT_SCALE * scale;
    const float intScale   = K_RAY_OFFSET_INT_SCALE * scale;

    int3 ofI = int3((int)(intScale * n.x), (int)(intScale * n.y), (int)(intScale * n.z));

    float3 pI = float3(asfloat(asint(p.x) + (p.x < 0 ? -ofI.x : ofI.x)),
                       asfloat(asint(p.y) + (p.y < 0 ? -ofI.y : ofI.y)),
                       asfloat(asint(p.z) + (p.z < 0 ? -ofI.z : ofI.z)));

    return float3(abs(p.x) < origin ? p.x + floatScale * n.x : pI.x,
                  abs(p.y) < origin ? p.y + floatScale * n.y : pI.y,
                  abs(p.z) < origin ? p.z + floatScale * n.z : pI.z);
}

float Luminance(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

bool RussianRouletteTerminate(inout float3 throughput, inout RayPayload rayPayload)
{
#if ENABLE_RUSSIAN_ROULETTE

    if (rayPayload.GetBounceIndexTotal() < 2)
        return false;

    float survivalProbability = clamp(max(throughput.r, max(throughput.g, throughput.b)), 0.05, 0.95);

    if (survivalProbability < RandomFloat01(rayPayload.rngState))
        return true;

    throughput *= 1 / survivalProbability;
#endif
    return false;
}

#endif
