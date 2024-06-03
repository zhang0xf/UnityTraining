// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter10/01_Reflection"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_ReflectColor ("Reflection Color", Color) = (1, 1, 1, 1) // _ReflectColor用于控制反射颜色
		_ReflectAmount ("Reflect Amount", Range(0, 1)) = 1 // _ReflectAmount用于控制这个材质的反射程度
		_Cubemap ("Reflection Cubemap", Cube) = "_Skybox" {} // _Cubemap就是用于模拟反射的环境映射纹理
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
			fixed4 _ReflectColor;
			fixed _ReflectAmount;
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
				fixed3 worldRefl : TEXCOORD3;
				SHADOW_COORDS(4)
			};

            v2f vert(a2v v) 
            {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
				
				// Compute the reflect dir in world space
                // 物体反射到摄像机中的光线方向，可以由光路可逆的原则来反向求得
                // 也就是说，我们可以计算视角方向关于顶点法线的反射方向来求得入射光线的方向。
				o.worldRefl = reflect(-o.worldViewDir, o.worldNormal);
				
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
				
				// Use the reflect dir in world space to access the cubemap
                // 在上面的计算中，我们在采样时并没有对i.worldRefl进行归一化操作。
                // 这是因为，用于采样的参数仅仅是作为方向变量传递给texCUBE函数的，因此我们没有必要进行一次归一化的操作。
				fixed3 reflection = texCUBE(_Cubemap, i.worldRefl).rgb * _ReflectColor.rgb;
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				// Mix the diffuse color with the reflected color
                // 使用_ReflectAmount来混合漫反射颜色和反射颜色，并和环境光照相加后返回
				fixed3 color = ambient + lerp(diffuse, reflection, _ReflectAmount) * atten;
				
				return fixed4(color, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Reflective/VertexLit"
}