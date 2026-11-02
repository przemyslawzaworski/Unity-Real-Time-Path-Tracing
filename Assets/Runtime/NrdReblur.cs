using System;
using System.Runtime.InteropServices;
using System.Text;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

namespace PortablePathTracing {
#pragma warning disable CS0649

sealed class NrdReblur : IDisposable {
    const string Library="NRD";
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern IntPtr PTNrdCreate();
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern void PTNrdDestroy(IntPtr p);
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern int PTNrdPipelineCount(IntPtr p);
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern int PTNrdPipeline(IntPtr p,int i,StringBuilder name,int size);
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern int PTNrdUpdate(IntPtr p,float[] projection,float[] previousProjection,float[] view,float[] previousView,int width,int height,int previousWidth,int previousHeight,int frame,int reset,float deltaMs,int historyFrames);
    [DllImport(Library,CallingConvention=CallingConvention.Cdecl)] static extern int PTNrdDispatch(IntPtr p,int i,out int pipeline,out int gx,out int gy,[Out] uint[] constants,int capacity,[Out] int[] resources,int resourceCapacity);
    [Serializable] public class Binding {public string name;[NonSerialized]public int id;}
    [Serializable] public class Pipeline {public string name,identifier;public bool hasConstants;public Binding[] resources;[NonSerialized]public ComputeShader shader;[NonSerialized]public int kernel;}
    [Serializable] public class Pool {public int format,downsample;}
    [Serializable] public class Manifest {public Pipeline[] pipelines;public Pool[] permanent,transient;public string[] resourceNames,formats;}
    readonly int width,height;
    readonly RenderTexture[] external=new RenderTexture[32];
    readonly uint[] constants=new uint[512];
    readonly int[] resources=new int[192];
    readonly float[] projectionData=new float[16],previousProjectionData=new float[16],viewData=new float[16],previousViewData=new float[16];
    readonly CommandBuffer commands=new CommandBuffer{name="NVIDIA NRD REBLUR diffuse + specular"};
    IntPtr planner;
    Manifest manifest;
    RenderTexture[] permanent,transient;
    RenderTexture diffuseResult,specularResult,result;
    ComputeBuffer constantBuffer;
    ComputeShader compose;
    Matrix4x4 previousProjection,previousView;
    Vector3 previousCameraPosition;
    Quaternion previousCameraRotation;
    float smoothedFrameTime=1f/60;
    bool reset=true,hasPrevious;
    uint frame;
    public bool Ready {get;private set;}
    public string Error {get;private set;}
    public Matrix4x4 PreviousViewProjection {get;private set;}
    public Matrix4x4 Projection {get;private set;}
    public Matrix4x4 View {get;private set;}



