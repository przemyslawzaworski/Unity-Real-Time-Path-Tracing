using UnityEngine;
using UnityEngine.Rendering;

namespace PortablePathTracing
{
    [AddComponentMenu("")]
    public sealed class PathTracingBootstrap : MonoBehaviour
    {
        float nextCheck;
        bool warned;
        PortablePathTracingSettings settings;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        static void Install()
        {
            var configuration = Resources.Load<PortablePathTracingSettings>("PathTracing/Settings");
            if (configuration != null && !configuration.automaticallyAddToMainCamera) return;
            var root = new GameObject("Portable Path Tracing (automatic setup)");
            DontDestroyOnLoad(root);
            root.AddComponent<PathTracingBootstrap>().settings = configuration;
        }

        void Update()
        {
            if (Time.unscaledTime < nextCheck) return;
            nextCheck = Time.unscaledTime + 0.5f;
            if (settings != null && !settings.automaticallyAddToMainCamera) return;
            if (GraphicsSettings.currentRenderPipeline != null || !SystemInfo.supportsRayTracingShaders
                || SystemInfo.graphicsDeviceType != GraphicsDeviceType.Direct3D12)
            {
                if (!warned)
                {
                    Debug.LogWarning("Portable Path Tracing: automatic setup skipped; use Built-in RP and DX12 on a ray tracing GPU. The normal renderer remains active.");
                    warned = true;
                }
                return;
            }
            Camera camera = Camera.main;
            if (camera == null || !camera.isActiveAndEnabled || camera.orthographic || camera.stereoEnabled) return;

            if (camera.GetComponent<PathTracer>() != null) return;
            var tracer = camera.gameObject.AddComponent<PathTracer>();
            if (settings != null) settings.ApplyTo(tracer);
        }
    }
}
