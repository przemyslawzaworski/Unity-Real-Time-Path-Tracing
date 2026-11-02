using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Video;

namespace PortablePathTracing
{

[RequireComponent(typeof(Camera)), DisallowMultipleComponent]
[AddComponentMenu("Rendering/Portable Path Tracer")]
public class PathTracer : MonoBehaviour
{
    public RayTracingShader rayTracingShader = null;

    public Cubemap envTexture = null;
    public bool environmentNEE = false;
    [Header("Display")]
    [Range(-12,12)] public float exposureEV = 3;
    public enum ToneMapping { None, Reinhard, AcesFitted }
    public ToneMapping toneMapping = ToneMapping.AcesFitted;
    public enum LightingView { Final, Diffuse, Specular, NormalRoughness, LinearDepth, MotionVectors, DenoiserCoverage }
    public LightingView lightingView = LightingView.Final;
    Material displayMaterial;
    EnvironmentImportance environmentImportance;
    long importanceSkyCapture = -1;
    public Shader opaqueProxyShader;
    public Shader glassProxyShader;
    [Tooltip("F8 switches between the original game renderer and path tracing during play.")]
    public bool pathTracingEnabled = true;
    [Min(0)] public float environmentIntensity = 1;
    public int ActiveInstances { get; private set; }
    private SceneGeometry sceneGeometry;
    private RenderTexture capturedEnvironment;
    private Cubemap fallbackEnvironment;
    private bool environmentCaptured;
    private VideoPlayer skyVideo;
    private long capturedVideoFrame = -1;
    private float nextSkyCapture;
    private float nextVideoSearch;
    private long skyFrameSerial;
    private long capturedSkyFrameSerial = -1;
    private long latestDecodedSkyFrame = -1;
    private bool skyFrameReady;
    private bool previousFrameReadyEvents;
    private bool previousSkipOnDrop;
    private long skyCaptureCount;
    private float nextSkyStatusLog;
    [Tooltip("Write video/capture progress every five seconds in Development Builds and the Editor.")]
    public bool skyPlaybackDiagnostics = false;
    public enum SkyResolution { Low256 = 256, Medium512 = 512, High1024 = 1024, Ultra2048 = 2048 }
    [Tooltip("Resolution of each cubemap face. Higher values preserve cloud detail at a greater GPU cost.")]
    public SkyResolution skyCubemapResolution = SkyResolution.High1024;
    [Min(0)]
    [Tooltip("0 follows every new decoded video frame. A positive value limits sky updates in seconds.")]
    public float skyRefreshInterval = 0;
    private Camera skyCaptureCamera;
    private bool capturePending = true;

    [Range(1, 100)]
    public uint bounceCountOpaque = 5;

    [Range(1, 100)]
    public uint bounceCountTransparent = 8;

    [Header("Real-time quality")]
    [Range(1, 128)]
    [Tooltip("Independent paths per pixel, accumulated entirely inside the current frame. Cost grows roughly linearly.")]
    public int samplesPerFrame = 8;

    [Range(0.25f, 1.0f)]
    public float renderScale = 1.0f;

    [Tooltip("Denoise using the selected mode. NRD uses motion-compensated history; Spatial filters the current frame.")]
    public bool denoise = true;
    public enum DenoiserMode { Spatial, NrdReblur }
    public DenoiserMode denoiserMode = DenoiserMode.NrdReblur;
    [Range(1,63)] public int nrdMaxHistoryFrames=32;
    public string NrdStatus => nrd==null?"inactive":nrd.Ready?"NRD 4.18 REBLUR diffuse + specular":nrd.Error;
    NrdReblur nrd;
    int nrdWidth,nrdHeight;
    bool resourcesNRD;
    RenderTexture nrdSpecular,nrdNormals,nrdViewZ,nrdSpecularFactor,nrdMotion,dummyNrdDepth;
    Texture previousNrdEnvironment;
    float previousNrdIntensity;
    [ContextMenu("Reset denoiser history")]
    public void ResetDenoiserHistory(){if(nrd!=null)nrd.ResetHistory();}
    public ComputeShader denoiserShader;
    [Range(1, 4)] public int denoiserIterations = 2;
    [Range(0.1f, 10.0f)] public float denoiserStrength = 2.0f;

    [Min(0)]
    [Tooltip("Optional per-path luminance clamp. 0 disables it (unbiased). Positive values reduce fireflies but lose energy.")]
    public float sampleLuminanceClamp = 0.0f;

    [Header("Debug")]
    public bool debugSingleBounce = false;

    [Range(0, 100)]
    [Tooltip("When Debug Single Bounce is enabled, this selects which bounce to visualize. 0 is the primary ray hit (directly visible emission and direct lighting).")]
    public uint debugBounceIndex = 0;

    [Tooltip("Flag pixels whose sample is non-finite (NaN or Inf) in bright magenta to locate the source of bad samples. The flag lasts for the current frame.")]
    public bool debugValidate = false;

    private uint cameraWidth = 0;
    private uint cameraHeight = 0;

