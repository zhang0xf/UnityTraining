// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter10/05_GlassRefraction"
{
    Properties 
    {
		_MainTex ("Main Tex", 2D) = "white" {} // _MainTex是该玻璃的材质纹理，默认为白色纹理
		_BumpMap ("Normal Map", 2D) = "bump" {} // _BumpMap是玻璃的法线纹理；
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {} // _Cubemap是用于模拟反射的环境纹理；
		_Distortion ("Distortion", Range(0, 100)) = 10 // _Distortion则用于控制模拟折射时图像的扭曲程度
        // _RefractAmount用于控制折射程度，当_RefractAmount值为0时，该玻璃只包含反射效果，当_RefractAmount值为1时，该玻璃只包括折射效果。
		_RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
	}

    SubShader
    {
        // We must be transparent, so other objects are drawn before this one.
        // 把Queue设置成Transparent可以确保该物体渲染时，其他所有不透明物体都已经被渲染到屏幕上了，否则就可能无法正确得到“透过玻璃看到的图像”。
		// 而设置RenderType则是为了在使用着色器替换（Shader Replacement）时，该物体可以在需要时被正确渲染。
        Tags { "Queue"="Transparent" "RenderType"="Opaque" }

        // This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
        // 通过关键词GrabPass定义了一个抓取屏幕图像的Pass
        // 在这个Pass中我们定义了一个字符串，该字符串内部的名称决定了抓取得到的屏幕图像将会被存入哪个纹理中。
        // 实际上，我们可以省略声明该字符串，但直接声明纹理名称的方法往往可以得到更高的性能
		GrabPass { "_RefractionTex" }

        pass
        {
            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
			float _Distortion;
			fixed _RefractAmount;
			sampler2D _RefractionTex;
            // _RefractionTex_TexelSize可以让我们得到该纹理的纹素大小，例如一个大小为256×512的纹理，它的纹素大小为(1/256, 1/512)。
            // 我们需要在对屏幕图像的采样坐标进行偏移时使用该变量。
			float4 _RefractionTex_TexelSize;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
			    float4 TtoW1 : TEXCOORD3;  
			    float4 TtoW2 : TEXCOORD4; 
			};

            v2f vert (a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
                // 通过调用内置的ComputeGrabScreenPos函数来得到对应被抓取的屏幕图像的采样坐标。
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
                // 由于我们需要在片元着色器中把法线方向从切线空间（由法线纹理采样得到）变换到世界空间下，以便对Cubemap进行采样，
                // 因此，我们需要在这里计算该顶点对应的从切线空间到世界空间的变换矩阵，并把该矩阵的每一行分别存储在TtoW0、TtoW1和TtoW2的xyz分量中。
				// 这里面使用的数学方法就是，得到切线空间下的3个坐标轴（xyz轴分别对应了副切线、切线和法线的方向）在世界空间下的表示，再把它们依次按列组成一个变换矩阵即可。
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}

            fixed4 frag (v2f i) : SV_Target 
            {		
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
                // 对法线纹理进行采样，得到切线空间下的法线方向。
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));	
				
				// Compute the offset in tangent space
                // 我们使用该值和_Distortion属性以及_RefractionTex_TexelSize来对屏幕图像的采样坐标进行偏移，模拟折射效果。
                // 我们选择使用切线空间下的法线方向来进行偏移，是因为该空间下的法线可以反映顶点局部空间下的法线方向。
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                // 我们对scrPos透视除法得到真正的屏幕坐标，再使用该坐标对抓取的屏幕图像_RefractionTex进行采样，得到模拟的折射颜色。
				fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy/i.scrPos.w).rgb;
				
				// Convert the normal to world space
                // 把法线方向从切线空间变换到了世界空间下（使用变换矩阵的每一行，即TtoW0、TtoW1和TtoW2，分别和法线方向点乘，构成新的法线方向）
                // 并据此得到视角方向相对于法线方向的反射方向。随后，使用反射方向对Cubemap进行采样，并把结果和主纹理颜色相乘后得到反射颜色。
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed3 reflDir = reflect(-worldViewDir, bump);
				fixed4 texColor = tex2D(_MainTex, i.uv.xy);
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;
				
                // 使用_RefractAmount属性对反射和折射颜色进行混合，作为最终的输出颜色。
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;
				
				return fixed4(finalColor, 1);
			}

            ENDCG
        }
    }

    FallBack "Diffuse"
}