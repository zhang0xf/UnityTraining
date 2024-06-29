Shader "Custom RP/Lit" {
	
	Properties {
        _BaseMap("Texture", 2D) = "white" {}
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0) // 灰色
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5 // Alpha剔除阈值
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
        _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1 // One:全部
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0 // Zero:忽略
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1 // 是否写入深度缓冲
    }
	
	SubShader {
		
		Pass {
            Tags {
				"LightMode" = "CustomLit" // 使用自定义的光照方法(custom lighting approach)
			}

            // Blend SrcAlpha OneMinusSrcAlpha // Traditional transparency
            // Blend One OneMinusSrcAlpha // Premultiplied transparency
            // Blend One One // Additive
            // Blend OneMinusDstColor One // Soft additive
            // Blend DstColor Zero // Multiplicative
            // Blend DstColor SrcColor // 2x multiplicative
            // 延伸:如果没有指定BlendOp命令,则默认操作为Add.混合的对象是:当前片元着色器输出和渲染目标(Render Target)[渲染目标是Camera Buffer或Texture].
            Blend [_SrcBlend] [_DstBlend] // [XXX]:用于访问Shader属性
            ZWrite [_ZWrite]

            HLSLPROGRAM
            // 提高'Target Level',因为有些图形API不支持长度可变的循环(另见:'for(int i = 0; i < GetDirectionalLightCount(); i++)...'),以及不支持线性光照(linear lighting).
            #pragma target 3.5 
            // 启动toggle会向'Material'的'active keywords'列表中添加'_CLIPPING keyword'.禁用toggle则会移除它.
            // 该指令告诉Unity根据关键字(keyword)是否定义编译不同版本的着色器(Shader).
            #pragma shader_feature _CLIPPING
            #pragma shader_feature _PREMULTIPLY_ALPHA
            // GPU instancing:CPU收集每个对象的'transformation and material properties',并以数组形式发送到GPU,GPU迭代数组元素,并按顺序进行渲染.
            // 该指令告诉Unity为Shader生成两种变体,一种支持GPU instancing,另一种不支持.[通过Inspector面板设置]
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
            #include "LitPass.hlsl" // 将HLSL代码放在一个单独的文件中.
			ENDHLSL
        }

	}

    CustomEditor "CustomShaderGUI" // 指示Unity编辑器使用类'CustomShaderGUI'来绘制使用'Lit Shader'的'Material'的Inspector面板.
}