    private Camera renderCamera;
    private uint frameSequence;
    private bool warnedUnsupported;
    private RenderTexture surfaceGuide;
    private RenderTexture diffuseOutput, albedoGuide;
    private bool resourcesDenoise;
    private int resourcesFinalIndex = -1;
    private int denoiserKernel = -1;
    private ComputeShader cachedDenoiser;
    private static Texture2D sharedEnergyCompLUT;
    private Light[] cachedLights;
    private float nextLightSearch;
    private bool lightRegistryDirty = true;

    [ContextMenu("Refresh scene registry")]
    public void RefreshScene()
    {
        lightRegistryDirty = true;
        if (sceneGeometry != null) sceneGeometry.RefreshRegistry();
    }

    private void OnSceneLoaded(UnityEngine.SceneManagement.Scene scene, UnityEngine.SceneManagement.LoadSceneMode mode) { RefreshScene(); }
    private void OnSceneUnloaded(UnityEngine.SceneManagement.Scene scene) { RefreshScene(); }
    private RenderTexture[] filterBuffers = new RenderTexture[2];

    private RenderTexture rayTracingOutput = null;

    private RayTracingAccelerationStructure rayTracingAccelerationStructure = null;

    private Texture2D energyCompLUT = null;

    [StructLayout(LayoutKind.Sequential)]
    private struct LightData
    {
        public Vector3 color;
        public uint    type;
        public Vector3 direction;
        public float   range;
        public Vector3 position;
        public float   _pad0;
    }

    private const int LIGHT_DATA_STRIDE = 48;

    private GraphicsBuffer lightsBuffer = null;
    private readonly List<LightData> lightsScratch = new List<LightData>();

    private static readonly LightData[] DummyLights = new LightData[1];

    private void CreateRayTracingAccelerationStructure()
    {
        if (rayTracingAccelerationStructure == null)
        {
            RayTracingAccelerationStructure.Settings settings = new RayTracingAccelerationStructure.Settings()
            {
                rayTracingModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything,
                managementMode = RayTracingAccelerationStructure.ManagementMode.Manual,
                layerMask = -1
            };
            rayTracingAccelerationStructure = new RayTracingAccelerationStructure(settings);
        }
    }

    private void BuildAccelerationStructure()
    {
        if (sceneGeometry == null) sceneGeometry = new SceneGeometry(opaqueProxyShader, glassProxyShader);
        sceneGeometry.TrackMotion=resourcesNRD;
        ActiveInstances = sceneGeometry.Populate(rayTracingAccelerationStructure, renderCamera);
        Shader.SetGlobalInt("g_GlassInstanceCount", sceneGeometry.GlassInstances);
        rayTracingAccelerationStructure.Build();
    }

    private void ReleaseResources()
    {
        if (sceneGeometry != null) { sceneGeometry.Dispose(); sceneGeometry = null; }
        ActiveInstances = 0;
        if(environmentImportance!=null){environmentImportance.Dispose();environmentImportance=null;}
        if(displayMaterial!=null){Destroy(displayMaterial);displayMaterial=null;}
        if (rayTracingAccelerationStructure != null)
        {
            rayTracingAccelerationStructure.Release();
            rayTracingAccelerationStructure = null;
        }

        ReleaseTexture(ref rayTracingOutput);
        ReleaseTexture(ref surfaceGuide);
        ReleaseTexture(ref diffuseOutput);
        ReleaseTexture(ref albedoGuide);
        ReleaseTexture(ref nrdSpecular);ReleaseTexture(ref nrdNormals);ReleaseTexture(ref nrdViewZ);
        ReleaseTexture(ref nrdSpecularFactor);ReleaseTexture(ref nrdMotion);
        for (int i = 0; i < filterBuffers.Length; i++)
            ReleaseTexture(ref filterBuffers[i]);

        if (lightsBuffer != null)
        {
            lightsBuffer.Release();
            lightsBuffer = null;
        }

        if(nrd!=null){nrd.Dispose();nrd=null;}
        ReleaseTexture(ref dummyNrdDepth);

        energyCompLUT = null;

        cameraWidth = 0;
        cameraHeight = 0;
    }

    private static void SetPunctualColor(ref LightData data, Light light)
    {
        Color c = light.color.linear * light.intensity;
        data.color = new Vector3(c.r, c.g, c.b);
    }

