#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

// real4本身不是一个合法的类型,根据目标平台不同,它可能是float4或half4的别名,所以需要通过'Common.hlsl'引入这些定义.
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "UnityInput.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld // 'SpaceTransforms.hlsl'只能识别'UNITY_MATRIX_M'.
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_I_V unity_MatrixInvV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_PREV_MATRIX_M unity_prev_MatrixM
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM
#define UNITY_MATRIX_P glstate_matrix_projection

// 为了实现'GPU Instancing',需要知道当前渲染对象的索引,索引可以通过顶点数据(vertex data)获取.
// 'UnityInstancing.hlsl'提供了宏(另见'UNITY_VERTEX_INPUT_INSTANCE_ID')可以简化这一操作.但是它需要顶点着色器(vertex function)有一个struct参数.
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
// 'SpaceTransforms.hlsl'包含许多常用的函数和其他,例如'TransformObjectToWorld'转换函数.因此我们无需重复实现.[需要安装Package]
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl" 
	
#endif