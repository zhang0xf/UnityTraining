using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    private const string bufferName = "Render Camera"; // 在frame debugger工具中显示

    private ScriptableRenderContext context;
    private Camera camera;
    private readonly CommandBuffer buffer;
    private CullingResults cullingResults;
    private readonly Lighting lighting;

    private static ShaderTagId unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"); // SRPDefaultUnlit pass(SRP默认渲染通道)
    private static ShaderTagId litShaderTagId = new ShaderTagId("CustomLit"); // CustomLit pass(渲染通道)
    public CameraRenderer()
    {
        buffer = new CommandBuffer
        {
            name = bufferName
        };

        lighting = new Lighting();
    }

    public void Render(ScriptableRenderContext context, Camera camera, bool useDynamicBatching, bool useGPUInstancing)
    {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();
        PrepareForSceneWindow();

        if (!Cull()) return;

        // 传递当前摄像机的属性.
        // 例如:视图投影矩阵(view-projection matrix) = 视图矩阵(view matrix) * 投影矩阵(projection matrix).
        // 视图矩阵(view matrix)负责将几何图形转换到摄像机空间,
        // 投影矩阵(projection matrix)负责透视投影(perspective projection)或正交投影(orthographic projection).
        // 延伸:几何图元经过透视投影矩阵之后转换到齐次裁剪空间(homogeneous clip space)[视锥体形状],
        // 在齐次裁剪空间的基础上进行透视除法(perspective division)或称齐次除法(homogeneous division)可以得到归一化的设备坐标空间(NDC)[立方体形状],
        // 在NDC空间的基础上映射到屏幕空间[二维空间],并结合深度缓冲进行片元着色.
        // 延伸:顶点着色器(vertex shader)的输出在齐次裁剪空间,即positionCS.
        // 片元着色器(fragment shader)的输入来自屏幕空间,齐次裁剪空间-NDC空间-屏幕空间的转换是由底层自动完成.
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth, flags <= CameraClearFlags.Color,
            flags == CameraClearFlags.Color ? camera.backgroundColor.linear : Color.clear);
        buffer.BeginSample(SampleName); // 优化调试
        ExecuteBuffer();

        lighting.Setup(context, cullingResults);

        DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);
        DrawUnsupportedShaders();
        DrawGizmos();

        buffer.EndSample(SampleName);
        ExecuteBuffer();
        context.Submit();
    }

    private void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    private void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        // 渲染不透明(opaque)
        var sortingSettings = new SortingSettings(camera);
        sortingSettings.criteria = SortingCriteria.CommonOpaque;
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings);
        drawingSettings.enableDynamicBatching = useDynamicBatching;
        drawingSettings.enableInstancing = useGPUInstancing;
        drawingSettings.SetShaderPassName(1, litShaderTagId); // 添加渲染通道
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        // 渲染天空盒子
        context.DrawSkybox(camera);

        // 渲染透明(transparent)[不写入深度缓冲]
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    private bool Cull()
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }
}