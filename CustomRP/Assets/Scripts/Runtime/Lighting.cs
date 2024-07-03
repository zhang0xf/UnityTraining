using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{
    private const string bufferName = "Lighting";
    private const int maxDirLightCount = 4; // 最多支持4个平行光

    private readonly CommandBuffer buffer;
    private CullingResults cullingResults;
    private readonly Shadows shadows;

    private readonly static int dirLightCountId = Shader.PropertyToID("_DirectionalLightCount");
    private readonly static int dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors");
    private readonly static int dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections");
    private readonly static int dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");

    private readonly static Vector4[] dirLightColors = new Vector4[maxDirLightCount];
    private readonly static Vector4[] dirLightDirections = new Vector4[maxDirLightCount];
    private readonly static Vector4[] dirLightShadowData = new Vector4[maxDirLightCount];

    public Lighting()
    {
        buffer = new CommandBuffer
        {
            name = bufferName
        };

        shadows = new Shadows();
    }

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings shadowSettings)
    {
        this.cullingResults = cullingResults;
        buffer.BeginSample(bufferName);
        shadows.Setup(context, cullingResults, shadowSettings);
        SetupLights();
        shadows.Render();
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    void SetupLights()
    {
        // NativeArray:在'managed C# code'和'native Unity engine code'之间高效率地分享数据.
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
        buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }

    void SetupDirectionalLight(int index, ref VisibleLight visibleLight)
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2); // 矩阵的第3列
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }

    public void Cleanup()
    {
        shadows.Cleanup();
    }
}