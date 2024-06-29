using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    private const string bufferName = "Lighting";
    private const int maxDirLightCount = 4; // 最多支持4个平行光

    private readonly CommandBuffer buffer;
    private CullingResults cullingResults;

    private readonly static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount");
    private readonly static int dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors");
    private readonly static int dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");

    private readonly static Vector4[] dirLightColors = new Vector4[maxDirLightCount];
    private readonly static Vector4[] dirLightDirections = new Vector4[maxDirLightCount];

    public Lighting()
    {
        buffer = new CommandBuffer
        {
            name = bufferName
        };
    }

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults)
    {
        this.cullingResults = cullingResults;
        buffer.BeginSample(bufferName);
        SetupLights();
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void SetupLights()
    {
        // NativeArray:可以访问'native memory buffer',在'managed C# code'和'native Unity engine code'之间高效率地分享数据.
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;

        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                if (dirLightCount >= maxDirLightCount) break;
            }
        }

        buffer.SetGlobalInt(dirLightCountId, visibleLights.Length); // 发送到GPU
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
    }

    void SetupDirectionalLight(int index, ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2); // 矩阵的第3列
    }
}