    private int CollectLights()
    {
        lightsScratch.Clear();

        if (cachedLights == null || lightRegistryDirty || Time.unscaledTime >= nextLightSearch)
        {
            cachedLights = Object.FindObjectsByType<Light>(FindObjectsInactive.Include, FindObjectsSortMode.None);
            nextLightSearch = Time.unscaledTime + 0.25f;
            lightRegistryDirty = false;
        }
        foreach (Light light in cachedLights)
        {
            if (light == null || !light.isActiveAndEnabled)
                continue;

            LightData data = new LightData();

            switch (light.type)
            {
                case LightType.Directional:
                    data.type = 0;
                    data.direction = light.transform.forward.normalized;
                    SetPunctualColor(ref data, light);
                    break;
                case LightType.Point:
                    data.type = 1;
                    data.position = light.transform.position;
                    data.range = light.range;
                    SetPunctualColor(ref data, light);
                    break;
                default:
                    continue;
            }

            lightsScratch.Add(data);
        }

        int count = lightsScratch.Count;

        int requiredCapacity = Mathf.Max(count, 1);
        if (lightsBuffer == null || lightsBuffer.count < requiredCapacity)
        {
            if (lightsBuffer != null)
                lightsBuffer.Release();
            lightsBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, requiredCapacity, LIGHT_DATA_STRIDE);
        }

        if (count > 0)
            lightsBuffer.SetData(lightsScratch);
        else
            lightsBuffer.SetData(DummyLights);

        return count;
    }

    private static float SmithG1(float NdotV, float a)
    {
        float a2 = a * a;
        return 2.0f * NdotV / Mathf.Max(NdotV + Mathf.Sqrt(a2 + (1.0f - a2) * NdotV * NdotV), 1e-7f);
    }

    private static float SmithG2(float NdotL, float NdotV, float a)
    {
        float a2 = a * a;
        float lambdaV = NdotL * Mathf.Sqrt(a2 + (1.0f - a2) * NdotV * NdotV);
        float lambdaL = NdotV * Mathf.Sqrt(a2 + (1.0f - a2) * NdotL * NdotL);
        return 2.0f * NdotL * NdotV / Mathf.Max(lambdaV + lambdaL, 1e-7f);
    }

    private static Vector3 SampleGGXVNDF(Vector3 Ve, float alpha, float u1, float u2)
    {
        Vector3 Vh = new Vector3(alpha * Ve.x, alpha * Ve.y, Ve.z).normalized;
        float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
        Vector3 T1 = lensq > 0.0f ? new Vector3(-Vh.y, Vh.x, 0.0f) * (1.0f / Mathf.Sqrt(lensq)) : new Vector3(1, 0, 0);
        Vector3 T2 = Vector3.Cross(Vh, T1);
        float r = Mathf.Sqrt(u1);
        float phi = 2.0f * Mathf.PI * u2;
        float t1 = r * Mathf.Cos(phi);
        float t2 = r * Mathf.Sin(phi);
        float s = 0.5f * (1.0f + Vh.z);
        t2 = (1.0f - s) * Mathf.Sqrt(Mathf.Max(0.0f, 1.0f - t1 * t1)) + s * t2;
        Vector3 Nh = t1 * T1 + t2 * T2 + Mathf.Sqrt(Mathf.Max(0.0f, 1.0f - t1 * t1 - t2 * t2)) * Vh;
        return new Vector3(alpha * Nh.x, alpha * Nh.y, Mathf.Max(0.0f, Nh.z)).normalized;
    }

    private static float RadicalInverseVdC(uint bits)
    {
        bits = (bits << 16) | (bits >> 16);
        bits = ((bits & 0x55555555u) << 1) | ((bits & 0xAAAAAAAAu) >> 1);
        bits = ((bits & 0x33333333u) << 2) | ((bits & 0xCCCCCCCCu) >> 2);
        bits = ((bits & 0x0F0F0F0Fu) << 4) | ((bits & 0xF0F0F0F0u) >> 4);
        bits = ((bits & 0x00FF00FFu) << 8) | ((bits & 0xFF00FF00u) >> 8);
        return bits * 2.3283064365386963e-10f;
    }

    private static float GGXDirectionalAlbedo(float NdotV, float alpha, int sampleCount)
    {
        Vector3 V = new Vector3(Mathf.Sqrt(Mathf.Max(0.0f, 1.0f - NdotV * NdotV)), 0.0f, NdotV);
        float g1 = SmithG1(NdotV, alpha);
        float sum = 0.0f;
        for (int i = 0; i < sampleCount; i++)
        {
            Vector3 H = SampleGGXVNDF(V, alpha, (i + 0.5f) / sampleCount, RadicalInverseVdC((uint)i));
            float VdotH = Vector3.Dot(V, H);
            Vector3 L = 2.0f * VdotH * H - V;
            if (L.z > 0.0f)
                sum += SmithG2(L.z, NdotV, alpha) / Mathf.Max(g1, 1e-7f);
        }
        return sum / sampleCount;
    }

    private Texture2D BakeEnergyCompLUT()
    {
        const int size = 64;
        const int sampleCount = 2048;

        Texture2D lut = new Texture2D(size, size, TextureFormat.RHalf, false, true)
        {
            name = "GGX Energy Compensation LUT",
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear,
        };

        Color[] pixels = new Color[size * size];
        for (int j = 0; j < size; j++)
        {

            float roughness = (j + 0.5f) / size;
            float alpha = Mathf.Max(roughness * roughness, 1e-4f);
            for (int i = 0; i < size; i++)
            {
                float NdotV = Mathf.Max((i + 0.5f) / size, 1e-3f);
                pixels[j * size + i] = new Color(GGXDirectionalAlbedo(NdotV, alpha, sampleCount), 0.0f, 0.0f, 0.0f);
            }
        }

        lut.SetPixels(pixels);
        lut.Apply(false, true);
        return lut;
    }

