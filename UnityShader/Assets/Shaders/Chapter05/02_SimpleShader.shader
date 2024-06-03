Shader "UnityShadersBook/Chapter05/02_SimpleShader"
{
    SubShader
    {
        pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            // 使用一个结构体来定义顶点着色器的输入
            // a2v : "application" to "vertex shader"
            struct a2v{
                // POSITION 的语义：告诉Unity，用模型空间的顶点坐标填充 vertex 变量
                float4 vertex : POSITION;
                // NORMAL 的语义：告诉Unity，用模型空间的法线方向填充 normal 变量
                float3 normal : NORMAL;
                // TEXCOORD0 的语义：告诉Unity，用模型空间的第一套纹理坐标填充 texcoord 变量
                float4 texcoord: TEXCOORD0;
            };

            float4 vert(a2v v) : SV_POSITION
            {
                // 使用 v.vertex 来访问模型空间的顶点坐标
                return UnityObjectToClipPos(v.vertex);
            }

            fixed4 frag() :SV_TARGET
            {
                return fixed4(1.0, 1.0, 1.0, 1.0);
            }

            ENDCG
        }
    }
}