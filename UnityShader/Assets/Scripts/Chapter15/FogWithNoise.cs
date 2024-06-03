using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FogWithNoise : PostEffectsBase
{
    public Shader fogShader;
    private Material fogMaterial = null;

    public Material material
    {
        get
        {
            fogMaterial = CheckShaderAndCreateMaterial(fogShader, fogMaterial);
            return fogMaterial;
        }
    }

    // 我们需要获取摄像机的相关参数，如近裁剪平面的距离、FOV等，同时还需要获取摄像机在世界空间下的前方、上方和右方等方向，
    // 因此我们用两个变量存储摄像机的Camera组件和Transform组件
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

    private Transform myCameraTransform;
    public Transform cameraTransform
    {
        get
        {
            if (myCameraTransform == null)
            {
                myCameraTransform = MyCamera.transform;
            }

            return myCameraTransform;
        }
    }

    [Range(0.1f, 3.0f)]
    public float fogDensity = 1.0f; // fogDensity用于控制雾的浓度

    public Color fogColor = Color.white; // fogColor用于控制雾的颜色

    public float fogStart = 0.0f; // 我们使用的雾效模拟函数是基于高度的，因此参数fogStart用于控制雾效的起始高度
    public float fogEnd = 2.0f; // fogEnd用于控制雾效的终止高度

    public Texture noiseTexture; // noiseTexture是我们使用的噪声纹理

    [Range(-0.5f, 0.5f)]
    public float fogXSpeed = 0.1f; // fogXSpeed和fogYSpeed分别对应了噪声纹理在X和Y方向上的移动速度，以此来模拟雾的飘动效果

    [Range(-0.5f, 0.5f)]
    public float fogYSpeed = 0.1f;

    [Range(0.0f, 3.0f)]
    public float noiseAmount = 1.0f; // noiseAmount用于控制噪声程度，当noiseAmount为0时，表示不应用任何噪声，即得到一个均匀的基于高度的全局雾效。

    void OnEnable()
    {
        // 由于本例需要获取摄像机的深度纹理，我们在脚本的OnEnable函数中设置摄像机的相应状态：
        GetComponent<Camera>().depthTextureMode |= DepthTextureMode.Depth;
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            // 利用13.3节学习的方法计算近裁剪平面的4个角对应的向量，并把它们存储在一个矩阵类型的变量（frustumCorners）中。
            Matrix4x4 frustumCorners = Matrix4x4.identity;

            float fov = MyCamera.fieldOfView;
            float near = MyCamera.nearClipPlane;
            float aspect = MyCamera.aspect;

            float halfHeight = near * Mathf.Tan(fov * 0.5f * Mathf.Deg2Rad);
            Vector3 toRight = cameraTransform.right * halfHeight * aspect;
            Vector3 toTop = cameraTransform.up * halfHeight;

            Vector3 topLeft = cameraTransform.forward * near + toTop - toRight;
            float scale = topLeft.magnitude / near;

            topLeft.Normalize();
            topLeft *= scale;

            Vector3 topRight = cameraTransform.forward * near + toRight + toTop;
            topRight.Normalize();
            topRight *= scale;

            Vector3 bottomLeft = cameraTransform.forward * near - toTop - toRight;
            bottomLeft.Normalize();
            bottomLeft *= scale;

            Vector3 bottomRight = cameraTransform.forward * near + toRight - toTop;
            bottomRight.Normalize();
            bottomRight *= scale;

            frustumCorners.SetRow(0, bottomLeft);
            frustumCorners.SetRow(1, bottomRight);
            frustumCorners.SetRow(2, topRight);
            frustumCorners.SetRow(3, topLeft);

            material.SetMatrix("_FrustumCornersRay", frustumCorners);

            material.SetFloat("_FogDensity", fogDensity);
            material.SetColor("_FogColor", fogColor);
            material.SetFloat("_FogStart", fogStart);
            material.SetFloat("_FogEnd", fogEnd);

            material.SetTexture("_NoiseTex", noiseTexture);
            material.SetFloat("_FogXSpeed", fogXSpeed);
            material.SetFloat("_FogYSpeed", fogYSpeed);
            material.SetFloat("_NoiseAmount", noiseAmount);

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
