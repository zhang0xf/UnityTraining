Shader "Custom RP/Lit" {
	
	Properties {
        _BaseMap("Texture", 2D) = "white" {}
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
        _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
		[HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
    }
	
	SubShader {

        HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl" // 所有渲染通道(pass)均会包含此文件.
		#include "LitInput.hlsl"
		ENDHLSL
		
		Pass {
            Tags {
				"LightMode" = "CustomLit" // 使用自定义的光照方法
			}

            Blend [_SrcBlend] [_DstBlend] // Blend:将当前片元着色器的输出与渲染目标进行混合,方括号用于访问Shader属性.
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma target 3.5
            // 该指令告诉Unity根据关键字是否被定义编译生成不同版本的着色器变体.
            // #pragma shader_feature _CLIPPING
            // 使用下划线代表关键字'_SHADOWS_CLIP'和'_SHADOWS_DITHER'都未被定义的默认状态.
            #pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma shader_feature _RECEIVE_SHADOWS
            #pragma shader_feature _PREMULTIPLY_ALPHA
            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ LIGHTMAP_ON
            // GPU Instancing:CPU收集每个对象的转换信息和材质属性,以数组形式发送到GPU.GPU迭代数组元素,并按顺序进行渲染.
            // Unity根据是否启用GPU Instancing编译生成不同版本的着色器变体.
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
            #include "LitPass.hlsl"
			ENDHLSL
        }

        Pass {
			Tags {
				"LightMode" = "ShadowCaster" // Unity使用'ShadowCaster'通道渲染阴影(另见:DrawShadows)
			}

			ColorMask 0 // 渲染阴影只需要写入深度,因此禁止颜色数据.

			HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _CLIPPING
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
		}

        Pass {
			Tags {
				"LightMode" = "Meta" // Unity使用特殊的'Meta'通道来决定光线烘焙时的发射光颜色.
			}

			Cull Off // 该通道要求Cull始终Off.

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
		}

	}

    CustomEditor "CustomShaderGUI" // 指示Unity使用'CustomShaderGUI'类来绘制Inspector面板.
}