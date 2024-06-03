// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter12/01_BrightnessSaturationAndContrast"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {} // 原屏幕图像存储在 _MainTex
        // 事实上，我们可以省略Properties中的属性声明，Properties中声明的属性仅仅是为了显示在材质面板中，
        // 但对于屏幕特效来说，它们使用的材质都是临时创建的，我们也不需要在材质面板上调整参数，而是直接从脚本传递给Unity Shader。
		_Brightness ("Brightness", Float) = 1
		_Saturation("Saturation", Float) = 1
		_Contrast("Contrast", Float) = 1
	}

    SubShader
    {
        Pass
        {
            // 屏幕后处理实际上是在场景中绘制了一个与屏幕同宽同高的四边形面片，为了防止它对其他物体产生影响，我们需要设置相关的渲染状态。
            // 在这里，我们关闭了深度写入，是为了防止它“挡住”在其后面被渲染的物体。
            // 例如，如果当前的OnRenderImage函数在所有不透明的Pass执行完毕后立即被调用，不关闭深度写入就会影响后面透明的Pass的渲染。
            ZTest Always 
            Cull Off 
            ZWrite Off

            CGPROGRAM  
			#pragma vertex vert  
			#pragma fragment frag  
			  
			#include "UnityCG.cginc"  
			  
			sampler2D _MainTex;  
			half _Brightness;
			half _Saturation;
			half _Contrast;

            struct v2f {
				float4 pos : SV_POSITION;
				half2 uv: TEXCOORD0;
			};
			
            // appdata_img结构体
            // 它只包含了图像处理时必需的顶点坐标和纹理坐标等变量
			v2f vert(appdata_img v) 
            {
				v2f o;
				
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv = v.texcoord;
						 
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				fixed4 renderTex = tex2D(_MainTex, i.uv);
				  
				// Apply brightness
                // 调整亮度值
				fixed3 finalColor = renderTex.rgb * _Brightness;
				
				// Apply saturation
                // 计算该像素对应的亮度值（luminance），这是通过对每个颜色分量乘以一个特定的系数再相加得到的。
				fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
                // 使用该亮度值创建了一个饱和度为0的颜色值
				fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
                // 使用_Saturation属性在其和上一步得到的颜色之间进行插值，从而得到希望的饱和度颜色。
				finalColor = lerp(luminanceColor, finalColor, _Saturation);
				
				// Apply contrast
                // 对比度的处理类似，我们首先创建一个对比度为0的颜色值（各分量均为0.5），
                // 再使用_Contrast属性在其和上一步得到的颜色之间进行插值，从而得到最终的处理结果。
				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
				finalColor = lerp(avgColor, finalColor, _Contrast);
				
				return fixed4(finalColor, renderTex.a);  
			}

            ENDCG
        }
    }

    Fallback Off
}