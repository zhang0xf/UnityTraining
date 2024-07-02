#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

// 注意代码顺序:函数定义要在使用之前.

// 计算给定表面有多少入射光.
float3 IncomingLight (Surface surface, Light light) {
	// saturate:使点积(dot)的值位于0～1区间,因为点积为负时,代表光线从背面照射,此时不该有光照.
    return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color; 
}

// 计算光线和表面的最终光照.
float3 GetLighting (Surface surface, BRDF brdf, Light light) {
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

// 计算光照
float3 GetLighting (Surface surfaceWS, BRDF brdf, GI gi) {
	ShadowData shadowData = GetShadowData(surfaceWS);
    float3 color = gi.diffuse * brdf.diffuse;
	for (int i = 0; i < GetDirectionalLightCount(); i++) {
		Light light = GetDirectionalLight(i, surfaceWS, shadowData);
		color += GetLighting(surfaceWS, brdf, light); // 颜色相加
	}
	return color;
}

#endif