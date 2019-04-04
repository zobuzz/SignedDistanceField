Shader "Hidden/Raymarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			#include "DistanceFunctions.cginc"

			sampler2D _MainTex;
			sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum, _CamToWorld;
			uniform float4 _Sphere1, _Sphere2, _Box1;
			uniform float _DegreeRotate;

			uniform float _maxDistance;
			uniform float _Box1Round, _BoxSphereSmooth, _SphereIntersectSmooth;
			uniform float3 _LightDir, _LightCol;
			uniform float _LightIntensity;
			uniform float3 _mainColor;
			uniform float2 _ShadowDistance;
			uniform float _ShadowIntensity, _ShadowPenumbra;
			// uniform float3 _modInterval;
			uniform int _MaxIteration;
			uniform float _IterAccuracy;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;

				half index = v.vertex.z;
				v.vertex.z = 0;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

				o.ray = _CamFrustum[(int)index].xyz;
				o.ray /= abs(o.ray.z);
				o.ray = mul(_CamToWorld, o.ray);

                return o;
            }

			float3 RotateY(float3 v, float degree)
			{
				float r = 0.0174532925 * degree;
				float sinR = sin(r);
				float cosR = cos(r);
				return float3(cosR * v.x - sinR * v.z, v.y, sinR * v.x + cosR * v.z);
			}

			float BoxSphere(float3 p)
			{
				float Sphere1 = sdSphere(RotateY(p - _Sphere1.xyz, _DegreeRotate), _Sphere1.w);

				float Box1 = sdRoundBox(RotateY(p - _Box1.xyz, _DegreeRotate) , _Box1.www, _Box1Round);
				
				float combine1 = opSS(Sphere1, Box1, _BoxSphereSmooth);

				float Sphere2 = sdSphere(RotateY(p - _Sphere2.xyz, _DegreeRotate), _Sphere2.w);
				float combine2 = opIS(Sphere2, combine1, _SphereIntersectSmooth);
				return combine2;
			}

			float distanceField(float3 p)
			{
				float ground = sdPlane(p, float4(0, 1, 0, 0));
				//float modX = pMod1(p.x, _modInterval.x);
				//float modY = pMod1(p.y, _modInterval.y);
				//float modZ = pMod1(p.z, _modInterval.z);
				float boxSphere1 = BoxSphere(p);
				//SDF transform ,radius
				//return opS(Sphere1, Box1);
				return opU(ground, boxSphere1);
			}

			// lightOrigin  lightDirection  minTravel  maxTravel
			float hardShadow(float3 ro, float3 rd, float mint, float maxt)
			{
				for(float t = mint; t < maxt; )
				{
					float h = distanceField(ro + rd*t);
					if(h < 0.001)
					{
						return 0.0;
					}
					t += h;
				}
				return 1.0;
			}

			// lightOrigin  lightDirection  minTravel  maxTravel
			float softShadow(float3 ro, float3 rd, float mint, float maxt, float k)
			{
				float result = 1.0;
				for(float t = mint; t < maxt; )
				{
					float h = distanceField(ro + rd*t);
					if(h < 0.001)
					{
						return 0.0;
					}
					result = min(result, k*h/t);
					t += h;
				}
				return result;
			}			

			uniform float _AoStepSize, _AoIntensity;
			uniform int _AoIterations;

			float AmbientOcclusion(float3 p, float3 n)
			{
				float step = _AoStepSize;
				float ao = 0.0;
				float dist = 0.0;
				for( int i=1; i<= _AoIterations; i++)
				{
					dist = step * i;
					ao += max(0.0, (dist - distanceField(p + n * dist)) / dist);
				}
				return 1 - ao * _AoIntensity;
			}

			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.001f, 0.0f);
				float3 n = float3(
					distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
					distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
					distanceField(p + offset.yyx) - distanceField(p - offset.yyx)
					);
				return normalize(n);
			}

			float3 Shading(float3 p, float3 n)
			{
				float3 result;
				// diffuse color
				float3 color = _mainColor.rgb;
				// directional light
				float3 light = _LightCol * (dot(n, -_LightDir) * 0.5 + 0.5) * _LightIntensity;
				//Shadows
				//float shadow = hardShadow(p, -_LightDir, _ShadowDistance.x, _ShadowDistance.y) * 0.5 + 0.5;
				float shadow = softShadow(p, -_LightDir, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;

				float ao = AmbientOcclusion(p, n);
				shadow = max(0.0, pow(shadow, _ShadowIntensity));

				result = color * light * shadow * ao;

				return result;
			}

			fixed4 raymarching(float3 ro, float3 rd, float depth)
			{
				fixed4 result = fixed4(0, 0, 0, 1);
				const int max_iteration = 200;

				float t = 0;
				for (int i = 0; i < _MaxIteration; i++)
				{
					if (t > _maxDistance || t>= depth)
					{
						//Envirment
						result = fixed4(rd, 0);
						break;
					}

					float3 p = ro + rd*t;  //this kind of step is known as sphere trace
					//check for hit in distance field
					float d = distanceField(p);
					if (d < _IterAccuracy)//we have hit something
					{
						//shading here
						float3 n = getNormal(p);
						//float ndl = saturate(dot(n, -_LightDir));
						float3 s = Shading(p,n);

						result = fixed4(s.rgb, 1);

						break;
					}
					t += d;
				}

				return result;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				fixed3 col = tex2D(_MainTex, i.uv);

				float3 rayDirection = normalize(i.ray.xyz);
				//float3 rayOrigin = _CamWorldSpace;
				float3 rayOrigin = _WorldSpaceCameraPos;
				fixed4 result = raymarching(rayOrigin, rayDirection, depth);

				return fixed4(col * (1 - result.w) + result.xyz * result.w, 1);
            }
            ENDCG
        }
    }
}
