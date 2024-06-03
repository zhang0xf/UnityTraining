// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter14/02_Hatching"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1) // _Color是用于控制模型颜色的属性
		_TileFactor ("Tile Factor", Float) = 1 // _TileFactor是纹理的平铺系数，_TileFactor越大，模型上的素描线条越密
		_Outline ("Outline", Range(0, 1)) = 0.1
        // _Hatch0至_Hatch5对应了渲染时使用的6张素描纹理，它们的线条密度依次增大。
		_Hatch0 ("Hatch 0", 2D) = "white" {}
		_Hatch1 ("Hatch 1", 2D) = "white" {}
		_Hatch2 ("Hatch 2", 2D) = "white" {}
		_Hatch3 ("Hatch 3", 2D) = "white" {}
		_Hatch4 ("Hatch 4", 2D) = "white" {}
		_Hatch5 ("Hatch 5", 2D) = "white" {}
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        // 由于素描风格往往也需要在物体周围渲染轮廓线，因此我们直接使用14.1节中渲染轮廓线的Pass
        UsePass "UnityShadersBook/Chapter14/01_ToonShading/OUTLINE"

        Pass
        {
            // 为了能够正确获取各个光照变量，我们设置了Pass的标签和相关的编译指令：
            Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag 
			
			#pragma multi_compile_fwdbase
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			#include "UnityShaderVariables.cginc"
			
			fixed4 _Color;
			float _TileFactor;
			sampler2D _Hatch0;
			sampler2D _Hatch1;
			sampler2D _Hatch2;
			sampler2D _Hatch3;
			sampler2D _Hatch4;
			sampler2D _Hatch5;

            struct a2v {
				float4 vertex : POSITION;
				float4 tangent : TANGENT; 
				float3 normal : NORMAL; 
				float2 texcoord : TEXCOORD0; 
			};

            // 由于一共声明了6张纹理，这意味着需要6个混合权重，我们把它们存储在两个fixed3类型的变量（hatchWeights0和hatchWeights1）中。
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				fixed3 hatchWeights0 : TEXCOORD1;
				fixed3 hatchWeights1 : TEXCOORD2;
				float3 worldPos : TEXCOORD3;
				SHADOW_COORDS(4)
			};

            v2f vert(a2v v) 
            {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
                // 使用_TileFactor得到了纹理采样坐标。
				o.uv = v.texcoord.xy * _TileFactor;
				
                // 在计算6张纹理的混合权重之前，我们首先需要计算逐顶点光照。
                // 因此，我们使用世界空间下的光照方向和法线方向得到漫反射系数diff。
				fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed diff = max(0, dot(worldLightDir, worldNormal));
				
                // 权重值初始化为0
				o.hatchWeights0 = fixed3(0, 0, 0);
				o.hatchWeights1 = fixed3(0, 0, 0);
				
                // 并把diff缩放到[0, 7]范围，得到hatchFactor。
				float hatchFactor = diff * 7.0;
				
                // 我们把[0, 7]的区间均匀划分为7个子区间，通过判断hatchFactor所处的子区间来计算对应的纹理混合权重。
				if (hatchFactor > 6.0) {
					// Pure white, do nothing
				} else if (hatchFactor > 5.0) {
					o.hatchWeights0.x = hatchFactor - 5.0;
				} else if (hatchFactor > 4.0) {
					o.hatchWeights0.x = hatchFactor - 4.0;
					o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;
				} else if (hatchFactor > 3.0) {
					o.hatchWeights0.y = hatchFactor - 3.0;
					o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;
				} else if (hatchFactor > 2.0) {
					o.hatchWeights0.z = hatchFactor - 2.0;
					o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;
				} else if (hatchFactor > 1.0) {
					o.hatchWeights1.x = hatchFactor - 1.0;
					o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;
				} else {
					o.hatchWeights1.y = hatchFactor;
					o.hatchWeights1.z = 1.0 - o.hatchWeights1.y;
				}

                // 最后，我们计算了顶点的世界坐标，并使用TRANSFER_SHADOW宏来计算阴影纹理的采样坐标。
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				TRANSFER_SHADOW(o);
				
				return o; 
			}

            fixed4 frag(v2f i) : SV_Target 
            {			
                // 当得到了6六张纹理的混合权重后，我们对每张纹理进行采样并和它们对应的权重值相乘得到每张纹理的采样颜色。
				fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
				fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
				fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
				fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
				fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
				fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;
                // 我们还计算了纯白在渲染中的贡献度，这是通过从1中减去所有6张纹理的权重来得到的。
                // 这是因为素描中往往有留白的部分，因此我们希望在最后的渲染中光照最亮的部分是纯白色的。
				fixed4 whiteColor = fixed4(1, 1, 1, 1) * (1 - i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z - 
							i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);
				
                // 最后，我们混合了各个颜色值
				fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
                // 并和阴影值atten、模型颜色_Color相乘后返回最终的渲染结果。
				return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
			}
			
			ENDCG
        }
    }

    FallBack "Diffuse"
}