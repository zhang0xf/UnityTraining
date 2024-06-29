using UnityEngine;

// 在使用渲染管线批处理技术(SRP Batcher)加速多个相同Shader('material property'不同)的渲染速度时(另见'UnlitPass.hlsl'),
// 当每个Object都需要设置不同的'BaseColor Property',且Object很多时,需要手动创建很多Material.
// 这种情况下,我们应该能够设置每个Object的BaseColor,而不是为每个Object创建一个Material.
// 注意这个Component需要使用'GPU Instancing'并且禁用'SRP Batcher',因为'SRP Batcher'无法处理'per-object material properties'.
[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{
    [SerializeField] private Color baseColor = Color.white;
    [SerializeField, Range(0f, 1f)] private float cutoff = 0.5f;
    [SerializeField, Range(0f, 1f)] private float metallic = 0f;
    [SerializeField, Range(0f, 1f)] private float smoothness = 0.5f;

    private static MaterialPropertyBlock block;

    private readonly static int baseColorId = Shader.PropertyToID("_BaseColor");
    private readonly static int cutoffId = Shader.PropertyToID("_Cutoff");
    private readonly static int metallicId = Shader.PropertyToID("_Metallic");
    private readonly static int smoothnessId = Shader.PropertyToID("_Smoothness");

    void Awake()
    {
        OnValidate();
    }

    // Invoked in the Unity editor when the component is loaded or changed.
    void OnValidate()
    {
        block ??= new MaterialPropertyBlock();
        block.SetColor(baseColorId, baseColor);
        block.SetFloat(cutoffId, cutoff);
        block.SetFloat(metallicId, metallic);
        block.SetFloat(smoothnessId, smoothness);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }
}