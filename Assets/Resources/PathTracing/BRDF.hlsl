#ifndef BRDF_HLSL
#define BRDF_HLSL

#include "Utils.hlsl"

float SmoothnessToAlpha(float smoothness)
{
    float roughness = 1.0 - smoothness;
    return max(roughness * roughness, 1e-4);
}

float3 FresnelSchlick(float3 F0, float VdotH)
{
    float x = saturate(1.0 - VdotH);
    float x2 = x * x;
    return F0 + (1.0 - F0) * (x2 * x2 * x);
}

float SmithG1_GGX(float NdotV, float alpha)
{
    float a2 = alpha * alpha;
    float denom = NdotV + sqrt(a2 + (1.0 - a2) * NdotV * NdotV);
    return 2.0 * NdotV / max(denom, 1e-7);
}

float SmithG2_GGX_HeightCorrelated(float NdotL, float NdotV, float alpha)
{
    float a2 = alpha * alpha;
    float lambdaV = NdotL * sqrt(a2 + (1.0 - a2) * NdotV * NdotV);
    float lambdaL = NdotV * sqrt(a2 + (1.0 - a2) * NdotL * NdotL);
    return 2.0 * NdotL * NdotV / max(lambdaV + lambdaL, 1e-7);
}

float3 SampleGGXVNDF(float3 Ve, float alpha, float u1, float u2)
{

    float3 Vh = normalize(float3(alpha * Ve.x, alpha * Ve.y, Ve.z));

    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    float3 T1 = lensq > 0 ? float3(-Vh.y, Vh.x, 0) * rsqrt(lensq) : float3(1, 0, 0);
    float3 T2 = cross(Vh, T1);

    float r = sqrt(u1);
    float phi = K_TWO_PI * u2;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s) * sqrt(1.0 - t1 * t1) + s * t2;

    float3 Nh = t1 * T1 + t2 * T2 + sqrt(max(0.0, 1.0 - t1 * t1 - t2 * t2)) * Vh;

    return normalize(float3(alpha * Nh.x, alpha * Nh.y, max(0.0, Nh.z)));
}

float D_GGX(float NdotH, float alpha)
{
    float a2 = alpha * alpha;
    float t = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / max(K_PI * t * t, 1e-7);
}

float3 EvaluateSpecularGGX(float3 V, float3 L, float3 N, float3 F0, float alpha)
{
    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    if (NdotL <= 0.0 || NdotV <= 0.0)
        return float3(0, 0, 0);

    float3 H     = normalize(V + L);
    float  NdotH = saturate(dot(N, H));
    float  VdotH = saturate(dot(V, H));

    float  D  = D_GGX(NdotH, alpha);
    float  G2 = SmithG2_GGX_HeightCorrelated(NdotL, NdotV, alpha);
    float3 F  = FresnelSchlick(F0, VdotH);
    return F * (D * G2 / max(4.0 * NdotV, 1e-7));
}

float3 EvaluateDiffuseLambert(float3 albedo, float3 N, float3 L)
{
    float NdotL = saturate(dot(N, L));
    return albedo * (NdotL / K_PI);
}

float ShadowTerminatorTerm(float3 Ng, float3 Ns, float3 L)
{
    float NgdotL = dot(Ng, L);
    if (NgdotL <= 0.0)
        return 0.0;

    float denom = dot(Ns, L) * dot(Ng, Ns);
    float G = denom > 0.0 ? min(1.0, NgdotL / denom) : 1.0;
    return ((1.0 - G) * G + 1.0) * G;
}

float3 ComputeConsistentShadingNormal(float3 V, float3 Ng, float3 Ns)
{

    float side = dot(Ng, V) >= 0.0 ? 1.0 : -1.0;

    float NsdotV = side * dot(Ns, V);
    float3 Nv = Ns - side * min(0.0, NsdotV) * V;

    float3 R = reflect(-V, Nv);
    float NgdotR = dot(Ng, R);
    float sideR = NgdotR >= 0.0 ? 1.0 : -1.0;

    if (side == sideR)
        return Ns;

    R = normalize(R - (NgdotR + sideR * 0.001) * Ng);
    return side * normalize(V + R);
}

bool SampleSpecularGGX(float3 V, float3 N, float3 F0, float alpha, inout uint rngState, out float3 L, out float3 weight)
{
    float3 T, B;
    BuildOrthonormalBasis(N, T, B);

    float3 Ve = float3(dot(V, T), dot(V, B), dot(V, N));

    float u1 = RandomFloat01(rngState);
    float u2 = RandomFloat01(rngState);
    float3 Hts = SampleGGXVNDF(Ve, alpha, u1, u2);

    float3 H = Hts.x * T + Hts.y * B + Hts.z * N;
    L = reflect(-V, H);

    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    if (NdotL <= 0.0 || NdotV <= 0.0)
    {
        weight = float3(0, 0, 0);
        return false;
    }

    float VdotH = saturate(dot(V, H));
    float3 F = FresnelSchlick(F0, VdotH);

    float G1 = SmithG1_GGX(NdotV, alpha);
    float G2 = SmithG2_GGX_HeightCorrelated(NdotL, NdotV, alpha);
    weight = F * (G2 / max(G1, 1e-7));
    return true;
}

void SampleDiffuseLambert(float3 N, float3 albedo, inout uint rngState, out float3 L, out float3 weight)
{

    float3 s = N + RandomUnitVector(rngState);
    L = dot(s, s) < 1e-6 ? N : normalize(s);
    weight = albedo;
}

bool SampleGlassGGX(float3 rayDir, float3 N, float etaI, float etaT, float alpha, inout uint rngState, out float3 L, out float3 weight, out bool isReflected)
{
    float3 V = -rayDir;

    float3 T, B;
    BuildOrthonormalBasis(N, T, B);

    float3 Ve = float3(dot(V, T), dot(V, B), dot(V, N));

    float u1 = RandomFloat01(rngState);
    float u2 = RandomFloat01(rngState);
    float3 Hts = SampleGGXVNDF(Ve, alpha, u1, u2);
    float3 H = Hts.x * T + Hts.y * B + Hts.z * N;

    float F = FresnelReflectAmountTransparent(etaI, etaT, rayDir, H);

    if (RandomFloat01(rngState) < F)
    {
        L = reflect(rayDir, H);
        isReflected = true;
    }
    else
    {
        L = refract(rayDir, H, etaI / etaT);
        isReflected = false;

        if (dot(L, L) < 1e-6)
        {
            L = reflect(rayDir, H);
            isReflected = true;
        }
    }

    float NdotV = dot(N, V);
    float NdotL = abs(dot(N, L));
    if (NdotV <= 0.0 || NdotL <= 0.0)
    {
        weight = float3(0, 0, 0);
        return false;
    }

    float G1 = SmithG1_GGX(NdotV, alpha);
    float G2 = SmithG2_GGX_HeightCorrelated(NdotL, NdotV, alpha);
    weight = (G2 / max(G1, 1e-7)).xxx;
    return true;
}

#endif

