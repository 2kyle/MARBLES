shader_type spatial;
// Painted-toy look for the lane pieces: a base colour with a simple painted
// pattern on top (stripes, checks, dots, chevrons or wood grain), a faint
// brush speckle, darker paint towards the bottom and a soft bright edge.
// Patterns are worked out from the piece's own shape (no textures needed),
// so they stay the same size however the piece is turned.
//
// pattern: 0 plain, 1 stripes, 2 checks, 3 dots, 4 chevrons, 5 wood grain

uniform vec4 base_color : source_color = vec4(0.8, 0.8, 0.8, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0);
uniform int pattern = 0;
// Pattern repeats per metre.
uniform float pattern_scale = 3.0;
// Which way stripes, chevrons and grain run (in the piece's own space).
uniform vec3 pattern_axis = vec3(0.0, 0.0, 1.0);
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.55;
uniform float glow : hint_range(0.0, 4.0) = 0.0;
// Height (metres) over which the paint darkens towards the ground, and how
// high this part's middle sits above the ground.
uniform float ground_shade = 0.25;
uniform float height_offset = 0.0;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A soft-edged band: 1 on the painted half of each repeat.
float band(float t) {
	float w = fwidth(t) * 1.5 + 0.001;
	float s = abs(fract(t) - 0.5) * 2.0;
	return smoothstep(0.5 - w, 0.5 + w, s);
}

void fragment() {
	vec3 axis = normalize(pattern_axis);
	vec3 side = normalize(cross(axis, abs(axis.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0)));
	float m = 0.0;
	if (pattern == 1) {
		m = band(dot(obj_pos, axis) * pattern_scale);
	} else if (pattern == 2) {
		vec3 c = floor(obj_pos * pattern_scale + 0.001);
		m = mod(c.x + c.y + c.z, 2.0);
	} else if (pattern == 3) {
		vec3 n = abs(obj_normal);
		vec2 uv = n.y > max(n.x, n.z) ? obj_pos.xz : (n.x > n.z ? obj_pos.yz : obj_pos.xy);
		vec2 g = fract(uv * pattern_scale) - 0.5;
		float d = length(g);
		float w = fwidth(d) + 0.001;
		m = 1.0 - smoothstep(0.22 - w, 0.22 + w, d);
	} else if (pattern == 4) {
		float t = dot(obj_pos, axis) * pattern_scale + abs(dot(obj_pos, side)) * pattern_scale * 0.9;
		m = band(t);
	} else if (pattern == 5) {
		float t = dot(obj_pos, side) * pattern_scale + noise(obj_pos * 2.0) * 1.2 + noise(obj_pos * 0.7) * 0.6;
		m = smoothstep(0.65, 0.95, abs(fract(t) - 0.5) * 2.0) * 0.7;
	}
	vec3 col = mix(base_color.rgb, accent_color.rgb, m);
	// Brush speckle so the paint isn't perfectly flat.
	col *= 0.93 + 0.1 * noise(obj_pos * 22.0);
	// Paint gets a touch darker near the ground (cheap contact shading).
	col *= mix(0.8, 1.0, smoothstep(0.0, ground_shade, obj_pos.y + height_offset + 0.02));
	ALBEDO = col;
	ROUGHNESS = roughness_amount;
	SPECULAR = 0.4;
	// A soft bright edge, like light catching rounded toy edges.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * glow + vec3(1.0, 0.97, 0.9) * rim * 0.06;
}
