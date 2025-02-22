package arm.data;

import kha.graphics4.TextureFormat;
import kha.Blob;
import kha.Image;
import iron.data.Data;
import iron.system.ArmPack;

class ConstData {

	// 2D layer view
	#if (kha_direct3d11 || kha_direct3d12)

	public static var layerViewVert = "
uniform float4x4 projectionMatrix;
struct SPIRV_Cross_Output { float4 color : TEXCOORD0; float2 texCoord : TEXCOORD1; float4 gl_Position : SV_Position; };
SPIRV_Cross_Output main(float3 pos : TEXCOORD0, float2 tex : TEXCOORD1, float4 col : TEXCOORD2) {
	SPIRV_Cross_Output stage_output;
	stage_output.gl_Position = mul(float4(pos, 1.0f), projectionMatrix);
	stage_output.gl_Position.z = (stage_output.gl_Position.z + stage_output.gl_Position.w) * 0.5;
	stage_output.texCoord = tex;
	stage_output.color = col;
	return stage_output;
}
";
	public static var layerViewFrag = "
Texture2D<float4> tex;
SamplerState _tex_sampler;
float4 main(float4 color : TEXCOORD0, float2 texCoord : TEXCOORD1) : SV_Target0 {
	return tex.SampleLevel(_tex_sampler, texCoord, 0) * color;
}
";

	#else // kha_opengl

	public static var layerViewVert = "#version 330
in vec3 pos;
in vec2 tex;
in vec4 col;
uniform mat4 projectionMatrix;
out vec2 texCoord;
out vec4 color;
void main() {
	gl_Position = projectionMatrix * vec4(pos, 1.0);
	texCoord = tex;
	color = col;
}
";
	public static var layerViewFrag = "#version 330
uniform sampler2D tex;
in vec2 texCoord;
in vec4 color;
out vec4 FragColor;
void main() {
	FragColor = textureLod(tex, texCoord, 0) * color;
}
";
	#end


	// 2D layer merge
	#if (kha_direct3d11 || kha_direct3d12)

