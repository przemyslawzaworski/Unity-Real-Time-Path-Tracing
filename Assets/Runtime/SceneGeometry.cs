using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace PortablePathTracing
{

    public sealed class SceneGeometry : IDisposable
    {
        sealed class MaterialEntry
        {
            public Material source, converted;
            public int crc;
            public bool initialized;
            public int revision = -1;
            public int seen;
        }
        sealed class InstanceEntry
        {
            public int handle, seen, layer;
            public uint mask;
            public Mesh mesh;
            public Material material;
            public bool cutout, dynamicGeometry;
            public Matrix4x4 matrix;
        }
        sealed class RendererEntry
        {
            public Renderer source;
            public Mesh baked, previousBaked;
            public GraphicsBuffer previousVertices;
            public Matrix4x4 previousMatrix;
            public bool bakedHistory;
            public readonly List<MaterialPropertyBlock> blocks = new List<MaterialPropertyBlock>();
            public int seen;
            public readonly Dictionary<int, InstanceEntry> instances = new Dictionary<int, InstanceEntry>();
        }
        readonly Dictionary<(Material, bool), MaterialEntry> materials = new Dictionary<(Material, bool), MaterialEntry>();
        readonly Dictionary<Renderer, RendererEntry> renderers = new Dictionary<Renderer, RendererEntry>();
        readonly List<Renderer> expired = new List<Renderer>();
        readonly Shader opaque, glass;
        int revision;
        GraphicsBuffer dummyMotionVertices;
        public bool TrackMotion { get; set; }
        Renderer[] registry;
        public int GlassInstances { get; private set; }
        readonly List<int> expiredSubmeshes = new List<int>();
        float nextRegistryScan;
        readonly List<Material> slots = new List<Material>();
        readonly List<(Material, bool)> expiredMaterials = new List<(Material, bool)>();
        public void RefreshRegistry() { registry = null; }

        public SceneGeometry(Shader opaque, Shader glass) { this.opaque = opaque; this.glass = glass; }

        public int Populate(RayTracingAccelerationStructure acceleration, Camera camera)
        {
            revision++;
            if(dummyMotionVertices==null) {
                dummyMotionVertices=new GraphicsBuffer(GraphicsBuffer.Target.Raw,3,4);
                dummyMotionVertices.SetData(new uint[3]);
            }
            Shader.SetGlobalBuffer("g_PTPreviousVertices",dummyMotionVertices);
            GlassInstances = 0;
            int count = 0;
            if (registry == null || Time.unscaledTime >= nextRegistryScan)
            {
                registry = UnityEngine.Object.FindObjectsByType<Renderer>(FindObjectsInactive.Include, FindObjectsSortMode.None);
                nextRegistryScan = Time.unscaledTime + 0.25f;
            }
            foreach (Renderer source in registry)
            {
                if (source == null || !source.enabled || source.forceRenderingOff || !source.gameObject.activeInHierarchy
                    || (camera.cullingMask & (1 << source.gameObject.layer)) == 0
                    || source.GetComponentInParent<Canvas>() != null) continue;
                Mesh mesh = null;
                var skinned = source as SkinnedMeshRenderer;
                if (source is MeshRenderer)
                {
                    var filter = source.GetComponent<MeshFilter>();
                    if (filter != null) mesh = filter.sharedMesh;
                }
                else if (skinned != null) mesh = skinned.sharedMesh;
                if (mesh == null || mesh.vertexCount == 0) continue;

                if (source.GetComponent("TextMeshPro") != null) continue;
                if (!renderers.TryGetValue(source, out RendererEntry entry))
                {
                    entry = new RendererEntry { source = source };
                    renderers.Add(source, entry);
                }
                bool historyValid=entry.seen>0 && entry.seen==revision-1;
                entry.seen = revision;
                if(!historyValid)entry.previousMatrix=source.localToWorldMatrix;
                if (skinned != null)
                {
                    if (entry.baked == null) entry.baked = new Mesh { name = "Path tracing deformed mesh", hideFlags = HideFlags.HideAndDontSave };
                    if(TrackMotion)
                    {
                        if(entry.previousBaked==null)entry.previousBaked=new Mesh {name="Path tracing previous deformed mesh",hideFlags=HideFlags.HideAndDontSave};
                        var swap=entry.previousBaked;entry.previousBaked=entry.baked;entry.baked=swap;
                        entry.baked.vertexBufferTarget|=GraphicsBuffer.Target.Raw;
                    }
                    skinned.BakeMesh(entry.baked, false);
                    mesh = entry.baked;
                }
                if(entry.previousVertices!=null){entry.previousVertices.Dispose();entry.previousVertices=null;}
                int previousStride=0,previousOffset=0;
                bool deformedHistory=TrackMotion && skinned!=null && entry.bakedHistory && historyValid && entry.previousBaked!=null
                    && entry.previousBaked.vertexCount==mesh.vertexCount;
                if(deformedHistory) {
                    int stream=entry.previousBaked.GetVertexAttributeStream(VertexAttribute.Position);
                    previousStride=entry.previousBaked.GetVertexBufferStride(stream);
                    previousOffset=entry.previousBaked.GetVertexAttributeOffset(VertexAttribute.Position);
                    entry.previousVertices=entry.previousBaked.GetVertexBuffer(stream);
                }
                slots.Clear();
                source.GetSharedMaterials(slots);
                for (int sub = 0; sub < mesh.subMeshCount; sub++)
                {
                    if (mesh.GetTopology(sub) != MeshTopology.Triangles || mesh.GetIndexCount(sub) == 0 || slots.Count == 0) continue;
                    Material original = slots[Mathf.Min(sub, slots.Count - 1)];
                    if (original == null || original.shader == null) continue;

                    bool isGlass = original.shader.name == "PortablePathTracing/StandardGlass";
                    if (original.renderQueue > 2500 && !isGlass) continue;
                    Material material = ConvertMaterial(original, mesh.HasVertexAttribute(VertexAttribute.Color), isGlass);
                    while (entry.blocks.Count <= sub) entry.blocks.Add(new MaterialPropertyBlock());
                    var block = entry.blocks[sub];
                    source.GetPropertyBlock(block, Mathf.Min(sub, slots.Count - 1));
                    if (block.isEmpty) source.GetPropertyBlock(block);
                    float sign = source.localToWorldMatrix.determinant < 0 ? -1 : 1;
                    block.SetVector("unity_WorldTransformParams", new Vector4(0, 0, 0, sign));
                    block.SetMatrix("g_PTPreviousObjectToWorld",entry.previousMatrix);
                    block.SetFloat("g_PTHistoryValid",historyValid && (skinned==null || deformedHistory)?1:0);
                    block.SetFloat("g_PTDeformedHistory",deformedHistory?1:0);
                    block.SetInt("g_PTPreviousVertexStride",previousStride);
                    block.SetInt("g_PTPreviousVertexOffset",previousOffset);
                    block.SetBuffer("g_PTPreviousVertices",deformedHistory?entry.previousVertices:dummyMotionVertices);
                    bool cutout = material.IsKeywordEnabled("ALPHATEST_ON");
                    var config = new RayTracingMeshInstanceConfig
                    {
                        mesh = mesh, subMeshIndex = (uint)sub, material = material,
                        materialProperties = block, layer = source.gameObject.layer,
                        mask = isGlass ? 0x02u : 0x01u, enableTriangleCulling = false,
                        frontTriangleCounterClockwise = false,
                        dynamicGeometry = skinned != null || source.rayTracingMode == UnityEngine.Experimental.Rendering.RayTracingMode.DynamicGeometry,
                        subMeshFlags = cutout && !isGlass ? RayTracingSubMeshFlags.Enabled
                            : RayTracingSubMeshFlags.Enabled | RayTracingSubMeshFlags.ClosestHitOnly
                    };
                    Matrix4x4 matrix = source.localToWorldMatrix;
                    bool replace = !entry.instances.TryGetValue(sub, out InstanceEntry instance)
                        || instance.mesh != mesh || instance.material != material
                        || instance.layer != config.layer || instance.cutout != cutout || instance.mask != config.mask
                        || instance.dynamicGeometry != config.dynamicGeometry;
                    if (replace)
                    {
                        if (instance != null) acceleration.RemoveInstance(instance.handle);
                        instance = new InstanceEntry
                        {
                            handle = acceleration.AddInstance(in config, matrix, null, uint.MaxValue),
                            mesh = mesh, material = material, layer = config.layer, cutout = cutout,
                            dynamicGeometry = config.dynamicGeometry, matrix = matrix, mask = config.mask
                        };
                        entry.instances[sub] = instance;
                    }
                    else
                    {
                        if (instance.matrix != matrix)
                        {
                            acceleration.UpdateInstanceTransform(instance.handle, matrix);
                            instance.matrix = matrix;
                        }
                        acceleration.UpdateInstancePropertyBlock(instance.handle, block);
                    }
                    instance.seen = revision;
                    if (isGlass) GlassInstances++;
                    count++;
                }
                entry.previousMatrix=source.localToWorldMatrix;
                entry.bakedHistory=TrackMotion && skinned!=null;
                expiredSubmeshes.Clear();
                foreach (var item in entry.instances)
                    if (item.Value.seen != revision) expiredSubmeshes.Add(item.Key);
                foreach (int sub in expiredSubmeshes)
                {
                    acceleration.RemoveInstance(entry.instances[sub].handle);
                    entry.instances.Remove(sub);
                }
            }
            expired.Clear();
            foreach (var item in renderers)
                if (item.Value.seen != revision) expired.Add(item.Key);
            foreach (Renderer key in expired)
            {
                foreach (var instance in renderers[key].instances.Values) acceleration.RemoveInstance(instance.handle);
                if(renderers[key].previousVertices!=null)renderers[key].previousVertices.Dispose();
                if(renderers[key].previousBaked!=null)UnityEngine.Object.Destroy(renderers[key].previousBaked);
                if (renderers[key].baked != null) UnityEngine.Object.Destroy(renderers[key].baked);
                renderers.Remove(key);
            }
            expiredMaterials.Clear();
            foreach (var item in materials)
                if (item.Value.source == null || item.Value.seen != revision) expiredMaterials.Add(item.Key);
            foreach (var key in expiredMaterials)
            {
                if (materials[key].converted != null) UnityEngine.Object.Destroy(materials[key].converted);
                materials.Remove(key);
            }
            return count;
        }

        Material ConvertMaterial(Material source, bool hasColors, bool isGlass)
        {
            var key = (source, hasColors);
            if (!materials.TryGetValue(key, out MaterialEntry entry))
            {
                entry = new MaterialEntry { source = source, converted = new Material(isGlass ? glass : opaque)
                    { name = source.name + " [path tracing]", hideFlags = HideFlags.HideAndDontSave } };
                materials.Add(key, entry);
            }
            entry.seen = revision;
            if (entry.revision == revision) return entry.converted;
            entry.revision = revision;
            int crc = source.ComputeCRC();
            if (entry.initialized && entry.crc == crc && entry.converted.shader == (isGlass ? glass : opaque)) return entry.converted;
            entry.crc = crc;
            entry.initialized = true;
            Material m = entry.converted;
            m.shader = isGlass ? glass : opaque;
            foreach (string keyword in m.shaderKeywords) m.DisableKeyword(keyword);
            Color color = GetColor(source, "_Color", GetColor(source, "_BaseColor", Color.white));
            m.SetColor("_Color", color);
            m.SetFloat("_IOR", GetFloat(source, "_IOR", 1.5f));
            m.EnableKeyword("DOUBLE_SIDED_ON");
            string normal = source.HasProperty("_BumpMap") ? "_BumpMap" : "_NormalMapTex";
            Texture normalTexture = source.HasProperty(normal) ? source.GetTexture(normal) : null;
            CopyTexture(source, m, normal, "_NormalMapTex", null);
            m.SetFloat("_NormalMapScale", GetFloat(source, "_BumpScale", GetFloat(source, "_NormalMapScale", 1)));
            SetKeyword(m, "NORMAL_MAP_ON", normalTexture != null);
            if (isGlass)
            {
                SetKeyword(m, "FLAT_SHADING_ON", GetFloat(source, "_FlatShading", 0) > 0.5f);
                m.SetFloat("_Roughness", GetFloat(source, "_Roughness", 0));
                m.SetFloat("_ExtinctionCoefficient", GetFloat(source, "_ExtinctionCoefficient", 0));
                return m;
            }

            m.SetFloat("_VertexColorMode", hasColors ? GetFloat(source, "_VertexColorMode", 0) : 0);
            CopyTexture(source, m, source.HasProperty("_MainTex") ? "_MainTex" : "_BaseMap", "_MainTex", Texture2D.whiteTexture);
            m.SetFloat("_Metallic", GetFloat(source, "_Metallic", 0));
            m.SetFloat("_Smoothness", GetFloat(source, "_Smoothness", GetFloat(source, "_Glossiness", 0)));

            m.SetColor("_SpecularColor", GetColor(source, "_SpecularColor", Color.white));
            Color emission = source.IsKeywordEnabled("_EMISSION") || source.IsKeywordEnabled("EMISSION_ON")
                ? GetColor(source, "_EmissionColor", Color.black) : Color.black;
            m.SetColor("_EmissionColor", emission);
            SetKeyword(m, "EMISSION_ON", emission.maxColorComponent > 0);
            CopyTexture(source, m, source.HasProperty("_EmissionMap") ? "_EmissionMap" : "_EmissionTex", "_EmissionTex", Texture2D.whiteTexture);
            bool specular = source.shader.name.Contains("Specular") || (source.HasProperty("_SpecColor") && !source.HasProperty("_Metallic"));
            bool metallicMap = !specular && source.IsKeywordEnabled("_METALLICGLOSSMAP") && source.GetTexture("_MetallicGlossMap") != null;
            bool specularMap = specular && source.IsKeywordEnabled("_SPECGLOSSMAP") && source.GetTexture("_SpecGlossMap") != null;
            CopyTexture(source, m, "_MetallicGlossMap", "_MetallicGlossMap", Texture2D.whiteTexture);
            CopyTexture(source, m, "_SpecGlossMap", "_SpecGlossMap", Texture2D.whiteTexture);
            m.SetColor("_SpecColor", GetColor(source, "_SpecColor", new Color(0.04f, 0.04f, 0.04f)));
            m.SetFloat("_GlossMapScale", GetFloat(source, "_GlossMapScale", 1));
            m.SetFloat("_SmoothnessTextureChannel", GetFloat(source, "_SmoothnessTextureChannel", 0));
            SetKeyword(m, "METALLIC_MAP_ON", metallicMap);
            SetKeyword(m, "SPECULAR_MAP_ON", specularMap);
            SetKeyword(m, "SPECULAR_COLOR_ON", specular && !specularMap);
            bool detail = source.IsKeywordEnabled("_DETAIL_MULX2") && GetFloat(source, "_UVSec", 0) == 0;
            CopyTexture(source, m, "_DetailAlbedoMap", "_DetailAlbedoMap", Texture2D.grayTexture);
            CopyTexture(source, m, "_DetailNormalMap", "_DetailNormalMap", Texture2D.normalTexture);
            CopyTexture(source, m, "_DetailMask", "_DetailMask", Texture2D.whiteTexture);
            m.SetFloat("_DetailNormalMapScale", GetFloat(source, "_DetailNormalMapScale", 1));
            SetKeyword(m, "DETAIL_ON", detail);
            bool cutout = source.IsKeywordEnabled("_ALPHATEST_ON") || source.IsKeywordEnabled("ALPHATEST_ON") || source.renderQueue >= 2450;
            m.SetFloat("_Cutoff", GetFloat(source, "_Cutoff", 0.5f));
            SetKeyword(m, "ALPHATEST_ON", cutout);
            m.EnableKeyword("ENERGY_COMPENSATION_ON");
            return m;
        }

        static Color GetColor(Material m, string name, Color fallback) { return m.HasProperty(name) ? m.GetColor(name) : fallback; }
        static float GetFloat(Material m, string name, float fallback) { return m.HasProperty(name) ? m.GetFloat(name) : fallback; }
        static void SetKeyword(Material m, string keyword, bool enabled) { if (enabled) m.EnableKeyword(keyword); else m.DisableKeyword(keyword); }
        static void CopyTexture(Material source, Material destination, string from, string to, Texture fallback)
        {
            bool has = source.HasProperty(from);
            Texture texture = has ? source.GetTexture(from) : null;
            destination.SetTexture(to, texture != null ? texture : fallback);
            destination.SetTextureScale(to, has ? source.GetTextureScale(from) : Vector2.one);
            destination.SetTextureOffset(to, has ? source.GetTextureOffset(from) : Vector2.zero);
        }
        public void Dispose()
        {
            foreach (var item in materials) if (item.Value.converted != null) UnityEngine.Object.Destroy(item.Value.converted);
            foreach (var item in renderers) if (item.Value.baked != null) UnityEngine.Object.Destroy(item.Value.baked);
            foreach(var entry in renderers.Values) {
                if(entry.previousVertices!=null)entry.previousVertices.Dispose();
                if(entry.previousBaked!=null)UnityEngine.Object.Destroy(entry.previousBaked);
            }
            if(dummyMotionVertices!=null){dummyMotionVertices.Dispose();dummyMotionVertices=null;}
            materials.Clear(); renderers.Clear();
        }
    }
}