    private static void ReleaseTexture(ref RenderTexture texture)
    {
        if (texture == null) return;
        texture.Release();
        if (Application.isPlaying) Destroy(texture); else DestroyImmediate(texture);
        texture = null;
    }

    private static RenderTexture CreateTexture(int width, int height, string label, bool half = false)
    {
        var texture = new RenderTexture(width, height, 0, half && SystemInfo.SupportsRandomWriteOnRenderTextureFormat(RenderTextureFormat.ARGBHalf) ? RenderTextureFormat.ARGBHalf : RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear)
        {
            name = label, enableRandomWrite = true,
            filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp
        };
        texture.Create();
        return texture;
    }

    private void CreateResources(int sourceWidth, int sourceHeight, bool useDenoiser, bool useNrd)
    {
        CreateRayTracingAccelerationStructure();
        if (energyCompLUT == null)
        {
            if (sharedEnergyCompLUT == null)
            {
                var baked = Resources.Load<TextAsset>("PathTracing/EnergyCompensation");
                if (baked != null && baked.bytes.Length == 64 * 64 * 2)
                {
                    sharedEnergyCompLUT = new Texture2D(64, 64, TextureFormat.RHalf, false, true)
                    {
                        name = "GGX Energy Compensation LUT", wrapMode = TextureWrapMode.Clamp,
                        filterMode = FilterMode.Bilinear, hideFlags = HideFlags.HideAndDontSave
                    };
                    sharedEnergyCompLUT.LoadRawTextureData(baked.bytes);
                    sharedEnergyCompLUT.Apply(false, true);
                }
                else sharedEnergyCompLUT = BakeEnergyCompLUT();
            }
            energyCompLUT = sharedEnergyCompLUT;
        }
        int width = Mathf.Max(1, Mathf.RoundToInt(sourceWidth * Mathf.Clamp(renderScale, 0.25f, 1)));
        int height = Mathf.Max(1, Mathf.RoundToInt(sourceHeight * Mathf.Clamp(renderScale, 0.25f, 1)));
        int finalIndex = (Mathf.Clamp(denoiserIterations, 1, 4) - 1) % 2;
        if (rayTracingOutput != null && cameraWidth == width && cameraHeight == height && resourcesDenoise == useDenoiser
            && resourcesNRD==useNrd && (!useDenoiser || resourcesFinalIndex == finalIndex)) return;
        ReleaseTexture(ref rayTracingOutput);
        ReleaseTexture(ref surfaceGuide);
        ReleaseTexture(ref diffuseOutput);
        ReleaseTexture(ref albedoGuide);
        ReleaseTexture(ref nrdSpecular);ReleaseTexture(ref nrdNormals);ReleaseTexture(ref nrdViewZ);
        ReleaseTexture(ref nrdSpecularFactor);ReleaseTexture(ref nrdMotion);
        for (int i = 0; i < filterBuffers.Length; i++) ReleaseTexture(ref filterBuffers[i]);
        rayTracingOutput = CreateTexture(width, height, "Current frame path radiance");
        resourcesDenoise = useDenoiser;
        resourcesNRD=useNrd;
        resourcesFinalIndex = finalIndex;
        if (useDenoiser)
        {

            surfaceGuide = CreateTexture(width, height, "Primary normal and distance", true);
            diffuseOutput = CreateTexture(width, height, "Diffuse illumination and variance", true);
            albedoGuide = CreateTexture(width, height, "Primary diffuse albedo", true);

            if(!useNrd) {
                for (int i = 0; i < filterBuffers.Length; i++)filterBuffers[i]=CreateTexture(width,height,"Spatial denoiser "+i,i!=finalIndex);
            } else {
                nrdSpecular=CreateTexture(width,height,"NRD specular input",true);
                nrdNormals=CreateTexture(width,height,"NRD normal and roughness",true);
                nrdViewZ=NrdReblur.Create(width,height,UnityEngine.Experimental.Rendering.GraphicsFormat.R32_SFloat,"NRD linear view Z");
                nrdSpecularFactor=CreateTexture(width,height,"NRD specular material factor",true);
                nrdMotion=CreateTexture(width,height,"NRD previous minus current UV motion",true);
            }
        }
        cameraWidth = (uint)width;
        cameraHeight = (uint)height;
    }

    [ContextMenu("Load bundled shaders")]
    public void ResolveResources()
    {
        if (rayTracingShader == null) rayTracingShader = Resources.Load<RayTracingShader>("PathTracing/RayGenerator");
        if (opaqueProxyShader == null) opaqueProxyShader = Resources.Load<Shader>("PathTracing/PathTracingStandard");
        if (glassProxyShader == null) glassProxyShader = Resources.Load<Shader>("PathTracing/PathTracingStandardGlass");
        if (denoiserShader == null) denoiserShader = Resources.Load<ComputeShader>("PathTracing/FrameDenoiser");
        if(envTexture==null) {
            var defaults=Resources.Load<PortablePathTracingSettings>("PathTracing/Settings");
            if(defaults!=null)envTexture=defaults.environmentOverride;
        }
    }

