#ifndef RAY_PAYLOAD_H
#define RAY_PAYLOAD_H

struct RayPayload
{
    float4 primarySurface;
    float3 primaryAlbedo;
    float3 primaryDirectDiffuse;
    uint primarySpecular;
    float coneWidth;
    float coneSpread;
    float environmentMisWeight;
    float lastHitDistance;
    float primaryLobeSelector;
    float4 primaryNormalRoughness;
    float3 primaryDiffuseFactor;
    float3 primarySpecularFactor;
    float3 primaryEmission;
    float3 primaryPreviousPosition;
    float primaryHistoryValid;
    float3 weight;
    float3 emission;
    float3 bounceRayOrigin;
    float3 bounceRayDirection;
    uint bounceIndices;
    uint rngState;

    void Init(uint initialRngState)
    {
        primarySurface = float4(0, 0, 0, -1);
        primaryAlbedo = 0;
        primaryDirectDiffuse = 0;
        primarySpecular = 1;
        coneWidth = 0;
        coneSpread = 0;
        environmentMisWeight = 1;
        lastHitDistance = 10000;
        primaryLobeSelector = 0;
        primaryNormalRoughness = float4(0,0,1,-1);
        primaryDiffuseFactor = 1;
        primarySpecularFactor = 1;
        primaryEmission=0;
        primaryPreviousPosition=0;
        primaryHistoryValid=0;
        weight = float3(1, 1, 1);
        emission = float3(0, 0, 0);
        rngState = initialRngState;
        bounceIndices = 0;
        bounceRayOrigin = float3(0, 0, 0);
        bounceRayDirection = float3(0, 0, 0);
    }

    uint GetBounceIndexOpaque()      { return bounceIndices & 0xff; }
    uint GetBounceIndexTransparent() { return (bounceIndices >> 8) & 0xff; }
    uint GetBounceIndexTotal()       { return bounceIndices >> 16; }

    void IncrementBounceIndexOpaque()      { bounceIndices += 0x00000001; }
    void IncrementBounceIndexTransparent() { bounceIndices += 0x00000100; }
    void IncrementBounceIndexTotal()       { bounceIndices += 0x00010000; }

    void Terminate()    { bounceIndices = 0xffffffff; }
    bool IsTerminated() { return bounceIndices == 0xffffffff; }
};

#endif

