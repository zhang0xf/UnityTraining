// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter10/04_Mirror"
{
    Properties 
    {
		_MainTex ("Main Tex", 2D) = "white" {}
	}

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass
        {
            CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			sampler2D _MainTex;

            struct a2v {
				float4 vertex : POSITION;
				float3 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

            v2f vert(a2v v) 
            {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.uv = v.texcoord;
				// Mirror needs to filp x
                // 翻转了x分量的纹理坐标。
				o.uv.x = 1 - o.uv.x;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target 
            {
				return tex2D(_MainTex, i.uv);
			}

            ENDCG
        }
    }

    FallBack Off
}