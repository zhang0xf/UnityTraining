using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline
{
    private readonly CameraRenderer renderer;
    private bool useDynamicBatching;
    private bool useGPUInstancing;

    public CustomRenderPipeline(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        // 当Shader兼容(Compatible)渲染管线批处理(SRP Batcher)时,开启SRP Batching才有效果.[Shader是否兼容批处理可由Shader的Inspector面板查看]
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true; // 光线颜色转换到线性空间(linear space)
        renderer = new CameraRenderer();
    }


    protected override void Render(ScriptableRenderContext context, Camera[] cameras) { }

    protected override void Render(ScriptableRenderContext context, List<Camera> cameras)
    {
        for (int i = 0; i < cameras.Count; i++)
        {
            // 支持每个摄像机使用不同的渲染方法,
            // 例如:一个相机负责第一人称视角,另一个相机负责3D地图;
            // 例如:一个相机使用forward rendering,另一个相机使用deferred rendering.
            renderer.Render(context, cameras[i], useDynamicBatching, useGPUInstancing);
        }
    }
}