// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter11/02_ScrollingBackground"
{
    Properties 
    {
        // _MainTex和_DetailTex分别是第一层（较远）和第二层（较近）的背景纹理
		_MainTex ("Base Layer (RGB)", 2D) = "white" {}
		_DetailTex ("2nd Layer (RGB)", 2D) = "white" {}
        // _ScrollX和_Scroll2X对应了各自的水平滚动速度。
		_ScrollX ("Base layer Scroll Speed", Float) = 1.0
		_Scroll2X ("2nd layer Scroll Speed", Float) = 1.0
		_Multiplier ("Layer Multiplier", Float) = 1 // _Multiplier参数则用于控制纹理的整体亮度。
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			sampler2D _DetailTex;
			float4 _MainTex_ST;
			float4 _DetailTex_ST;
			float _ScrollX;
			float _Scroll2X;
			float _Multiplier;

            struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
			};

            v2f vert (a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
                // 首先利用TRANSFORM_TEX来得到初始的纹理坐标。
                // 然后，我们利用内置的_Time.y变量在水平方向上对纹理坐标进行偏移，以此达到滚动的效果。
                // 我们把两张纹理的纹理坐标存储在同一个变量o.uv中，以减少占用的插值寄存器空间。
                // frac： 
                // it gives you the value after the decimal place.
                // if you pass in a float2, 3 or 4 then it'll do that for each component individually.
                // frac(0.5) = 0.5
                // frac(1.25) = 0.25
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex) + frac(float2(_ScrollX, 0.0) * _Time.y);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _DetailTex) + frac(float2(_Scroll2X, 0.0) * _Time.y);
				
				return o;
			}

            fixed4 frag (v2f i) : SV_Target 
            {
				fixed4 firstLayer = tex2D(_MainTex, i.uv.xy);
				fixed4 secondLayer = tex2D(_DetailTex, i.uv.zw);
				
                // lerp：插值函数
                // 在学习贝塞尔曲线的时候也接触过！
				fixed4 c = lerp(firstLayer, secondLayer, secondLayer.a);
                // 使用_Multiplier参数和输出颜色进行相乘，以调整背景亮度。
				c.rgb *= _Multiplier;
				
				return c;
			}

            ENDCG
        }
    }
    FallBack "VertexLit"
}