#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

// 渲染管线批处理(SRP Batcher):在GPU缓存Shader属性以减少CPU和GPU的通信数据量,以及CPU发送这些数据产生的额外负荷.
// SRP Batcher构建方式:通过将Shader属性定义在一个Buffer中.如:
// CBUFFER_START(UnityPerMaterial)
//     float4 _BaseColor;
// CBUFFER_END
// 其中'CBUFFER_START'宏用来处理平台差异,若平台不支持'cbuffer'则代码将被编译器忽略.
// 注意:SRP Batcher并不是只有一个Draw Call,只是减少了Draw Call的成本,且与GPU Instancing不兼容(优先执行SRP Batcher).

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld; // 它由GPU在每次绘制时设置一次,在绘制期间都是同一个常量.
float4x4 unity_WorldToObject;
float4 unity_LODFade; // 出于效率,同一转换组的其他变量即使不使用也需要填入Buffer.
real4 unity_WorldTransformParams;

// 延伸:Unity会将Mesh的UV布局缩放并重新定位到'Light Map'中.
float4 unity_LightmapST;
float4 unity_DynamicLightmapST;

// 'Light Probe'多项式组成部分,插值需要.
float4 unity_SHAr; 
float4 unity_SHAg;
float4 unity_SHAb;
float4 unity_SHBr;
float4 unity_SHBg;
float4 unity_SHBb;
float4 unity_SHC;

 // LPPV相关
float4 unity_ProbeVolumeParams;
float4x4 unity_ProbeVolumeWorldToObject;
float4 unity_ProbeVolumeSizeInv;
float4 unity_ProbeVolumeMin;
CBUFFER_END

float4x4 unity_MatrixVP;
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