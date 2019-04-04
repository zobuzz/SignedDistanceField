
#define PI 3.14159265359
#define D2Rad  0.01745329251
// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// RoundBox
float sdRoundBox(in float3 p, in float3 b, float3 r)
{
	float3 q = abs(p) - b;
	return min(max(q.x, max(q.y, q.z)), 0.0) + length(max(q, 0.0)) - r;
}
// Plane
// n.xyz : normal of the plane (normalized).
// n.w : offset
float sdPlane(float3 p, float4 n)
{
	// n must be normalized 
	return dot(p, n.xyz) + n.w;
}

// BOOLEAN OPERATORS //

// Union
float opU(float d1, float d2)
{
	return min(d1, d2);
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

// Mod Position Axis
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}

// SMOOTH BOOLEAN OPERATORS //
// Union Smooth
float opUS(float d1, float d2, float k)
{
	float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
	return lerp( d2, d1, h ) - k*h*(1.0 - h);
}

float opSS(float d1, float d2, float k)
{
	float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0);
	return lerp( d2, -d1, h) + k*h*(1.0 - h);
}

float opIS(float d1, float d2, float k)
{
	float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0);
	return lerp( d2, d1, h ) + k*h*(1.0 - h);
}

// SMOOTH BOOLEAN OPERATORS WITH COlOR//
float4 opUS_Color(float4 d1, float4 d2, float k)
{
	float h = clamp( 0.5 + 0.5 * (d2.w - d1.w) / k, 0.0, 1.0);
	float dist = lerp(d2.w, d1.w, h) - k * h * (1.0 - h);
	float3 color = lerp(d2.rgb, d1.rgb, h);
	return float4(color, dist);
}

float4 opU_Color(float4 d1, float4 d2)
{
	if( d1.w < d2.w )
	{
		return d1;
	}else{
		return d2;
	}
}
