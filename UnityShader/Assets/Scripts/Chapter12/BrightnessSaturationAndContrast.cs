using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BrightnessSaturationAndContrast : PostEffectsBase
{
    public Shader briSatConShader;
    private Material briSatConMaterial;
    public Material material
    {
        get
        {
            briSatConMaterial = CheckShaderAndCreateMaterial(briSatConShader, briSatConMaterial);
            return briSatConMaterial;
        }
    }

    // 提供了调整亮度、饱和度和对比度的参数
    [Range(0.0f, 3.0f)]
    public float brightness = 1.0f;

    [Range(0.0f, 3.0f)]
    public float saturation = 1.0f;

    [Range(0.0f, 3.0f)]
    public float contrast = 1.0f;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        // 检查材质是否可用。
        // 如果可用，就把参数传递给材质，再调用Graphics.Blit进行处理；
        // 否则，直接把原图像显示到屏幕上，不做任何处理。
        if (material != null)
        {
            material.SetFloat("_Brightness", brightness);
            material.SetFloat("_Saturation", saturation);
            material.SetFloat("_Contrast", contrast);

            // 调用Graphics.Blit函数使用特定的Unity Shader来对当前图像进行处理
            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
