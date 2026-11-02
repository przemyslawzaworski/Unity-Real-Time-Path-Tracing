Shader "PortablePathTracing/StandardGlass"
{
    Properties
    {
        _Color("Color", Color) = (1, 1, 1, 1)
        _ExtinctionCoefficient("Extinction Coefficient", Range(0.0, 20.0)) = 1.0

        _Roughness("Roughness", Range(0.0, 1.0)) = 0.0

        [Toggle] _FlatShading("Flat Shading", float) = 0

        [Normal]_NormalMapTex("Normal Map", 2D) = "bump" {}
        _NormalMapScale("Normal Map Scale", Range(0.0, 2.0)) = 1.0

        _IOR("Index of Refraction", Range(1.0, 2.8)) = 1.5
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "DisableBatching" = "True" }
        LOD 100

         Pass
        {
            Name "PathTracing"
            Tags{ "LightMode" = "RayTracing" }

            HLSLPROGRAM

            #include "UnityRaytracingMeshUtils.cginc"
            #include "RayPayload.hlsl"
            #include "Utils.hlsl"
            #include "BRDF.hlsl"
            #include "GlobalResources.hlsl"

            #pragma raytracing main_hit_group

            #pragma multi_compile_local _ FLAT_SHADING_ON
			#pragma multi_compile_local _ DOUBLE_SIDED_ON
            #pragma multi_compile_local _ NORMAL_MAP_ON

            float4 _Color;
            float _IOR;
            float _Roughness;
            float _ExtinctionCoefficient;
            float _FlatShading;

            Texture2D<float4> _NormalMapTex;
            float4 _NormalMapTex_ST;
            SamplerState sampler__NormalMapTex;
            float _NormalMapScale;

            struct AttributeData
            {
                float2 barycentrics;
            };

            struct Vertex
            {
                float3 position;
                float3 normal;
                float2 uv;
#if NORMAL_MAP_ON
                float4 tangent;
#endif
            };

            Vertex FetchVertex(uint vertexIndex)
            {
                Vertex v;
                v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
                v.normal = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
                v.uv = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
#if NORMAL_MAP_ON
                v.tangent = UnityRayTracingFetchVertexAttribute4(vertexIndex, kVertexAttributeTangent);
#endif
                return v;
            }

            Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
            {
                Vertex v;
                v.position = InterpolatePositionPrecise(v0.position, v1.position, v2.position, barycentrics);

                #define INTERPOLATE_ATTRIBUTE(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
                INTERPOLATE_ATTRIBUTE(normal);
                INTERPOLATE_ATTRIBUTE(uv);
#if NORMAL_MAP_ON
                INTERPOLATE_ATTRIBUTE(tangent);
#endif
                return v;
            }

            struct SurfaceHit
            {
                float3 worldPosition;
                float3 worldNormal;
                float3 worldGeomNormal;
                bool   isFrontFace;
            };

            SurfaceHit LoadSurfaceHit(AttributeData attribs)
            {
                uint3 tri = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());
                Vertex v0 = FetchVertex(tri.x);
                Vertex v1 = FetchVertex(tri.y);
                Vertex v2 = FetchVertex(tri.z);

                float3 bary = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
                Vertex v = InterpolateVertices(v0, v1, v2, bary);

                SurfaceHit s;
                s.isFrontFace = HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE;

#if FLAT_SHADING_ON
                float3 e0 = v1.position - v0.position;
                float3 e1 = v2.position - v0.position;
                float3 localNormal = normalize(cross(e0, e1));
#else
                float3 localNormal = v.normal;
#endif

                float3 worldOutNormal = normalize(mul(localNormal, (float3x3)WorldToObject()));
                float3 shadingNormal = worldOutNormal;

#if NORMAL_MAP_ON

                float3 worldTangent = mul((float3x3)ObjectToWorld(), v.tangent.xyz);
                worldTangent -= worldOutNormal * dot(worldOutNormal, worldTangent);
                float tangentLengthSq = dot(worldTangent, worldTangent);
                if (tangentLengthSq > 1e-12)
                {
                    worldTangent *= rsqrt(tangentLengthSq);
                    float handedness = v.tangent.w * sign(determinant((float3x3)ObjectToWorld()));
                    float3 worldBitangent = cross(worldOutNormal, worldTangent) * handedness;

                    float4 packedNormal = _NormalMapTex.SampleLevel(sampler__NormalMapTex, _NormalMapTex_ST.xy * v.uv + _NormalMapTex_ST.zw, 0);
                    float3 tangentNormal = UnpackNormalMapScaled(packedNormal, _NormalMapScale);
                    float3x3 tangentToWorld = float3x3(worldTangent, worldBitangent, worldOutNormal);
                    shadingNormal = normalize(mul(tangentNormal, tangentToWorld));
                }
#endif

                float sideFlip = s.isFrontFace ? 1.0 : -1.0;
                s.worldNormal     = shadingNormal  * sideFlip;
                s.worldGeomNormal = worldOutNormal * sideFlip;

                s.worldPosition = TransformObjectToWorldPositionPrecise(v.position);
                return s;
            }

            [shader("anyhit")]
            void GlassShadowAnyHit(inout GlassShadowPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {

                if (HitKind() == HIT_KIND_TRIANGLE_FRONT_FACE)
                {
                    payload.transmittance *= saturate(_Color.rgb) * 0.96;
                }
                IgnoreHit();
            }

            [shader("closesthit")]
            void ClosestHitMain(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
            {
                if (payload.GetBounceIndexTransparent() >= g_MaxBounceCountTransparent)
                {
                    payload.emission = float3(0, 0, 0);
                    payload.weight = float3(0, 0, 0);
                    payload.Terminate();
                    return;
                }

                payload.lastHitDistance=RayTCurrent();
                payload.environmentMisWeight = 1;
                SurfaceHit hit = LoadSurfaceHit(attribs);
                if (payload.GetBounceIndexTotal() == 0)
                    payload.primarySurface = float4(hit.worldNormal, RayTCurrent());

                float etaI  = hit.isFrontFace ? 1.0 : _IOR;
                float etaT  = hit.isFrontFace ? _IOR : 1.0;
                float alpha = max(_Roughness * _Roughness, 1e-4);

                float3 L;
                float3 weight;
                bool   isReflected;
                if (!SampleGlassGGX(WorldRayDirection(), hit.worldNormal, etaI, etaT, alpha, payload.rngState, L, weight, isReflected))
                {
                    payload.weight = float3(0, 0, 0);
                    payload.emission = float3(0, 0, 0);
                    payload.Terminate();
                    return;
                }

                float3 absorption = !hit.isFrontFace ? exp(-(1.0 - _Color.xyz) * RayTCurrent() * _ExtinctionCoefficient) : float3(1, 1, 1);

                float pushSign = isReflected ? 1.0 : -1.0;

                payload.weight = weight * absorption;
                payload.emission = float3(0, 0, 0);
                payload.bounceRayOrigin = OffsetRayOrigin(hit.worldPosition, pushSign * hit.worldGeomNormal);
                payload.bounceRayDirection = L;
				payload.IncrementBounceIndexTransparent();
            }

            ENDHLSL
        }

    }

}

