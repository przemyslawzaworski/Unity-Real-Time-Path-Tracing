#ifndef GLOBAL_RESOURCES_H
#define GLOBAL_RESOURCES_H

RaytracingAccelerationStructure g_AccelStruct : register(t0, space1);

uint g_MaxBounceCountOpaque;
uint g_MaxBounceCountTransparent;

#include "Lights.hlsl"
#include "EnvironmentSampling.hlsl"
uint g_UseNRD;

StructuredBuffer<Light> g_Lights : register(t1, space1);
uint                    g_LightCount;

#endif

