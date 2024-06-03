// Blinn-Phong光照模型
Shader "UnityShadersBook/Chapter06/06_BlinnPhong"
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

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
            };

            // 顶点着色器之需要计算世界空间下的法线方向和顶点坐标
            v2f vert(a2v v)
            {
                v2f o;

                // Transform the vertex from object space to projection space
				o.pos = UnityObjectToClipPos(v.vertex);

                // Transform the normal from object space to world space
				o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
				// Transform the vertex from object space to world space
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                return o;
            }

            // 在片元着色器中计算关键的关照模型
            fixed4 frag(v2f i) : SV_Target 
            {
				// Get ambient term
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz); // 只适用于平行光，不具通用性。
				
				// Compute diffuse term
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                // Get the view direction in world space
				fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
				// Get the half direction in world space
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				// Compute specular term
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);
				
				return fixed4(ambient + diffuse + specular, 1.0);
			}

            ENDCG
        }
    }

    FallBack "Specular"
}