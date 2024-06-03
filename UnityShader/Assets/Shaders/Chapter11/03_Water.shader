// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter11/03_Water"
{
    Properties 
    {
		_MainTex ("Main Tex", 2D) = "white" {}  // _MainTex是河流纹理 
		_Color ("Color Tint", Color) = (1, 1, 1, 1) // _Color用于控制整体颜色
		_Magnitude ("Distortion Magnitude", Float) = 1 // _Magnitude用于控制水流波动的幅度
 		_Frequency ("Distortion Frequency", Float) = 1 // _Frequency用于控制波动频率
 		_InvWaveLength ("Distortion Inverse Wave Length", Float) = 10 // _InvWaveLength用于控制波长的倒数（_InvWaveLength越大，波长越小）
 		_Speed ("Speed", Float) = 0.5 // _Speed用于控制河流纹理的移动速度。
	}

    SubShader
    {
        // Need to disable batching because of the vertex animation
        // 一些SubShader在使用Unity的批处理功能时会出现问题，这时可以通过该标签来直接指明是否对该SubShader使用批处理。
        // 而这些需要特殊处理的Shader通常就是指包含了模型空间的顶点动画的Shader。
        // 这是因为，批处理会合并所有相关的模型，而这些模型各自的模型空间就会丢失。
        // 而在本例中，我们需要在物体的模型空间下对顶点位置进行偏移。因此，在这里需要取消对该Shader的批处理操作。
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Off // 关闭了剔除功能。这是为了让水流的每个面都能显示。
			
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
			
            // 在顶点着色器中进行了相关的顶点动画
			v2f vert(a2v v) 
            {
				v2f o;
				
				float4 offset;
                // 我们只希望对顶点的x方向进行位移，因此yzw的位移量被设置为0。
				offset.yzw = float3(0.0, 0.0, 0.0);
                // 利用_Frequency属性和内置的_Time.y变量来控制正弦函数的频率。
                // 为了让不同位置具有不同的位移，我们对上述结果加上了模型空间下的位置分量，并乘以_InvWaveLength来控制波长。
                // 最后，我们对结果值乘以_Magnitude属性来控制波动幅度，得到最终的位移。
				// y = sin(ax + b); 其中：x = 顶点(x, y, z)
				offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;
				
                // 剩下的工作，我们只需要把位移量添加到顶点位置上，再进行正常的顶点变换即可。
                o.pos = UnityObjectToClipPos(v.vertex + offset);
				
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                // 我们还进行了纹理动画，即使用_Time.y和_Speed来控制在水平方向上的纹理动画。
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
    }

    FallBack "Transparent/VertexLit"
}