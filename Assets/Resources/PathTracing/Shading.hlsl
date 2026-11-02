#ifndef SHADING_HLSL
#define SHADING_HLSL

#include "GlobalResources.hlsl"
#include "BRDF.hlsl"
#include "Utils.hlsl"
#include "RayPayload.hlsl"
#include "NRD/Library/NRD.hlsli"

Texture2D<float>  g_EnergyCompLUT;
SamplerState sampler_g_EnergyCompLUT;

struct SurfaceHit
{
    float3 worldPosition;
    float3 worldNormal;
    float3 worldVertexNormal;
    float3 worldFaceNormal;
    float2 uv;
    float4 vertexColor;
    float textureFootprint;
    float3 previousPosition;
    bool isFrontFace;
};

struct MaterialSample
{
    float3 diffuseAlbedo;
    float3 F0;
    float alpha;
    float3 emission;
};

float3 SpecularEnergyCompensation(float3 F0, float NdotV, float alpha)
{
    float  Ess  = g_EnergyCompLUT.SampleLevel(sampler_g_EnergyCompLUT, float2(NdotV, sqrt(alpha)), 0);
    float3 Favg = F0 + (1.0 - F0) * (1.0 / 21.0);
    return 1.0 + Favg * (1.0 - Ess) / max(Ess, 1e-3);
}

