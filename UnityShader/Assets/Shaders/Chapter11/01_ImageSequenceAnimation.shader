// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter11/01_ImageSequenceAnimation"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Image Sequence", 2D) = "white" {} // _MainTex就是包含了所有关键帧图像的纹理
        // _HorizontalAmount和_VerticalAmount分别代表了该图像在水平方向和竖直方向包含的关键帧图像的个数。
    	_HorizontalAmount ("Horizontal Amount", Float) = 4
    	_VerticalAmount ("Vertical Amount", Float) = 4
    	_Speed ("Speed", Range(1, 100)) = 30 // _Speed属性用于控制序列帧动画的播放速度。
	}

    SubShader
    {
        // 由于序列帧图像通常是透明纹理，我们需要设置Pass的相关状态，以渲染透明效果
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			
			CGPROGRAM
			
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _HorizontalAmount;
			float _VerticalAmount;
			float _Speed;

            struct a2v {  
			    float4 vertex : POSITION; 
			    float2 texcoord : TEXCOORD0;
			};  
			
			struct v2f {  
			    float4 pos : SV_POSITION;
			    float2 uv : TEXCOORD0;
			};

            v2f vert (a2v v) 
            {  
				v2f o;  
				o.pos = UnityObjectToClipPos(v.vertex);  
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);  
				return o;
			}  
			
			fixed4 frag (v2f i) : SV_Target 
            {
                // 使用time除以_HorizontalAmount的结果值的商来作为当前对应的行索引，除法结果的余数则是列索引
				float time = floor(_Time.y * _Speed);  
				float row = floor(time / _HorizontalAmount);
				float column = time - row * _HorizontalAmount;
				
				// uv的分量x,y的范围在[0, 1]，所有都说的通了。
                half2 uv = float2(i.uv.x /_HorizontalAmount, i.uv.y / _VerticalAmount);
                uv.x += column / _HorizontalAmount;
                uv.y -= row / _VerticalAmount;
				// 讲上述过程的除法整合到一起就是下面的代码：
				// half2 uv = i.uv + half2(column, -row);
				// uv.x /=  _HorizontalAmount;
				// uv.y /= _VerticalAmount;
				
				fixed4 c = tex2D(_MainTex, uv);
				c.rgb *= _Color;
				
				return c;
			} 

            ENDCG
        }
    }

    FallBack "Transparent/VertexLit"
}