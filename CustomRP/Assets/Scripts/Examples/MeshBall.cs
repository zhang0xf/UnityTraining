using UnityEngine;

public class MeshBall : MonoBehaviour
{
    [SerializeField] private Mesh mesh = default;
    [SerializeField] private Material material = default;

    private readonly Matrix4x4[] matrices = new Matrix4x4[1023];
    private readonly Vector4[] baseColors = new Vector4[1023];
    private MaterialPropertyBlock block;

    private readonly static int baseColorId = Shader.PropertyToID("_BaseColor");

    void Awake()
    {
        for (int i = 0; i < matrices.Length; i++)
        {
            Quaternion quaternion = Quaternion.Euler(Random.value * 360f, Random.value * 360f, Random.value * 360f);
            matrices[i] = Matrix4x4.TRS(Random.insideUnitSphere * 10f, quaternion, Vector3.one * Random.Range(0.5f, 1.5f));
            baseColors[i] = new Vector4(Random.value, Random.value, Random.value, Random.Range(0.5f, 1f));
        }
    }

    void Update()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray(baseColorId, baseColors);
        }
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block);
    }
}