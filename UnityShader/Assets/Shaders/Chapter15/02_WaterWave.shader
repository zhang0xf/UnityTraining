// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter15/02_WaterWave"
{
    Properties 
    {
        
		_Color ("Main Color", Color) = (0, 0.15, 0.115, 1) //  _Color用于控制水面颜色；
		_MainTex ("Base (RGB)", 2D) = "white" {} // _MainTex是水面波纹材质纹理，默认为白色纹理；
		_WaveMap ("Wave Map", 2D) = "bump" {} // _WaveMap是一个由噪声纹理生成的法线纹理；
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {} // _Cubemap是用于模拟反射的立方体纹理；
		_WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01 // //_WaveXSpeed和_WaveYSpeed分别用于控制法线纹理在X和Y方向上的平移速度。
		_WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
		_Distortion ("Distortion", Range(0, 100)) = 10 // _Distortion则用于控制模拟折射时图像的扭曲程度；
	}

    SubShader
    {
        // 定义相应的渲染队列，并使用GrabPass来获取屏幕图像
        // 把Queue设置成Transparent可以确保该物体渲染时，其他所有不透明物体都已经被渲染到屏幕上了，否则就可能无法正确得到“透过水面看到的图像”。
        // 而设置RenderType则是为了在使用着色器替换（Shader Replacement）时，该物体可以在需要时被正确渲染。这通常发生在我们需要得到摄像机的深度和法线纹理时
        // We must be transparent, so other objects are drawn before this one.
		Tags { "Queue"="Transparent" "RenderType"="Opaque" }
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		GrabPass { "_RefractionTex" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _WaveMap;
			float4 _WaveMap_ST;
			samplerCUBE _Cubemap;
			fixed _WaveXSpeed;
			fixed _WaveYSpeed;
			float _Distortion;
            // _RefractionTex和_RefractionTex_TexelSize变量，这对应了在使用GrabPass时，指定的纹理名称。
            // _RefractionTex_TexelSize可以让我们得到该纹理的纹素大小，例如一个大小为256×512的纹理，它的纹素大小为(1/256, 1/512)。
            // 我们需要在对屏幕图像的采样坐标进行偏移时使用该变量。	
			sampler2D _RefractionTex;
			float4 _RefractionTex_TexelSize;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
				float4 TtoW1 : TEXCOORD3;  
				float4 TtoW2 : TEXCOORD4; 
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
                // 通过调用ComputeGrabScreenPos来得到对应被抓取屏幕图像的采样坐标。
                // 它的主要代码和ComputeScreenPos基本类似，最大的不同是针对平台差异造成的采样坐标问题（见5.6.1节）进行了处理。
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
                // 由于我们需要在片元着色器中把法线方向从切线空间（由法线纹理采样得到）变换到世界空间下，以便对Cubemap进行采样，
                // 因此，我们需要在这里计算该顶点对应的从切线空间到世界空间的变换矩阵，并把该矩阵的每一行分别存储在TtoW0、TtoW1和TtoW2的xyz分量中。
				// TtoW0等值的w分量同样被利用起来，用于存储世界空间下的顶点坐标。
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                // 使用内置的_Time.y变量和_WaveXSpeed、_WaveYSpeed属性计算了法线纹理的当前偏移量，

				float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
				
				// Get the normal in tangent space
                //并利用该值对法线纹理进行两次采样（这是为了模拟两层交叉的水面波动的效果），对两次结果相加并归一化后得到切线空间下的法线方向。
				fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
				fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
				fixed3 bump = normalize(bump1 + bump2);
				
                // _Distortion值越大，偏移量越大，水面背后的物体看起来变形程度越大。
                // 我们选择使用切线空间下的法线方向来进行偏移，是因为该空间下的法线可以反映顶点局部空间下的法线方向
				// Compute the offset in tangent space
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                // 在计算偏移后的屏幕坐标时，我们把偏移量和屏幕坐标的z分量相乘，这是为了模拟深度越大、折射程度越大的效果。
                // 如果读者不希望产生这样的效果，可以直接把偏移值叠加到屏幕坐标上。
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                // 我们对scrPos进行了透视除法，再使用该坐标对抓取的屏幕图像_RefractionTex进行采样，得到模拟的折射颜色。
				fixed3 refrCol = tex2D( _RefractionTex, i.scrPos.xy/i.scrPos.w).rgb;
				
                // 我们把法线方向从切线空间变换到了世界空间下
                //（使用变换矩阵的每一行，即TtoW0、TtoW1和TtoW2，分别和法线方向点乘，构成新的法线方向）
				// Convert the normal to world space
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed); // 我们也对主纹理进行了纹理动画，以模拟水波的效果。
                // 并据此得到视角方向相对于法线方向的反射方向。
				fixed3 reflDir = reflect(-viewDir, bump);
                // 随后，使用反射方向对Cubemap进行采样，并把结果和主纹理颜色相乘后得到反射颜色。
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb * _Color.rgb;
				
                // 为了混合折射和反射颜色，我们随后计算了菲涅耳系数。
                // 我们使用之前的公式来计算菲涅耳系数，并据此来混合折射和反射颜色，作为最终的输出颜色。
				fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
				fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
        }
    }

    // Do not cast shadow
	FallBack Off
}