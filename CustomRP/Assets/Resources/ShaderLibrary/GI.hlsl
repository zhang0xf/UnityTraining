#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

#if defined(LIGHTMAP_ON)
	#define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1; // 'light map uv'通过第二个纹理坐标通道提供.
	#define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
    #define TRANSFER_GI_DATA(input, output) \
		output.lightMapUV = input.lightMapUV * \
		unity_LightmapST.xy + unity_LightmapST.zw;
	#define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
	#define GI_ATTRIBUTE_DATA
	#define GI_VARYINGS_DATA
	#define TRANSFER_GI_DATA(input, output)
	#define GI_FRAGMENT_DATA(input) 0.0
#endif

TEXTURE2D(unity_Lightmap); // 纹理句柄(light map texture)
SAMPLER(samplerunity_Lightmap); // 纹理采样器

TEXTURE3D_FLOAT(unity_ProbeVolumeSH); // 'LPPV'的'volume data'被存储在'3D float texture'.
SAMPLER(samplerunity_ProbeVolumeSH); // 纹理采样器

struct GI {
	float3 diffuse; // 间接光照(Indirect light)来自于所有方向,所以只能用作漫反射照明(diffuse lighting),而不能用作高光(specular).
};

float3 SampleLightMap (float2 lightMapUV) {
	#if defined(LIGHTMAP_ON)
        return SampleSingleLightmap(
			TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,
            float4(1.0, 1.0, 0.0, 0.0), // scale and translation to apply.我们已经在之前完成.
            #if defined(UNITY_LIGHTMAP_FULL_HDR) // 'light map'是否被压缩.
				false,
			#else
				true,
			#endif
			float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0) // 解码说明
		);
	#else
		return 0.0;
	#endif
}

float3 SampleLightProbe (Surface surfaceWS) {
	#if defined(LIGHTMAP_ON) // 如果'light map'正在应用于这个物体,则返回0.
		return 0.0;
	#else
        if (unity_ProbeVolumeParams.x) {
			return SampleProbeVolumeSH4( // 使用'LPPV'
				TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
				surfaceWS.position, surfaceWS.normal,
				unity_ProbeVolumeWorldToObject,
				unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
				unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
			);
		}
		else {
			float4 coefficients[7];
			coefficients[0] = unity_SHAr; // probe data
			coefficients[1] = unity_SHAg;
			coefficients[2] = unity_SHAb;
			coefficients[3] = unity_SHBr;
			coefficients[4] = unity_SHBg;
			coefficients[5] = unity_SHBb;
			coefficients[6] = unity_SHC;
			return max(0.0, SampleSH9(coefficients, surfaceWS.normal));
		}
	#endif
}

GI GetGI (float2 lightMapUV, Surface surfaceWS) {
	GI gi;
    gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
	return gi;
}

#endif