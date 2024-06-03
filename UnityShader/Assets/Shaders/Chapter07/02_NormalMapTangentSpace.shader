// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter07/02_NormalMapTangentSpace"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
        // 默认值 bump 是Unity内置的法线纹理，当没有提供任何法线纹理时，"bump"就对应了模型自带的法线信息。
		_BumpMap ("Normal Map", 2D) = "bump" {}
        // _BumpScale 则是用于控制凹凸程度的，当它为0时，意味着该法线纹理不会对光照产生任何影响。
		_BumpScale ("Bump Scale", Float) = 1.0
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
    }

    SubShader
    {
        pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }

            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"

            fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST; // 得到纹理的属性（平铺和偏移系数）
			sampler2D _BumpMap;
			float4 _BumpMap_ST; // 得到纹理的属性（平铺和偏移系数）
			float _BumpScale;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; // 将顶点的切线方向填充到 tangent 变量中
				float4 texcoord : TEXCOORD0;
			};

            struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 lightDir: TEXCOORD1; // 变换后的光照方向
				float3 viewDir : TEXCOORD2; // 变换后的视角方向
			};

            // Unity doesn't support the 'inverse' function in native shader
			// so we write one by our own
			// Note: this function is just a demonstration(示范), not too confident on the math or the speed
			// Reference: http://answers.unity3d.com/questions/218333/shader-inversefloat4x4-function.html
			float4x4 inverse(float4x4 input) 
            {
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
				
				float4x4 cofactors = float4x4(
				     minor(_22_23_24, _32_33_34, _42_43_44), 
				    -minor(_21_23_24, _31_33_34, _41_43_44),
				     minor(_21_22_24, _31_32_34, _41_42_44),
				    -minor(_21_22_23, _31_32_33, _41_42_43),
				    
				    -minor(_12_13_14, _32_33_34, _42_43_44),
				     minor(_11_13_14, _31_33_34, _41_43_44),
				    -minor(_11_12_14, _31_32_34, _41_42_44),
				     minor(_11_12_13, _31_32_33, _41_42_43),
				    
				     minor(_12_13_14, _22_23_24, _42_43_44),
				    -minor(_11_13_14, _21_23_24, _41_43_44),
				     minor(_11_12_14, _21_22_24, _41_42_44),
				    -minor(_11_12_13, _21_22_23, _41_42_43),
				    
				    -minor(_12_13_14, _22_23_24, _32_33_34),
				     minor(_11_13_14, _21_23_24, _31_33_34),
				    -minor(_11_12_14, _21_22_24, _31_32_34),
				     minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

            v2f vert(a2v v) 
            {
                v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);

                // 我们使用了2张纹理，因此需要存储2个纹理坐标。
                // 实际上，_MainTex 和 _BumpMap 通常会使用同一组纹理坐标，出于减少插值寄存器的使用数目的目的，我们往往只计算和存储一个纹理坐标即可。
                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                ///
				/// Note that the code below can handle both uniform and non-uniform scales
				///

				// // Construct a matrix that transforms a point/vector from tangent space to world space
				// fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				// fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				// fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

				// /*
				// float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
				// 								   worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
				// 								   worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
				// 								   0.0, 0.0, 0.0, 1.0);
				// // The matrix that transforms from world space to tangent space is inverse of tangentToWorld
				// float3x3 worldToTangent = inverse(tangentToWorld);
				// */
				
				// //wToT = the inverse of tToW = the transpose(转置) of tToW as long as tToW is an orthogonal(正交) matrix.
				// float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

				// // Transform the light and view dir from world space to tangent space
				// o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
				// o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

                ///
				/// Note that the code below can only handle uniform scales, not including non-uniform scales
				/// 

				// Compute the binormal(计算副法线)
                // 需要使用 tangent.w 分量来决定切线空间中的第三个坐标轴——副切线的方向性。
				float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w;
				// Construct a matrix which transform vectors from object space to tangent space
				float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
				// Or just use the built-in macro
				// TANGENT_SPACE_ROTATION;
				
				// Transform the light direction from object space to tangent space
				o.lightDir = mul(rotation, normalize(ObjSpaceLightDir(v.vertex))).xyz;
				// Transform the view direction from object space to tangent space
				o.viewDir = mul(rotation, normalize(ObjSpaceViewDir(v.vertex))).xyz;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target 
            {				
				fixed3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentViewDir = normalize(i.viewDir);
				
				// Get the texel in the normal map
                // 利用 tex2D 对法线纹理 _BumpMap 进行采样
				fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
				fixed3 tangentNormal;
				// If the texture is not marked as "Normal map"
                // 没有将 Textrue Type 标记为“Normal Map”，需要手动从像素值反映射到法线向量。
                //tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;
                //tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				// Or mark the texture as "Normal map", and use the built-in funciton
				tangentNormal = UnpackNormal(packedNormal);
				tangentNormal.xy *= _BumpScale; // 乘以凹凸程度
                // 由于法线都是单位矢量，因此tangentNormal.z分量可以由tangentNormal.xy计算而得。
				tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
				
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

				fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}