// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// 逐顶点的漫反射光照
Shader "UnityShadersBook/Chapter06/01_DiffuseVertexLevel"
{
    Properties
    {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
	}

    SubShader
    {
        pass
        {
            Tags
            {
                // 定义该 pass 在unity光照流水线中的角色
                // 只有定义了正确的 LightMode，我们才能获得一些unity的内置光照变量，例如下面的 _LightColor0。
                "LightMode"="ForwardBase"
            }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Diffuse;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
                fixed3 color : COLOR;
            };

            // 在顶点着色器中，计算漫反射光照模型
            v2f vert(a2v v)
            {
                v2f o;
                // Transform the vertex from object space to projection space
                o.pos = UnityObjectToClipPos(v.vertex);

                // Get ambient term
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // Transform the normal from object space to world space
                // 使用顶点变换的逆转置矩阵对法线进行相同的变换。
				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
                // Get the light direction in world space
                // 光源方向可以由 _WorldSpaceLightPos0 得到。需要注意，这里对光源方向的计算并不具有通用性。
				fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                // Compute diffuse term
                // unity提供内置变量 _LightColor0 来访问该 Pass 处理的光源的颜色和强度信息。
                // saturate 函数将参数截取在[0, 1]范围内，如果参数是一个矢量，那么会对每一个分量进行这样的操作。
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight)); // 漫反射公式

                o.color = ambient + diffuse;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target 
            {
				return fixed4(i.color, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Diffuse"
}