// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// 逐顶点的高光反射光照模型
// 高光效果有比较大的问题，这是因为高光反射部分的计算是非线性的，而在顶点着色器中计算光照再进行插值的过程是线性的。
// 破坏了愿计算的线性关系。就会出现较大的视觉问题。
Shader "UnityShadersBook/Chapter06/04_SpecularVertexLevel"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (1, 1, 1, 1)
        _Specular("Specular", Color) = (1, 1, 1, 1) // 控制材质的高光反射颜色
        _Gloss("Gloss", Range(8.0, 256)) = 20 // 控制高光区域的大小
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

            // 由于颜色属性的范围在0到1之间，因此对于 _Diffuse 和 _Specular 我们可以使用 fixed 精度来存储。
            // 而 _Gloss 的范围很大，因此需要使用 float 精度才来存储。
            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
                float3 color : COLOR;
            };

            // 在顶点着色器中，计算包含高光反射的光照模型
            v2f vert(a2v v)
            {
                v2f o;

                // Transform the vertex from object space to projection space
				o.pos = UnityObjectToClipPos(v.vertex);

                // Get ambient term
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // Transform the normal from object space to world space
				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				// Get the light direction in world space
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                // Compute diffuse term
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                // 函数reflect(i,n)
                // i: 入射方向，n: 法线方向，返回反射方向    

                // Get the reflect direction in world space
				fixed3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
				// Get the view direction in world space(逐顶点)
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex).xyz);

                // Compute specular term(高光反射计算公式)
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                o.color = ambient + diffuse + specular;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
				return fixed4(i.color, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}