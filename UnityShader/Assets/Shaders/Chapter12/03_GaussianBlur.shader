// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "UnityShadersBook/Chapter12/03_GaussianBlur"
{
    Properties 
    {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_BlurSize ("Blur Size", Float) = 1.0
	}

    SubShader
    {
        // 我们将第一次使用CGINCLUDE来组织代码。
        // 这些代码不需要包含在任何Pass语义块中，在使用时，我们只需要在Pass中直接指定需要使用的顶点着色器和片元着色器函数名即可。
        // 由于高斯模糊需要定义两个Pass，但它们使用的片元着色器代码是完全相同的，使用CGINCLUDE可以避免我们编写两个完全一样的frag函数。
        CGINCLUDE
	
	    #include "UnityCG.cginc"

	    sampler2D _MainTex;  
	    half4 _MainTex_TexelSize; // 使用了Unity提供的_MainTex_TexelSize变量，以计算相邻像素的纹理坐标偏移量。
	    float _BlurSize;

	    struct v2f {
	    	float4 pos : SV_POSITION;
            // 一个5×5的二维高斯核可以拆分成两个大小为5的一维高斯核，因此我们只需要计算5个纹理坐标即可。
            // 为此，我们在v2f结构体中定义了一个5维的纹理坐标数组。
            // 数组的第一个坐标存储了当前的采样纹理，而剩余的四个坐标则是高斯模糊中对邻域采样时使用的纹理坐标。
            
	    	half2 uv[5]: TEXCOORD0;
	    };

        // 竖直方向的顶点着色器代码
        v2f vertBlurVertical(appdata_img v) 
        {
		    v2f o;
		    o.pos = UnityObjectToClipPos(v.vertex);

		    half2 uv = v.texcoord;

            // 我们还和属性_BlurSize相乘来控制采样距离。在高斯核维数不变的情况下，_BlurSize越大，模糊程度越高，但采样数却不会受到影响。
            // 通过把计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算，提高性能。
            // 由于从顶点着色器到片元着色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果。
		    o.uv[0] = uv;
		    o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize; // +1
		    o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize; // -1
		    o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize; // +2
		    o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize; // -2

		    return o;
	    }

        // 水平方向的顶点着色器代码
        v2f vertBlurHorizontal(appdata_img v) 
        {
		    v2f o;
		    o.pos = UnityObjectToClipPos(v.vertex);

		    half2 uv = v.texcoord;

		    o.uv[0] = uv;
		    o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize; // +1
		    o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize; // -1
		    o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize; // +2
		    o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize; // -2

		    return o;
	    }

        // 定义两个Pass共用的片元着色器
        fixed4 fragBlur(v2f i) : SV_Target 
        {
            // 一个5×5的二维高斯核可以拆分成两个大小为5的一维高斯核，并且由于它的对称性，我们只需要记录3个高斯权重，也就是代码中的weight变量。
		    float weight[3] = {0.4026, 0.2442, 0.0545};

            // 将结果值sum初始化为当前的像素值乘以它的权重值。
		    fixed3 sum = tex2D(_MainTex, i.uv[0]).rgb * weight[0];

            // 根据对称性，我们进行了两次迭代，每次迭代包含了两次纹理采样，并把像素值和权重相乘后的结果叠加到sum中。
		    for (int it = 1; it < 3; it++) 
            {
		    	sum += tex2D(_MainTex, i.uv[it*2-1]).rgb * weight[it];
		    	sum += tex2D(_MainTex, i.uv[it*2]).rgb * weight[it];
		    }

            // 最后，函数返回滤波结果sum
		    return fixed4(sum, 1.0);
	    }

        ENDCG

        ZTest Always 
        Cull Off 
        ZWrite Off

        // 我们定义了高斯模糊使用的两个Pass
        // 我们为两个Pass使用NAME语义（见3.3.3节）定义了它们的名字。
        // 这是因为，高斯模糊是非常常见的图像处理操作，很多屏幕特效都是建立在它的基础上的，例如Bloom效果（见12.5节）。
        // 为Pass定义名字，可以在其他Shader中直接通过它们的名字来使用该Pass，而不需要再重复编写代码。
	    Pass 
        {
	    	NAME "GAUSSIAN_BLUR_VERTICAL"

	    	CGPROGRAM

	    	#pragma vertex vertBlurVertical  
	    	#pragma fragment fragBlur

	    	ENDCG  
	    }

	    Pass 
        {  
	    	NAME "GAUSSIAN_BLUR_HORIZONTAL"

	    	CGPROGRAM  

	    	#pragma vertex vertBlurHorizontal  
	    	#pragma fragment fragBlur

	    	ENDCG
	    }
    }

    FallBack Off // 关闭该Shader的Fallback
    // FallBack "Diffuse"
}