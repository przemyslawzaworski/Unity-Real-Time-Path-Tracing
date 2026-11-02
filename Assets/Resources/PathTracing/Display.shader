Shader "Hidden/PortablePathTracing/Display" {
Properties { _MainTex("Radiance",2D)="black" {} }
SubShader { Cull Off ZWrite Off ZTest Always
Pass {
HLSLPROGRAM
#pragma vertex vert_img
#pragma fragment frag
#include "UnityCG.cginc"
sampler2D _MainTex;
float _ExposureEV;
int _ToneMapping;
float3 ToneMap(float3 x) {
    if(_ToneMapping==1) return x/(1+x);
    if(_ToneMapping==2) return saturate((x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14));
    return x;
}
float4 frag(v2f_img i):SV_Target {
    float3 c=tex2D(_MainTex,i.uv).rgb;
    c=all(isfinite(c))?max(c,0):0;
    return float4(ToneMap(c*exp2(_ExposureEV)),1);
}
ENDHLSL
}}}
