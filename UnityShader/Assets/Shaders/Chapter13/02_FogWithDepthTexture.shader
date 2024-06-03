// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter13/02_FogWithDepthTexture"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_FogDensity ("Fog Density", Float) = 1.0
		_FogColor ("Fog Color", Color) = (1, 1, 1, 1)
		_FogStart ("Fog Start", Float) = 0.0
		_FogEnd ("Fog End", Float) = 1.0
	}

    SubShader
    {
        // 我们使用CGINCLUDE来组织代码。我们在SubShader块中利用CGINCLUDE和ENDCG语义来定义一系列代码
        CGINCLUDE
		
		#include "UnityCG.cginc"
		
        // _FrustumCornersRay虽然没有在Properties中声明，但仍可由脚本传递给Shader。
        // 除了Properties中声明的各个属性，我们还声明了深度纹理_CameraDepthTexture, Unity会在背后把得到的深度纹理传递给该值。
		float4x4 _FrustumCornersRay;
		
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;
		sampler2D _CameraDepthTexture;
		half _FogDensity;
		fixed4 _FogColor;
		float _FogStart;
		float _FogEnd;
		
		struct v2f {
			float4 pos : SV_POSITION; // 顶点位置
			half2 uv : TEXCOORD0; // 屏幕图像纹理坐标
			half2 uv_depth : TEXCOORD1; // 深度纹理纹理坐标
			float4 interpolatedRay : TEXCOORD2; // interpolatedRay变量存储插值后的像素向量
		};

        v2f vert(appdata_img v) 
        {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
            // 我们对深度纹理的采样坐标进行了平台差异化处理。
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
			
            // 我们采用的方法是判断它的纹理坐标。
            // 我们知道，在Unity中，纹理坐标的(0, 0)点对应了左下角，而(1, 1)点对应了右上角。
            // 我们据此来判断该顶点对应的索引，这个对应关系和我们在脚本中对frustumCorners的赋值顺序是一致的。
            // 尽管我们这里使用了很多判断语句，但由于屏幕后处理所用的模型是一个四边形网格，只包含4个顶点，因此这些操作不会对性能造成很大影响。
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
            // 首先，我们需要重建该像素在世界空间中的位置。
            // 我们首先使用SAMPLE_DEPTH_TEXTURE对深度纹理进行采样，
            // 再使用LinearEyeDepth得到视角空间下的线性深度值。
            // 之后，与interpolatedRay相乘后再和世界空间下的摄像机位置相加，即可得到世界空间下的位置。
			float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
            // 这个公式看上去很奇怪，需要结合15.3节的公式进行思考（四个Ray的公式中省略了depth，这里linearDepth又给不上了？是在找不出解释了。）
			float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz; 
			
            // 我们根据材质属性_FogEnd和_FogStart计算当前的像素高度worldPos.y对应的雾效系数fogDensity，
            // 再和参数_FogDensity相乘后，利用saturate函数截取到[0, 1]范围内，作为最后的雾效系数。
            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart); 
			fogDensity = saturate(fogDensity * _FogDensity);
			
            // 我们使用该系数将雾的颜色和原始颜色进行混合后返回。
			fixed4 finalColor = tex2D(_MainTex, i.uv);
			finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
			
			return finalColor;
		}
		
		ENDCG

        Pass 
        {
			ZTest Always 
            Cull Off 
            ZWrite Off
			     	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
    }

    FallBack Off
}