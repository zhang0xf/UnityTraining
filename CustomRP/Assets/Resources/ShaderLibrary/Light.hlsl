#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4 // 最多支持4个平行光.

CBUFFER_START(_CustomLight)
    int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

// 为了计算光照,需要光线数据.
struct Light {
	float3 color;
	float3 direction; // 需要注意:光线的方向被定义为来自哪个方向,而非去向哪个方向.[例如:'float3(0.0, 1.0, 0.0)'表示光线的方向为从上往下].
};

int GetDirectionalLightCount () {
	return _DirectionalLightCount;
}

Light GetDirectionalLight (int index) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb; // 注意:'rgb'和'xyz'是语义上的别名,对于'Swizzling'操作来说,rgba和xyzw是等价的.
	light.direction = _DirectionalLightDirections[index].xyz;
	return light;
}

#endif