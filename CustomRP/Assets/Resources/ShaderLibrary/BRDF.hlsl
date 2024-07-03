#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

// Bidirectional Reflectance Distribution Function

#define MIN_REFLECTIVITY 0.04 // 非金属也有反射率,平均约为0.04,也会产生高光.

// 计算双向反射率分布函数需要的表面属性.
struct BRDF {
	float3 diffuse; 
	float3 specular;
	float roughness;
};

float OneMinusReflectivity (float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY; 
	return range - metallic * range; // 将金属度解释为反射率(通常高光金属会反射所有光而不会产生漫反射).
}

BRDF GetBRDF (Surface surface, bool applyAlphaToDiffuse = false) {
	BRDF brdf;
    float oneMinusReflectivity = OneMinusReflectivity(surface.metallic); 
	brdf.diffuse = surface.color * oneMinusReflectivity;
    if (applyAlphaToDiffuse) { // 渲染透明材质时否应用透明度来渐隐漫反射.
		brdf.diffuse *= surface.alpha; // 漫反射随Alpha值消散.(设置'blend One OneMinusSrcAlph'以保证高光不随Alpha值消散)
	}
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);
    float perceptualRoughness =	PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	return brdf;
}

// 高光反射的强度取决于完美反射角度与摄像机观察角度之间的匹配程度.
float SpecularStrength (Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

float3 DirectBRDF (Surface surface, BRDF brdf, Light light) {
	return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

#endif