Shader "Custom RP/Unlit" {
	
	Properties {
        _BaseMap("Texture", 2D) = "white" {}
        _BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5 // Alpha剔除阈值
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1 // One:全部
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0 // Zero:忽略
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1 // 是否写入深度缓冲
    }
	
	SubShader {
		
		Pass {
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
            // 启动toggle会向'Material'的'active keywords'列表中添加'_CLIPPING keyword'.禁用toggle则会移除它.
            // 该指令告诉Unity根据关键字(keyword)是否定义编译不同版本的着色器(Shader).
            #pragma shader_feature _CLIPPING
            // GPU instancing:CPU收集每个对象的'transformation and material properties',并以数组形式发送到GPU,GPU迭代数组元素,并按顺序进行渲染.
            // 该指令告诉Unity为Shader生成两种变体,一种支持GPU instancing,另一种不支持.[通过Inspector面板设置]
            #pragma multi_compile_instancing
            #pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment
            #include "UnlitPass.hlsl" // 将HLSL代码放在一个单独的文件中.
			ENDHLSL
        }

	}
}