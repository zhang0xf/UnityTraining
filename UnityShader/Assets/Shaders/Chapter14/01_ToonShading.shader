// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter14/01_ToonShading"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Ramp ("Ramp Texture", 2D) = "white" {} // _Ramp是用于控制漫反射色调的渐变纹理
		_Outline ("Outline", Range(0, 1)) = 0.1 // _Outline用于控制轮廓线宽度
		_OutlineColor ("Outline Color", Color) = (0, 0, 0, 1) // _OutlineColor对应了轮廓线颜色
		_Specular ("Specular", Color) = (1, 1, 1, 1) // _Specular是高光反射颜色
		_SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01 // _SpecularScale用于控制计算高光反射时使用的阈值
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass
        {
            // 使用NAME命令为该Pass定义了名称。这是因为，描边在非真实感渲染中是非常常见的效果，
            // 为该Pass定义名称可以让我们在后面的使用中不需要再重复编写此Pass，而只需要调用它的名字即可。
            NAME "OUTLINE"
			
            // 这个Pass只渲染背面的三角面片，因此，我们需要设置正确的渲染状态.
			Cull Front
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			float _Outline;
			fixed4 _OutlineColor;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			}; 
			
			struct v2f {
			    float4 pos : SV_POSITION;
			};

            v2f vert (a2v v) 
            {
				v2f o;
				
                // 在顶点着色器中我们首先把顶点和法线变换到视角空间下，这是为了让描边可以在观察空间达到最好的效果。
				float4 pos = mul(UNITY_MATRIX_MV, v.vertex); 
				float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                // 设置法线的z分量，对其归一化后再将顶点沿其方向扩张，得到扩张后的顶点坐标。
                // 对法线的处理是为了尽可能避免背面扩张后的顶点挡住正面的面片。
				normal.z = -0.5;
				pos = pos + float4(normalize(normal), 0) * _Outline;
                // 最后，我们把顶点从视角空间变换到裁剪空间。
				o.pos = mul(UNITY_MATRIX_P, pos);
				
				return o;
			}
			
			float4 frag(v2f i) : SV_Target 
            { 
				return float4(_OutlineColor.rgb, 1);               
			}
			
			ENDCG
        }

        Pass
        {
            // 定义光照模型所在的Pass，以渲染模型的正面。
            // 由于光照模型需要使用Unity提供的光照等信息，我们需要为Pass进行相应的设置，并添加相应的编译指令：
            Tags { "LightMode"="ForwardBase" }

            Cull Back
		
			CGPROGRAM
		
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_fwdbase
		
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Ramp;
			fixed4 _Specular;
			fixed _SpecularScale;
		
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0;
				float4 tangent : TANGENT;
			}; 

            struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
				float3 worldNormal : TEXCOORD1;
				float3 worldPos : TEXCOORD2;
				SHADOW_COORDS(3)
			};
			
			v2f vert (a2v v) 
            {
				v2f o;
				
                // 计算了世界空间下的法线方向和顶点位置，并使用Unity提供的内置宏SHADOW_COORDS和TRANSFER_SHADOW来计算阴影所需的各个变量。
				o.pos = UnityObjectToClipPos( v.vertex);
				o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
				o.worldNormal  = UnityObjectToWorldNormal(v.normal);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				TRANSFER_SHADOW(o);
				
				return o;
			}

            float4 frag(v2f i) : SV_Target 
            { 
                // 我们计算了光照模型中需要的各个方向矢量，并对它们进行了归一化处理。
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
				
                // 我们计算了材质的反射率albedo和环境光照ambient。
				fixed4 c = tex2D (_MainTex, i.uv);
				fixed3 albedo = c.rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
                // 我们使用内置的UNITY_LIGHT_ATTENUATION宏来计算当前世界坐标下的阴影值。
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
                // 我们计算了半兰伯特漫反射系数，并和阴影值相乘得到最终的漫反射系数。
				fixed diff =  dot(worldNormal, worldLightDir);
				diff = (diff * 0.5 + 0.5) * atten;
				
                // 我们使用这个漫反射系数对渐变纹理_Ramp进行采样，并将结果和材质的反射率、光照颜色相乘，作为最后的漫反射光照。
				fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;
				
                // 高光反射的计算
				fixed spec = dot(worldNormal, worldHalfDir);
                // 使用fwidth对高光区域的边界进行抗锯齿处理，并将计算而得的高光反射系数和高光反射颜色相乘，得到高光反射的光照部分。
				fixed w = fwidth(spec) * 2.0;
                // 值得注意的是，我们在最后还使用了step(0.0001, _SpecularScale)，这是为了在_SpecularScale为0时，可以完全消除高光反射的光照。
				fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}
		
			ENDCG
        }
    }

    // 这对产生正确的阴影投射效果很重要
    FallBack "Diffuse"
}