	public static var layerMergeVert = "
struct SPIRV_Cross_Output { float2 texCoord : TEXCOORD0; float4 gl_Position : SV_Position; };
SPIRV_Cross_Output main(float2 pos : TEXCOORD0) {
	SPIRV_Cross_Output stage_output;
	stage_output.gl_Position = float4(pos.xy, 0.0, 1.0);
	stage_output.gl_Position.z = (stage_output.gl_Position.z + stage_output.gl_Position.w) * 0.5;
	const float2 madd = float2(0.5, 0.5);
	stage_output.texCoord = pos.xy * madd + madd;
	stage_output.texCoord.y = 1.0 - stage_output.texCoord.y;
	return stage_output;
}
";
	public static var layerMergeFrag = "
Texture2D<float4> tex0;
SamplerState _tex0_sampler;
Texture2D<float4> tex1;
SamplerState _tex1_sampler;
Texture2D<float4> tex2;
SamplerState _tex2_sampler;
Texture2D<float4> texa;
SamplerState _texa_sampler;
Texture2D<float4> texb;
SamplerState _texb_sampler;
Texture2D<float4> texc;
SamplerState _texc_sampler;
uniform float opac;
uniform int blending;
float3 hsv_to_rgb(const float3 c) {
	const float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
float3 rgb_to_hsv(const float3 c) {
	const float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
	float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
struct SPIRV_Cross_Output { float4 color0 : SV_Target0; float4 color1 : SV_Target1; float4 color2 : SV_Target2; };
SPIRV_Cross_Output main(float2 texCoord : TEXCOORD0) {
	float4 col0 = tex0.SampleLevel(_tex0_sampler, texCoord, 0);
	float4 col1 = tex1.SampleLevel(_tex1_sampler, texCoord, 0);
	float4 col2 = tex2.SampleLevel(_tex2_sampler, texCoord, 0);
	float4 cola = texa.SampleLevel(_texa_sampler, texCoord, 0);
	float4 colb = texb.SampleLevel(_texb_sampler, texCoord, 0);
	float4 colc = texc.SampleLevel(_texc_sampler, texCoord, 0);
	float str = col0.a * opac;
	SPIRV_Cross_Output stage_output;
	if (blending == 0) { // Mix
		stage_output.color0 = float4(lerp(cola.rgb, col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 1) { // Darken
		stage_output.color0 = float4(lerp(cola.rgb, min(cola.rgb, col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 2) { // Multiply
		stage_output.color0 = float4(lerp(cola.rgb, cola.rgb * col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 3) { // Burn
		stage_output.color0 = float4(lerp(cola.rgb, float3(1.0, 1.0, 1.0) - (float3(1.0, 1.0, 1.0) - cola.rgb) / col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 4) { // Lighten
		stage_output.color0 = float4(max(cola.rgb, col0.rgb * str), max(col0.a, cola.a));
	}
	else if (blending == 5) { // Screen
		stage_output.color0 = float4((float3(1.0, 1.0, 1.0) - (float3(1.0 - str, 1.0 - str, 1.0 - str) + str * (float3(1.0, 1.0, 1.0) - col0.rgb)) * (float3(1.0, 1.0, 1.0) - cola.rgb)), max(col0.a, cola.a));
	}
	else if (blending == 6) { // Dodge
		stage_output.color0 = float4(lerp(cola.rgb, cola.rgb / (float3(1.0, 1.0, 1.0) - col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 7) { // Add
		stage_output.color0 = float4(lerp(cola.rgb, cola.rgb + col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 8) { // Overlay
		stage_output.color0 = float4(lerp(cola.rgb, (cola.rgb < float3(0.5, 0.5, 0.5) ? float3(2.0, 2.0, 2.0) * cola.rgb * col0.rgb : float3(1.0, 1.0, 1.0) - float3(2.0, 2.0, 2.0) * (float3(1.0, 1.0, 1.0) - col0.rgb) * (float3(1.0, 1.0, 1.0) - cola.rgb)), str), max(col0.a, cola.a));
	}
	else if (blending == 9) { // Soft Light
		stage_output.color0 = float4(((1.0 - str) * cola.rgb + str * ((float3(1.0, 1.0, 1.0) - cola.rgb) * col0.rgb * cola.rgb + cola.rgb * (float3(1.0, 1.0, 1.0) - (float3(1.0, 1.0, 1.0) - col0.rgb) * (float3(1.0, 1.0, 1.0) - cola.rgb)))), max(col0.a, cola.a));
	}
	else if (blending == 10) { // Linear Light
		stage_output.color0 = float4((cola.rgb + str * (float3(2.0, 2.0, 2.0) * (col0.rgb - float3(0.5, 0.5, 0.5)))), max(col0.a, cola.a));
	}
	else if (blending == 11) { // Difference
		stage_output.color0 = float4(lerp(cola.rgb, abs(cola.rgb - col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 12) { // Subtract
		stage_output.color0 = float4(lerp(cola.rgb, cola.rgb - col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 13) { // Divide
		stage_output.color0 = float4(float3(1.0 - str, 1.0 - str, 1.0 - str) * cola.rgb + float3(str, str, str) * cola.rgb / col0.rgb, max(col0.a, cola.a));
	}
	else if (blending == 14) { // Hue
		stage_output.color0 = float4(lerp(cola.rgb, hsv_to_rgb(float3(rgb_to_hsv(col0.rgb).r, rgb_to_hsv(cola.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else if (blending == 15) { // Saturation
		stage_output.color0 = float4(lerp(cola.rgb, hsv_to_rgb(float3(rgb_to_hsv(cola.rgb).r, rgb_to_hsv(col0.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else if (blending == 16) { // Color
		stage_output.color0 = float4(lerp(cola.rgb, hsv_to_rgb(float3(rgb_to_hsv(col0.rgb).r, rgb_to_hsv(col0.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else { // Value
		stage_output.color0 = float4(lerp(cola.rgb, hsv_to_rgb(float3(rgb_to_hsv(cola.rgb).r, rgb_to_hsv(cola.rgb).g, rgb_to_hsv(col0.rgb).b)), str), max(col0.a, cola.a));
	}
	stage_output.color1 = float4(lerp(colb, col1, str));
	stage_output.color2 = float4(lerp(colc, col2, str));
	return stage_output;
}
";
	public static var maskMergeFrag = "
Texture2D<float4> tex0;
SamplerState _tex0_sampler;
Texture2D<float4> texa;
SamplerState _texa_sampler;
struct SPIRV_Cross_Output { float4 color0 : SV_Target0; };
SPIRV_Cross_Output main(float2 texCoord : TEXCOORD0) {
	float4 col0 = tex0.SampleLevel(_tex0_sampler, texCoord, 0);
	float mask = texa.SampleLevel(_texa_sampler, texCoord, 0).r;
	SPIRV_Cross_Output stage_output;
	stage_output.color0 = float4(col0.rgb, col0.a * mask);
	return stage_output;
}
";

	#else // kha_opengl

	public static var layerMergeVert = "#version 330
in vec2 pos;
out vec2 texCoord;
void main() {
	gl_Position = vec4(pos.xy, 0.0, 1.0);
	const vec2 madd = vec2(0.5, 0.5);
	texCoord = pos.xy * madd + madd;
}
";
	public static var layerMergeFrag = "#version 330
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D texa;
uniform sampler2D texb;
uniform sampler2D texc;
uniform float opac;
uniform int blending;
in vec2 texCoord;
out vec4 FragColor[3];
vec3 hsv_to_rgb(const vec3 c) {
	const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
vec3 rgb_to_hsv(const vec3 c) {
	const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
void main() {
	vec4 col0 = textureLod(tex0, texCoord, 0);
	vec4 col1 = textureLod(tex1, texCoord, 0);
	vec4 col2 = textureLod(tex2, texCoord, 0);
	vec4 cola = textureLod(texa, texCoord, 0);
	vec4 colb = textureLod(texb, texCoord, 0);
	vec4 colc = textureLod(texc, texCoord, 0);
	float str = col0.a * opac;
	if (blending == 0) { // Mix
		FragColor[0] = vec4(mix(cola.rgb, col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 1) { // Darken
		FragColor[0] = vec4(mix(cola.rgb, min(cola.rgb, col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 2) { // Multiply
		FragColor[0] = vec4(mix(cola.rgb, cola.rgb * col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 3) { // Burn
		FragColor[0] = vec4(mix(cola.rgb, vec3(1.0, 1.0, 1.0) - (vec3(1.0, 1.0, 1.0) - cola.rgb) / col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 4) { // Lighten
		FragColor[0] = vec4(max(cola.rgb, col0.rgb * str), max(col0.a, cola.a));
	}
	else if (blending == 5) { // Screen
		FragColor[0] = vec4((vec3(1.0, 1.0, 1.0) - (vec3(1.0 - str, 1.0 - str, 1.0 - str) + str * (vec3(1.0, 1.0, 1.0) - col0.rgb)) * (vec3(1.0, 1.0, 1.0) - cola.rgb)), max(col0.a, cola.a));
	}
	else if (blending == 6) { // Dodge
		FragColor[0] = vec4(mix(cola.rgb, cola.rgb / (vec3(1.0, 1.0, 1.0) - col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 7) { // Add
		FragColor[0] = vec4(mix(cola.rgb, cola.rgb + col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 8) { // Overlay
		//FragColor[0] = vec4(mix(cola.rgb, (cola.rgb < vec3(0.5, 0.5, 0.5) ? vec3(2.0, 2.0, 2.0) * cola.rgb * col0.rgb : vec3(1.0, 1.0, 1.0) - vec3(2.0, 2.0, 2.0) * (vec3(1.0, 1.0, 1.0) - col0.rgb) * (vec3(1.0, 1.0, 1.0) - cola.rgb)), str), max(col0.a, cola.a)); // TODO
		FragColor[0] = vec4(mix(cola.rgb, col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 9) { // Soft Light
		FragColor[0] = vec4(((1.0 - str) * cola.rgb + str * ((vec3(1.0, 1.0, 1.0) - cola.rgb) * col0.rgb * cola.rgb + cola.rgb * (vec3(1.0, 1.0, 1.0) - (vec3(1.0, 1.0, 1.0) - col0.rgb) * (vec3(1.0, 1.0, 1.0) - cola.rgb)))), max(col0.a, cola.a));
	}
	else if (blending == 10) { // Linear Light
		FragColor[0] = vec4((cola.rgb + str * (vec3(2.0, 2.0, 2.0) * (col0.rgb - vec3(0.5, 0.5, 0.5)))), max(col0.a, cola.a));
	}
	else if (blending == 11) { // Difference
		FragColor[0] = vec4(mix(cola.rgb, abs(cola.rgb - col0.rgb), str), max(col0.a, cola.a));
	}
	else if (blending == 12) { // Subtract
		FragColor[0] = vec4(mix(cola.rgb, cola.rgb - col0.rgb, str), max(col0.a, cola.a));
	}
	else if (blending == 13) { // Divide
		FragColor[0] = vec4(vec3(1.0 - str, 1.0 - str, 1.0 - str) * cola.rgb + vec3(str, str, str) * cola.rgb / col0.rgb, max(col0.a, cola.a));
	}
	else if (blending == 14) { // Hue
		FragColor[0] = vec4(mix(cola.rgb, hsv_to_rgb(vec3(rgb_to_hsv(col0.rgb).r, rgb_to_hsv(cola.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else if (blending == 15) { // Saturation
		FragColor[0] = vec4(mix(cola.rgb, hsv_to_rgb(vec3(rgb_to_hsv(cola.rgb).r, rgb_to_hsv(col0.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else if (blending == 16) { // Color
		FragColor[0] = vec4(mix(cola.rgb, hsv_to_rgb(vec3(rgb_to_hsv(col0.rgb).r, rgb_to_hsv(col0.rgb).g, rgb_to_hsv(cola.rgb).b)), str), max(col0.a, cola.a));
	}
	else { // Value
		FragColor[0] = vec4(mix(cola.rgb, hsv_to_rgb(vec3(rgb_to_hsv(cola.rgb).r, rgb_to_hsv(cola.rgb).g, rgb_to_hsv(col0.rgb).b)), str), max(col0.a, cola.a));
	}
	FragColor[1] = vec4(mix(colb, col1, str));
	FragColor[2] = vec4(mix(colc, col2, str));
}
";
	public static var maskMergeFrag = "#version 330
uniform sampler2D tex0;
uniform sampler2D texa;
in vec2 texCoord;
out vec4 FragColor;
void main() {
	vec4 col0 = textureLod(tex0, texCoord, 0);
	float mask = textureLod(texa, texCoord, 0).r;
	FragColor = vec4(col0.rgb, col0.a * mask);
}
";
	#end

	#if (kha_direct3d11 || kha_direct3d12)

	public static var cursorVert = "
uniform float4x4 VP;
uniform float4x4 invVP;
uniform float2 mouse;
uniform float2 step;
uniform float radius;
Texture2D<float4> texa; // direct3d12 unit align
SamplerState _texa_sampler; // direct3d12 unit align
Texture2D<float4> gbufferD;
SamplerState _gbufferD_sampler;
Texture2D<float4> gbuffer0;
SamplerState _gbuffer0_sampler;
float2 octahedronWrap(float2 v) { return (1.0 - abs(v.yx)) * (float2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0)); }
float3x3 rotAxis(float3 axis, float a) {
	float c = cos(a);
	float3 as = axis * sin(a).xxx;
	float3x3 p = float3x3(axis.xxx * axis, axis.yyy * axis, axis.zzz * axis);
	float3x3 q = float3x3(c, -as.z, as.y, as.z, c, -as.x, -as.y, as.x, c);
	return p * (1.0 - c) + q;
}
float3 getNormal(float2 uv) {
	float2 g0 = gbuffer0.SampleLevel(_gbuffer0_sampler, uv, 0.0).rg;
	float3 n;
	n.z = 1.0 - abs(g0.x) - abs(g0.y);
	n.xy = n.z >= 0.0 ? g0.xy : octahedronWrap(g0.xy);
	return n;
}
struct SPIRV_Cross_Output { float2 texCoord : TEXCOORD0; float4 gl_Position : SV_Position; };
SPIRV_Cross_Output main(float4 pos : TEXCOORD1, float2 nor : TEXCOORD0, float2 tex : TEXCOORD2) {
	SPIRV_Cross_Output stage_output;
	stage_output.texCoord = tex;
	float2 mouseinv = float2(mouse.x, 1.0 - mouse.y);
	float depth = gbufferD.SampleLevel(_gbufferD_sampler, mouseinv, 0).r;
	float keep = texa.SampleLevel(_texa_sampler, mouseinv, 0).r; // direct3d12 unit align
	depth += keep * 0.0; // direct3d12 unit align
	float4 wpos = float4(mouse * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	wpos = mul(wpos, invVP);
	wpos.xyz /= wpos.w;
	float3 n = normalize(
		getNormal(mouseinv + float2(step.x, step.y)) +
		getNormal(mouseinv + float2(-step.x, step.y)) +
		getNormal(mouseinv + float2(-step.x, -step.y)) +
		getNormal(mouseinv + float2(step.x, -step.y)) +
		getNormal(mouseinv)
	);
	float ax = acos(dot(float3(1,0,0), float3(n.x,0,0)));
	float az = acos(dot(float3(0,0,1), float3(0,0,n.z)));
	float sy = -sign(n.y);
	wpos.xyz += mul(mul(pos.xyz * radius.xxx, rotAxis(float3(0,0,1), ax + 3.14/2)),
					rotAxis(float3(1,0,0), -az * sy + 3.14/2));
	stage_output.gl_Position = mul(float4(wpos.xyz, 1.0), VP);
	stage_output.gl_Position.z = (stage_output.gl_Position.z + stage_output.gl_Position.w) * 0.5;
	return stage_output;
}
";
	public static var cursorFrag = "
Texture2D<float4> tex;
SamplerState _tex_sampler;
float4 main(float2 texCoord : TEXCOORD0) : SV_Target0 {
	float4 col = tex.Sample(_tex_sampler, texCoord);
	return float4(col.rgb / col.a, col.a);
}
";

	#else // kha_opengl

	public static var cursorVert = "#version 330
uniform mat4 VP;
uniform mat4 invVP;
uniform vec2 mouse;
uniform vec2 step;
uniform float radius;
uniform sampler2D gbufferD;
uniform sampler2D gbuffer0;
in vec4 pos;
in vec2 nor;
in vec2 tex;
out vec2 texCoord;
vec2 octahedronWrap(const vec2 v) { return (1.0 - abs(v.yx)) * (vec2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0)); }
mat3 rotAxis(vec3 axis, float a) {
	float c = cos(a);
	vec3 as = axis * sin(a);
	mat3 p = mat3(axis.x * axis, axis.y * axis, axis.z * axis);
	mat3 q = mat3(c, -as.z, as.y, as.z, c, -as.x, -as.y, as.x, c);
	return p * (1.0 - c) + q;
}
vec3 getNormal(vec2 uv) {
	vec2 g0 = textureLod(gbuffer0, mouse, 0.0).rg;
	vec3 n;
	n.z = 1.0 - abs(g0.x) - abs(g0.y);
	n.xy = n.z >= 0.0 ? g0.xy : octahedronWrap(g0.xy);
	return n;
}
void main() {
	texCoord = tex;
	float depth = textureLod(gbufferD, mouse, 0.0).r;
	vec4 wpos = vec4(mouse * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	wpos = invVP * wpos;
	wpos.xyz /= wpos.w;
	vec3 n = normalize(
		getNormal(mouse + vec2(step.x, step.y)) +
		getNormal(mouse + vec2(-step.x, step.y)) +
		getNormal(mouse + vec2(-step.x, -step.y)) +
		getNormal(mouse + vec2(step.x, -step.y)) +
		getNormal(mouse)
	);
	float ax = acos(dot(vec3(1,0,0), vec3(n.x,0,0)));
	float az = acos(dot(vec3(0,0,1), vec3(0,0,n.z)));
	float sy = -sign(n.y);
	wpos.xyz +=
		rotAxis(vec3(1,0,0), -az * sy + 3.14/2) *
		rotAxis(vec3(0,0,1), ax + 3.14/2) *
		(pos.xyz * radius);
	gl_Position = VP * vec4(wpos.xyz, 1.0);
}
";
	public static var cursorFrag = "#version 330
uniform sampler2D tex;
in vec2 texCoord;
out vec4 FragColor;
void main() {
	vec4 col = texture(tex, texCoord);
	FragColor = vec4(col.rgb / col.a, col.a);
}
";

	#end

	public static var font_x0 = [1,2,6,10,18,25,34,42,45,50,55,61,68,71,75,79,85,92,97,104,111,118,1,8,15,22,29,32,35,41,48,55,61,72,81,89,97,105,112,119,1,9,13,20,28,35,45,53,61,69,77,85,93,101,109,1,12,20,28,36,40,46,50,56,62,66,73,80,87,94,101,106,113,120,123,1,8,11,21,28,35,42,49,54,61,66,73,80,90,97,104,111,116,119,1];
	public static var font_y0 = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,14,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,37,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,50,62];
	public static var font_x1 = [1,5,9,17,24,33,41,44,49,54,60,67,70,74,78,84,91,96,103,110,117,124,7,14,21,28,31,34,40,47,54,60,71,80,88,96,104,111,118,126,8,12,19,27,34,44,52,60,68,76,84,92,100,108,116,11,19,27,35,39,45,49,55,61,65,72,79,86,93,100,105,112,119,122,126,7,10,20,27,34,41,48,53,60,65,72,79,89,96,103,110,115,118,123,8];
	public static var font_y1 = [1,10,5,9,13,11,10,5,13,13,6,8,5,3,4,10,10,9,9,10,9,10,23,22,23,23,21,22,19,18,19,23,25,22,22,23,22,22,22,23,34,34,35,34,34,34,34,35,34,36,34,35,34,35,34,45,45,45,45,49,46,49,42,38,40,44,47,44,47,44,46,46,46,45,48,59,59,56,56,57,59,59,56,57,59,57,56,56,56,59,56,61,60,61,65];
	public static var font_xoff = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
	public static var font_yoff = [10,2,1,2,0,1,2,1,1,1,2,3,8,6,8,2,2,2,2,2,2,2,2,2,2,2,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,2,0,2,10,1,4,1,4,1,4,1,4,1,2,2,1,1,4,4,4,4,4,4,4,2,4,4,4,4,4,4,1,2,1,5];
	public static var font_xadvance = [2.74625,2.85458,3.54791,6.83041,6.22916,8.125,6.89541,1.93375,3.79166,3.85666,4.7775,6.28875,2.1775,3.06041,2.91958,4.57166,6.22916,6.22916,6.22916,6.22916,6.22916,6.22916,6.22916,6.22916,6.22916,6.22916,2.68666,2.34541,5.63875,6.08833,5.79583,5.23791,9.96125,7.23666,6.90625,7.22041,7.27458,6.305,6.13166,7.55625,7.9083,3.01708,6.12083,6.955,5.96916,9.685,7.90833,7.62666,6.99833,7.62666,6.83041,6.58125,6.61916,7.19333,7.05791,9.84208,6.955,6.6625,6.64083,2.94125,4.55,2.94125,4.63666,5.005,3.42875,6.03416,6.22375,5.80666,6.25625,5.87708,3.85125,6.22375,6.11,2.69208,2.64875,5.6225,2.69208,9.72291,6.12083,6.32666,6.22375,6.305,3.75375,5.72,3.62375,6.11541,5.37333,8.33625,5.49791,5.24875,5.49791,3.75375,2.70291,3.75375,7.54541];

	#if arm_ltc
	public static var ltcMatTex: Image = null;
	public static var ltcMagTex: Image = null;
	public static function initLTC() {
		// Real-Time Polygonal-Light Shading with Linearly Transformed Cosines
		// https://eheitzresearch.wordpress.com/415-2/
		Data.getBlob("ltc_mat.arm", function(ltc_mat:Blob) {
			Data.getBlob("ltc_mag.arm", function(ltc_mag:Blob) {
				ltcMatTex = Image.fromBytes(ArmPack.decode(ltc_mat.toBytes()), 64, 64, TextureFormat.RGBA128);
				ltcMagTex = Image.fromBytes(ArmPack.decode(ltc_mag.toBytes()), 64, 64, TextureFormat.A32);
			});
		});
	}
	#end
}
