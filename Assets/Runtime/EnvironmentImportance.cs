using System;
using UnityEngine;
using UnityEngine.Rendering;
namespace PortablePathTracing {
sealed class EnvironmentImportance : IDisposable {
    readonly ComputeShader builder;
    readonly GraphicsBuffer conditional = new GraphicsBuffer(GraphicsBuffer.Target.Structured,256*128,4);
    readonly GraphicsBuffer marginal = new GraphicsBuffer(GraphicsBuffer.Target.Structured,128,4);
    readonly GraphicsBuffer weights = new GraphicsBuffer(GraphicsBuffer.Target.Structured,256*128,4);
    Texture previous;
    public EnvironmentImportance() { builder=Resources.Load<ComputeShader>("PathTracing/EnvironmentDistribution"); }
    public bool Bind(Texture environment,RayTracingShader rays,bool refresh) {
        if(builder==null)return false;
        if(previous!=environment || refresh) {
            int rows=builder.FindKernel("BuildRows"),total=builder.FindKernel("BuildMarginal");
            builder.SetTexture(rows,"_Environment",environment);
            builder.SetBuffer(rows,"_Conditional",conditional);builder.SetBuffer(rows,"_Marginal",marginal);builder.SetBuffer(rows,"_Weights",weights);
            builder.Dispatch(rows,128,1,1);builder.SetBuffer(total,"_Marginal",marginal);builder.Dispatch(total,1,1,1);previous=environment;
        }
        Shader.SetGlobalBuffer("g_EnvConditional",conditional);Shader.SetGlobalBuffer("g_EnvMarginal",marginal);Shader.SetGlobalBuffer("g_EnvWeights",weights);
        rays.SetBuffer("g_EnvConditional",conditional);rays.SetBuffer("g_EnvMarginal",marginal);rays.SetBuffer("g_EnvWeights",weights);
        return true;
    }
    public void Dispose(){conditional.Dispose();marginal.Dispose();weights.Dispose();}
}}
