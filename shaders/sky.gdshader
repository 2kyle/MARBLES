shader_type sky;
// The sky: blue gradient, a sun that follows the Sun light, soft clouds and
// a ring of distant hills on the horizon. All made here, no image files.

uniform vec3 top_color : source_color = vec3(0.22, 0.45, 0.82);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.84, 0.95);
uniform vec3 sea_color : source_color = vec3(0.04, 0.16, 0.24);
uniform vec3 hill_color : source_color = vec3(0.32, 0.46, 0.4);
uniform vec3 far_hill_color : source_color = vec3(0.52, 0.64, 0.7);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));

	// Clouds, projected onto a flat layer overhead.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.4;
		float c = fbm(uv + vec2(3.0, 7.0));
		c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.3, c);
		c *= smoothstep(0.0, 0.12, h);
		vec3 cloud = mix(vec3(0.82, 0.85, 0.9), vec3(1.0), smoothstep(0.0, 0.5, h));
		col = mix(col, cloud, c * 0.9);
	}

	// Sun.
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += vec3(1.0, 0.9, 0.7) * (pow(s, 900.0) * 6.0 + pow(s, 12.0) * 0.25);
	}

	// Hills around the horizon (far ring, then near ring).
	float az = atan(d.x, d.z);
	float far_h = 0.02 + 0.05 * fbm(vec2(az * 3.0, 1.0));
	if (h < far_h && h > -0.02) {
		col = mix(col, far_hill_color, 0.9);
	}
	float near_h = -0.005 + 0.06 * pow(fbm(vec2(az * 2.0 + 10.0, 4.0)), 1.6) * 1.8;
	if (h < near_h && h > -0.02) {
		col = hill_color * (0.8 + 0.4 * fbm(vec2(az * 30.0, h * 200.0)));
	}

	// The sea below the horizon.
	if (h <= -0.02) {
		col = mix(sea_color * 1.6, sea_color, smoothstep(-0.02, -0.25, h));
	}
	COLOR = col;
}
