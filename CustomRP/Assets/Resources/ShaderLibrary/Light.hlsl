#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4 // 最多支持4个平行光.

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

// 为了计算光照,需要光线数据.
struct Light {
	float3 color;
	float3 direction; // 需要注意:光线的方向被定义为来自哪个方向,而非去向哪个方向.[例如:'float3(0.0, 1.0, 0.0)'表示光线的方向为从上往下].
	float attenuation;
};

int GetDirectionalLightCount () {
	return _DirectionalLightCount;
}

DirectionalShadowData GetDirectionalShadowData (int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	data.strength = _DirectionalLightShadowData[lightIndex].x * shadowData.strength;
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex; // 在平行光的大'tile'中选择正确的级联小'tile'.
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	return data;
}

Light GetDirectionalLight (int index, Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb; // 注意:'rgb'和'xyz'是语义上的别名,对于'Swizzling'操作来说,rgba和xyzw是等价的.
	light.direction = _DirectionalLightDirections[index].xyz;
	DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
	light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
	// light.attenuation = shadowData.cascadeIndex * 0.25; // 此段代码用于测试级联区域[移动摄像机观察变化]
	return light;
}

#endif