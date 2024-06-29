#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

// 为了计算光照,需要获得表面属性.
struct Surface {
	float3 normal;
    float3 viewDirection;
	float3 color;
	float alpha;
    float metallic;
	float smoothness;
};

#endif