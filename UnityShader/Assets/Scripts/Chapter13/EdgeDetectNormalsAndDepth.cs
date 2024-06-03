using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EdgeDetectNormalsAndDepth : PostEffectsBase
{
    public Shader edgeDetectShader;
    private Material edgeDetectMaterial = null;
    public Material material
    {
        get
        {
            edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
            return edgeDetectMaterial;
        }
    }

    // 在脚本中提供了调整边缘线强度描边颜色以及背景颜色的参数。
    // 同时添加了控制采样距离以及对深度和法线进行边缘检测时的灵敏度参数
    [Range(0.0f, 1.0f)]
    public float edgesOnly = 0.0f;

    public Color edgeColor = Color.black;

    public Color backgroundColor = Color.white;

    // sampleDistance用于控制对深度+法线纹理采样时，使用的采样距离。
    // 从视觉上来看，sampleDistance值越大，描边越宽。
    public float sampleDistance = 1.0f;

    // sensitivityDepth和sensitivityNormals将会影响当邻域的深度值或法线值相差多少时，会被认为存在一条边界。
    // 如果把灵敏度调得很大，那么可能即使是深度或法线上很小的变化也会形成一条边。
    public float sensitivityDepth = 1.0f;

    public float sensitivityNormals = 1.0f;

    void OnEnable()
    {
        // 由于本例需要获取摄像机的深度+法线纹理，我们在脚本的OnEnable函数中设置摄像机的相应状态：
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
    }

    // 在默认情况下，OnRenderImage函数会在所有的不透明和透明的Pass执行完毕后被调用，以便对场景中所有游戏对象都产生影响。
    // 但有时，我们希望在不透明的Pass（即渲染队列小于等于2500的Pass，内置的Background、Geometry和AlphaTest渲染队列均在此范围内）
    // 执行完毕后立即调用该函数，而不对透明物体（渲染队列为Transparent的Pass）产生影响.
    // 此时，我们可以在OnRenderImage函数前添加ImageEffectOpaque属性来实现这样的目的。
    // 在本例中，我们只希望对不透明物体进行描边，而不希望透明物体也被描边，因此需要添加该属性。
    [ImageEffectOpaque]
    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            material.SetFloat("_EdgeOnly", edgesOnly);
            material.SetColor("_EdgeColor", edgeColor);
            material.SetColor("_BackgroundColor", backgroundColor);
            material.SetFloat("_SampleDistance", sampleDistance);
            material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
