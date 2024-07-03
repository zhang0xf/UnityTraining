using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline
{
    private readonly CameraRenderer renderer;
    private readonly bool useDynamicBatching;
    private readonly bool useGPUInstancing;
    private readonly ShadowSettings shadowSettings;

    public CustomRenderPipeline(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher, ShadowSettings shadowSettings)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.shadowSettings = shadowSettings;
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        GraphicsSettings.lightsUseLinearIntensity = true;
        renderer = new CameraRenderer();
    }


    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {

    }

    protected override void Render(ScriptableRenderContext context, List<Camera> cameras)
    {
        for (int i = 0; i < cameras.Count; i++)
        {
            // 支持每个摄像机使用不同的渲染方法,
            // 例如:一个相机负责第一人称视角,另一个相机负责3D地图;
            // 例如:一个相机使用forward rendering,另一个相机使用deferred rendering.
            renderer.Render(context, cameras[i], useDynamicBatching, useGPUInstancing, shadowSettings);
        }
    }
}