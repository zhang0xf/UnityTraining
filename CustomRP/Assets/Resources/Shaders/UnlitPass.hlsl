#ifndef CUSTOM_UNLIT_PASS_INCLUDED // 防止重复包含
#define CUSTOM_UNLIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

// 渲染管线批处理(SRP Batcher):在GPU缓存'material properties'以减少CPU和GPU的通信数据量,以及CPU发送这些数据产生的额外负荷.
// 构建批处理方式:所有'material properties'需要定义在一个'memory buffer'中,就像是一个结构体.
// CBUFFER_START:该宏属于Core RP Library,用来处理不同平台差异,不支持cbuffer的平台这段代码就不会存在.
// 注意:'SRP Batcher'并不是只有一个'Draw Call',只是减少了设置'Draw Call'的成本,并且与'GPU Instancing'互相不兼容.'SRP Batcher'优先执行.
// CBUFFER_START(UnityPerMaterial)
// 	float4 _BaseColor; // 下划线是代表一个'material property'的标准写法.[通过Inspector配置]
// CBUFFER_END

// 纹理和采样器属于Shader资源,无法按'per-instance'提供,需要声明在全局范围.
// TEXTURE2D(_BaseMap); // 纹理句柄
// SAMPLER(sampler_BaseMap); // 纹理采样器(控制如何采样纹理)

// GPU Instancing:仅适用于相同'Material'的'Mesh'.另见:https://docs.unity3d.com/Manual/GPUInstancing.html
// 注意:'batch size'会根据目标平台以及每个Instance需要提供多少数据而不同.如果超出限制,会导致不止一个批处理.
// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
//     UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST) // 该变量提供纹理的'tiling and offset',应该声明在buff中,即能够按'per-instance'设置.
//     UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
//     UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes {
	float3 positionOS : POSITION; // Object Space Position.
    float2 baseUV : TEXCOORD0; // 纹理坐标是顶点属性(vertex Attributes)中的一部分,'TEXCOORD0'表示第一对坐标.
    UNITY_VERTEX_INPUT_INSTANCE_ID // 当使用'GPU Instancing'时,对象索引(Object Index)可以从顶点数据中获取.
};

struct Varyings {
	float4 positionCS : SV_POSITION; // 齐次裁剪空间坐标(Homogeneous Clip Space Position).
    float2 baseUV : VAR_BASE_UV; // 该变量用于传递纹理坐标,'VAR_BASE_UV'不是特定语义,而是任意未使用的标识符,用来赋予变量含义.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings UnlitPassVertex(Attributes input) 
{
    Varyings output;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    float3 positionWS = TransformObjectToWorld(input.positionOS);
    output.positionCS = TransformWorldToHClip(positionWS);
    // float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	// output.baseUV = input.baseUV * baseST.xy + baseST.zw;
    output.baseUV = TransformBaseUV(input.baseUV);
    return output;
}

// 返回值类型float4:颜色(R,G,B,A)
// 延伸:如果正在针对手游进行优化,尽可能使用half替代float.原则上positions和'texture coordinates'可以使用float,其余的使用half.
// 非手游平台,精度通常不是问题.即使你使用了half,大部分GPU也会使用float.
// 语义SV_TARGET:float4只是一个数据,可能代表着任何含义,具体的语义需要由函数自身指示(SV_TARGET).
// 延伸:关于着色器语义,另见:https://docs.unity.cn/cn/2020.3/Manual/SL-ShaderSemantics.html
float4 UnlitPassFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(input);
    // float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV); // 采样纹理
	// float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    // float4 base = baseMap * baseColor;
    float4 base = GetBase(input.baseUV);
    #if defined(_CLIPPING)
        clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
    #endif
	return base;
}

#endif