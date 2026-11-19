shader_type spatial;
// A sea of cloud to stand on: soft white billows with lilac shadows that
// slowly drift and roll.

uniform vec4 cloud : source_color = vec4(1.0, 0.98, 0.97, 1.0);
uniform vec4 shadow : source_color = vec4(0.72, 0.68, 0.88, 1.0);
uniform float speed = 0.6;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float billows(vec2 p) {
	vec2 d = vec2(TIME * speed, TIME * speed * 0.4);
	return noise(p * 0.04 + d * 0.02) * 0.55 + noise(p * 0.12 - d * 0.05) * 0.3 + noise(p * 0.4 + d * 0.1) * 0.15;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += billows(world_pos.xz) * 2.5 - 1.0;
}

void fragment() {
	float b = billows(world_pos.xz);
	ALBEDO = mix(shadow.rgb, cloud.rgb, smoothstep(0.25, 0.7, b));
	EMISSION = cloud.rgb * 0.04;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