    void Reset() { ResolveResources(); }

    [ContextMenu("Toggle path tracing")]
    public void TogglePathTracing() { pathTracingEnabled = !pathTracingEnabled; }

    private void OnEnable()
    {
        renderCamera = GetComponent<Camera>();
        UnityEngine.SceneManagement.SceneManager.sceneLoaded += OnSceneLoaded;
        UnityEngine.SceneManagement.SceneManager.sceneUnloaded += OnSceneUnloaded;
        RefreshScene();
        ResolveResources();
        capturePending = true;
    }

    private void Update()
    {

#if ENABLE_LEGACY_INPUT_MANAGER
        if (Input.GetKeyDown(KeyCode.F8)) TogglePathTracing();
#endif
        if (!pathTracingEnabled && sceneGeometry != null) ReleaseResources();
    }

    private Material CurrentSkyMaterial()
    {
        var overrideSky = renderCamera.GetComponent<Skybox>();
        return overrideSky != null && overrideSky.enabled ? overrideSky.material : RenderSettings.skybox;
    }

    private void LateUpdate()
    {
        if (!pathTracingEnabled || envTexture != null || !SystemInfo.supportsRayTracingShaders
            || renderCamera.stereoEnabled || renderCamera.orthographic || GraphicsSettings.currentRenderPipeline != null)
            return;
        EnsureFallbackEnvironment();
        if (capturedEnvironment != null && capturedEnvironment.width != (int)skyCubemapResolution)
            capturePending = true;
        if (Time.unscaledTime >= nextVideoSearch)
        {
            nextVideoSearch = Time.unscaledTime + 1;
            Material skyMaterial = CurrentSkyMaterial();
            Texture skyTexture = skyMaterial != null && skyMaterial.HasProperty("_MainTex") ? skyMaterial.GetTexture("_MainTex") : null;
            VideoPlayer found = null;
            if (skyTexture != null)
                foreach (var video in Object.FindObjectsByType<VideoPlayer>(FindObjectsSortMode.None))
                    if (video.isActiveAndEnabled && video.targetTexture == skyTexture) { found = video; break; }
            if (found != skyVideo)
            {
                UnbindSkyVideo();
                skyVideo = found;
                if (skyVideo != null)
                {
                    previousFrameReadyEvents = skyVideo.sendFrameReadyEvents;
                    previousSkipOnDrop = skyVideo.skipOnDrop;
                    skyVideo.skipOnDrop = false;
                    skyVideo.errorReceived += OnSkyVideoError;
                    skyVideo.frameReady += OnSkyVideoFrameReady;
                    skyVideo.sendFrameReadyEvents = true;
                }
                capturePending = true;
            }
        }
        LogSkyPlaybackStatus();
        if (skyVideo != null)
        {

            if (!skyVideo.isPrepared || skyVideo.texture == null || !skyFrameReady) return;
            if (!capturePending && (skyFrameSerial == capturedSkyFrameSerial || Time.unscaledTime < nextSkyCapture)) return;
        }
        else if (!capturePending) return;
        CaptureEnvironment();
        if (skyVideo != null)
        {
            capturedVideoFrame = latestDecodedSkyFrame;
            capturedSkyFrameSerial = skyFrameSerial;
        }
        nextSkyCapture = Time.unscaledTime + Mathf.Max(0, skyRefreshInterval);
    }

    private void UnbindSkyVideo()
    {
        if (skyVideo != null)
        {
            skyVideo.errorReceived -= OnSkyVideoError;
            skyVideo.frameReady -= OnSkyVideoFrameReady;
            skyVideo.sendFrameReadyEvents = previousFrameReadyEvents;
            skyVideo.skipOnDrop = previousSkipOnDrop;
        }
        skyVideo = null;
        capturedVideoFrame = -1;
        skyFrameSerial = 0;
        capturedSkyFrameSerial = -1;
        latestDecodedSkyFrame = -1;
        skyFrameReady = false;
        nextSkyStatusLog = 0;
    }

    private void OnSkyVideoFrameReady(VideoPlayer source, long frame)
    {
        if (source != skyVideo) return;
        latestDecodedSkyFrame = frame;
        skyFrameSerial++;
        skyFrameReady = true;

    }

    private void OnSkyVideoError(VideoPlayer source, string message)
    {
        Debug.LogWarning("[PathTracingSky] Video error after decoded frame " + latestDecodedSkyFrame
            + ". Keeping the last sky; updates resume when another decoded frame arrives. " + message, this);
    }

