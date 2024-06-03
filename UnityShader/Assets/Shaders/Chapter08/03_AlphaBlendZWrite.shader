// 开启深度写入的透明度混合
Shader "UnityShadersBook/Chapter08/03_AplhaBlendZWrite"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_AlphaScale ("Alpha Scale", Range(0, 1)) = 1 // _AlphaScale用于在透明纹理的基础上控制整体的透明度。
	}

    SubShader
    {
        Tags 
        {
            "Queue"="Transparent" 
            "IgnoreProjector"="True" 
            "RenderType"="Transparent"
        }

        // Extra pass that renders to depth buffer only
        // 新添加的Pass的目的仅仅是为了把模型的深度信息写入深度缓冲中，从而剔除模型中被自身遮挡的片元。
        // Pass的第一行开启了深度写入。
        // 在第二行，我们使用了一个新的渲染命令——ColorMask。在ShaderLab中，ColorMask用于设置颜色通道的写掩码（write mask）。
        // ColorMask语义：ColorMask RGB | A | 0 | 其他任何R、G、B、A的组合​​
        // 当ColorMask设为0时，意味着该Pass不写入任何颜色通道，即不会输出任何颜色。
        // 这正是我们需要的——该Pass只需写入深度缓存即可。
		Pass {
			ZWrite On
			ColorMask 0
		}

        pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed _AlphaScale;

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
				
                // Transforms 2D UV by scale/bias property
                // #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed4 texColor = tex2D(_MainTex, i.uv);
				
				fixed3 albedo = texColor.rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
			}

            ENDCG
        }
    }
    
    FallBack "Transparent/VertexLit"
}