using UnityEngine;

// 渲染阴影的其中一个方式:生成阴影贴图(Shadow Map)来存储从光线起点到达表面所经过的距离.
// 同一光线方向上,所有比这个距离更远的物体都不能被照亮.

[System.Serializable]
public class ShadowSettings
{
    public enum MapSize
    {
        _256 = 256,
        _512 = 512,
        _1024 = 1024,
        _2048 = 2048,
        _4096 = 4096,
        _8192 = 8192
    }

    // 过滤阴影贴图的方式:更大的过滤器使阴影更柔和,更少锯齿.
    public enum FilterMode
    {
        PCF2x2,
        PCF3x3,
        PCF5x5,
        PCF7x7
    }

    [System.Serializable]
    public struct Directional
    {
        public enum CascadeBlendMode
        {
            Hard,
            Soft,
            Dither
        }

        public MapSize atlasSize; // 图集大小(使用一个纹理来存储多个阴影贴图).

        [Range(1, 4)]
        public int cascadeCount;

        [Range(0f, 1f)]
        public float cascadeRatio1, cascadeRatio2, cascadeRatio3; // 前3个级联区域比率可配置,最后一个总是覆盖最大区域.

        public readonly Vector3 CascadeRatios => new Vector3(cascadeRatio1, cascadeRatio2, cascadeRatio3);

        [Range(0.001f, 1f)]
        public float cascadeFade;

        public FilterMode filter;

        // 从一个级联剔除球采样,再辅以一个抖动模式,来模拟在两个级联球采样并插值的操作.对比两次采样开销更小.
        public CascadeBlendMode cascadeBlend;
    }

    public Directional directional = new Directional
    {
        atlasSize = MapSize._1024,
        filter = FilterMode.PCF2x2,
        cascadeCount = 4,
        cascadeRatio1 = 0.1f,
        cascadeRatio2 = 0.25f,
        cascadeRatio3 = 0.5f,
        cascadeFade = 0.1f,
        cascadeBlend = Directional.CascadeBlendMode.Hard
    };

    // 如果为很远的物体渲染阴影,那么会需要更多的绘制以及一个非常大的贴图来充分地覆盖区域,这通常不不切实际的.
    [Min(0.001f)]
    public float maxDistance = 100f; // 最大阴影距离

    [Range(0.001f, 1f)]
    public float distanceFade = 0.1f;
}