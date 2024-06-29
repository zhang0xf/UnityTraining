#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

// 渲染管线批处理(SRP Batcher):另见'UnlitPass.hlsl'中对'CBUFFER_START(UnityPerMaterial)'的解释.
CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld; // 它由GPU在每次绘制时设置一次,在绘制期间顶点函数和片元函数的所有调用该变量的地方都是相同的常量.
float4x4 unity_WorldToObject; // float4x4:4行4列的矩阵.
float4 unity_LODFade; // 特定的转换矩阵组(transformation group)中包含该值,所以即使不用也需要包含进来.
real4 unity_WorldTransformParams;
CBUFFER_END

float4x4 unity_MatrixVP; // 即'view-projection matrix',将顶点从世界空间(world space)转换到齐次裁剪空间(homogeneous clip space).
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

float3 _WorldSpaceCameraPos;

#endif