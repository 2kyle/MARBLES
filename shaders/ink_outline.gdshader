shader_type spatial;
// Ink outlines round everything, like a hand-inked cartoon: drawn over the
// whole screen from the depth and normal buffers (no textures, and no extra
// copies of any mesh). Silhouettes get a line where something sits in front
// of something further away, and sharp creases (box edges, the top of a
// wall) get a softer line. Round low-poly shapes stay smooth, and lines fade
// out into the distance so far-off islands don't turn into scribbles.
//
// It lives on a 2x2 quad parked in front of the game camera (see
// InkOutline in scripts/art_style.gd). Settings > GRAPHICS turns it off on Low.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 ink : source_color = vec4(0.12, 0.07, 0.13, 1.0);
// How dark the lines are (0 = off).
uniform float strength : hint_range(0.0, 1.0) = 0.7;
// Line width in pixels (at 720p; it scales with the screen).
uniform float thickness = 1.2;
// Silhouette sensitivity: bigger = fewer lines.
uniform float depth_edge = 0.06;
// Crease sensitivity: lines where surfaces meet at more than about 55 degrees.
uniform float crease = 0.55;
// Lines fade out between these distances (metres).
uniform float fade_near = 30.0;
uniform float fade_far = 110.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// 1 / view distance (0 for the sky). It changes in a straight line across
// any flat surface, so a flat floor seen at a slant makes no lines.
float inv_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	if (d <= 0.000001) {
		return 0.0;
	}
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return 1.0 / max(-v.z / v.w, 0.0001);
}

vec3 normal_at(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness * max(VIEWPORT_SIZE.y / 720.0, 1.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float c = inv_depth(uv, INV_PROJECTION_MATRIX);
	float l = inv_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float r = inv_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX);
	float u = inv_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	float d = inv_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX);
	// Bend in 1/depth: zero on flat surfaces, big at a silhouette.
	float bend = max(abs(l + r - 2.0 * c), abs(u + d - 2.0 * c));
	float near = max(max(c, l), max(max(r, u), d));
	float sil = smoothstep(depth_edge, depth_edge * 2.0, bend / max(near, 0.0001));
	// Creases, from the normals (only where there's something there).
	float cr = 0.0;
	if (c > 0.0) {
		vec3 n = normal_at(uv);
		float m = min(min(dot(n, normal_at(uv + vec2(px.x, 0.0))), dot(n, normal_at(uv - vec2(px.x, 0.0)))),
				min(dot(n, normal_at(uv + vec2(0.0, px.y))), dot(n, normal_at(uv - vec2(0.0, px.y)))));
		cr = (1.0 - smoothstep(crease - 0.12, crease, m)) * 0.6;
	}
	float dist = near > 0.0 ? 1.0 / near : 1000.0;
	float fade = 1.0 - smoothstep(fade_near, fade_far, dist);
	ALBEDO = ink.rgb;
	ALPHA = clamp(max(sil, cr) * fade * strength, 0.0, 1.0);
}
