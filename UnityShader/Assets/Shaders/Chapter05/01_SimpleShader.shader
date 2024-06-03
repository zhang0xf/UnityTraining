// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter05/01_SimpleShader"
{
    SubShader
    {
        Pass
        {
            // CG代码片段
            CGPROGRAM

            // pragma vertex “function name”
            // 表明哪个函数包含了顶点着色器的代码
            #pragma vertex vert
            // pragma fragment “function name”
            // 表明哪个函数包含了片元着色器的代码
            #pragma fragment frag

            // 逐顶点执行
            // 输入：v，包含了这个顶点的位置
            // POSITION 的语义：告诉Unity，将模型的顶点坐标填充到输入参数v中
            // SV_POSITION 的语义：告诉Unity，顶点着色器的输出是裁剪空间中的顶点坐标
            float4 vert(float4 v : POSITION) : SV_POSITION
            {
                // return mul(UNITY_MATRIX_MVP,v) 已经弃用
                // 将顶点坐标从模型空间转换到裁剪空间
                return UnityObjectToClipPos(v);
            }

            // SV_TARGET同时也是HLSL中的一个系统语义，它等同于告诉渲染器，把用户的输出颜色存储到一个渲染目标中，这里将输出到默认的帧缓存中。
            fixed4 frag() : SV_TARGET
            {
                // 返回一个表示白色的fixed4类型的变量
                // 片元着色器输出的颜色的每个分量范围在[0,1]，其中(0,0,0)表示黑色，而(1,1,1)表示白色
                return fixed4(1.0, 1.0, 1.0, 1.0);
            }

            ENDCG
        }
    }
}