void ShadeOpaqueSurface(inout RayPayload payload, in SurfaceHit hit, in MaterialSample mat, float3 V)
{

    float specLum = Luminance(mat.F0);
    float diffLum = Luminance(mat.diffuseAlbedo);
    float specularChance = clamp(specLum / max(specLum + diffLum, 1e-7), 0.1, 0.9);

    if(g_UseNRD!=0 && payload.GetBounceIndexTotal()==0) specularChance=clamp(specularChance,0.25,0.75);
    float3 diffuseTint = mat.diffuseAlbedo * (1.0 - mat.F0);

#if NORMAL_MAP_ON

    float3 specularNormal = ComputeConsistentShadingNormal(V, hit.worldVertexNormal, hit.worldNormal);
#else

    float3 specularNormal = hit.worldNormal;
#endif

#if ENERGY_COMPENSATION_ON
    float  NdotV = saturate(dot(specularNormal, V));
    float3 specularEnergyComp = SpecularEnergyCompensation(mat.F0, NdotV, mat.alpha);
#else
    float3 specularEnergyComp = 1.0;
#endif

    float3 hitRayOrigin = OffsetRayOrigin(hit.worldPosition, hit.worldFaceNormal);

    float3 directLight = float3(0, 0, 0);
    float3 directDiffuse = 0;
    if (g_LightCount > 0)
    {
        uint li = min((uint)(RandomFloat01(payload.rngState) * g_LightCount), g_LightCount - 1);
        float3 wi;
        float dist;
        float3 Le;

        if (SampleLight(g_Lights[li], hit.worldPosition, payload.rngState, wi, dist, Le)
            && dot(hit.worldNormal,     wi) > 0
            && dot(hit.worldFaceNormal, wi) > 0)
        {
            float  pickPdf = 1.0 / (float)g_LightCount;
            float3 fSpec   = EvaluateSpecularGGX(V, wi, specularNormal, mat.F0, mat.alpha) * specularEnergyComp;
            float3 fDiff   = EvaluateDiffuseLambert(diffuseTint, hit.worldNormal, wi);
            float3 shadowRayOrigin = OffsetRayOrigin(hit.worldPosition, hit.worldFaceNormal, K_SHADOW_RAY_OFFSET_SCALE);
            float3 visible = TraceShadowRay(shadowRayOrigin, wi, dist * (1.0 - K_SHADOW_RAY_T_EPSILON));

            directLight = (fSpec + fDiff) * Le * visible / pickPdf;
            directDiffuse = fDiff * Le * visible / pickPdf;

#if NORMAL_MAP_ON

            float terminator = ShadowTerminatorTerm(hit.worldVertexNormal, hit.worldNormal, wi);
            directLight *= terminator;
            directDiffuse *= terminator;
#endif
        }
    }

    if(g_EnvironmentNEE != 0)
    {
        float3 wi=PTSampleEnvironment(payload.rngState,RandomFloat01(payload.rngState));
        if(dot(hit.worldNormal,wi)>0 && dot(hit.worldFaceNormal,wi)>0)
        {
            float envPdf=PTEnvironmentPdf(wi);
            float diffPdf=(1-specularChance)*saturate(dot(hit.worldNormal,wi))/K_PI;
            float specPdf=specularChance*PTSpecularPdf(V,wi,specularNormal,mat.alpha);
            float3 Le=PTEnvironmentRadiance(wi);
            float visible=TraceEnvironmentVisibility(OffsetRayOrigin(hit.worldPosition,hit.worldFaceNormal,K_SHADOW_RAY_OFFSET_SCALE),wi);
            float3 d=EvaluateDiffuseLambert(diffuseTint,hit.worldNormal,wi)*PTPowerHeuristic(envPdf,diffPdf);
            float3 s=EvaluateSpecularGGX(V,wi,specularNormal,mat.F0,mat.alpha)*specularEnergyComp*PTPowerHeuristic(envPdf,specPdf);
#if NORMAL_MAP_ON
            visible*=ShadowTerminatorTerm(hit.worldVertexNormal,hit.worldNormal,wi);
#endif
            float3 factor=Le*(visible/max(envPdf,1e-20));
            directLight+=(d+s)*factor;directDiffuse+=d*factor;
        }
    }
    float lobeSelector=g_UseNRD!=0 && payload.GetBounceIndexTotal()==0?payload.primaryLobeSelector:RandomFloat01(payload.rngState);
    bool doSpecular = lobeSelector < specularChance;
    if (payload.GetBounceIndexTotal() == 0)
    {
        payload.primaryEmission=mat.emission;
        payload.primaryAlbedo = diffuseTint;
        payload.primaryNormalRoughness=float4(hit.worldNormal,sqrt(mat.alpha));
        NRD_MaterialFactors(hit.worldNormal,V,mat.diffuseAlbedo,mat.F0,sqrt(mat.alpha),payload.primaryDiffuseFactor,payload.primarySpecularFactor);
        payload.primaryDirectDiffuse = directDiffuse;
        payload.primarySpecular = doSpecular ? 1u : 0u;
    }

    payload.coneSpread = max(payload.coneSpread, doSpecular ? sqrt(mat.alpha) * 0.1 : 0.25);

    float3 L;
    float3 weight;
    if (doSpecular)
    {
        if (!SampleSpecularGGX(V, specularNormal, mat.F0, mat.alpha, payload.rngState, L, weight))
        {
            payload.weight = float3(0, 0, 0);
            payload.emission = mat.emission + directLight;
            payload.Terminate();
            return;
        }
        weight *= specularEnergyComp;
        weight /= specularChance;
    }
    else
    {
        SampleDiffuseLambert(hit.worldNormal, diffuseTint, payload.rngState, L, weight);
        weight /= (1.0 - specularChance);
    }

#if NORMAL_MAP_ON

    float bounceTerminator = ShadowTerminatorTerm(hit.worldVertexNormal, hit.worldNormal, L);
    if (bounceTerminator <= 0.0)
    {
        payload.weight = float3(0, 0, 0);
        payload.emission = mat.emission + directLight;
        payload.Terminate();
        return;
    }
    weight *= bounceTerminator;
#endif

    float selectedPdf=doSpecular?specularChance*PTSpecularPdf(V,L,specularNormal,mat.alpha)
        :(1-specularChance)*saturate(dot(hit.worldNormal,L))/K_PI;
    payload.environmentMisWeight=g_EnvironmentNEE!=0?PTPowerHeuristic(selectedPdf,PTEnvironmentPdf(L)):1;
    payload.weight = weight;
    payload.emission = mat.emission + directLight;
    payload.bounceRayOrigin = hitRayOrigin;
    payload.bounceRayDirection = L;
    payload.IncrementBounceIndexOpaque();
}

#endif

