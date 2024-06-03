// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter15/01_Dissolve"
{
    Properties 
    {
		_BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0 // _BurnAmount属性用于控制消融程度，当值为0时，物体为正常效果，当值为1时，物体会完全消融。
		_LineWidth("Burn Line Width", Range(0.0, 0.2)) = 0.1 // _LineWidth属性用于控制模拟烧焦效果时的线宽，它的值越大，火焰边缘的蔓延范围越广。
		_MainTex ("Base (RGB)", 2D) = "white" {} // _MainTex和_BumpMap分别对应了物体原本的漫反射纹理和法线纹理。
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BurnFirstColor("Burn First Color", Color) = (1, 0, 0, 1) // _BurnFirstColor和_BurnSecondColor对应了火焰边缘的两种颜色值。
		_BurnSecondColor("Burn Second Color", Color) = (1, 0, 0, 1)
		_BurnMap("Burn Map", 2D) = "white"{} // _BurnMap则是关键的噪声纹理。
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass
        {
            // 为了得到正确的光照，我们设置了Pass的LightMode和multi_compile_fwdbase的编译指令。
            // 值得注意的是，我们还使用Cull命令关闭了该Shader的面片剔除，也就是说，模型的正面和背面都会被渲染。
            // 这是因为，消融会导致裸露模型内部的构造，如果只渲染正面会出现错误的结果。
            Tags { "LightMode"="ForwardBase" }

			Cull Off
			
			CGPROGRAM
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#pragma multi_compile_fwdbase
			
			#pragma vertex vert
			#pragma fragment frag
			
			fixed _BurnAmount;
			fixed _LineWidth;
			sampler2D _MainTex;
			sampler2D _BumpMap;
			fixed4 _BurnFirstColor;
			fixed4 _BurnSecondColor;
			sampler2D _BurnMap;
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			float4 _BurnMap_ST;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uvMainTex : TEXCOORD0;
				float2 uvBumpMap : TEXCOORD1;
				float2 uvBurnMap : TEXCOORD2;
				float3 lightDir : TEXCOORD3;
				float3 worldPos : TEXCOORD4;
				SHADOW_COORDS(5)
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
                // 使用宏TRANSFORM_TEX计算了三张纹理对应的纹理坐标，再把光源方向从模型空间变换到了切线空间。
				o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				TANGENT_SPACE_ROTATION;
  				o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
  				
  				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
  				
  				TRANSFER_SHADOW(o);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
                // 首先对噪声纹理进行采样，并将采样结果和用于控制消融程度的属性_BurnAmount相减，传递给clip函数。
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
                // 当结果小于0时，该像素将会被剔除，从而不会显示到屏幕上。如果通过了测试，则进行正常的光照计算。
				clip(burn.r - _BurnAmount);
				
				float3 tangentLightDir = normalize(i.lightDir);
				fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));
				
                // 首先根据漫反射纹理得到材质的反射率albedo，并由此计算得到环境光照，进而得到漫反射光照。
				fixed3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

                // 然后，我们计算了烧焦颜色burnColor。
                // 我们想要在宽度为_LineWidth的范围内模拟一个烧焦的颜色变化，第一步就使用了smoothstep函数来计算混合系数t。
                // 当t值为1时，表明该像素位于消融的边界处，当t值为0时，表明该像素为正常的模型颜色，而中间的插值则表示需要模拟一个烧焦效果。
				fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
                // 用t来混合两种火焰颜色_BurnFirstColor和_BurnSecondColor
				fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
                // 为了让效果更接近烧焦的痕迹，我们还使用pow函数对结果进行处理。
				burnColor = pow(burnColor, 5);
				
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                // 再次使用t来混合正常的光照颜色（环境光+漫反射）和烧焦颜色。
                // 我们这里又使用了step函数来保证当_BurnAmount为0时，不显示任何消融效果。
				fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, t * step(0.0001, _BurnAmount));
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
        }

        // Pass to render object as a shadow caster
		Pass 
        {
            // 使用透明度测试的物体的阴影需要特别处理，如果仍然使用普通的阴影Pass，那么被剔除的区域仍然会向其他物体投射阴影，造成“穿帮”。
            // 为了让物体的阴影也能配合透明度测试产生正确的效果，我们需要自定义一个投射阴影的Pass：
            Tags { "LightMode" = "ShadowCaster" }

            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#pragma multi_compile_shadowcaster
			
			#include "UnityCG.cginc"
			
			fixed _BurnAmount;
			sampler2D _BurnMap;
			float4 _BurnMap_ST;
			
			struct v2f {
                // 在v2f结构体中利用V2F_SHADOW_CASTER来定义阴影投射需要定义的变量。
				V2F_SHADOW_CASTER;
				float2 uvBurnMap : TEXCOORD1;
			};
			
            // 阴影投射的重点在于我们需要按正常Pass的处理来剔除片元或进行顶点动画，以便阴影可以和物体正常渲染的结果相匹配。
			v2f vert(appdata_base v) 
            {
				v2f o;
				
                // 使用TRANSFER_SHADOW_CASTER_NORMALOFFSET来填充V2F_SHADOW_CASTER在背后声明的一些变量，这是由Unity在背后为我们完成的。
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				
                // 我们需要在顶点着色器中关注自定义的计算部分，这里指的就是我们需要计算噪声纹理的采样坐标uvBurnMap。
				o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);
				
				return o;
			}

            fixed4 frag(v2f i) : SV_Target 
            {
                // 在片元着色器中，我们首先按之前的处理方法使用噪声纹理的采样结果来剔除片元，
				fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
				
				clip(burn.r - _BurnAmount);
				
                //  // 最后再利用SHADOW_CASTER_FRAGMENT来让Unity为我们完成阴影投射的部分，把结果输出到深度图和阴影映射纹理中。
				SHADOW_CASTER_FRAGMENT(i)
			}

			ENDCG
        }
    }

    FallBack "Diffuse"
}