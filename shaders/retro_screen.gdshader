shader_type canvas_item;
// The "retro bowling alley" look, drawn over the 3D world (under the HUD).
// Think a 70s/80s alley photographed on warm film: amber highlights,
// slightly purple shadows, a soft dark edge round the screen, a little film
// grain. "Arcade" adds faint CRT scanlines and a touch of colour fringing.
//
// Every effect has its own strength below, so it's easy to tune. Set
// a strength to 0 to switch that part off.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// 0 = off, 1 = full strength. The game sets this from Settings.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// Warm film colours.
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.9, 0.74);
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.32, 0.55);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.18;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
// Dark corners.
uniform float vignette : hint_range(0.0, 1.0) = 0.38;
// Film grain (moving noise).
uniform float grain : hint_range(0.0, 0.2) = 0.035;
// Arcade extras.
uniform float scanlines : hint_range(0.0, 1.0) = 0.0;
uniform float fringe : hint_range(0.0, 3.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	vec3 col;
	if (fringe > 0.0) {
		// Colour fringing, stronger toward the edges like an old tube.
		vec2 off = c * dot(c, c) * fringe * 0.02;
		col.r = texture(screen, uv + off).r;
		col.g = texture(screen, uv).g;
		col.b = texture(screen, uv - off).b;
	} else {
		col = texture(screen, uv).rgb;
	}
	vec3 src = col;

	// Contrast and saturation.
	col = (col - 0.5) * contrast + 0.5;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	// Split toning: purple into the shadows, amber into the highlights.
	vec3 toned = mix(col * mix(vec3(1.0), shadow_tint * 1.9, 1.0 - smoothstep(0.0, 0.55, luma)),
			col * highlight_tint * 1.08, smoothstep(0.35, 1.0, luma));
	col = mix(col, toned, tint_strength);

	// Vignette.
	float v = smoothstep(0.85, 0.25, length(c * vec2(1.0, 0.82)));
	col *= mix(1.0, v, vignette);

	// Scanlines: one dark line every 3 pixels (screen space, so they stay
	// crisp at any size).
	if (scanlines > 0.0) {
		float line = 0.5 + 0.5 * cos(FRAGCOORD.y * 2.094);
		col *= 1.0 - scanlines * 0.22 * line;
	}

	// Film grain, a little stronger in the shadows.
	float n = hash(FRAGCOORD.xy + fract(TIME * 7.13) * 100.0) - 0.5;
	col += n * grain * (1.3 - luma);

	COLOR = vec4(mix(src, clamp(col, 0.0, 1.0), amount), 1.0);
}