    private void LogSkyPlaybackStatus()
    {
        if (!skyPlaybackDiagnostics || !(Debug.isDebugBuild || Application.isEditor) || Time.unscaledTime < nextSkyStatusLog) return;
        nextSkyStatusLog = Time.unscaledTime + 5;
        if (skyVideo == null)
        {
            Debug.Log("[PathTracingSky] No matching VideoPlayer; cubemap captures=" + skyCaptureCount, this);
            return;
        }
        Debug.Log("[PathTracingSky] playing=" + skyVideo.isPlaying + " prepared=" + skyVideo.isPrepared
            + " decodedFrame=" + latestDecodedSkyFrame + " decodedEvents=" + skyFrameSerial
            + " capturedFrame=" + capturedVideoFrame + " capturedEvents=" + capturedSkyFrameSerial
            + " cubemapCaptures=" + skyCaptureCount + " skipOnDrop=" + skyVideo.skipOnDrop, this);
    }

    private void EnsureFallbackEnvironment()
    {
        if (fallbackEnvironment != null) return;
        fallbackEnvironment = new Cubemap(2, TextureFormat.RGBAHalf, false)
            { name = "Path tracing ambient fallback", hideFlags = HideFlags.HideAndDontSave };
        for (int face = 0; face < 6; face++)
        {
            Color color = face == (int)CubemapFace.PositiveY ? RenderSettings.ambientSkyColor
                : face == (int)CubemapFace.NegativeY ? RenderSettings.ambientGroundColor : RenderSettings.ambientEquatorColor;
            if (QualitySettings.activeColorSpace == ColorSpace.Gamma) color = color.linear;
            fallbackEnvironment.SetPixels(new[] { color, color, color, color }, (CubemapFace)face);
        }
        fallbackEnvironment.Apply(false, true);
    }

    [ContextMenu("Refresh sky environment")]
    public void RefreshEnvironment() { capturePending = true; nextSkyCapture = 0; }

    private void CaptureEnvironment()
    {
        int resolution = Mathf.Clamp((int)skyCubemapResolution, 256, 2048);
        if (capturedEnvironment != null && capturedEnvironment.width != resolution)
        {
            ReleaseTexture(ref capturedEnvironment);
            environmentCaptured = false;
        }
        if (capturedEnvironment == null)
        {
            capturedEnvironment = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGBHalf, RenderTextureReadWrite.Linear)
            {
                name = "Path tracing live sky", hideFlags = HideFlags.HideAndDontSave,
                dimension = TextureDimension.Cube, useMipMap = false,
                filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp
            };
            capturedEnvironment.Create();
        }

