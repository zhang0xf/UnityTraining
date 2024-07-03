using UnityEngine;
using UnityEngine.Rendering;

public class Shadows
{
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex; // 光线的索引.
        public float slopeScaleBias; // 斜率偏差(解决视觉伪影现象)
        public float nearPlaneOffset; // 近裁剪面偏移(处理横跨近裁剪面的大型物体)
    }

    private const string bufferName = "Shadows";
    // 渲染阴影会产生额外的开销导致降低帧率,需要限制产生阴影的平行光的数量.
    private const int maxShadowedDirectionalLightCount = 4;
    private const int maxCascades = 4;
    private readonly CommandBuffer buffer;
    private ScriptableRenderContext context;
    private CullingResults cullingResults;
    private ShadowSettings settings;
    private readonly ShadowedDirectionalLight[] ShadowedDirectionalLights;
    private int ShadowedDirectionalLightCount;

    // 所有阴影贴图渲染到同一个阴影图集.
    private readonly static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas");
    // 在阴影图集中采样深度信息,需要将世界空间的坐标转换到阴影图集坐标.
    private readonly static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    private readonly static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades]; // 每一个级联都需要转换矩阵
    private readonly static int cascadeCountId = Shader.PropertyToID("_CascadeCount");
    private readonly static int cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    private readonly static int cascadeDataId = Shader.PropertyToID("_CascadeData");
    private readonly static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];
    private readonly static Vector4[] cascadeData = new Vector4[maxCascades];
    private readonly static int shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize");
    private readonly static int shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    private readonly static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3", // 关键字
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    private readonly static string[] cascadeBlendKeywords = {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    public Shadows()
    {
        buffer = new CommandBuffer
        {
            name = bufferName
        };

        ShadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];
    }

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings settings)
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;

        ShadowedDirectionalLightCount = 0;
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    // 为某个平行光在阴影图集中渲染阴影贴图预留空间,并存储一些用于渲染阴影的信息.
    public Vector3 ReserveDirectionalShadows(Light light, int visibleLightIndex)
    {
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount &&
            light.shadows != LightShadows.None && light.shadowStrength > 0f &&
            cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            ShadowedDirectionalLights[ShadowedDirectionalLightCount] = new ShadowedDirectionalLight
            {
                visibleLightIndex = visibleLightIndex,
                slopeScaleBias = light.shadowBias,
                nearPlaneOffset = light.shadowNearPlane
            };

            return new Vector3(
                light.shadowStrength,
                settings.directional.cascadeCount * ShadowedDirectionalLightCount++,
                light.shadowNormalBias
            );
        }
        return Vector3.zero;
    }

    public void Render()
    {
        if (ShadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
        else
        {
            // 在没有任何平行光需要渲染阴影时,如果不声明'Texture'那么在'WebGL 2.0'中会导致问题.
            // 所以声明一个大小为'1 * 1'的虚拟纹理来避免产生问题.
            buffer.GetTemporaryRT(dirShadowAtlasId, 1, 1, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        }
    }

    void RenderDirectionalShadows()
    {
        int atlasSize = (int)settings.directional.atlasSize;
        // 声明一个正方形的'Render Texture',深度缓冲区的位数是32(越高越好),类型选择'Shadowmap'(默认是一个'ARGB Texture').
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        // 渲染到上述声明的'Render Texture'中而非摄像机的缓冲中.
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.ClearRenderTarget(true, false, Color.clear);
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        // 当渲染多个平行光阴影贴图时,渲染结果会在整个阴影图集上重叠,所以需要在图集上为每个阴影贴图切分出一个单独的区域.
        // 当使用阴影级联技术时,需要在每个平行光所占区域内,进一步为每个级联切分出单独渲染区域.
        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        for (int i = 0; i < ShadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }

        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount); // 发送到GPU.
        buffer.SetGlobalVectorArray(cascadeCullingSpheresId, cascadeCullingSpheres);
        buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(
            shadowDistanceFadeId,
            new Vector4(
                1f / settings.maxDistance,
                1f / settings.distanceFade,
                1f / (1f - f * f)
            )
        );
        SetKeywords(directionalFilterKeywords, (int)settings.directional.filter - 1); // 设置关键字.
        SetKeywords(cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1);
        buffer.SetGlobalVector(shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize));
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        ShadowedDirectionalLight light = ShadowedDirectionalLights[index];
        // 因为正在为平行光渲染阴影,所有使用正交模式(Orthographic).
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex,
            BatchCullingProjectionType.Orthographic);
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;
        // 需要确保在级联过渡区域内,'shadow caster'不会被剔除.
        float cullingFactor = Mathf.Max(0f, 0.8f - settings.directional.cascadeFade);

        for (int i = 0; i < cascadeCount; i++)
        {
            // 由于平行光无限远,没有位置信息,而渲染阴影需要一个有限的区域.
            // 因此需要找到一个立方体裁剪空间(转换矩阵),该空间是光线空间与摄像机产生阴影的区域相重叠的空间.
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, light.nearPlaneOffset,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            // 使用级联阴影的一个弊端是:对于同一个光线,需要渲染相同的‘shadow caster’多次.
            // 针对弊端的优化:在更大的级联中只要确保'shadow caster'的结果一定被小的级联覆盖,则可以剔除这些'shadow caster'.
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            shadowSettings.splitData = splitData;
            if (index == 0) // 级联剔除球与光线方向无关.即所有光线均相同.
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            int tileIndex = tileOffset + i;
            var offset = SetTileViewport(tileIndex, split, tileSize); // 切分图集.
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix, offset, split);
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
            // 自阴影(self-shadowing)的解决方案:
            // 1.常量偏移(Bias). 设置太高会将阴影推离物体,造成一种'视觉伪影'现象.
            // 2.斜率偏差(Slope Scale Bias).
            // 3.法线偏移(Normal Bias). 设置太高会导致阴影相对物体来说较窄.
            // buffer.SetGlobalDepthBias(500000f, 0f);
            buffer.SetGlobalDepthBias(0f, light.slopeScaleBias);
            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
            buffer.SetGlobalDepthBias(0f, 0f);
        }
    }

    void SetKeywords(string[] keywords, int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                buffer.DisableShaderKeyword(keywords[i]);
            }
        }
    }

    void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        float texelSize = 2f * cullingSphere.w / tileSize; // 法线偏移值(normal bias).
        // 增加过滤器采样区域可以使阴影变柔和,但也会导致自阴影的条纹重新出现,需要相应的增加法线偏移.
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);
        // 增加过滤器采样区域意味着可能在级联剔除球之外进行采样,可以通过将半径减小来避免球外采样.
        cullingSphere.w -= filterSize;
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;
        cascadeData[index] = new Vector4(1f / cullingSphere.w, filterSize * 1.4142136f); // 1.4142136f = 根号2.
    }

    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);
        buffer.SetViewport(new Rect(offset.x * tileSize, offset.y * tileSize, tileSize, tileSize));
        return offset;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        // Z buffer(Z缓冲区)反转.
        // 由于缓冲区精度以及非线性存储的特性,反转存储Z缓冲区可以更好地利用bit.
        // 正常情况下0代表深度为0,1代表最大深度.这也是OpenGL所使用的方式.
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }

        float scale = 1f / split;
        // 裁剪空间的坐标区间为:-1 ~ 1,而纹理坐标及深度的范围是:0 ~ 1,需要进行坐标转换.
        // 并且还需要应用'offset'和'scale'.
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);

        return m;
    }

    public void Cleanup()
    {
        buffer.ReleaseTemporaryRT(dirShadowAtlasId); // release temporary render texture.
        ExecuteBuffer();
    }
}