    public NrdReblur(int w,int h) {
        width=w;height=h;
        try {
            var json=Resources.Load<TextAsset>("PathTracing/NRD/Manifest");
            if(json==null)throw new InvalidOperationException("Missing NRD manifest");
            manifest=JsonUtility.FromJson<Manifest>(json.text);
            planner=PTNrdCreate();if(planner==IntPtr.Zero)throw new InvalidOperationException("NRD instance creation failed");
            if(PTNrdPipelineCount(planner)!=manifest.pipelines.Length)throw new InvalidOperationException("NRD DLL/shader manifest version mismatch");
            var name=new StringBuilder(1024);
            for(int i=0;i<manifest.pipelines.Length;i++) {
                var p=manifest.pipelines[i];PTNrdPipeline(planner,i,name,name.Capacity);
                if(name.ToString()!=p.identifier)throw new InvalidOperationException("NRD pipeline identifier mismatch");
                p.shader=Resources.Load<ComputeShader>("PathTracing/NRD/"+p.name);
                if(p.shader==null)throw new InvalidOperationException("Missing NRD compute shader "+p.name);
                p.kernel=p.shader.FindKernel("main");
                foreach(var b in p.resources)b.id=Shader.PropertyToID(b.name);
            }
            permanent=AllocatePool(manifest.permanent,"NRD history");transient=AllocatePool(manifest.transient,"NRD scratch");
            diffuseResult=Create(w,h,GraphicsFormat.R16G16B16A16_SFloat,"NRD diffuse result");
            specularResult=Create(w,h,GraphicsFormat.R16G16B16A16_SFloat,"NRD specular result");
            result=Create(w,h,GraphicsFormat.R32G32B32A32_SFloat,"NRD recombined radiance");
            constantBuffer=new ComputeBuffer(128,16,ComputeBufferType.Constant);
            compose=Resources.Load<ComputeShader>("PathTracing/NrdCompose");
            if(compose==null)throw new InvalidOperationException("Missing NRD composition shader");
            Ready=true;
        } catch(Exception e) {Error=e.Message;Dispose();}
    }
    public static RenderTexture Create(int w,int h,GraphicsFormat format,string name) {
        if(!SystemInfo.IsFormatSupported(format,GraphicsFormatUsage.LoadStore)) {
            if(format==GraphicsFormat.R16G16B16A16_SNorm)format=GraphicsFormat.R16G16B16A16_SFloat;
            else throw new NotSupportedException("UAV format unsupported: "+format);
        }
        var d=new RenderTextureDescriptor(w,h){graphicsFormat=format,depthBufferBits=0,msaaSamples=1,enableRandomWrite=true};
        var t=new RenderTexture(d){name=name,filterMode=FilterMode.Point,wrapMode=TextureWrapMode.Clamp};
        if(!t.Create())throw new InvalidOperationException("Failed to allocate "+name);return t;
    }
    RenderTexture[] AllocatePool(Pool[] descriptions,string name) {
        var list=new RenderTexture[descriptions.Length];
        try {
            for(int i=0;i<list.Length;i++) {
                var p=descriptions[i];var f=Format(manifest.formats[p.format]);
                list[i]=Create((width+p.downsample-1)/p.downsample,(height+p.downsample-1)/p.downsample,f,name+" "+i);
            }
        } catch {foreach(var t in list)Release(t);throw;}return list;
    }
    static GraphicsFormat Format(string s) {
        switch(s) {
            case "R8_UNORM":return GraphicsFormat.R8_UNorm;
            case "RG8_UNORM":return GraphicsFormat.R8G8_UNorm;
            case "R16_UINT":return GraphicsFormat.R16_UInt;
            case "R16_SFLOAT":return GraphicsFormat.R16_SFloat;
            case "RGBA16_SNORM":return GraphicsFormat.R16G16B16A16_SNorm;
            case "RGBA16_UINT":return GraphicsFormat.R16G16B16A16_UInt;
            case "RGBA16_SFLOAT":return GraphicsFormat.R16G16B16A16_SFloat;
            case "R32_SFLOAT":return GraphicsFormat.R32_SFloat;
            case "R32_UINT":return GraphicsFormat.R32_UInt;
            default:throw new NotSupportedException("NRD pool format "+s);
        }
    }
    public void ResetHistory(){reset=true;}
    public void Fail(Exception error){Error=error.Message;Dispose();}
    public void Prepare(Camera camera) {

        float f=1f/Mathf.Tan(camera.fieldOfView*Mathf.Deg2Rad*0.5f),n=camera.nearClipPlane,far=10000;
        Matrix4x4 p=new Matrix4x4();p[0,0]=f*height/width;p[1,1]=-f;p[2,2]=far/(far-n);p[2,3]=-n*far/(far-n);p[3,2]=1;
        Projection=p;View=camera.transform.worldToLocalMatrix;
        if(!hasPrevious){previousProjection=p;previousView=View;}
        if(hasPrevious && (Vector3.Distance(previousCameraPosition,camera.transform.position)>5 || Quaternion.Angle(previousCameraRotation,camera.transform.rotation)>45 || previousProjection!=p))reset=true;
        PreviousViewProjection=previousProjection*previousView;
    }
    static void MatrixData(Matrix4x4 m,float[] data){for(int col=0;col<4;col++)for(int row=0;row<4;row++)data[col*4+row]=m[row,col];}
    public RenderTexture Run(Camera camera,RenderTexture radiance,RenderTexture diffuse,RenderTexture specular,RenderTexture normals,RenderTexture viewZ,RenderTexture motion,RenderTexture diffuseFactor,RenderTexture specularFactor,int maximumFrames,int lightingView) {
        if(!Ready)return radiance;
        external[0]=motion;external[1]=normals;external[2]=viewZ;external[6]=diffuse;external[7]=specular;external[18]=diffuseResult;external[19]=specularResult;
        MatrixData(Projection,projectionData);MatrixData(previousProjection,previousProjectionData);MatrixData(View,viewData);MatrixData(previousView,previousViewData);
        float dt=Mathf.Clamp(Time.unscaledDeltaTime,0.001f,0.2f);smoothedFrameTime=Mathf.Lerp(smoothedFrameTime,dt,1-Mathf.Exp(-dt/0.2f));
        int frames=Mathf.Clamp(Mathf.RoundToInt(0.2f/smoothedFrameTime),1,maximumFrames);
        int dispatches=PTNrdUpdate(planner,projectionData,previousProjectionData,viewData,previousViewData,width,height,width,height,(int)frame,reset?1:0,dt*1000,frames);
        if(dispatches<0)throw new InvalidOperationException("NRD dispatch planning failed: "+dispatches);
        commands.Clear();
        commands.BeginSample("PPT NRD REBLUR");
        for(int i=0;i<dispatches;i++) {
            int count=PTNrdDispatch(planner,i,out int pipeline,out int gx,out int gy,constants,2048,resources,resources.Length);
            var p=manifest.pipelines[pipeline];if(count<0 || count!=p.resources.Length)throw new InvalidOperationException("NRD resource binding mismatch");
            if(p.hasConstants) {
                commands.SetBufferData(constantBuffer,constants);
                commands.SetComputeConstantBufferParam(p.shader,Shader.PropertyToID("_NRDConstants"),constantBuffer,0,2048);
            }
            for(int j=0;j<count;j++) {
                int type=resources[j*3+1],index=resources[j*3+2];
                RenderTexture t=type==30?transient[index]:type==31?permanent[index]:external[type];
                if(t==null)throw new InvalidOperationException("Unbound NRD resource "+manifest.resourceNames[type]);
                commands.SetComputeTextureParam(p.shader,p.kernel,p.resources[j].id,t);
            }
            commands.DispatchCompute(p.shader,p.kernel,gx,gy,1);
        }
        commands.EndSample("PPT NRD REBLUR");
        commands.BeginSample("PPT NRD Recombine");
        int k=compose.FindKernel("Compose");
        commands.SetComputeTextureParam(compose,k,"_Original",radiance);commands.SetComputeTextureParam(compose,k,"_RawDiffuse",diffuse);commands.SetComputeTextureParam(compose,k,"_RawSpecular",specular);
        commands.SetComputeTextureParam(compose,k,"_Diffuse",diffuseResult);commands.SetComputeTextureParam(compose,k,"_Specular",specularResult);
        commands.SetComputeTextureParam(compose,k,"_DiffuseFactor",diffuseFactor);commands.SetComputeTextureParam(compose,k,"_SpecularFactor",specularFactor);
        commands.SetComputeTextureParam(compose,k,"_NormalRoughness",normals);commands.SetComputeTextureParam(compose,k,"_ViewZ",viewZ);commands.SetComputeTextureParam(compose,k,"_Motion",motion);
        commands.SetComputeTextureParam(compose,k,"_Output",result);commands.SetComputeIntParam(compose,"_LightingView",lightingView);
        commands.DispatchCompute(compose,k,(width+7)/8,(height+7)/8,1);
        commands.EndSample("PPT NRD Recombine");
        Graphics.ExecuteCommandBuffer(commands);
        previousProjection=Projection;previousView=View;previousCameraPosition=camera.transform.position;previousCameraRotation=camera.transform.rotation;
        hasPrevious=true;reset=false;frame++;
        return result;
    }
    static void Release(RenderTexture t){if(t!=null){t.Release();UnityEngine.Object.Destroy(t);}}
    bool disposed;
    public void Dispose() {
        if(disposed)return;disposed=true;
        Ready=false;if(planner!=IntPtr.Zero){PTNrdDestroy(planner);planner=IntPtr.Zero;}
        if(permanent!=null)foreach(var t in permanent)Release(t);if(transient!=null)foreach(var t in transient)Release(t);
        permanent=null;transient=null;Release(diffuseResult);Release(specularResult);Release(result);
        if(constantBuffer!=null){constantBuffer.Release();constantBuffer=null;}
        commands.Release();
    }
}}
