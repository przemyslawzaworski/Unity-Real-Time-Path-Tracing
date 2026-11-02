#ifndef PT_ENVIRONMENT_SAMPLING
#define PT_ENVIRONMENT_SAMPLING
#include "Utils.hlsl"
TextureCube<float4> g_EnvTex;
SamplerState sampler_g_EnvTex;
float g_EnvironmentIntensity;
uint g_EnvironmentNEE;
StructuredBuffer<float> g_EnvConditional;
StructuredBuffer<float> g_EnvMarginal;
StructuredBuffer<float> g_EnvWeights;
#define PT_ENV_W 256u
#define PT_ENV_H 128u
float3 PTEnvironmentRadiance(float3 d) { return g_EnvTex.SampleLevel(sampler_g_EnvTex,d,0).rgb * g_EnvironmentIntensity; }
float PTCellSolidAngle(uint y) { return (K_TWO_PI/PT_ENV_W)*(cos(K_PI*y/PT_ENV_H)-cos(K_PI*(y+1)/PT_ENV_H)); }
float PTEnvironmentPdf(float3 d)
{
    float total=g_EnvMarginal[PT_ENV_H-1];
    if(total<=1e-20) return 1.0/(4*K_PI);
    float u=frac(atan2(d.x,d.z)/K_TWO_PI+0.5);
    uint x=min((uint)(u*PT_ENV_W),PT_ENV_W-1);
    uint y=min((uint)(acos(clamp(d.y,-1.0,1.0))/K_PI*PT_ENV_H),PT_ENV_H-1);
    return 0.95*g_EnvWeights[y*PT_ENV_W+x]/(total*PTCellSolidAngle(y))+0.05/(4*K_PI);
}
float3 PTSampleEnvironment(inout uint rng,float selector)
{
    float total=g_EnvMarginal[PT_ENV_H-1];
    if(selector<0.05 || total<=1e-20)
    {
        float y=1-2*RandomFloat01(rng),phi=K_TWO_PI*RandomFloat01(rng);
        float r=sqrt(saturate(1-y*y));return float3(r*sin(phi),y,r*cos(phi));
    }
    float target=RandomFloat01(rng)*total;
    uint lo=0,hi=PT_ENV_H-1;
    [unroll] for(uint k=0;k<7;k++){uint mid=(lo+hi)/2;if(g_EnvMarginal[mid]<=target)lo=mid+1;else hi=mid;}
    uint y=min(lo,PT_ENV_H-1);
    target=RandomFloat01(rng)*g_EnvConditional[y*PT_ENV_W+PT_ENV_W-1];
    lo=0;hi=PT_ENV_W-1;
    [unroll] for(uint k=0;k<8;k++){uint mid=(lo+hi)/2;if(g_EnvConditional[y*PT_ENV_W+mid]<=target)lo=mid+1;else hi=mid;}
    lo=min(lo,PT_ENV_W-1);
    float phi=K_TWO_PI*((lo+RandomFloat01(rng))/PT_ENV_W-0.5);
    float cosTheta=lerp(cos(K_PI*y/PT_ENV_H),cos(K_PI*(y+1)/PT_ENV_H),RandomFloat01(rng));
    float r=sqrt(saturate(1-cosTheta*cosTheta));return float3(r*sin(phi),cosTheta,r*cos(phi));
}
float PTPowerHeuristic(float a,float b) { a*=a;b*=b;return a/max(a+b,1e-30); }
float PTSpecularPdf(float3 V,float3 L,float3 N,float alpha)
{
    float nv=dot(N,V);if(nv<=0 || dot(N,L)<=0)return 0;
    float3 H=normalize(V+L);float nh=saturate(dot(N,H));
    float a2=alpha*alpha,den=nh*nh*(a2-1)+1;
    float D=a2/(K_PI*den*den);
    float G1=2*nv/max(nv+sqrt(a2+(1-a2)*nv*nv),1e-8);
    return D*G1/(4*nv);
}
#endif
