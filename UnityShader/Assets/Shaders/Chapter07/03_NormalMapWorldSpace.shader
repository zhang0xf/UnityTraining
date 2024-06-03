// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter07/03_NormalMapWorldSpace"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
		_MainTex ("Main Tex", 2D) = "white" {}
		_BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Bump Scale", Float) = 1.0
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
    }

    SubShader
    {
        pass
        {
            Tags
            {
                "LightMode"="ForwardBase"
            }

            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"

            fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST; // 得到纹理的属性（平铺和偏移系数）
			sampler2D _BumpMap;
			float4 _BumpMap_ST; // 得到纹理的属性（平铺和偏移系数）
			float _BumpScale;
			fixed4 _Specular;
			float _Gloss;

            struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; // 将顶点的切线方向填充到 tangent 变量中
				float4 texcoord : TEXCOORD0;
			};

            struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
                // 包含从切线空间到世界空间的变换矩阵
                // 寄存器容量有限，矩阵按行拆分为多个变量再进行存储
				float4 TtoW0 : TEXCOORD1; // 第1行
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3; 
			};

            // 计算从切线空间到世界空间的变换矩阵
            v2f vert(a2v v) 
            {
                v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;
				
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// Compute the matrix that transform directions from tangent space to world space
				// Put the world position in w component for optimization
                // 按列摆放的到切线空间到世界空间的变换矩阵
                // 把世界空间下的顶点位置的xyz分量分别存储在了这些变量的w分量中，以便充分利用插值寄存器的存储空间。
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				
				return o;
            }

            fixed4 frag(v2f i) : SV_Target 
            {				
				// Get the position in world space		
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				// Compute the light and view dir in world space
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
                // 使用内置的UnpackNormal函数对法线纹理进行采样和解码
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
				bump.xy *= _BumpScale;
				bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy)));
				// Transform the narmal from tangent space to world space
                // 我们使用TtoW0、TtoW1和TtoW2存储的变换矩阵把法线变换到世界空间下。
                // 这是通过使用点乘操作来实现矩阵的每一行和法线相乘来得到的。
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				
				fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
				
				fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(bump, lightDir));

				fixed3 halfDir = normalize(lightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(bump, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }
    
    FallBack "Specular"
}