#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

// 渲染管线批处理(SRP Batcher):另见'UnlitPass.hlsl'中对'CBUFFER_START(UnityPerMaterial)'的解释.
CBUFFER_START(UnityPerDraw) // All UnityPerDraw data gets instanced when needed.能够与'GPU Instancing'配合工作.
float4x4 unity_ObjectToWorld; // 它由GPU在每次绘制时设置一次,在绘制期间顶点函数和片元函数的所有调用该变量的地方都是相同的常量.
float4x4 unity_WorldToObject; // float4x4:4行4列的矩阵.
float4 unity_LODFade; // 特定的转换矩阵组(transformation group)中包含该值,所以即使不用也需要包含进来.
real4 unity_WorldTransformParams;

// 'light map'的坐标通常由Unity为每个'Mesh'自动生成,或者直接是导入'Mesh'数据的一部分.
// 每个'Mesh'的'unwrap uv layout'都被缩放及重新定位到'light map'中,使每个'instance'在'light map'中都有自己独立的空间.需要将这种坐标关系应用到'light map uv'.(另见'GI.hlsl'宏定义)
float4 unity_LightmapST; // [deprecated]
float4 unity_DynamicLightmapST; // 为了'SRP Batcher'兼容性不被破坏.

// 表示红光,蓝光,绿光的多项式组成部分.'light probe'插值需要.
float4 unity_SHAr;
float4 unity_SHAg;
float4 unity_SHAb;
float4 unity_SHBr;
float4 unity_SHBg;
float4 unity_SHBb;
float4 unity_SHC;

// LPPV相关输入
float4 unity_ProbeVolumeParams;
float4x4 unity_ProbeVolumeWorldToObject;
float4 unity_ProbeVolumeSizeInv;
float4 unity_ProbeVolumeMin;
CBUFFER_END

float4x4 unity_MatrixVP; // 即'view-projection matrix',将顶点从世界空间(world space)转换到齐次裁剪空间(homogeneous clip space).
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

float3 _WorldSpaceCameraPos;

bool4 unity_MetaFragmentControl;
float unity_OneOverOutputBoost;
float unity_MaxOutputValue;

#endif