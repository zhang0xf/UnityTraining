// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter11/04_Billboard"
{
    Properties 
    {
		_MainTex ("Main Tex", 2D) = "white" {} // _MainTex是广告牌显示的透明纹理
		_Color ("Color Tint", Color) = (1, 1, 1, 1) // _Color用于控制显示整体颜色
        // _VerticalBillboarding则用于调整是固定法线还是固定指向上的方向，即约束垂直方向的程度
		_VerticalBillboarding ("Vertical Restraints", Range(0, 1)) = 1 
	}

    SubShader
    {
        // Need to disable batching because of the vertex animation
        // 一些SubShader在使用Unity的批处理功能时会出现问题，这时可以通过该标签来直接指明是否对该SubShader使用批处理。
        // 而这些需要特殊处理的Shader通常就是指包含了模型空间的顶点动画的Shader。
        // 这是因为，批处理会合并所有相关的模型，而这些模型各自的模型空间就会被丢失。
        // 而在广告牌技术中，我们需要使用物体的模型空间下的位置来作为锚点进行计算。因此。在这里需要取消对该Shader的批处理操作。
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off // 关闭了剔除功能。这是为了让广告牌的每个面都能显示。
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"

            sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed _VerticalBillboarding;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

            v2f vert (a2v v) 
            {
				v2f o;
				
				// Suppose the center in object space is fixed
                // 我们首先选择模型空间的原点作为广告牌的锚点，并利用内置变量获取模型空间下的视角位置
				float3 center = float3(0, 0, 0);
				float3 viewer = mul(unity_WorldToObject,float4(_WorldSpaceCameraPos, 1));
				
				float3 normalDir = viewer - center;
				// If _VerticalBillboarding equals 1, we use the desired view dir as the normal dir
				// Which means the normal dir is fixed
				// Or if _VerticalBillboarding equals 0, the y of normal is 0
				// Which means the up dir is fixed
				normalDir.y =normalDir.y * _VerticalBillboarding;
				normalDir = normalize(normalDir);
				// Get the approximate up dir
				// If normal dir is already towards up, then the up dir is towards front
				float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
				float3 rightDir = normalize(cross(upDir, normalDir));
				upDir = normalize(cross(normalDir, rightDir));
				
				// Use the three vectors to rotate the quad
				float3 centerOffs = v.vertex.xyz - center;
				float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
              
				o.pos = UnityObjectToClipPos(float4(localPos, 1));
				o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);

				return o;
			}

            fixed4 frag (v2f i) : SV_Target 
            {
				fixed4 c = tex2D (_MainTex, i.uv);
				c.rgb *= _Color.rgb;
				
				return c;
			}
			
            ENDCG
        }
    }

    FallBack "Transparent/VertexLit"
}