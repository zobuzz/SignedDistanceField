Shader "Hidden/RaymarchSpheres"
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
			// setup global
			uniform float _maxDistance;
			uniform int _MaxIteration;
			uniform float _IterAccuracy;
			// shadow
			uniform float2 _ShadowDistance;
			uniform float _ShadowIntensity, _ShadowPenumbra;
			// AO params
			uniform float _AoStepSize, _AoIntensity;
			uniform int _AoIterations;
			// Light params
			uniform float3 _LightDir, _LightCol;
			uniform float _LightIntensity;
			// Color
			uniform float3 _mainColor;
			// SDF
			uniform float4 _sphere;
			uniform float _sphereSmooth;
			uniform float _degreeRotate;
			uniform float _degreeGlobal;
			// Reflection
			uniform int _ReflectionCount;
			uniform float _ReflectionIntensity, _EnvRefIntensity;
			samplerCUBE _ReflectionCube;
			// Colors
			uniform fixed4 _GroundColor;
			uniform fixed4 _SphereColor[8];
			uniform float _ColorIntensity;

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

			float4 distanceField(float3 p)
			{
				float4 ground = float4(_GroundColor.rgb, sdPlane(p, float4(0, 1, 0, 0)));
				float4 sphere = float4(_SphereColor[0].rgb, sdSphere(p - RotateY(_sphere.xyz, _degreeGlobal), _sphere.w));

				for(int i=1; i<8; i++)
				{
					float4 sphereAdd = float4(_SphereColor[i].rgb, sdSphere(RotateY(p, _degreeRotate * i) - RotateY(_sphere.xyz, _degreeGlobal), _sphere.w));
					sphere = opUS_Color(sphere, sphereAdd, _sphereSmooth);
				}
				return opU_Color(ground, sphere);
			}

			// lightOrigin  lightDirection  minTravel  maxTravel
			float hardShadow(float3 ro, float3 rd, float mint, float maxt)
			{
				for(float t = mint; t < maxt; )
				{
					float h = distanceField(ro + rd*t).w;
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
					float h = distanceField(ro + rd*t).w;
					if(h < 0.001)
					{
						return 0.0;
					}
					result = min(result, k*h/t);
					t += h;
				}
				return result;
			}			

			float AmbientOcclusion(float3 p, float3 n)
			{
				float step = _AoStepSize;
				float ao = 0.0;
				float dist = 0.0;
				for( int i=1; i<= _AoIterations; i++)
				{
					dist = step * i;
					ao += max(0.0, (dist - distanceField(p + n * dist).w) / dist);
				}
				return 1 - ao * _AoIntensity;
			}

			float3 getNormal(float3 p)
			{
				const float2 offset = float2(0.001f, 0.0f);
				float3 n = float3(
					distanceField(p + offset.xyy).w - distanceField(p - offset.xyy).w,
					distanceField(p + offset.yxy).w - distanceField(p - offset.yxy).w,
					distanceField(p + offset.yyx).w - distanceField(p - offset.yyx).w
					);
				return normalize(n);
			}

			float3 Shading(float3 p, float3 n, float3 c)
			{
				float3 eyeDir = normalize(_WorldSpaceCameraPos - p);
				float3 refDir = reflect(-eyeDir, n);

				float3 result;
				// diffuse color
				float3 color = c * _ColorIntensity;
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

			bool raymarching(float3 ro, float3 rd, float depth, float maxDistance, 
			int maxIterations, inout float3 p, inout float3 c)
			{
				bool hit = false;
				float t = 0;
				for (int i = 0; i < maxIterations; i++)
				{
					if (t > maxDistance || t>= depth)
					{
						//Envirment
						hit = false;
						break;
					}

					p = ro + rd*t;  //this kind of step is known as sphere trace
					//check for hit in distance field
					float4 d = distanceField(p);
					if (d.w < _IterAccuracy)//we have hit something
					{
						hit = true;
						c = d.rgb;
						break;
					}
					t += d.w;
				}

				return hit;
			}

            fixed4 frag (v2f i) : SV_Target
            {
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				fixed3 col = tex2D(_MainTex, i.uv);

				float3 rayDirection = normalize(i.ray.xyz);
				//float3 rayOrigin = _CamWorldSpace;
				float3 rayOrigin = _WorldSpaceCameraPos;

				fixed4 result;
				float3 hitPosition;
				float3 hitColor;
				// inout hitPosition, hitColor
				bool hit = raymarching(rayOrigin, rayDirection, depth, _maxDistance, _MaxIteration, hitPosition, hitColor);
				if(hit)
				{
					//shading here
					float3 n = getNormal(hitPosition);
					//float ndl = saturate(dot(n, -_LightDir));
					float3 s = Shading(hitPosition, n, hitColor);
					result = fixed4(s.rgb, 1);

					float3 eyeDir = normalize(_WorldSpaceCameraPos - hitPosition);
					float3 refDir = reflect(-eyeDir, n);

					result += fixed4(texCUBE(_ReflectionCube , refDir).rgb * _EnvRefIntensity * _ReflectionIntensity, 1);

					// first reflection 
					if(_ReflectionCount > 0)
					{
						rayDirection = normalize(reflect(rayDirection, n));
						rayOrigin = hitPosition + rayDirection * 0.01f;

						hit = raymarching(rayOrigin, rayDirection, _maxDistance, _maxDistance * 0.5 , _MaxIteration / 2, hitPosition, hitColor);
						if(hit)
						{
							n = getNormal(hitPosition);
							s = Shading(hitPosition, n, hitColor);
							result += fixed4(s * _ReflectionIntensity, 0);
							//second reflection
							if(_ReflectionCount > 1)
							{
								rayDirection = normalize(reflect(rayDirection, n));
								rayOrigin = hitPosition + rayDirection * 0.01f;

								hit = raymarching(rayOrigin, rayDirection, _maxDistance, _maxDistance * 0.25 , _MaxIteration / 4, hitPosition, hitColor);
								if(hit)
								{
									n = getNormal(hitPosition);
									s = Shading(hitPosition, n, hitColor);
									result += fixed4(s * _ReflectionIntensity, 0);
								}
							}
						}
					}
					
				}else
				{
					result = fixed4(0, 0, 0, 1);
				}

				return fixed4(col * (1 - result.w) + result.xyz * result.w, 1);
            }
            ENDCG
        }
    }
}
