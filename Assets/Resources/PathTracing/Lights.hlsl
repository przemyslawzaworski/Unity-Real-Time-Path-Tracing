#ifndef LIGHTS_HLSL
#define LIGHTS_HLSL

#include "Utils.hlsl"

#define LIGHT_TYPE_DIRECTIONAL  0
#define LIGHT_TYPE_POINT        1

#define K_PUNCTUAL_LIGHT_THRESHOLD 0.01

#define K_DIRECTIONAL_ANGULAR_DIAMETER (0.5 * K_PI / 180.0)

struct Light
{
    float3 color;
    uint   type;
    float3 direction;
    float  range;
    float3 position;
    float  _pad0;
};

struct ShadowRayPayload
{
    uint visible;
};

uint g_GlassInstanceCount;

struct GlassShadowPayload
{
    float3 transmittance;
};

float3 TraceShadowRay(float3 origin, float3 direction, float distance)
{
    RayDesc shadowRay;
    shadowRay.Origin    = origin;
    shadowRay.Direction = direction;
    shadowRay.TMin      = 0;
    shadowRay.TMax      = distance;

    ShadowRayPayload shadowPayload;
    shadowPayload.visible = 0;

    const uint shadowRayMissShaderIndex = 1;

    TraceRay(g_AccelStruct,
             RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH | RAY_FLAG_SKIP_CLOSEST_HIT_SHADER | RAY_FLAG_CULL_BACK_FACING_TRIANGLES,
             0x01, 0, 1, shadowRayMissShaderIndex, shadowRay, shadowPayload);

    if (shadowPayload.visible == 0) return 0;
    if (g_GlassInstanceCount == 0) return 1;

    GlassShadowPayload glassPayload;
    glassPayload.transmittance = 1;
    TraceRay(g_AccelStruct, RAY_FLAG_FORCE_NON_OPAQUE | RAY_FLAG_SKIP_CLOSEST_HIT_SHADER,
             0x02, 0, 1, 2, shadowRay, glassPayload);
    return glassPayload.transmittance;
}

float TraceEnvironmentVisibility(float3 origin,float3 direction)
{
    RayDesc r;r.Origin=origin;r.Direction=direction;r.TMin=0;r.TMax=K_T_MAX;
    ShadowRayPayload p;p.visible=0;
    TraceRay(g_AccelStruct,RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH|RAY_FLAG_SKIP_CLOSEST_HIT_SHADER,0x01,0,1,1,r,p);
    if(p.visible==0 || g_GlassInstanceCount==0)return p.visible;
    p.visible=0;
    TraceRay(g_AccelStruct,RAY_FLAG_FORCE_OPAQUE|RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH|RAY_FLAG_SKIP_CLOSEST_HIT_SHADER,0x02,0,1,1,r,p);
    return p.visible;
}

bool SampleLight(Light light, float3 worldPos, inout uint rngState, out float3 wi, out float dist, out float3 Le)
{
    wi   = float3(0, 1, 0);
    dist = 0;
    Le   = float3(0, 0, 0);

    switch (light.type)
    {
        case LIGHT_TYPE_DIRECTIONAL:
        {

            float3 axis        = -light.direction;
            float  cosThetaMax = cos(K_DIRECTIONAL_ANGULAR_DIAMETER * 0.5);
            float  u1          = RandomFloat01(rngState);
            float  u2          = RandomFloat01(rngState);
            float  cosTheta    = lerp(cosThetaMax, 1.0, u1);
            float  sinTheta    = sqrt(saturate(1.0 - cosTheta * cosTheta));
            float  phi         = K_TWO_PI * u2;

            float3 T, B;
            BuildOrthonormalBasis(axis, T, B);
            wi   = (cos(phi) * T + sin(phi) * B) * sinTheta + axis * cosTheta;
            dist = K_T_MAX;
            Le   = light.color;
            return true;
        }
        case LIGHT_TYPE_POINT:
        {

            float3 toLight = light.position - worldPos;
            float  d2      = dot(toLight, toLight);
            float  d       = sqrt(d2);
            if (d >= light.range)
                return false;

            float invD        = min(rcp(d), rcp(K_PUNCTUAL_LIGHT_THRESHOLD));
            float r2          = light.range * light.range;
            float window      = saturate(1.0 - (d2 / r2) * (d2 / r2));
            float attenuation = invD * window;
            attenuation *= attenuation;

            wi   = toLight / d;
            dist = d;
            Le   = light.color * attenuation;
            return true;
        }
    }

    return false;
}

#endif

