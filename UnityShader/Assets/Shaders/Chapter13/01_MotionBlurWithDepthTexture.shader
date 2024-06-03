// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter13/01_MotionBlurWithDepthTexture"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}

    SubShader
    {
        CGINCLUDE
		
		#include "UnityCG.cginc"
		
		sampler2D _MainTex;
        // _MainTex_TexelSize变量，它对应了主纹理的纹素大小，我们需要使用该变量来对深度纹理的采样坐标进行平台差异化处理
		half4 _MainTex_TexelSize;
        // _CameraDepthTexture是Unity传递给我们的深度纹理，
        // 而_CurrentViewProjectionInverseMatrix和_PreviousViewProjectionMatrix是由脚本传递而来的矩阵。
		sampler2D _CameraDepthTexture;
		float4x4 _CurrentViewProjectionInverseMatrix;
		float4x4 _PreviousViewProjectionMatrix;
		half _BlurSize;
		
		struct v2f {
			float4 pos : SV_POSITION;
			half2 uv : TEXCOORD0;
			half2 uv_depth : TEXCOORD1; // 增加了专门用于对深度纹理采样的纹理坐标变量
		};

        v2f vert(appdata_img v) 
        {
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			
			o.uv = v.texcoord;
			o.uv_depth = v.texcoord;
			
            // 由于在本例中，我们需要同时处理多张渲染纹理，因此在DirectX这样的平台上，我们需要处理平台差异导致的图像翻转问题。
			#if UNITY_UV_STARTS_AT_TOP
			if (_MainTex_TexelSize.y < 0)
				o.uv_depth.y = 1 - o.uv_depth.y;
			#endif
					 
			return o;
		}
        
        fixed4 frag(v2f i) : SV_Target 
        {
			// Get the depth buffer value at this pixel.
			float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
            // d是由NDC下的坐标映射而来的。我们想要构建像素的NDC坐标H，就需要把这个深度值重新映射回NDC。
            // 这个映射很简单，只需要使用原映射的反函数即可，即d*2-1。 同样，NDC的xy分量可以由像素的纹理坐标映射而来（NDC下的xyz分量范围均为[-1,1]）。
			// H is the viewport position at this pixel in the range -1 to 1.
			float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);
            // 当得到NDC下的坐标H后，我们就可以使用当前帧的视角*投影矩阵的逆矩阵对其进行变换，
			// Transform by the view-projection inverse.
			float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
            // 并把结果值除以它的w分量来得到世界空间下的坐标表示worldPos。
			// Divide by w to get the world position. 
			float4 worldPos = D / D.w;
			
			// Current viewport position 
			float4 currentPos = H;
            // 一旦得到了世界空间下的坐标，我们就可以使用前一帧的视角*投影矩阵对它进行变换，得到前一帧在NDC下的坐标previousPos。
			// Use the world position, and transform by the previous view-projection matrix.  
			float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
			// Convert to nonhomogeneous points [-1,1] by dividing by w.
			previousPos /= previousPos.w;
			
            // 然后，我们计算前一帧和当前帧在屏幕空间下的位置差，得到该像素的速度velocity。
			// Use this frame's position and last frame's to compute the pixel velocity.
			float2 velocity = (currentPos.xy - previousPos.xy)/2.0f;
			
			float2 uv = i.uv;
			float4 c = tex2D(_MainTex, uv);
			uv += velocity * _BlurSize;
			for (int it = 1; it < 3; it++, uv += velocity * _BlurSize) {
				float4 currentColor = tex2D(_MainTex, uv);
				c += currentColor;
			}
			c /= 3;
			
			return fixed4(c.rgb, 1.0);
		}
		
		ENDCG

        Pass {      
			ZTest Always 
            Cull Off 
            ZWrite Off
			    	
			CGPROGRAM  
			
			#pragma vertex vert  
			#pragma fragment frag  
			  
			ENDCG  
		}
    }

    FallBack Off
}