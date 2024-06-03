Shader "UnityShadersBook/Chapter05/03_SimpleShader"
{
    SubShader
    {
        pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord: TEXCOORD0;
            };

            // 使用一个结构体来定义顶点着色器的输出
            struct v2f{
                // SV_POSITION 的语义：告诉Unity，pos 里包含了顶点在裁剪空间中的位置信息
                float4 pos : SV_POSITION;
                // COLOR0 的语义：可以用于存储颜色信息
                fixed3 color : COLOR0;
            };

            v2f vert(a2v v)
            {
                // 申明输出结构
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                // v.normal 包含了顶点的法线方向，其分量范围在[-1.0, 1.0]
                // 下面的代码把分量范围映射到了[0.0, 1.0]
                // 存储到 o.color 中传递给片元着色器
                o.color = v.normal * 0.5 + fixed3(0.5, 0.5, 0.5);
                return o;
            }

            fixed4 frag(v2f i) :SV_TARGET
            {
                // 将插值后的 i.color 显示到屏幕上
                return fixed4(i.color, 1.0);
            }

            ENDCG
        }
    }
}