        if (skyCaptureCamera == null)
        {
            var sky = new GameObject("Path tracing sky capture") { hideFlags = HideFlags.HideAndDontSave };
            skyCaptureCamera = sky.AddComponent<Camera>();
            skyCaptureCamera.enabled = false;
            skyCaptureCamera.cullingMask = 0;
            skyCaptureCamera.allowHDR = true;
            skyCaptureCamera.allowMSAA = false;
            sky.AddComponent<Skybox>();
        }
        Material skyMaterial = CurrentSkyMaterial();
        skyCaptureCamera.clearFlags = skyMaterial != null ? CameraClearFlags.Skybox : CameraClearFlags.SolidColor;
        skyCaptureCamera.backgroundColor = RenderSettings.ambientSkyColor;
        var skybox = skyCaptureCamera.GetComponent<Skybox>();
        skybox.material = skyMaterial;
        skybox.enabled = skyMaterial != null;
        if (skyCaptureCamera.RenderToCubemap(capturedEnvironment))
        {
            environmentCaptured = true;
            skyCaptureCount++;
            capturePending = false;
        }
        else
        {
            capturePending = false;
            Debug.LogWarning("Could not capture sky cubemap; using the ambient fallback.", this);
        }
    }

    void OnDestroy()
    {
        if (skyCaptureCamera != null) Destroy(skyCaptureCamera.gameObject);
        UnbindSkyVideo();
        ReleaseTexture(ref capturedEnvironment);
        if (fallbackEnvironment != null) Destroy(fallbackEnvironment);
        ReleaseResources();
    }

    void OnDisable()
    {
        UnityEngine.SceneManagement.SceneManager.sceneLoaded -= OnSceneLoaded;
        UnityEngine.SceneManagement.SceneManager.sceneUnloaded -= OnSceneUnloaded;
        UnbindSkyVideo();
        ReleaseResources();
    }

    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (renderCamera == null) renderCamera = GetComponent<Camera>();
        if (!Application.isPlaying || !pathTracingEnabled)
        {
            Graphics.Blit(src, dest);
            return;
        }
        if (!SystemInfo.supportsRayTracingShaders || SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12
            || GraphicsSettings.currentRenderPipeline != null || renderCamera.stereoEnabled || renderCamera.orthographic
            || !rayTracingShader || !opaqueProxyShader || !glassProxyShader)
        {
            if (!warnedUnsupported)
            {
                Debug.LogWarning("Portable Path Tracing: using the normal renderer. Requires Built-in RP, a perspective non-XR camera, DX12 ray tracing support and bundled shaders. Current API: "
                    + SystemInfo.graphicsDeviceType + ". Start Unity with -force-d3d12 if needed.", this);
                warnedUnsupported = true;
            }
            Graphics.Blit(src, dest);
            return;
        }

        if (renderCamera == null) renderCamera = GetComponent<Camera>();
        EnsureFallbackEnvironment();
        bool useDenoiser = denoise && denoiserShader != null && !debugValidate && !debugSingleBounce;
        bool wantNrd=useDenoiser && denoiserMode==DenoiserMode.NrdReblur;
        int targetWidth=Mathf.Max(1,Mathf.RoundToInt(src.width*Mathf.Clamp(renderScale,.25f,1)));
        int targetHeight=Mathf.Max(1,Mathf.RoundToInt(src.height*Mathf.Clamp(renderScale,.25f,1)));
        if(nrd!=null && (!wantNrd || targetWidth!=nrdWidth || targetHeight!=nrdHeight)){nrd.Dispose();nrd=null;}
        if(wantNrd && nrd==null) {
            nrdWidth=targetWidth;nrdHeight=targetHeight;nrd=new NrdReblur(targetWidth,targetHeight);
            if(!nrd.Ready)Debug.LogWarning("NRD unavailable; spatial fallback: "+nrd.Error,this);
        }
        bool useNrd=wantNrd && nrd.Ready;
        CreateResources(src.width, src.height, useDenoiser,useNrd);
        if(useNrd)nrd.Prepare(renderCamera);
        Shader.SetGlobalInt("g_UseNRD",useNrd?1:0);rayTracingShader.SetInt("g_UseNRD",useNrd?1:0);
        rayTracingShader.SetMatrix("g_PTCameraToWorld",renderCamera.transform.localToWorldMatrix);
        rayTracingShader.SetMatrix("g_PTWorldToView",renderCamera.transform.worldToLocalMatrix);
        rayTracingShader.SetMatrix("g_PTPreviousViewProjection",useNrd?nrd.PreviousViewProjection:Matrix4x4.identity);
        int lightCount = CollectLights();
        BuildAccelerationStructure();

        rayTracingShader.SetShaderPass("PathTracing");

        Shader.SetGlobalInt(Shader.PropertyToID("g_MaxBounceCountOpaque"), (int)System.Math.Min(bounceCountOpaque, 254u));
        Shader.SetGlobalInt(Shader.PropertyToID("g_MaxBounceCountTransparent"), (int)System.Math.Min(bounceCountTransparent, 254u));
        Shader.SetGlobalBuffer(Shader.PropertyToID("g_Lights"), lightsBuffer);
        Shader.SetGlobalInt(Shader.PropertyToID("g_LightCount"), lightCount);
        Shader.SetGlobalTexture(Shader.PropertyToID("g_EnergyCompLUT"), energyCompLUT);

        rayTracingShader.SetAccelerationStructure(Shader.PropertyToID("g_AccelStruct"), rayTracingAccelerationStructure);
        rayTracingShader.SetFloat(Shader.PropertyToID("g_Zoom"), Mathf.Tan(Mathf.Deg2Rad * renderCamera.fieldOfView * 0.5f));
        rayTracingShader.SetFloat(Shader.PropertyToID("g_AspectRatio"), src.width / (float)src.height);
        rayTracingShader.SetInt(Shader.PropertyToID("g_SamplesPerFrame"), Mathf.Clamp(samplesPerFrame, 1, 128));
        rayTracingShader.SetFloat(Shader.PropertyToID("g_SampleLuminanceClamp"), Mathf.Max(0, sampleLuminanceClamp));
        rayTracingShader.SetInt(Shader.PropertyToID("g_FrameIndex"), unchecked((int)frameSequence++));
        rayTracingShader.SetInt(Shader.PropertyToID("g_DebugBounceIndex"), (int)debugBounceIndex);
        Texture environment = envTexture != null ? (Texture)envTexture
            : environmentCaptured && capturedEnvironment != null ? (Texture)capturedEnvironment : fallbackEnvironment;
        rayTracingShader.SetTexture(Shader.PropertyToID("g_EnvTex"), environment);
        rayTracingShader.SetFloat(Shader.PropertyToID("g_EnvironmentIntensity"), Mathf.Max(0, environmentIntensity));
        Shader.SetGlobalTexture("g_EnvTex",environment);
        Shader.SetGlobalFloat("g_EnvironmentIntensity",Mathf.Max(0,environmentIntensity));
        if(environmentImportance==null) environmentImportance=new EnvironmentImportance();
        bool neeReady=environmentImportance.Bind(environment,rayTracingShader,importanceSkyCapture!=skyCaptureCount);
        if(useNrd && (previousNrdEnvironment!=environment
            || Mathf.Abs(environmentIntensity-previousNrdIntensity)>Mathf.Max(previousNrdIntensity*.25f,.01f)))nrd.ResetHistory();
        previousNrdEnvironment=environment;previousNrdIntensity=environmentIntensity;
        importanceSkyCapture=skyCaptureCount;
        Shader.SetGlobalInt("g_EnvironmentNEE",environmentNEE && neeReady?1:0);
        rayTracingShader.SetInt("g_EnvironmentNEE",environmentNEE && neeReady?1:0);
        Shader.SetGlobalFloat("g_UseRandomVertexColors", 0f);
        Shader.SetGlobalFloat("g_DetailAlbedoScale", QualitySettings.activeColorSpace == ColorSpace.Linear ? 4.5947938f : 2f);

        rayTracingShader.SetInt(Shader.PropertyToID("g_DebugSingleBounce"), debugSingleBounce ? 1 : 0);
        rayTracingShader.SetInt(Shader.PropertyToID("g_DebugValidate"), debugValidate ? 1 : 0);

        rayTracingShader.SetTexture(Shader.PropertyToID("g_Radiance"), rayTracingOutput);

        rayTracingShader.SetInt("g_WriteDenoiserGuides", useDenoiser ? 1 : 0);
        rayTracingShader.SetTexture("g_SurfaceGuide", useDenoiser ? surfaceGuide : rayTracingOutput);
        rayTracingShader.SetTexture("g_Diffuse", useDenoiser ? diffuseOutput : rayTracingOutput);
        rayTracingShader.SetTexture("g_Albedo", useDenoiser ? albedoGuide : rayTracingOutput);
        if(dummyNrdDepth==null)dummyNrdDepth=NrdReblur.Create(1,1,UnityEngine.Experimental.Rendering.GraphicsFormat.R32_SFloat,"Inactive NRD depth binding");
        rayTracingShader.SetTexture("g_NrdSpecular",useNrd?nrdSpecular:rayTracingOutput);
        rayTracingShader.SetTexture("g_NrdNormalRoughness",useNrd?nrdNormals:rayTracingOutput);
        rayTracingShader.SetTexture("g_NrdViewZ",useNrd?nrdViewZ:dummyNrdDepth);
        rayTracingShader.SetTexture("g_NrdSpecularFactor",useNrd?nrdSpecularFactor:rayTracingOutput);
        rayTracingShader.SetTexture("g_NrdMotion",useNrd?nrdMotion:rayTracingOutput);
        rayTracingShader.Dispatch("MainRayGenShader", (int)cameraWidth, (int)cameraHeight, 1, renderCamera);

        RenderTexture result = rayTracingOutput;

        if (useDenoiser && !useNrd)
        {
            if (cachedDenoiser != denoiserShader || denoiserKernel < 0)
            {
                cachedDenoiser = denoiserShader;
                denoiserKernel = denoiserShader.FindKernel("Atrous");
            }
            int kernel = denoiserKernel;
            result = diffuseOutput;
            denoiserShader.SetTexture(kernel, "_Albedo", albedoGuide);
            denoiserShader.SetTexture(kernel, "_RawDiffuse", diffuseOutput);
            denoiserShader.SetTexture(kernel, "_Radiance", rayTracingOutput);
            denoiserShader.SetTexture(kernel, "_Guide", surfaceGuide);
            denoiserShader.SetFloat("_Strength", Mathf.Max(0.1f, denoiserStrength));
            for (int i = 0; i < Mathf.Clamp(denoiserIterations, 1, 4); i++)
            {
                RenderTexture target = filterBuffers[i % 2];
                denoiserShader.SetInt("_Step", 1 << i);
                denoiserShader.SetInt("_FinalPass", i == Mathf.Clamp(denoiserIterations, 1, 4) - 1 ? 1 : 0);
                denoiserShader.SetTexture(kernel, "_Input", result);
                denoiserShader.SetTexture(kernel, "_Output", target);
                denoiserShader.Dispatch(kernel, ((int)cameraWidth + 7) / 8, ((int)cameraHeight + 7) / 8, 1);
                result = target;
            }
        }
        if(useNrd) {
            try {result=nrd.Run(renderCamera,rayTracingOutput,diffuseOutput,nrdSpecular,nrdNormals,nrdViewZ,nrdMotion,albedoGuide,nrdSpecularFactor,nrdMaxHistoryFrames,(int)lightingView);}
            catch(System.Exception error) {nrd.Fail(error);result=rayTracingOutput;Debug.LogWarning("NRD disabled; raw radiance this frame, spatial fallback next frame: "+error.Message,this);}
        }
        if(displayMaterial==null) {
            Shader shader=Resources.Load<Shader>("PathTracing/Display");
            if(shader!=null)displayMaterial=new Material(shader){hideFlags=HideFlags.HideAndDontSave};
        }
        if(displayMaterial!=null && !debugValidate && !debugSingleBounce) {
            displayMaterial.SetFloat("_ExposureEV",lightingView>=LightingView.NormalRoughness?0:exposureEV);displayMaterial.SetInt("_ToneMapping",lightingView>=LightingView.NormalRoughness?0:(int)toneMapping);
            Graphics.Blit(result,dest,displayMaterial);
        } else Graphics.Blit(result,dest);
    }
}

}

