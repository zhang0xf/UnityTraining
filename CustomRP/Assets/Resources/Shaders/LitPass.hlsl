#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

struct Attributes {
	float3 positionOS : POSITION; // Object Space Position.
    float3 normalOS : NORMAL; // Object Space Normal.
    float2 baseUV : TEXCOORD0; // 纹理坐标(使用第一个纹理坐标通道).
    GI_ATTRIBUTE_DATA // Light Map的坐标(定义在GI.hsls).
    UNITY_VERTEX_INPUT_INSTANCE_ID // GPU Instancing的索引.
};

struct Varyings {
	float4 positionCS : SV_POSITION; // Homogeneous(齐次) Clip Space Position.
    float3 positionWS : VAR_POSITION; // World Space Surface Position.
    float3 normalWS : VAR_NORMAL; // 片元计算光照需要法线信息(通常在世界空间中计算).
    float2 baseUV : VAR_BASE_UV; // 传递纹理坐标,'VAR_BASE_UV'不是特定语义,而是任意未使用的标识符.
	GI_VARYINGS_DATA
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex(Attributes input)
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    TRANSFER_GI_DATA(input, output);
    output.positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(output.positionWS);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

// 返回值类型float4:表示颜色(R,G,B,A)
// 延伸:如果正在针对手游进行优化,尽可能使用half替代float.原则上position和'texture coordinates'可以使用float,其余的使用half.
// 非手游平台,精度通常不是问题.即使你使用了half,大部分GPU也会转换为float.
// SV_TARGET:float4只是一个数据,可能代表着任何含义,具体的语义需要由函数自身指示(SV_TARGET).
float4 LitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    float4 base = GetBase(input.baseUV);
    #if defined(_CLIPPING)
        clip(base.a - GetCutoff(input.baseUV));
    #endif

    Surface surface;
    surface.position = input.positionWS;
    // 跨三角形的线性插值会影响法线的长度,使之不再是单位长度,所以需要归一化.
	surface.normal = normalize(input.normalWS);
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
    surface.depth = -TransformWorldToView(input.positionWS).z;
    surface.color = base.rgb;
	surface.alpha = base.a;
    surface.metallic = GetMetallic(input.baseUV);
    surface.smoothness = GetSmoothness(input.baseUV);
    surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);

    #if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif

    GI gi = GetGI(GI_FRAGMENT_DATA(input), surface);

    float3 color = GetLighting(surface, brdf, gi);
    
    color += GetEmission(input.baseUV);
    
    return float4(color, surface.alpha);
}

#endif