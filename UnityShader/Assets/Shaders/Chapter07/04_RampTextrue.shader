// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 需要注意的是，我们需要把渐变纹理的Wrap Mode设为Clamp模式，以防止对纹理进行采样时由于浮点数精度而造成的问题。

Shader "UnityShadersBook/Chapter07/04_RampTextrue"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_RampTex ("Ramp Tex", 2D) = "white" {}
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}

    SubShader
    {
        pass
        {
            Tags { "LightMode"="ForwardBase" }
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _RampTex;
			float4 _RampTex_ST; // 我们为渐变纹理_RampTex定义了它的纹理属性变量_RampTex_ST
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 uv : TEXCOORD2;
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

				// 使用了内置的 TRANSFORM_TEX 宏来计算经过平铺和偏移后的纹理坐标。
				o.uv = TRANSFORM_TEX(v.texcoord, _RampTex);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// Use the texture to sample the diffuse color
                // 通过对法线方向和光照方向的点积做一次0.5倍的缩放以及一个0.5大小的偏移来计算半兰伯特部分halfLambert。
				fixed halfLambert  = 0.5 * dot(worldNormal, worldLightDir) + 0.5;
                // 由于_RampTex实际就是一个一维纹理（它在纵轴方向上颜色不变），因此纹理坐标的u和v方向我们都使用了halfLambert。
				fixed3 diffuseColor = tex2D(_RampTex, fixed2(halfLambert, halfLambert)).rgb * _Color.rgb;
				
				fixed3 diffuse = _LightColor0.rgb * diffuseColor;
				
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}