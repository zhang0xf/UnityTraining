// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
// 阴影投射的重点在于我们需要按正常Pass的处理来剔除片元或进行顶点动画，以便阴影可以和物体正常渲染的结果相匹配。
Shader "UnityShadersBook/Chapter11/05_VertexAnimationWithShadow"
{
    Properties {
		_MainTex ("Main Tex", 2D) = "white" {}
		_Color ("Color Tint", Color) = (1, 1, 1, 1)
		_Magnitude ("Distortion Magnitude", Float) = 1
 		_Frequency ("Distortion Frequency", Float) = 1
 		_InvWaveLength ("Distortion Inverse Wave Length", Float) = 10
 		_Speed ("Speed", Float) = 0.5
	}

    SubShader
    {
        // Need to disable batching because of the vertex animation
		Tags {"DisableBatching"="True"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
			
			Cull Off
			
			CGPROGRAM  
			#pragma vertex vert 
			#pragma fragment frag
			
			#include "UnityCG.cginc" 
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			float _Magnitude;
			float _Frequency;
			float _InvWaveLength;
			float _Speed;

            struct a2v {
			    float4 vertex : POSITION;
			    float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
			    float4 pos : SV_POSITION;
			    float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) 
            {
				v2f o;
				
				float4 offset;
				offset.yzw = float3(0.0, 0.0, 0.0);
				offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
				o.pos = UnityObjectToClipPos(v.vertex + offset);
				
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv +=  float2(0.0, _Time.y * _Speed);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed4 c = tex2D(_MainTex, i.uv);
				c.rgb *= _Color.rgb;
				
				return c;
			} 

            ENDCG
        }

        // Pass to render object as a shadow caster
		Pass
        {
            Tags { "LightMode" = "ShadowCaster" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"
			
			float _Magnitude;
			float _Frequency;
			float _InvWaveLength;
			float _Speed;
			
			struct v2f { 
			    V2F_SHADOW_CASTER; // 阴影投射需要定义的变量
			};
            
            // 这些宏里需要使用一些特定的输入变量，因此我们需要保证为它们提供了这些变量。
            // 例如，TRANSFER_SHADOW_CASTER_NORMALOFFSET 会使用名称v作为输入结构体，
            // v中需要包含顶点位置v.vertex和顶点法线v.normal的信息，我们可以直接使用内置的appdata_base结构体，它包含了这些必需的顶点变量。
            v2f vert(appdata_base v) 
            {
				v2f o;
				
                // 首先按之前对顶点的处理方法计算顶点的偏移量，
				float4 offset;
				offset.yzw = float3(0.0, 0.0, 0.0);
				offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
				 // 不同的是，我们直接把偏移值加到顶点位置变量中，再使用 TRANSFER_SHADOW_CASTER_NORMALOFFSET 来让Unity为我们完成剩下的事情。
                v.vertex = v.vertex + offset;

				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target 
            {
                // 使用 SHADOW_CASTER_FRAGMENT 来让Unity自动完成阴影投射的部分，把结果输出到深度图和阴影映射纹理中。
			    SHADOW_CASTER_FRAGMENT(i)
			}

            ENDCG
        }
    }

    FallBack "VertexLit"
}