using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class RenderCubemapWizard : ScriptableWizard
{
    public Transform renderFromPosition;
    public Cubemap cubemap;

    void OnWizardUpdate()
    {
        helpString = "Select transform to render from and cubemap to render into";
        isValid = (renderFromPosition != null) && (cubemap != null);
    }

    // This is called when the user clicks on the Create button.
    // 在renderFromPosition（由用户指定）位置处动态创建一个摄像机，
    // 并调用 Camera.RenderToCubemap 函数把从当前位置观察到的图像渲染到用户指定的立方体纹理cubemap中，完成后再销毁临时摄像机。
    void OnWizardCreate()
    {
        // create temporary camera for rendering
        GameObject go = new GameObject("CubemapCamera");
        go.AddComponent<Camera>();
        // place it on the object
        go.transform.position = renderFromPosition.position;
        // render into cubemap		
        go.GetComponent<Camera>().RenderToCubemap(cubemap);
        // destroy temporary camera
        DestroyImmediate(go);
    }

    [MenuItem("GameObject/Render into Cubemap")]
    static void RenderCubemap()
    {
        ScriptableWizard.DisplayWizard<RenderCubemapWizard>(
            "Render cubemap", "Render!");
    }
}
