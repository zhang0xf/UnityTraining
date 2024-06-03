// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter07/01_SingleTextrue"
{
    Properties
    {
        // 为了控制整体的色调，我们申明了 _Color 属性
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        // 申明一个名为 _MainTex 的纹理，2D 是纹理属性的声明方式。“White”是内置纹理的名字，也就是一个全白纹理。
		_MainTex ("Main Tex", 2D) = "white" {}
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
            // _MainTex_ST 的名字不是随便起的，在Unity中，我们需要使用“纹理名_ST”的方式来声明某个纹理的属性。其中，ST 是缩放（Scale）和平移（translation）的缩写。
            // _MainTex_ST 可以让我们得到该纹理的缩放和平移（偏移）值，_MainTex_ST.xy 存储的是缩放值，而 _MainTex_ST.zw 存储的是偏移值。
            // 这些值可以在材质面板的纹理属性中调节，即 Tiling 和 Offset。
			float4 _MainTex_ST;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 texcoord : TEXCOORD0; // Unity会将模型的第一组纹理坐标存储到该变量
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				float2 uv : TEXCOORD2; // 用于存储纹理坐标的变量，以便片元着色器使用该坐标进行纹理采样。
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
                // 使用纹理的属性值 _MainTex_ST 来对顶点纹理坐标进行变换，得到最终的纹理坐标。
				o.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				// Or just call the built-in function
                // o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}

            // 实现片元着色器，并在计算漫反射时使用纹理中的纹素（类比像素的概念）值
            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				// Use the texture to sample the diffuse color
                // 使用 CG 的 tex2D 函数对纹理进行采样。第一个参数：需要被采样的纹理，第二个参数：float2类型的纹理坐标。将返回计算得到的纹素值。
                // 我们使用采样结果和颜色属性 _Color 的乘积来作为材质的反射率 albedo，并把它和环境光照相乘得到环境光部分。
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }

    Fallback "Specular"
}