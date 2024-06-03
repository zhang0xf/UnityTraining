using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EdgeDetection : PostEffectsBase
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

    // 提供用于调整边缘线强度、描边颜色以及背景颜色的参数
    // 当edgesOnly值为0时，边缘将会叠加在原渲染图像上；当edgesOnly值为1时，则会只显示边缘，不显示原渲染图像。
    [Range(0.0f, 1.0f)]
    public float edgesOnly = 0.0f;

    public Color edgeColor = Color.black;

    public Color backgroundColor = Color.white;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        // 检查材质是否可用。如果可用，就把参数传递给材质，再调用Graphics.Blit进行处理；
        // 否则，直接把原图像显示到屏幕上，不做任何处理。
        if (material != null)
        {
            material.SetFloat("_EdgeOnly", edgesOnly);
            material.SetColor("_EdgeColor", edgeColor);
            material.SetColor("_BackgroundColor", backgroundColor);

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
