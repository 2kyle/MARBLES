shader_type spatial;
// The city's streets, drawn from the ground's position (no textures): a
// grid of asphalt roads with dashed centre lines, kerbs, pavements and
// zebra crossings, and paved squares in between.

uniform vec2 offset = vec2(0.0);
uniform float block = 26.0;
uniform float road = 9.0;
uniform vec4 asphalt : source_color = vec4(0.2, 0.2, 0.24, 1.0);
uniform vec4 pavement : source_color = vec4(0.55, 0.53, 0.52, 1.0);
uniform vec4 plaza : source_color = vec4(0.62, 0.58, 0.55, 1.0);
uniform vec4 paint : source_color = vec4(0.95, 0.85, 0.35, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = world_pos.xz - offset + vec2(road * 0.5);
	vec2 cell = floor(p / block);
	vec2 l = mod(p, block);
	bool road_x = l.x < road;
	bool road_z = l.y < road;
	vec3 col = plaza.rgb;
	float rough = 0.9;
	if (road_x || road_z) {
		col = asphalt.rgb * (0.92 + 0.08 * hash(floor(world_pos.xz * 2.0)));
		rough = 0.75;
		// Dashed yellow line down the middle of each road.
		if (road_x && !road_z && abs(l.x - road * 0.5) < 0.12 && mod(l.y, 4.0) < 2.2) col = paint.rgb;
		if (road_z && !road_x && abs(l.y - road * 0.5) < 0.12 && mod(l.x, 4.0) < 2.2) col = paint.rgb;
		// Zebra crossings just before each crossroads.
		if (road_x && !road_z && l.y > road && l.y < road + 2.2 && mod(l.x, 1.2) < 0.6) col = vec3(0.92);
		if (road_z && !road_x && l.x > road && l.x < road + 2.2 && mod(l.y, 1.2) < 0.6) col = vec3(0.92);
	} else {
		// Pavement round the edge of each block, paving slabs inside.
		vec2 in_block = l - vec2(road);
		float edge = min(min(in_block.x, in_block.y), min(block - road - in_block.x, block - road - in_block.y));
		if (edge < 1.8) {
			col = pavement.rgb;
			if (edge < 0.25) col = vec3(0.72, 0.7, 0.68);
		} else {
			vec2 slab = fract(world_pos.xz / 1.5);
			float seam = step(0.96, max(slab.x, slab.y));
			col = plaza.rgb * (0.94 + 0.06 * hash(floor(world_pos.xz / 1.5) + cell)) * (1.0 - seam * 0.12);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
