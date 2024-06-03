// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter12/02_EdgeDetection"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {} // _MainTex对应了输入的渲染纹理
		_EdgeOnly ("Edge Only", Float) = 1.0
		_EdgeColor ("Edge Color", Color) = (0, 0, 0, 1)
		_BackgroundColor ("Background Color", Color) = (1, 1, 1, 1)
	}

    SubShader
    {
        Pass
        {
            ZTest Always 
            Cull Off 
            ZWrite Off
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			
			#pragma vertex vert  
			#pragma fragment fragSobel
			
			sampler2D _MainTex;  
			// xxx_TexelSize是Unity为我们提供的访问xxx纹理对应的每个纹素的大小。例如，一张512×512大小的纹理，该值大约为0.001953（即1/512）。
            // 由于卷积需要对相邻区域内的纹理进行采样，因此我们需要利用_MainTex_TexelSize来计算各个相邻区域的纹理坐标。
            // about "uniform":
            // If you supply it as a variable in the method, you have to explicitly set it to uniform. 
            // (But this is generally never used, because global variables are easier to read.)
            uniform half4 _MainTex_TexelSize;
			fixed _EdgeOnly;
			fixed4 _EdgeColor;
			fixed4 _BackgroundColor;
			
			struct v2f {
				float4 pos : SV_POSITION;
				half2 uv[9] : TEXCOORD0; // 定义了维数为9的纹理数组，对应了使用Sobel算子采样时需要的9个邻域纹理坐标。
			};

            v2f vert(appdata_img v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				half2 uv = v.texcoord;
				
                // 计算了边缘检测时需要的纹理坐标
                // 通过把计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算，提高性能。
                // 由于从顶点着色器到片元着色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果。
				o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
				o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
				o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
				o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
				o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
				o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
				o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
				o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
				o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);
						 
				return o;
			}
            
            // 计算亮度值
            fixed luminance(fixed4 color) 
            {
				return  0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b; 
			}

            // Sobel函数将利用Sobel算子对原图进行边缘检测
            half Sobel(v2f i) 
            {
                // 首先定义了水平方向和竖直方向使用的卷积核Gx和Gy
				const half Gx[9] = {-1,  0,  1,
									-2,  0,  2,
									-1,  0,  1};
				const half Gy[9] = {-1, -2, -1,
									0,  0,  0,
									1,  2,  1};		
				
				half texColor;
				half edgeX = 0;
				half edgeY = 0;
                // 我们依次对9个像素进行采样，计算它们的亮度值，再与卷积核Gx和Gy中对应的权重相乘后，叠加到各自的梯度值上。
				for (int it = 0; it < 9; it++) {
					texColor = luminance(tex2D(_MainTex, i.uv[it]));
					edgeX += texColor * Gx[it];
					edgeY += texColor * Gy[it];
				}
				
                // 最后，我们从1中减去水平方向和竖直方向的梯度值的绝对值，得到edge。edge值越小，表明该位置越可能是一个边缘点。
                // edge越小，说明"abs(edgeX) + abs(edgeY)"越大。（G ~= |Gx| + |Gy|）
                // 为什么需要“1-G”？可能是为了下面的插值计算服务。
				half edge = 1 - abs(edgeX) - abs(edgeY);
				
				return edge;
			}

            fixed4 fragSobel(v2f i) : SV_Target 
            {
                // 调用Sobel函数计算当前像素的梯度值edge
				half edge = Sobel(i);
				
                // 并利用该edge值分别计算了背景为原图和纯色下的颜色值，然后利用_EdgeOnly在两者之间插值得到最终的像素值。
				fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);
				fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge); 
				return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
 			}

            ENDCG
        }
    }

    FallBack Off
}