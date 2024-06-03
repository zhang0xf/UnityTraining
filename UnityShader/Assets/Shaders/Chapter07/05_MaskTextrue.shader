// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter07/05_MaskTextrue"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpScale("Bump Scale", Float) = 1.0
		_SpecularMask ("Specular Mask", 2D) = "white" {} // 高光反射遮罩纹理
		_SpecularScale ("Specular Scale", Float) = 1.0 // 用于控制遮罩影响度系数
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
			sampler2D _MainTex; // 主纹理
			float4 _MainTex_ST; // 三个纹理共同使用的纹理属性变量，在材质面板中修改主纹理的平铺系数和偏移系数会同时影响三个纹理的采样。
			sampler2D _BumpMap; // 法线纹理
			float _BumpScale;
			sampler2D _SpecularMask; // 遮罩纹理
			float _SpecularScale;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 lightDir: TEXCOORD1;
				float3 viewDir : TEXCOORD2;
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				
                // TANGENT_SPACE_ROTATION 宏 相当于嵌入如下两行代码：
                // float3 binormal = cross( v.normal, v.tangent.xyz ) * v.tangent.w;
                // float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal );
				TANGENT_SPACE_ROTATION;
				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
				o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
			 	fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);

				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
				tangentNormal.xy *= _BumpScale;
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));
				
			 	fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
			 	// Get the mask value
                // 由于本书使用的遮罩纹理中每个纹素的rgb分量其实都是一样的，表明了该点对应的高光反射强度，在这里我们选择使用r分量来计算掩码值。
                // 我们用得到的掩码值和_SpecularScale相乘，一起来控制高光反射的强度。
                // 我们使用的这张遮罩纹理其实有很多空间被浪费了——它的rgb分量存储的都是同一个值。
                // 在实际的游戏制作中，我们往往会充分利用遮罩纹理中的每一个颜色通道来存储不同的表面属性
			 	fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
			 	// Compute specular term with the specular mask
			 	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;
			
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}