using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MotionBlur : PostEffectsBase
{
    public Shader motionBlurShader;
    private Material motionBlurMaterial = null;

    public Material material
    {
        get
        {
            motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
            return motionBlurMaterial;
        }
    }

    // blurAmount的值越大，运动拖尾的效果就越明显，为了防止拖尾效果完全替代当前帧的渲染结果，我们把它的值截取在0.0～0.9范围内。

    [Range(0.0f, 0.9f)]
    public float blurAmount = 0.5f;

    // 定义一个RenderTexture类型的变量，保存之前图像叠加的结果
    private RenderTexture accumulationTexture;

    void OnDisable()
    {
        DestroyImmediate(accumulationTexture);
        // 我们在该脚本不运行时，即调用OnDisable函数时，立即销毁accumulation Texture。
        // 这是因为，我们希望在下一次开始应用运动模糊时重新叠加图像。
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            // 我们不仅判断它是否为空，还判断它是否与当前的屏幕分辨率相等，
            // 如果不满足，就说明我们需要重新创建一个适合于当前分辨率的accumulationTexture变量。
            // Create the accumulation texture
            if (accumulationTexture == null || accumulationTexture.width != src.width || accumulationTexture.height != src.height)
            {
                DestroyImmediate(accumulationTexture);
                accumulationTexture = new RenderTexture(src.width, src.height, 0);
                // 创建完毕后，由于我们会自己控制该变量的销毁，因此可以把它的hideFlags设置为HideFlags.HideAndDontSave，
                // 这意味着这个变量不会显示在Hierarchy中，也不会保存到场景中。
                accumulationTexture.hideFlags = HideFlags.HideAndDontSave;
                // 然后，我们使用当前的帧图像初始化accumulation Texture
                Graphics.Blit(src, accumulationTexture);
            }

            // 我们调用了accumulationTexture.Mark RestoreExpected函数来表明我们需要进行一个渲染纹理的恢复操作。
            // 恢复操作（restore operation）发生在渲染到纹理而该纹理又没有被提前清空或销毁的情况下。
            // We are accumulating motion over frames without clear/discard
            // by design, so silence any performance warnings from Unity
            // accumulationTexture.MarkRestoreExpected();

            material.SetFloat("_BlurAmount", 1.0f - blurAmount);

            // 我们每次调用OnRenderImage时都需要把当前的帧图像和accumulationTexture中的图像混合，
            // accumulationTexture纹理不需要提前清空，因为它保存了我们之前的混合结果。

            // 把当前的屏幕图像src叠加到accumulationTexture中。
            Graphics.Blit(src, accumulationTexture, material);
            // 把结果显示到屏幕上。
            Graphics.Blit(accumulationTexture, dest);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
