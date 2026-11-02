using UnityEngine;

namespace PortablePathTracing
{
    [CreateAssetMenu(menuName = "Rendering/Portable Path Tracing Settings")]
    public sealed class PortablePathTracingSettings : ScriptableObject
    {
        [Tooltip("Automatically attach to the enabled perspective camera tagged MainCamera during play.")]
        public bool automaticallyAddToMainCamera = true;
        [Range(1,128)] public int samplesPerFrame = 8;
        [Range(0.25f,1f)] public float renderScale = 1.0f;
        public bool denoise = true;
        [Range(1,4)] public int denoiserIterations = 2;
        [Range(0.1f,10f)] public float denoiserStrength = 2f;
        [Range(1,100)] public uint opaqueBounces = 5;
        [Range(1,100)] public uint glassBounces = 8;
        [Min(0)] public float environmentIntensity = 1f;
        public Cubemap environmentOverride;
        public bool environmentNEE=false;
        [Range(-12,12)]public float exposureEV=3;
        public PathTracer.ToneMapping toneMapping=PathTracer.ToneMapping.AcesFitted;
        public PathTracer.DenoiserMode denoiserMode=PathTracer.DenoiserMode.NrdReblur;
        [Range(1,63)]public int nrdMaxHistoryFrames=32;

        public void ApplyTo(PathTracer tracer)
        {
            tracer.samplesPerFrame = samplesPerFrame;
            tracer.renderScale = renderScale;
            tracer.denoise = denoise;
            tracer.denoiserIterations = denoiserIterations;
            tracer.denoiserStrength = denoiserStrength;
            tracer.bounceCountOpaque = opaqueBounces;
            tracer.bounceCountTransparent = glassBounces;
            tracer.environmentIntensity = environmentIntensity;
            tracer.envTexture = environmentOverride;
            tracer.environmentNEE=environmentNEE;tracer.exposureEV=exposureEV;tracer.toneMapping=toneMapping;
            tracer.denoiserMode=denoiserMode;tracer.nrdMaxHistoryFrames=nrdMaxHistoryFrames;
        }
    }
}
