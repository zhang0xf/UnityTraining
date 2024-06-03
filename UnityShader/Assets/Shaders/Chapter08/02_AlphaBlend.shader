// 透明度混合
Shader "UnityShadersBook/Chapter08/02_AplhaBlend"
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
            // Unity中透明度混合使用的渲染队列是名为Transparent的队列
            "Queue"="Transparent" 
            // IgnoreProjector设置为True，这意味着这个Shader不会受到投影器（Projectors）的影响
            "IgnoreProjector"="True" 
            // RenderType标签可以让Unity把这个Shader归入到提前定义的组（这里就是Transparent组）中，
            // 用来指明该Shader是一个使用了透明度混合的Shader。
            "RenderType"="Transparent"

            // 通常，使用了透明度混合的Shader都应该在SubShader中设置这3个标签。
        }

        pass
        {
            Tags { "LightMode"="ForwardBase" }

            // 把该Pass的深度写入（ZWrite）设置为关闭状态（Off)
            ZWrite Off
            // 开启并设置了该Pass的混合模式
            // 将源颜色（该片元着色器产生的颜色）的混合因子设为SrcAlpha，
            // 把目标颜色（已经存在于颜色缓冲中的颜色）的混合因子设为OneMinusSrcAlpha
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
				
                // 移除了透明度测试的代码，并设置了该片元着色器返回值中的透明通道，它是纹理像素的透明通道和材质参数_AlphaScale的乘积。
				return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
			}

            ENDCG
        }
    }
    
    FallBack "Transparent/VertexLit"
}