shader_type spatial;
// Patterned marble. The pattern is painted on the ball itself (object
// space), so you can see it roll. pattern: 0 plain, 1 stripes, 2 swirl,
// 3 galaxy, 4 lava, 5 checkers.

uniform vec4 base_color : source_color = vec4(1.0);
uniform int pattern = 0;
uniform float metallic_amount = 0.1;
uniform float roughness_amount = 0.15;
uniform float glow = 0.0;

varying vec3 obj;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	obj = normalize(VERTEX);
}

void fragment() {
	vec3 c = base_color.rgb;
	vec3 e = vec3(0.0);
	vec3 p = obj;
	if (pattern == 1) {
		float s = step(0.0, sin(p.y * 12.0));
		c = mix(c, vec3(0.97), s * 0.85);
	} else if (pattern == 2) {
		float n = fbm(p * 2.5);
		float s = sin(p.x * 6.0 + n * 9.0);
		c = mix(c, mix(c, vec3(1.0), 0.75), smoothstep(-0.2, 0.6, s));
		c = mix(c, c * 0.45, smoothstep(0.7, 1.0, s));
	} else if (pattern == 3) {
		float neb = fbm(p * 3.0 + 4.0);
		c = mix(vec3(0.02, 0.01, 0.06), base_color.rgb * 0.6, smoothstep(0.35, 0.8, neb));
		vec3 cell = floor(p * 26.0);
		float star = step(0.93, hash(cell)) * smoothstep(0.32, 0.0, length(fract(p * 26.0) - 0.5));
		c += vec3(star);
		e = base_color.rgb * smoothstep(0.5, 0.85, neb) * 0.4 + vec3(star) * 1.5;
	} else if (pattern == 4) {
		float n = fbm(p * 4.0);
		float crack = 1.0 - smoothstep(0.0, 0.06, abs(n - 0.5));
		c = mix(vec3(0.08, 0.05, 0.04), base_color.rgb * 0.3, n * 0.5);
		e = mix(vec3(1.0, 0.35, 0.05), base_color.rgb, 0.3) * crack;
	} else if (pattern == 5) {
		vec3 q = floor(p * 4.0);
		float chk = mod(q.x + q.y + q.z, 2.0);
		c = mix(c, vec3(0.08), chk);
	}
	if (pattern == 0 && glow > 0.0) {
		e = base_color.rgb;
	}
	ALBEDO = c;
	METALLIC = metallic_amount;
	ROUGHNESS = roughness_amount;
	EMISSION = e * glow;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.1;
}
