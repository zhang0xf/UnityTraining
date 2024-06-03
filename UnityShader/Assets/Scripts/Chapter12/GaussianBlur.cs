using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GaussianBlur : PostEffectsBase
{
    public Shader gaussianBlurShader;
    private Material gaussianBlurMaterial = null;

    public Material material
    {
        get
        {
            gaussianBlurMaterial = CheckShaderAndCreateMaterial(gaussianBlurShader, gaussianBlurMaterial);
            return gaussianBlurMaterial;
        }
    }

    // 提供了调整高斯模糊迭代次数、模糊范围和缩放系数的参数
    // blurSpread和downSample都是出于性能的考虑。
    // 在高斯核维数不变的情况下，_BlurSize越大，模糊程度越高，但采样数却不会受到影响。但过大的_BlurSize值会造成虚影，这可能并不是我们希望的。
    // 而downSample越大，需要处理的像素数越少，同时也能进一步提高模糊程度，但过大的downSample可能会使图像像素化。

    // Blur iterations - larger number means more blur.
    [Range(0, 4)]
    public int iterations = 3;

    // Blur spread for each iteration - larger value means more blur
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;

    [Range(1, 8)]
    public int downSample = 2;

    // 1st edition: just apply blur
    void OnRenderImage1(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            int rtW = src.width;
            int rtH = src.height;
            // 利用RenderTexture.GetTemporary函数分配了一块与屏幕图像大小相同的缓冲区。
            // 这是因为，高斯模糊需要调用两个Pass，我们需要使用一块中间缓存来存储第一个Pass执行完毕后得到的模糊结果。
            RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0);

            // Render the vertical pass
            // 使用Shader中的第一个Pass（即使用竖直方向的一维高斯核进行滤波）对src进行处理，并将结果存储在了buffer中。
            Graphics.Blit(src, buffer, material, 0);
            // Render the horizontal pass
            // 使用Shader中的第二个Pass（即使用水平方向的一维高斯核进行滤波）对buffer进行处理，返回最终的屏幕图像。
            Graphics.Blit(buffer, dest, material, 1);

            RenderTexture.ReleaseTemporary(buffer);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }

    // 在这个版本中，我们将利用缩放对图像进行降采样，从而减少需要处理的像素个数，提高性能。
    /// 2nd edition: scale the render texture
    void OnRenderImage2(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            // 我们在声明缓冲区的大小时，使用了小于原屏幕分辨率的尺寸，并将该临时渲染纹理的滤波模式设置为双线性。
            // 这样，在调用第一个Pass时，我们需要处理的像素个数就是原来的几分之一。
            // 对图像进行降采样不仅可以减少需要处理的像素个数，提高性能，而且适当的降采样往往还可以得到更好的模糊效果。
            // 尽管downSample值越大，性能越好，但过大的downSample可能会造成图像像素化。
            int rtW = src.width / downSample;
            int rtH = src.height / downSample;
            RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer.filterMode = FilterMode.Bilinear;

            // Render the vertical pass
            Graphics.Blit(src, buffer, material, 0);
            // Render the horizontal pass
            Graphics.Blit(buffer, dest, material, 1);

            RenderTexture.ReleaseTemporary(buffer);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }

    // 最后一个版本的代码还考虑了高斯模糊的迭代次数
    /// 3rd edition: use iterations for larger blur
	void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            int rtW = src.width / downSample;
            int rtH = src.height / downSample;

            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;

            // 代码显示了如何利用两个临时缓存在迭代之间进行交替的过程。
            // 我们首先定义了第一个缓存buffer0，并把src中的图像缩放后存储到buffer0中。
            Graphics.Blit(src, buffer0);

            for (int i = 0; i < iterations; i++)
            {
                material.SetFloat("_BlurSize", 1.0f + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // 在执行第一个Pass时，输入是buffer0，输出是buffer1，完毕后首先把buffer0释放，
                // 再把结果值buffer1存储到buffer0中，重新分配buffer1，然后再调用第二个Pass，重复上述过程。

                // Render the vertical pass
                Graphics.Blit(buffer0, buffer1, material, 0);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // Render the horizontal pass
                Graphics.Blit(buffer0, buffer1, material, 1);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }

            // 迭代完成后，buffer0将存储最终的图像，我们再利用Graphics.Blit(buffer0, dest)把结果显示到屏幕上，并释放缓存。
            Graphics.Blit(buffer0, dest);
            RenderTexture.ReleaseTemporary(buffer0);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
