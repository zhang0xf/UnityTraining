// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter10/01_Refraction"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_RefractColor ("Refraction Color", Color) = (1, 1, 1, 1)
		_RefractAmount ("Refraction Amount", Range(0, 1)) = 1
		_RefractRatio ("Refraction Ratio", Range(0.1, 1)) = 0.5 // 需要使用该属性得到不同介质的透射比，以此来计算折射方向。
		_Cubemap ("Refraction Cubemap", Cube) = "_Skybox" {}
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
			
			#pragma multi_compile_fwdbase	
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Color;
			fixed4 _RefractColor;
			float _RefractAmount;
			fixed _RefractRatio;
			samplerCUBE _Cubemap;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				fixed3 worldNormal : TEXCOORD1;
				fixed3 worldViewDir : TEXCOORD2;
				fixed3 worldRefr : TEXCOORD3;
				SHADOW_COORDS(4)
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
				
				// Compute the refract dir in world space
                // 我们使用了CG的refract函数来计算折射方向。
                // 它的第一个参数即为入射光线的方向，它必须是归一化后的矢量；
                // 第二个参数是表面法线，法线方向同样需要是归一化后的；
                // 第三个参数是入射光线所在介质的折射率和折射光线所在介质的折射率之间的比值，
                // 例如如果光是从空气射到玻璃表面，那么这个参数应该是空气的折射率和玻璃的折射率之间的比值，即1/1.5。
                // 它的返回值就是计算而得的折射方向，它的模则等于入射光线的模。
				o.worldRefr = refract(-normalize(o.worldViewDir), normalize(o.worldNormal), _RefractRatio);
				
				TRANSFER_SHADOW(o);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(i.worldViewDir);
								
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0, dot(worldNormal, worldLightDir));
				
				// Use the refract dir in world space to access the cubemap
                // 我们也没有对i.worldRefr进行归一化操作，因为对立方体纹理的采样只需要提供方向即可。
				fixed3 refraction = texCUBE(_Cubemap, i.worldRefr).rgb * _RefractColor.rgb;
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				// Mix the diffuse color with the refract color
                // 最后，我们使用_RefractAmount来混合漫反射颜色和折射颜色，并和环境光照相加后返回。
				fixed3 color = ambient + lerp(diffuse, refraction, _RefractAmount) * atten;
				
				return fixed4(color, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Reflective/VertexLit"
}