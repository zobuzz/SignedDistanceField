using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent (typeof (Camera))]
[ExecuteInEditMode]
public class RaymarchSpheresCamera : SceneViewFilter {
    public Shader _shader;

    public Material _raymarchMat;

    public Camera _camera;
    [Header ("Setup")]
    public float _maxDistance;

    [Range (0, 300)]
    public int _MaxIteration;
    [Range (0.001f, 0.1f)]
    public float _IterAccuracy;

    // public Vector3 _modInterval;
    [Header ("Light Variable")]
    public Transform _directionLight;
    public Color _LightCol;
    public float _LightIntensity;
    [Header ("Shadow")]
    public float _ShadowIntensity;
    public Vector2 _ShadowDistance;
    [Range (0, 64)]
    public float _ShadowPenumbra;
    [Header ("Reflection")]
    public int _ReflectionCount;
    [Range (0, 1)]
    public float _ReflectionIntensity;
    [Range (0, 1)]
    public float _EnvRefIntensity;
    public Cubemap _ReflectionCube;
    [Header ("Ambient Occlusion")]
    [Range (0, 1)]
    public float _AoStepSize;
    [Range (0, 1)]
    public float _AoIntensity;
    [Range (1, 10)]
    public int _AoIterations;

    [Header ("Signed Distance Field")]
    public Color _mainColor;
    public Vector4 _sphere;
    public float _sphereSmooth;
    public float _degreeRotate;
    public Color _GroundColor;
    public Gradient _SphereGradient;
    public Color[] _SphereColor = new Color[8];
    [Range (0, 4)]
    public float _ColorIntensity;
    
    private float _degreeGlobal = 0;
    private void Awake () { }

    private void Update()
    {
        if(Application.isPlaying)
        {
            _degreeGlobal += Time.smoothDeltaTime * 45;
            _raymarchMat.SetFloat("_degreeGlobal", _degreeGlobal);
        }
    }
    private void OnRenderImage (RenderTexture source, RenderTexture target) {

        if (null == _raymarchMat) {
            Graphics.Blit (source, target);
            return;
        }
        _camera.depthTextureMode = DepthTextureMode.Depth;

        _raymarchMat.SetMatrix ("_CamFrustum", CamFrustum (_camera));
        _raymarchMat.SetMatrix ("_CamToWorld", _camera.cameraToWorldMatrix);
        _raymarchMat.SetFloat ("_maxDistance", _maxDistance);

        _raymarchMat.SetVector ("_LightDir", _directionLight.forward);
        _raymarchMat.SetColor ("_LightCol", _LightCol);
        _raymarchMat.SetFloat ("_LightIntensity", _LightIntensity);

        _raymarchMat.SetFloat ("_ShadowIntensity", _ShadowIntensity);
        _raymarchMat.SetVector ("_ShadowDistance", _ShadowDistance);
        _raymarchMat.SetFloat ("_ShadowPenumbra", _ShadowPenumbra);

        // _raymarchMat.SetVector("_Sphere1", _sphere1);
        // _raymarchMat.SetVector("_Sphere2", _sphere2);
        // _raymarchMat.SetVector("_Box1", _box1);

        // _raymarchMat.SetFloat("_Box1Round", _box1round);
        // _raymarchMat.SetFloat("_BoxSphereSmooth", _boxSphereSmooth);
        // _raymarchMat.SetFloat("_SphereIntersectSmooth", _sphereIntersectSmooth);

        // _raymarchMat.SetVector("_modInterval", _modInterval);

        for (int i = 0; i < 8; i++) 
        {
            _SphereColor[i] = _SphereGradient.Evaluate (0.125f * i);
        }
        _raymarchMat.SetColor ("_GroundColor", _GroundColor);
        _raymarchMat.SetColorArray ("_SphereColor", _SphereColor);
        _raymarchMat.SetFloat ("_ColorIntensity", _ColorIntensity);

        _raymarchMat.SetVector ("_sphere", _sphere);
        _raymarchMat.SetFloat ("_sphereSmooth", _sphereSmooth);
        _raymarchMat.SetFloat ("_degreeRotate", _degreeRotate);

        _raymarchMat.SetColor ("_mainColor", _mainColor);
        _raymarchMat.SetTexture ("_MainTex", source);

        _raymarchMat.SetFloat ("_AoStepSize", _AoStepSize);
        _raymarchMat.SetFloat ("_AoIntensity", _AoIntensity);
        _raymarchMat.SetInt ("_AoIterations", _AoIterations);

        _raymarchMat.SetInt ("_MaxIteration", _MaxIteration);
        _raymarchMat.SetFloat ("_IterAccuracy", _IterAccuracy);

        _raymarchMat.SetInt ("_ReflectionCount", _ReflectionCount);
        _raymarchMat.SetFloat ("_ReflectionIntensity", _ReflectionIntensity);
        _raymarchMat.SetFloat ("_EnvRefIntensity", _EnvRefIntensity);
        _raymarchMat.SetTexture ("_ReflectionCube", _ReflectionCube);

        RenderTexture.active = target;
        GL.PushMatrix ();
        GL.LoadOrtho ();
        _raymarchMat.SetPass (0);
        GL.Begin (GL.QUADS);

        //BL
        GL.MultiTexCoord2 (0, 0.0f, 0.0f);
        GL.Vertex3 (0.0f, 0.0f, 3.0f);
        //BR
        GL.MultiTexCoord2 (0, 1.0f, 0.0f);
        GL.Vertex3 (1.0f, 0.0f, 2.0f);
        //TR
        GL.MultiTexCoord2 (0, 1.0f, 1.0f);
        GL.Vertex3 (1.0f, 1.0f, 1.0f);
        //TL
        GL.MultiTexCoord2 (0, 0.0f, 1.0f);
        GL.Vertex3 (0.0f, 1.0f, 0.0f);

        GL.End ();
        GL.PopMatrix ();
    }

    private Matrix4x4 CamFrustum (Camera cam) {
        Matrix4x4 frustum = Matrix4x4.identity;

        float fov = Mathf.Tan (cam.fieldOfView * 0.5f * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 TL = -Vector3.forward - goRight + goUp;
        Vector3 TR = -Vector3.forward + goRight + goUp;
        Vector3 BR = -Vector3.forward + goRight - goUp;
        Vector3 BL = -Vector3.forward - goRight - goUp;

        frustum.SetRow (0, TL);
        frustum.SetRow (1, TR);
        frustum.SetRow (2, BR);
        frustum.SetRow (3, BL);

        return frustum;

    }
}