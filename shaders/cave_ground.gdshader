shader_type spatial;
// The cavern floor: dark lumpy rock with glowing cracks of crystal, and
// still pools of glowing water in the low spots. All worked out from the
// floor's position, no textures.

uniform vec4 rock : source_color = vec4(0.16, 0.14, 0.2, 1.0);
uniform vec4 rock_light : source_color = vec4(0.3, 0.26, 0.36, 1.0);
uniform vec4 vein : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform vec4 pool : source_color = vec4(0.1, 0.75, 0.8, 1.0);
uniform float vein_glow = 1.6;

varying vec3 world_pos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Distance to the nearest edge between cells: thin lines = cracks.
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash2(i + o) - f;
			float d = dot(r, r);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return sqrt(d2) - sqrt(d1);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = noise(p * 0.08) * 0.6 + noise(p * 0.3) * 0.3 + noise(p * 1.2) * 0.1;
	vec3 col = mix(rock.rgb, rock_light.rgb, n);
	float c = cracks(p * 0.12 + vec2(noise(p * 0.2), noise(p * 0.2 + 7.0)) * 0.6);
	float line = 1.0 - smoothstep(0.0, 0.035, c);
	float pulse = 0.75 + 0.25 * sin(TIME * 0.8 + p.x * 0.05 + p.y * 0.03);
	vec3 emit = vein.rgb * line * vein_glow * pulse * smoothstep(0.5, 0.65, noise(p * 0.04));
	float wet = smoothstep(0.24, 0.2, noise(p * 0.025 + 3.0));
	col = mix(col, pool.rgb * 0.4, wet);
	emit += pool.rgb * wet * (0.9 + 0.3 * sin(TIME * 1.5 + n * 6.0));
	ALBEDO = col;
	EMISSION = emit;
	ROUGHNESS = mix(0.9, 0.1, wet);
	SPECULAR = mix(0.2, 0.6, wet);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
