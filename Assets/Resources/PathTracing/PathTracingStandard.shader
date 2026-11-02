Shader "PortablePathTracing/Standard"
{
    Properties
    {
        _VertexColorMode("Vertex Color Mode", Float) = 0
        _Color("Color", Color) = (1, 1, 1, 1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        [HDR]_EmissionColor("EmissionColor", Color) = (0,0,0)
        _EmissionTex("Emission", 2D) = "white" {}

        [Normal]_NormalMapTex("Normal Map", 2D) = "bump" {}
        _NormalMapScale("Normal Map Scale", Range(0.0, 2.0)) = 1.0

        _SpecularColor("SpecularColor", Color) = (1, 1, 1, 1)

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        _IOR("Index of Refraction", Range(1.0, 2.8)) = 1.5
        _MetallicGlossMap("Metallic Smoothness", 2D) = "white" {}
        _SpecGlossMap("Specular Smoothness", 2D) = "white" {}
        _SpecColor("Specular F0", Color) = (0.04,0.04,0.04,1)
        _GlossMapScale("Smoothness Scale", Float) = 1
        _SmoothnessTextureChannel("Smoothness From Albedo", Float) = 0
        _DetailAlbedoMap("Detail Albedo", 2D) = "gray" {}
        _DetailNormalMap("Detail Normal", 2D) = "bump" {}
        _DetailMask("Detail Mask", 2D) = "white" {}
        _DetailNormalMapScale("Detail Normal Scale", Float) = 1

        [HideInInspector] _SurfaceType("__type", Integer) = 0
        [HideInInspector] _SrcBlend("__src", Float) = 1
        [HideInInspector] _DstBlend("__dst", Float) = 0
        [HideInInspector] _ZWrite("__zw", Float) = 1
        [HideInInspector] _Cull("__cull", Float) = 2
        [HideInInspector] _EnergyCompensation("__energycomp", Float) = 0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "DisableBatching" = "True"}
        LOD 100

        Pass
        {
            Name "PathTracing"
            Tags{ "LightMode" = "RayTracing" }

            HLSLPROGRAM

            #include "GlobalResources.hlsl"
            #include "RayPayload.hlsl"
            #include "Shading.hlsl"
            #include "UnityRaytracingMeshUtils.cginc"

            #pragma raytracing main_hit_group

            #pragma multi_compile_local _ EMISSION_ON
            #pragma multi_compile_local _ ALPHATEST_ON
			#pragma multi_compile_local _ DOUBLE_SIDED_ON
            #pragma multi_compile_local _ NORMAL_MAP_ON
            #pragma multi_compile_local _ ENERGY_COMPENSATION_ON
            #pragma multi_compile_local _ METALLIC_MAP_ON SPECULAR_MAP_ON SPECULAR_COLOR_ON
            #pragma multi_compile_local _ DETAIL_ON

            float4x4 g_PTPreviousObjectToWorld;
            float g_PTHistoryValid;
            float g_PTDeformedHistory;
            uint g_PTPreviousVertexStride;
            uint g_PTPreviousVertexOffset;
            ByteAddressBuffer g_PTPreviousVertices;
            float3 PTPreviousVertex(uint i) {return asfloat(g_PTPreviousVertices.Load3(i*g_PTPreviousVertexStride+g_PTPreviousVertexOffset));}
            float _VertexColorMode;
            float g_UseRandomVertexColors;
            float4 _Color;
            float4 _SpecularColor;

            Texture2D<float4> _MainTex;
            float4 _MainTex_ST;
            SamplerState sampler__MainTex;

            Texture2D<float4> _EmissionTex;
            float4 _EmissionTex_ST;
            SamplerState sampler__EmissionTex;

            Texture2D<float4> _NormalMapTex;
            float4 _NormalMapTex_ST;
            SamplerState sampler__NormalMapTex;
            float _NormalMapScale;

            float _Cutoff;

            float4 _EmissionColor;

            float _Smoothness;
            float _Metallic;
            float _IOR;
            Texture2D<float4> _MetallicGlossMap;
            SamplerState sampler__MetallicGlossMap;
            Texture2D<float4> _SpecGlossMap;
            SamplerState sampler__SpecGlossMap;
            float4 _SpecColor;
            float _GlossMapScale;
            float _SmoothnessTextureChannel;
            Texture2D<float4> _DetailAlbedoMap;
            SamplerState sampler__DetailAlbedoMap;
            float4 _DetailAlbedoMap_ST;
            Texture2D<float4> _DetailMask;
            SamplerState sampler__DetailMask;
            Texture2D<float4> _DetailNormalMap;
            SamplerState sampler__DetailNormalMap;
            float _DetailNormalMapScale;
            float g_DetailAlbedoScale;

            float TextureLOD(Texture2D<float4> textureMap, float footprint, float2 tiling)
            {
                uint w, h;
                textureMap.GetDimensions(w, h);
                return max(0.0, log2(max(footprint * max(w * abs(tiling.x), h * abs(tiling.y)), 1e-8)));
            }

			float4 unity_WorldTransformParams;

            struct AttributeData
            {
                float2 barycentrics;
            };

            struct Vertex
            {
                float4 color;
                float3 position;
                float3 normal;
                float2 uv;
#if defined(NORMAL_MAP_ON) || defined(DETAIL_ON)
                float4 tangent;
#endif
            };

            Vertex FetchVertex(uint vertexIndex)
            {
                Vertex v;
                v.color = _VertexColorMode > 0 ? UnityRayTracingFetchVertexAttribute4(vertexIndex, kVertexAttributeColor) : float4(1,1,1,1);
                v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
                v.normal = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
                v.uv = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
#if defined(NORMAL_MAP_ON) || defined(DETAIL_ON)
                v.tangent = UnityRayTracingFetchVertexAttribute4(vertexIndex, kVertexAttributeTangent);
#endif
                return v;
            }

            Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
            {
                Vertex v;
                v.position = InterpolatePositionPrecise(v0.position, v1.position, v2.position, barycentrics);

                #define INTERPOLATE_ATTRIBUTE(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
                INTERPOLATE_ATTRIBUTE(color);
                INTERPOLATE_ATTRIBUTE(normal);
                INTERPOLATE_ATTRIBUTE(uv);
#if defined(NORMAL_MAP_ON) || defined(DETAIL_ON)
                INTERPOLATE_ATTRIBUTE(tangent);
#endif
                return v;
            }

			float GetOddNegativeScale()
			{

				return unity_WorldTransformParams.w >= 0.0 ? 1.0 : -1.0;
			}

            SurfaceHit LoadSurfaceHit(AttributeData attribs, float coneWidth)
            {
                uint3 tri = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());
                Vertex v0 = FetchVertex(tri.x);
                Vertex v1 = FetchVertex(tri.y);
                Vertex v2 = FetchVertex(tri.z);

                float3 bary = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
                Vertex v = InterpolateVertices(v0, v1, v2, bary);

                SurfaceHit s;
                s.isFrontFace = HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE;

				float frontFaceSign = s.isFrontFace ? 1.0f : -1.0f;

                float3 localNormal = frontFaceSign * v.normal;

                s.worldNormal = normalize(mul(localNormal, (float3x3)WorldToObject()));
                s.worldVertexNormal = s.worldNormal;

                float3 e0 = v1.position - v0.position;
                float3 e1 = v2.position - v0.position;

                float3 worldFaceNormal = normalize(mul(cross(e0, e1), (float3x3)WorldToObject()));
                s.worldFaceNormal = frontFaceSign * worldFaceNormal;

                s.worldPosition = TransformObjectToWorldPositionPrecise(v.position);
                float3 previousLocal=v.position;
                if(g_PTDeformedHistory>0.5)previousLocal=PTPreviousVertex(tri.x)*bary.x+PTPreviousVertex(tri.y)*bary.y+PTPreviousVertex(tri.z)*bary.z;
                s.previousPosition=mul(g_PTPreviousObjectToWorld,float4(previousLocal,1)).xyz;
                s.uv = v.uv;
                s.vertexColor = v.color;

                float3 we0 = mul((float3x3)ObjectToWorld(), e0);
                float3 we1 = mul((float3x3)ObjectToWorld(), e1);
                float a = dot(we0, we0), b = dot(we0, we1), c = dot(we1, we1);
                float det = max(a * c - b * b, 1e-16);
                float2 duv0 = v1.uv - v0.uv, duv1 = v2.uv - v0.uv;
                float3 gradU = ((duv0.x * c - duv1.x * b) * we0 + (duv1.x * a - duv0.x * b) * we1) / det;
                float3 gradV = ((duv0.y * c - duv1.y * b) * we0 + (duv1.y * a - duv0.y * b) * we1) / det;
                s.textureFootprint = coneWidth * max(length(gradU), length(gradV))
                    / max(abs(dot(s.worldFaceNormal, WorldRayDirection())), 0.2);

#if defined(NORMAL_MAP_ON) || defined(DETAIL_ON)

                float3 worldTangent = mul((float3x3)ObjectToWorld(), v.tangent.xyz);

                worldTangent -= s.worldNormal * dot(s.worldNormal, worldTangent);

                float tangentLengthSq = dot(worldTangent, worldTangent);

                if (tangentLengthSq > 1e-8)
                {
                    worldTangent *= rsqrt(tangentLengthSq);

                    float handedness = v.tangent.w * GetOddNegativeScale();
                    float3 worldBitangent = cross(s.worldNormal, worldTangent) * handedness;

                    float4 packedNormal = _NormalMapTex.SampleLevel(sampler__NormalMapTex, _NormalMapTex_ST.xy * s.uv + _NormalMapTex_ST.zw,
                        TextureLOD(_NormalMapTex, s.textureFootprint, _NormalMapTex_ST.xy));
#if NORMAL_MAP_ON
                    float3 tangentNormal = UnpackNormalMapScaled(packedNormal, _NormalMapScale);
#else
                    float3 tangentNormal = float3(0, 0, 1);
#endif
#if DETAIL_ON
                    float2 detailUV = s.uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
                    float mask = _DetailMask.SampleLevel(sampler__DetailMask, s.uv * _MainTex_ST.xy + _MainTex_ST.zw,
                        TextureLOD(_DetailMask, s.textureFootprint, _MainTex_ST.xy)).a;
                    float3 detailNormal = UnpackNormalMapScaled(_DetailNormalMap.SampleLevel(sampler__DetailNormalMap, detailUV,
                        TextureLOD(_DetailNormalMap, s.textureFootprint, _DetailAlbedoMap_ST.xy)), _DetailNormalMapScale);
                    detailNormal = normalize(lerp(float3(0,0,1), detailNormal, mask));

                    tangentNormal = normalize(float3(tangentNormal.xy + detailNormal.xy, tangentNormal.z * detailNormal.z));
#endif

                    float3x3 tangentToWorld = float3x3(worldTangent, worldBitangent, s.worldNormal);
                    s.worldNormal = normalize(mul(tangentNormal, tangentToWorld));
                }
#endif
                return s;
            }

            MaterialSample EvaluateMaterial(float2 uv, float4 vertexColor, float footprint)
            {
                float2 baseUV = _MainTex_ST.xy * uv + _MainTex_ST.zw;
                float4 albedoSample = _MainTex.SampleLevel(sampler__MainTex, baseUV, TextureLOD(_MainTex, footprint, _MainTex_ST.xy));
                float3 baseColor = _Color.xyz * albedoSample.xyz;
#if DETAIL_ON
                float mask = _DetailMask.SampleLevel(sampler__DetailMask, baseUV, TextureLOD(_DetailMask, footprint, _MainTex_ST.xy)).a;
                float3 detail = _DetailAlbedoMap.SampleLevel(sampler__DetailAlbedoMap,
                    uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw, TextureLOD(_DetailAlbedoMap, footprint, _DetailAlbedoMap_ST.xy)).rgb;
                baseColor *= lerp(1.0.xxx, detail * g_DetailAlbedoScale, mask);
#endif

                if (_VertexColorMode == 1)
                {
                    float3 vertexAlbedo = vertexColor.rgb;
                    if (g_UseRandomVertexColors > 0.5)
                    {
                        float3 p3 = frac(vertexColor.aaa * float3(0.1031, 0.1030, 0.0973));
                        p3 += dot(p3, p3.yzx + 33.33);
                        vertexAlbedo = frac((p3.xxy + p3.yzz) * p3.zyx);
                    }
                    baseColor *= vertexAlbedo;
                }
                else if (_VertexColorMode == 2)
                    baseColor *= vertexColor.aaa;

                float3 emission = float3(0, 0, 0);
#if EMISSION_ON
                emission = _EmissionColor.xyz * _EmissionTex.SampleLevel(sampler__EmissionTex, _EmissionTex_ST.xy * uv + _EmissionTex_ST.zw, TextureLOD(_EmissionTex, footprint, _EmissionTex_ST.xy)).xyz;
#endif

                float iorF0 = (1.0 - _IOR) / (1.0 + _IOR);
                iorF0 *= iorF0;

                MaterialSample m;
                float metallic = _Metallic;
                float smoothness = _Smoothness;
                float3 specularF0 = iorF0 * _SpecularColor.xyz;
#if METALLIC_MAP_ON
                float4 packed = _MetallicGlossMap.SampleLevel(sampler__MetallicGlossMap, baseUV, TextureLOD(_MetallicGlossMap, footprint, _MainTex_ST.xy));
                metallic = packed.r;
                smoothness = packed.a * _GlossMapScale;
#elif SPECULAR_MAP_ON
                float4 packed = _SpecGlossMap.SampleLevel(sampler__SpecGlossMap, baseUV, TextureLOD(_SpecGlossMap, footprint, _MainTex_ST.xy));
                specularF0 = packed.rgb;
                metallic = 0;
                smoothness = packed.a * _GlossMapScale;
#elif SPECULAR_COLOR_ON
                specularF0 = _SpecColor.rgb;
                metallic = 0;
#endif
                if (_SmoothnessTextureChannel > 0.5) smoothness = albedoSample.a * _GlossMapScale;
                m.F0            = lerp(specularF0, baseColor, metallic);
                m.diffuseAlbedo = baseColor * (1.0 - metallic);
                m.alpha         = SmoothnessToAlpha(saturate(smoothness));
                m.emission      = emission;
                return m;
            }

            [shader("anyhit")]
            void AnyHitMain(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {
                uint3 tri = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());
                float2 uv0 = UnityRayTracingFetchVertexAttribute2(tri.x, kVertexAttributeTexCoord0);
                float2 uv1 = UnityRayTracingFetchVertexAttribute2(tri.y, kVertexAttributeTexCoord0);
                float2 uv2 = UnityRayTracingFetchVertexAttribute2(tri.z, kVertexAttributeTexCoord0);

                float2 uv = uv0 * (1.0 - attribs.barycentrics.x - attribs.barycentrics.y) + uv1 * attribs.barycentrics.x + uv2 * attribs.barycentrics.y;
                float alpha = _Color.a * _MainTex.SampleLevel(sampler__MainTex, _MainTex_ST.xy * uv + _MainTex_ST.zw, 0).a;
                if (alpha < _Cutoff)
                {
                    IgnoreHit();
                }
            }

            [shader("closesthit")]
            void ClosestHitMain(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {
                if (payload.GetBounceIndexOpaque() >= g_MaxBounceCountOpaque)
                {
                    payload.emission = float3(0, 0, 0);
                    payload.weight = float3(0, 0, 0);
                    payload.Terminate();
                    return;
                }

                payload.lastHitDistance=RayTCurrent();
                payload.coneWidth += RayTCurrent() * payload.coneSpread;
                SurfaceHit hit = LoadSurfaceHit(attribs, payload.coneWidth);
                if (payload.GetBounceIndexTotal() == 0)
                    payload.primarySurface = float4(hit.worldVertexNormal, RayTCurrent());
                if(payload.GetBounceIndexTotal()==0){payload.primaryPreviousPosition=hit.previousPosition;payload.primaryHistoryValid=g_PTHistoryValid;}
                MaterialSample mat = EvaluateMaterial(hit.uv, hit.vertexColor, hit.textureFootprint);

                ShadeOpaqueSurface(payload, hit, mat, -WorldRayDirection());
            }

            ENDHLSL
        }
    }

}

