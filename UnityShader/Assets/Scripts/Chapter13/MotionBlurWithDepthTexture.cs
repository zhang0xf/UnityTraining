using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MotionBlurWithDepthTexture : PostEffectsBase
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

    // 由于本节需要得到摄像机的视角和投影矩阵，我们需要定义一个Camera类型的变量，以获取该脚本所在的摄像机组件
    private Camera _MyCamera;
    public Camera MyCamera
    {
        get
        {
            if (_MyCamera == null)
            {
                _MyCamera = GetComponent<Camera>();
            }
            return _MyCamera;
        }
    }

    // 定义运动模糊时模糊图像使用的大小
    [Range(0.0f, 1.0f)]
    public float blurSize = 0.5f;

    // 我们还需要定义一个变量来保存上一帧摄像机的视角*投影矩阵
    private Matrix4x4 previousViewProjectionMatrix;

    void OnEnable()
    {
        // 由于本例需要获取摄像机的深度纹理，我们在脚本的OnEnable函数中设置摄像机的状态
        MyCamera.depthTextureMode |= DepthTextureMode.Depth;

        // 注意：摄像机会动，所以矩阵会变化
        previousViewProjectionMatrix = MyCamera.projectionMatrix * MyCamera.worldToCameraMatrix;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            // 我们首先需要计算和传递运动模糊使用的各个属性。
            // 本例需要使用两个变换矩阵:前一帧的视角*投影矩阵以及当前帧的视角*投影矩阵的逆矩阵。
            material.SetFloat("_BlurSize", blurSize);

            material.SetMatrix("_PreviousViewProjectionMatrix", previousViewProjectionMatrix);
            Matrix4x4 currentViewProjectionMatrix = MyCamera.projectionMatrix * MyCamera.worldToCameraMatrix;
            Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;
            material.SetMatrix("_CurrentViewProjectionInverseMatrix", currentViewProjectionInverseMatrix);
            previousViewProjectionMatrix = currentViewProjectionMatrix;

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
