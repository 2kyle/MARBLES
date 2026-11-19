shader_type spatial;
// The casino carpet: a loud seventies pattern of rings and wavy stripes in
// orange, mustard, brown and teal. Drawn from the floor's position.

uniform vec4 c1 : source_color = vec4(0.42, 0.16, 0.12, 1.0);
uniform vec4 c2 : source_color = vec4(0.95, 0.52, 0.15, 1.0);
uniform vec4 c3 : source_color = vec4(0.95, 0.78, 0.25, 1.0);
uniform vec4 c4 : source_color = vec4(0.12, 0.55, 0.55, 1.0);
uniform float tile = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / tile;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	// Alternate the tile so neighbouring rings swap colours.
	float flip = mod(cell.x + cell.y, 2.0);
	float r = length(f);
	float rings = floor(r * 7.0);
	vec3 col = c1.rgb;
	if (r < 0.48) {
		int k = int(mod(rings + flip, 4.0));
		col = k == 0 ? c2.rgb : (k == 1 ? c3.rgb : (k == 2 ? c4.rgb : c1.rgb));
	} else {
		// Wavy stripes between the rings.
		float w = sin(world_pos.x * 2.2 + sin(world_pos.z * 1.3) * 1.5);
		col = w > 0.4 ? c4.rgb * 0.8 : c1.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
