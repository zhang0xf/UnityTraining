#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

#define MIN_REFLECTIVITY 0.04 // 非金属也有反射率,平均约为0.04,也会些许高光.

// 需要使用表面属性(surface properties)来计算双向反射率分布函数(bidirectional reflectance distribution function)方程
struct BRDF {
	float3 diffuse; // 表面漫反射颜色
	float3 specular; // 表面高光反射颜色
	float roughness; // 表面粗糙度
};

float OneMinusReflectivity (float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY; 
	return range - metallic * range; // 通常高光金属会反射所有光而不会产生漫反射,将金属度解释为反射率.
}

BRDF GetBRDF (Surface surface, bool applyAlphaToDiffuse = false) {
	BRDF brdf;
    float oneMinusReflectivity = OneMinusReflectivity(surface.metallic); 
	brdf.diffuse = surface.color * oneMinusReflectivity; // 反射率决定漫反射.
    if (applyAlphaToDiffuse) {
        // 当使用透明通道(Transparent Render Queue)[可由Inspector窗口设置]是否应用透明度来'fade out'漫反射(diffuse reflection).
        // 延伸:当使用透明通道时,我们希望高光反射是不随着Alpha值消散的,且漫发射应该随着Alpha值消散.此时可以设置'Blend Mode': blend One OneMinusSrcAlpha,再使用预乘Alpha的方式消散diffuse.
		brdf.diffuse *= surface.alpha; // 预乘Alpha(Premultiplied Alpha)可以使物体看上去像玻璃.
	}
    // 介电表面(dielectric surfaces)的高光应该是白色,且根据能量守恒定律,出射光的能量不会超过入射光的能量.
    // brdf.specular = surface.color - brdf.diffuse;
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);
    float perceptualRoughness =	PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	return brdf;
}

// 高光反射的强度取决于完美的反射角度与摄像机观察角度之间的匹配程度.
// 计算公式采用和'Universal RP'中一样的公式,他是'Minimalist CookTorrance BRDF'的一种变体.
float SpecularStrength (Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

// 返回结果是由高光反射强度(SpecularStrength)调节的高光颜色(specular color) + 漫反射颜色.
float3 DirectBRDF (Surface surface, BRDF brdf, Light light) {
	return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

#endif