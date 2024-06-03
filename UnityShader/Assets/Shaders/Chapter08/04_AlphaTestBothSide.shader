// 双面渲染的透明度测试
Shader "UnityShadersBook/Chapter08/04_AplhaTestBothSide"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5 
	}

    SubShader
    {
        Tags 
        {
            "Queue"="AlphaTest"
            "IgnoreProjector"="True"
            "RenderType"="TransparentCutout"
        }

        pass
        {
            Tags { "LightMode"="ForwardBase" }

            // Turn off culling
            // 关闭剔除功能
			Cull Off

            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed _Cutoff; // 由于_Cutoff的范围在[0, 1]，因此我们可以使用fixed精度来存储它。

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
				
				clip (texColor.a - _Cutoff);
				// Equal to 
				// if ((texColor.a - _Cutoff) < 0.0) {
				// 	discard; // 使用 discard 指令来显示剔除该片元。
				// }
				
				fixed3 albedo = texColor.rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(worldNormal, worldLightDir));
				
				return fixed4(ambient + diffuse, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Transparent/Cutout/VertexLit"
}