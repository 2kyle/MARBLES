shader_type spatial;
// City buildings: the wall colour comes from the mesh (MeshBatch), and a
// grid of windows is drawn on every upright wall from the wall's position.
// Some windows are lit (warm or cool), so the city glows at sunset.

uniform float floor_h = 3.2;
uniform float window_w = 1.8;
uniform float lit_share = 0.3;
uniform float glow = 1.5;
uniform float ground_y = -4.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 col = base;
	vec3 emit = vec3(0.0);
	// COLOR.a < 0.5 marks shapes with no windows (roofs, trims, trees).
	if (COLOR.a > 0.5 && abs(world_normal.y) < 0.3) {
		float across = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		float up = world_pos.y - ground_y;
		vec2 cell = vec2(floor(across / window_w), floor(up / floor_h));
		vec2 f = vec2(fract(across / window_w), fract(up / floor_h));
		bool in_window = f.x > 0.18 && f.x < 0.82 && f.y > 0.3 && f.y < 0.82 && up > floor_h * 0.9;
		if (in_window) {
			float h = hash(vec3(cell, floor(world_normal.x * 3.0 + world_normal.z * 7.0) + floor(world_pos.x / 40.0)));
			if (h < lit_share) {
				vec3 light = h < lit_share * 0.6 ? vec3(1.0, 0.78, 0.42) : vec3(0.75, 0.88, 1.0);
				col = light;
				emit = light * glow * (0.6 + 0.4 * hash(vec3(cell.yx, 3.0)));
			} else {
				col = mix(base * 0.3, vec3(0.16, 0.2, 0.3), 0.7);
			}
		}
	}
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = 0.85;
	SPECULAR = 0.3;
}
