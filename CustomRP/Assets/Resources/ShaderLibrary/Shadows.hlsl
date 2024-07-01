#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3) // 如果3 * 3过滤器关键字启用
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare // 'Sampler state'可以通过在名字中添加特殊标识符被定义为内联形式.
SAMPLER_CMP(SHADOW_SAMPLER);

// SRP Batcher:注意与'GPU Instancing'的'per-Material'区分.
CBUFFER_START(_CustomShadows)
    int _CascadeCount;
	float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
    float4 _CascadeData[MAX_CASCADE_COUNT];
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
    float4 _ShadowAtlasSize;
    float4 _ShadowDistanceFade;
CBUFFER_END

struct DirectionalShadowData {
	float strength;
	int tileIndex;
    float normalBias; // light's existing Normal Bias.[来自于灯光的设置]
};

struct ShadowData {
	int cascadeIndex; // 级联索引是由每个片元(per fragment)决定的,而非light.
    float cascadeBlend; // 在级联剔除球之间添加一个过渡区域将前后两者混合在一起.
    float strength; // 超过了最大级联区域时,便没有合法的'shadow data',此时也不该采样阴影.(超过最大级联区域时,设置强度为0)
};

// 参数是:position in shadow texture space
float SampleDirectionalShadowAtlas (float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

float FilterDirectionalShadow (float3 positionSTS) {
	#if defined(DIRECTIONAL_FILTER_SETUP) // 启用过滤器时,需要多次采样.
        float weights[DIRECTIONAL_FILTER_SAMPLES];
        float2 positions[DIRECTIONAL_FILTER_SAMPLES];
        float4 size = _ShadowAtlasSize.yyxx;
        DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
        float shadow = 0;
        for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
            shadow += weights[i] * SampleDirectionalShadowAtlas(
                float3(positions[i].xy, positionSTS.z)
            );
        }
		return shadow;
	#else
		return SampleDirectionalShadowAtlas(positionSTS);
	#endif
}

// 采样阴影图集的结果决定有多少光到达表面(只考虑阴影),它的值是一个0～1的衰减因子.如果片元完全处于阴影中,采样会得到0;如果不在阴影中,采样会得到1;
float GetDirectionalShadowAttenuation (DirectionalShadowData directional, ShadowData global, Surface surfaceWS) {
	#if !defined(_RECEIVE_SHADOWS)
		return 1.0; // 不接收阴影.
	#endif
	// 延伸:Shader的分支语句是不高效的.(片元是并行的).
    if (directional.strength <= 0.0) { // 当阴影强度为0时,不需要采样阴影图集
		return 1.0;
	}
    // 沿着法线方向移动表面坐标(法线偏移'normal bias')[使light设置面板能调节'normalBias']
    float3 normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex].y);
    // position in shadow texture space
    float3 positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex],float4(surfaceWS.position + normalBias, 1.0)).xyz;
    float shadow = FilterDirectionalShadow(positionSTS);
    // 注意:虽然在剔除球之间过渡看上去效果很好,但是增加了采样时间.
    if (global.cascadeBlend < 1.0) { // 处在两个剔除球的过渡区域,需要去下一个级联采样,并在两个级联之间进行插值.以达到'Soft cascade transitions'.
		normalBias = surfaceWS.normal * (directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
		positionSTS = mul(_DirectionalShadowMatrices[directional.tileIndex + 1], float4(surfaceWS.position + normalBias, 1.0)).xyz;
		shadow = lerp(FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend);
	}
    return lerp(1.0, shadow, directional.strength); // 阴影的强度可以降低(不管是出于艺术目的,还是半透明阴影效果).当阴影强度降低到0时,应该不再受阴影影响,所以返回阴影衰减为1.
}

// fade公式
float FadedShadowStrength (float distance, float scale, float fade) {
	return saturate((1.0 - distance * scale) * fade);
}

ShadowData GetShadowData (Surface surfaceWS) {
	ShadowData data;
    data.cascadeBlend = 1.0;
    // 在最大距离处,直接'cutting off'阴影太过明显,使用线性'fade shadow'.
    data.strength = FadedShadowStrength(surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);
    int i;
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
            float fade = FadedShadowStrength(distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z);
			if (i == _CascadeCount - 1) { 
				data.strength *= fade; // 最后一级的级联将fade作为强度因子
			}
			else {
				data.cascadeBlend = fade; // 级联剔除球之间将fade用于混合.
			}
			break;
		}
	}
    
    if (i == _CascadeCount) {
		data.strength = 0.0;
	}
	#if defined(_CASCADE_BLEND_DITHER)
		else if (data.cascadeBlend < surfaceWS.dither) { // 如果不是最后一个级联,并且'blend value' < 'dither value'.
			i += 1; // jump to next.
		}
	#endif

	#if !defined(_CASCADE_BLEND_SOFT)
		data.cascadeBlend = 1.0;
	#endif

	data.cascadeIndex = i;
	return data;
}

#endif