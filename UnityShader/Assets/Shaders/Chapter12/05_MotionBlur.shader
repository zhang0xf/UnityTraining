// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter12/05_MotionBlur"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurAmount ("Blur Amount", Float) = 1.0
	}
    
    SubShader
    {
        CGINCLUDE
		
		#include "UnityCG.cginc"
		
        // _MainTex对应了输入的渲染纹理。
        // _BlurAmount是混合图像时使用的混合系数。
		sampler2D _MainTex;
		fixed _BlurAmount;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
		};
		
		v2f vert(appdata_img v) 
		{
			v2f o;
			
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
					 
			return o;
		}

        // 我们定义了两个片元着色器，一个用于更新渲染纹理的RGB通道部分
        // RGB通道版本的Shader对当前图像进行采样，并将其A通道的值设为_BlurAmount，以便在后面混合时可以使用它的透明通道进行混合。
        fixed4 fragRGB (v2f i) : SV_Target 
        {
			return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
		}
		
        // 另一个用于更新渲染纹理的A通道部分
        // A通道版本的代码就更简单了，直接返回采样结果。
        // 实际上，这个版本只是为了维护渲染纹理的透明通道值，不让其受到混合时使用的透明度值的影响。
		half4 fragA (v2f i) : SV_Target 
        {
			return tex2D(_MainTex, i.uv);
		}
		
		ENDCG
		
		ZTest Always 
        Cull Off 
        ZWrite Off

        // 在本例中我们需要两个Pass，一个用于更新渲染纹理的RGB通道，一个用于更新A通道。
        // 之所以要把A通道和RGB通道分开，是因为在更新RGB时我们需要设置它的A通道来混合图像，但又不希望A通道的值写入渲染纹理中。
        Pass {
			Blend SrcAlpha OneMinusSrcAlpha
			ColorMask RGB
			
			CGPROGRAM
			
			#pragma vertex vert  
			#pragma fragment fragRGB  
			
			ENDCG
		}
		
		Pass {   
			Blend One Zero
			ColorMask A
			   	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment fragA
			  
			ENDCG
		}
    }

    FallBack Off
}