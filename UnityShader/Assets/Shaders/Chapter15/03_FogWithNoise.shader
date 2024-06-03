// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter15/03_FogWithNoise"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
		_NoiseTex ("Noise Texture", 2D) = "white" {}
		_FogXSpeed ("Fog Horizontal Speed", Float) = 0.1
		_FogYSpeed ("Fog Vertical Speed", Float) = 0.1
		_NoiseAmount ("Noise Amount", Float) = 1
	}

    SubShader
    {
        // 我们使用CGINCLUDE来组织代码。我们在SubShader块中利用CGINCLUDE和ENDCG语义来定义一系列代码
        CGINCLUDE
		
		#include "UnityCG.cginc"
		
		float4x4 _FrustumCornersRay; // _FrustumCornersRay虽然没有在Properties中声明，但仍可由脚本传递给Shader。
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture; // 我们还声明了深度纹理_CameraDepthTexture, Unity会在背后把得到的深度纹理传递给该值。
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		sampler2D _NoiseTex;
		half _FogXSpeed;
		half _FogYSpeed;
		half _NoiseAmount;

        struct v2f {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float2 uv_depth : TEXCOORD1;
			float4 interpolatedRay : TEXCOORD2;
		};

        v2f vert(appdata_img v) 
        {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
			int index = 0;
			if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5) {
				index = 0;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5) {
				index = 1;
			} else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5) {
				index = 2;
			} else {
				index = 3;
			}
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				index = 3 - index;
			#endif
			
			o.interpolatedRay = _FrustumCornersRay[index];
				 	 
			return o;
		}

        fixed4 frag(v2f i) : SV_Target 
        {
            // 首先根据深度纹理来重建该像素在世界空间中的位置。
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;
			
            // 利用内置的_Time.y变量和_FogXSpeed、_FogYSpeed属性计算出当前噪声纹理的偏移量，并据此对噪声纹理进行采样，得到噪声值。
			float2 speed = _Time.y * float2(_FogXSpeed, _FogYSpeed);
            // 我们把该值减去0.5，再乘以控制噪声程度的属性_NoiseAmount，得到最终的噪声值。
			float noise = (tex2D(_NoiseTex, i.uv + speed).r - 0.5) * _NoiseAmount;
         
			float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
            // 随后，我们把该噪声值添加到雾效浓度的计算中，得到应用噪声后的雾效混合系数fogDensity
			fogDensity = saturate(fogDensity * _FogDensity * (1 + noise));
			
			fixed4 finalColor = tex2D(_MainTex, i.uv);
            // 最后，我们使用该系数将雾的颜色和原始颜色进行混合后返回。
			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
			
			return finalColor;
		}
		
		ENDCG

        Pass 
        {          	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG
		}
    }

    FallBack Off
}