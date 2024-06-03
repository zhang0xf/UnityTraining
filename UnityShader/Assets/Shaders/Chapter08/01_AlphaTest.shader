// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 透明度测试
Shader "UnityShadersBook/Chapter08/01_AplhaTest"
{
    Properties 
    {
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5 // 为了在材质面板中控制透明度测试时使用的阈值
        // _Cutoff参数用于决定我们调用clip进行透明度测试时使用的判断条件。它的范围是[0,1]，这是因为纹理像素的透明度就是在此范围内。
	}

    SubShader
    {
        Tags 
        {
            // 在Unity中透明度测试使用的渲染队列是名为AlphaTest的队列
            "Queue"="AlphaTest"
            // 把IgnoreProjector设置为True，这意味着这个Shader不会受到投影器（Projectors）的影响。
            "IgnoreProjector"="True"
            // RenderType标签可以让Unity把这个Shader归入到提前定义的组（这里就是TransparentCutout组）中，
            // 以指明该Shader是一个使用了透明度测试的Shader。RenderType标签通常被用于着色器替换功能。
            "RenderType"="TransparentCutout"
            // 通常，使用了透明度测试的Shader都应该在SubShader中设置这三个标签。
        }

        pass
        {
            Tags { "LightMode"="ForwardBase" }

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
				
				// Alpha test
                // clip函数：如果给定参数的任何一个分量是负数，就会舍弃当前像素的输出颜色。
                // void clip(float4 x); 
                // void clip(float3 x); 
                // void clip(float2 x); 
                // void clip(float1 x); 
                // void clip(float x);
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

    // 我们使用内置的Transparent/Cutout/VertexLit来作为回调Shader。
    // 这不仅能够保证在我们编写的SubShader无法在当前显卡上工作时可以有合适的代替Shader，
    // 还可以保证使用透明度测试的物体可以正确地向其他物体投射阴影
    FallBack "Transparent/Cutout/VertexLit"
}