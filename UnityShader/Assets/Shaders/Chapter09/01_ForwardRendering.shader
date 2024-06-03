// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter09/01_ForwardRendering"
{
    Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        // Base Pass
        pass
        {
            // Pass for ambient light & first pixel light (directional light)
			Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
			
			// Apparently need to add this declaration 
            // #pragma multi_compile_fwdbase 指令可以保证我们在Shader中使用光照衰减等光照变量可以被正确赋值。这是不可缺少的。
			#pragma multi_compile_fwdbase	
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);
                // 使用 _WorldSpaceLightPos0 来得到这个平行光的方向（位置对平行光来说没有意义）
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				
                // 计算场景中的环境光
                // 我们希望环境光计算一次即可，因此在后面的Additional Pass中就不会再计算这个部分。
                // 与之类似，还有物体的自发光，但在本例中，我们假设胶囊体没有自发光效果。
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
                // 在Base Pass中处理了场景中的最重要的平行光。
                // 使用 _LightColor0 来得到它的颜色和强度（_LightColor0已经是颜色和强度相乘后的结果）
			 	fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

			 	fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
			 	fixed3 halfDir = normalize(worldLightDir + viewDir);
			 	fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

                // 由于平行光可以认为是没有衰减的，因此这里我们直接令衰减值为1.0。
				fixed atten = 1.0;
				
				return fixed4(ambient + (diffuse + specular) * atten, 1.0);
			}

            ENDCG
        }

        // Additional Pass
        // 去掉Base Pass中环境光、自发光、逐顶点光照、SH光照的部分，并添加一些对不同光源类型的支持。
        pass
        {
            // Pass for other pixel lights
			Tags { "LightMode"="ForwardAdd" }

            // 使用Blend命令开启和设置了混合模式。这是因为，我们希望Additional Pass计算得到的光照结果可以在帧缓存中与之前的光照结果进行叠加。
            // 如果没有使用Blend命令的话，Additional Pass会直接覆盖掉之前的光照结果。
            // 我们选择的混合系数是Blend One One，这不是必需的，我们可以设置成Unity支持的任何混合系数。常见的还有Blend SrcAlpha One。
            Blend One One
            // Blend SrcAlpha One
		
			CGPROGRAM
			
			// Apparently need to add this declaration
            // 这个指令可以保证我们在Additional Pass中访问到正确的光照变量。
			#pragma multi_compile_fwdadd
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);

                // 计算光源方向
				#ifdef USING_DIRECTIONAL_LIGHT
                    // 处理的光源类型是平行光
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
				#else
					fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif
				
                // 颜色和强度我们仍然可以使用_LightColor0来得到
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));
				
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
                // 处理不同光源的衰减
                // 尽管我们可以使用数学表达式来计算给定点相对于点光源和聚光灯的衰减，但这些计算往往涉及开根号、除法等计算量相对较大的操作，
                // 因此Unity选择了使用一张纹理作为查找表（Lookup Table, LUT），以在片元着色器中得到光源的衰减。
                // 我们首先得到光源空间下的坐标，然后使用该坐标对衰减纹理进行采样得到衰减值。
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed atten = 1.0;
				#else
					#if defined (POINT)
				        float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
				        fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #elif defined (SPOT)
				        float4 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1));
				        fixed atten = (lightCoord.z > 0) * tex2D(_LightTexture0, lightCoord.xy / lightCoord.w + 0.5).w * tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
				    #else
				        fixed atten = 1.0;
				    #endif
				#endif

				return fixed4((diffuse + specular) * atten, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}