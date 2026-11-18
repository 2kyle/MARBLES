shader_type spatial;
// Water under the track. Gentle moving waves made from a few sine waves;
// it reflects the sky. Change the colours or wave sizes below.

uniform vec4 deep_color : source_color = vec4(0.01, 0.07, 0.13, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.03, 0.2, 0.27, 1.0);
uniform float wave_height = 0.12;
uniform float wave_speed = 0.6;

varying vec3 world_pos;

float height(vec2 p, float t) {
	float h = 0.0;
	h += sin(p.x * 0.35 + t * 1.1) * 0.5;
	h += sin(p.y * 0.42 - t * 0.9) * 0.4;
	h += sin((p.x + p.y) * 0.9 + t * 1.7) * 0.18;
	h += sin((p.x - p.y) * 1.6 - t * 2.3) * 0.08;
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += height(world_pos.xz, TIME * wave_speed) * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	float e = 0.15;
	// Small ripples on top of the big waves, only in the lighting.
	float r = sin(p.x * 1.3 + t * 2.0) * sin(p.y * 1.1 - t * 1.6) * 0.15;
	float hx = height(p + vec2(e, 0.0), t) - height(p - vec2(e, 0.0), t) + r * 0.2;
	float hz = height(p + vec2(0.0, e), t) - height(p - vec2(0.0, e), t) - r * 0.2;
	vec3 n = normalize(vec3(-hx * wave_height * 2.0, 2.0 * e, -hz * wave_height * 2.0));
	// Fade the ripples out in the distance so they don't shimmer.
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), smoothstep(30.0, 160.0, dist)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, 0.6 + 0.4 * fresnel);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
