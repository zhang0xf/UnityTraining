using UnityEngine;
using UnityEngine.Rendering;

public class Shadows
{
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex; // 产生阴影的的光线的索引.(场景中可能存在多个平行光)
        public float slopeScaleBias;
        public float nearPlaneOffset; // 横跨近裁剪面的大物体(shadow caster)产生的阴影会被扭曲,因为只有部分顶点受影响.解决方法是把近裁剪面往回拉一点.
    }

    private const string bufferName = "Shadows";
    private const int maxShadowedDirectionalLightCount = 4; // 渲染阴影会产生额外的开销导致降低帧率,需要限制能产生阴影的平行光的数量.
    private const int maxCascades = 4;
    private readonly CommandBuffer buffer;
    private ScriptableRenderContext context;
    private CullingResults cullingResults;
    private ShadowSettings settings;
    private readonly ShadowedDirectionalLight[] ShadowedDirectionalLights; // 所有会产生阴影的光线
    private int ShadowedDirectionalLightCount;

    private readonly static int dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"); // 平行光阴影图集.
    // 在阴影图集中采样深度信息时,需要根据一个世界空间(world space)坐标寻找其在阴影纹理(shadow texture)中的坐标,因此需要一个阴影转换矩阵.
    private readonly static int dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices");
    private readonly static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades]; // 每一个级联都需要转换矩阵
    private readonly static int cascadeCountId = Shader.PropertyToID("_CascadeCount");
    private readonly static int cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres");
    private readonly static int cascadeDataId = Shader.PropertyToID("_CascadeData");
    private readonly static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];
    private readonly static Vector4[] cascadeData = new Vector4[maxCascades];
    private readonly static int shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize");
    private readonly static int shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    private readonly static string[] directionalFilterKeywords = { // 添加3个关键字,为新的过滤器模式生成Shader变体.
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    private readonly static string[] cascadeBlendKeywords = { // 级联混合模式关键字,为当前模式生成Shader变体.
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

    // 为某个平行光在阴影图集(shadow atlas,另见:ShadowSettings中对图集的解释)中渲染'Shadow Map'预留空间,并存储一些用于渲染阴影的信息.
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

            // 对一个平行光进行阴影采样,需要知道在阴影图集(shadow atlas)中的'tile'索引.每个光线不同.
            return new Vector3(light.shadowStrength, settings.directional.cascadeCount * ShadowedDirectionalLightCount++, light.shadowNormalBias);
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
            // 不声明'Texture'在'WebGL 2.0'中会导致问题.所以在没有任何平行光需要渲染阴影时,声明一个大小为'1 * 1'的虚拟纹理来避免产生问题.
            buffer.GetTemporaryRT(dirShadowAtlasId, 1, 1, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        }
    }

    void RenderDirectionalShadows()
    {
        int atlasSize = (int)settings.directional.atlasSize;
        // 声明一个正方形的'Render Texture',深度缓冲区(depth buffer)的位数是32(越高越好),'Render Textures Type'选择'Shadowmap'(默认是一个通常的ARGB Texture).
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        // 渲染到上述声明的'Texture'中而非摄像机的buffer中,并且不关系'Texture'的初始状态(DontCare),因为会立刻clear.
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.ClearRenderTarget(true, false, Color.clear);
        buffer.BeginSample(bufferName);
        ExecuteBuffer();

        // 当支持不止一个平行光渲染阴影时(maxShadowedDirectionalLightCount > 1),多个光线的阴影渲染结果会在整个图集(entire atlas)上重叠,所以必须切分图集使得每个平行光在图集上都有一个独立的'tile'区域去渲染其结果.
        // 当使用级联阴影时,每一个平行光的'tile'区域又必须切分为4个(级联阴影数量)小'tile',来存储不同分辨率的'Shadow Map'.(再根据距离使用细节程度不同的Map)
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
        buffer.SetGlobalVector(shadowDistanceFadeId, new Vector4(1f / settings.maxDistance, 1f / settings.distanceFade, 1f / (1f - f * f)));
        SetKeywords(directionalFilterKeywords, (int)settings.directional.filter - 1); // 在'buffer'上设置关键字.
        SetKeywords(cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1);
        buffer.SetGlobalVector(shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize));
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index, int split, int tileSize)
    {
        ShadowedDirectionalLight light = ShadowedDirectionalLights[index];
        // 因为正在为平行光渲染阴影,所有使用正交模式(Orthographic).
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex, BatchCullingProjectionType.Orthographic);
        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;
        float cullingFactor = Mathf.Max(0f, 0.8f - settings.directional.cascadeFade); // 需要确保在级联过渡区域的'shadow caster'不会被剔除.

        for (int i = 0; i < cascadeCount; i++)
        {
            // 由于平行光无限远,没有位置信息,而渲染阴影需要一个有限的区域.
            // 因此需要找到一个立方体裁剪空间,该空间是光线空间与摄像机可视的并且能够产生阴影的区域相重叠的空间.函数的传出参数是需要的转换矩阵.
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, light.nearPlaneOffset,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            // 使用级联阴影的一个弊端是:对于同一个light,需要渲染相同的‘shadow caster’多次.
            // 剔除:在更大的级联(larger cascades)中剔除一些'shadow caster',只要确保它们的结果始终被小的级联(smaller cascade)覆盖.
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            shadowSettings.splitData = splitData;
            if (index == 0) // 只存储第一个平行光的'Culling Spheres',因为'Culling Spheres'与光线方向是无关的,即所有光线均相同.
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
            }
            int tileIndex = tileOffset + i;
            var offset = SetTileViewport(tileIndex, split, tileSize); // 为每个平行光(的每个级联区域)切分出单独的'tile'区域.
            // 从世界空间(world space)转换到光线空间(light space)的矩阵,并且需要考虑到'tile'在图集中的偏移.(每个级联区域都需要一个矩阵)
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(projectionMatrix * viewMatrix, offset, split);
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix); // 在buffer上应用视图和投影矩阵.
            // 自阴影(self-shadowing):越与光线平行的地方,自阴影越严重.一个简单的解决方法是在'shadow-caster'的深度(depth)上,添加一个常量偏移(bias).将他们推离光线.
            // 'bias'越大,自阴影越不明显,但是随着bias的增大,阴影也会随之偏移,造成一种'视觉伪影'的现象.此时需要使用斜率偏差(slope-scale bias).
            // 这两种方式都是凭直觉的,需要一定的经验才能得到较好的结果.
            // 更直观的方法是使用'Normal bias':在采样阴影时,膨胀'shadow caster'物体的表面,然后从离表面远一点的地方进行采样,以避免不正确的自阴影.
            // 'normal bias'太高也会导致显示问题:阴影相对于物体来说比较窄.
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
        // Normal bias equal to texel size.这是一个效果比较好的法线偏移值.(来自经验?)
        float texelSize = 2f * cullingSphere.w / tileSize;
        // 增加过滤器的'filter size'会使阴影变得柔和,但也会导致自阴影的条纹重新出现,需要相应的增加'normal bias'.
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);
        // 增加过滤器采样区域(sample region)意味着可能在级联剔除球之外进行采样,可以通过将半径减小来避免球外采样.
        cullingSphere.w -= filterSize;
        // Shader需要检查一个片元是否在某个级联'Culling Spheres'中,检查方法便是比较某处距球中心的距离的平方与球半径的平方,所以预计算半径的平方值传入Shader.
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;
        cascadeData[index] = new Vector4(1f / cullingSphere.w, filterSize * 1.4142136f); // 1.4142136f = 根号2. texels是正方形,最坏情况是沿着对角线偏移.
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
        // 裁剪空间的坐标区间为:-1 ~ 1,而纹理坐标及深度的范围是:0 ~ 1,需要进行坐标转换,并且还需要应用'offset'和'scale'.
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
