shader_type spatial;
// Fresh snow: soft white drifts with blue-ish hollows, and tiny glints
// that twinkle as the camera moves.

uniform vec4 snow : source_color = vec4(0.92, 0.94, 0.98, 1.0);
uniform vec4 shade : source_color = vec4(0.62, 0.7, 0.88, 1.0);

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (noise(world_pos.xz * 0.05) - 0.5) * 0.6;
}

void fragment() {
	vec2 p = world_pos.xz;
	float drift = noise(p * 0.05) * 0.7 + noise(p * 0.2) * 0.3;
	ALBEDO = mix(shade.rgb, snow.rgb, smoothstep(0.2, 0.75, drift));
	float glint = step(0.997, hash(floor(p * 6.0) + floor(VIEW.xz * 8.0)));
	EMISSION = vec3(glint) * 1.5;
	ROUGHNESS = 0.8;
	SPECULAR = 0.4;
}
