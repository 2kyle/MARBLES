shader_type spatial;
render_mode cull_disabled;
// A classic wooden bowling lane, painted on the track's floor.
//
// The floor's UV is in metres: UV.x runs across the lane (0 = centre line)
// and UV.y is the distance down the track from the start. So the boards,
// dots and arrows stay the same size however long or bendy the track is.
//
// What's drawn:
//   - 39 thin maple boards with dark seams, wood grain and staggered ends
//   - approach dots behind the start, a black foul line just after it
//   - a row of guide dots, then the seven aiming arrows in a V
//   - range finder marks a little way before the pins

uniform vec3 maple : source_color = vec3(0.86, 0.68, 0.45);
uniform vec3 maple_dark : source_color = vec3(0.74, 0.53, 0.32);
uniform vec3 ink : source_color = vec3(0.1, 0.06, 0.05);
uniform vec3 arrow_color : source_color = vec3(0.55, 0.1, 0.08);
uniform float lane_width = 5.0;
uniform float lane_length = 100.0;
// Distances down the track (metres).
uniform float approach_dots_at = 0.7;
uniform float foul_line_at = 3.1;
uniform float guide_dots_at = 5.0;
uniform float arrows_at = 7.0;
// Oil Slick stretches (Track.oils): start and end distances, -1 = unused.
uniform float oil_from[4];
uniform float oil_to[4];

const float BOARDS = 39.0;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// Centre of board number b (1 = far left, 20 = middle, 39 = far right).
float board_x(float b, float bw) { return (b - 20.0) * bw; }

float dot_mark(vec2 p, vec2 c, float r) {
	return 1.0 - smoothstep(r * 0.8, r, length(p - c));
}

// A slim triangle pointing down the lane, tip at `tip`.
float arrow_mark(vec2 p, vec2 tip, float len, float half_w) {
	float t = (tip.y - p.y) / len;   // 0 at the tip, 1 at the back
	if (t < 0.0 || t > 1.0) return 0.0;
	float w = half_w * t;
	return 1.0 - smoothstep(w * 0.85, w + 0.004, abs(p.x - tip.x));
}

void fragment() {
	vec2 p = UV;
	float bw = lane_width / BOARDS;
	float bf = (p.x + lane_width * 0.5) / bw;
	float b = floor(bf);
	float across = fract(bf);
	float h = hash(b + 3.0);

	// Each board a slightly different shade of maple, with fine grain.
	vec3 wood = mix(maple, maple_dark, h * 0.45);
	float grain = sin(p.y * (9.0 + h * 7.0) + across * 6.0 + h * 40.0) * 0.5 + 0.5;
	grain *= sin(p.y * 2.3 + h * 17.0) * 0.5 + 0.5;
	wood *= 0.95 + 0.07 * grain;
	// Boards end at different places, like a real lane.
	float seg = 3.0 + h * 2.5;
	float joint = fract((p.y + h * 11.0) / seg) * seg;
	float ends = 1.0 - smoothstep(0.0, 0.012, min(joint, seg - joint));
	// The thin dark lines between boards.
	float seam = 1.0 - smoothstep(0.0, 0.05, min(across, 1.0 - across));
	wood *= 1.0 - 0.38 * max(seam, ends * 0.7);

	float marks = 0.0;
	float arrows = 0.0;
	// Approach dots, behind the start.
	for (float k = 0.0; k < 5.0; k += 1.0) {
		float bb = k == 0.0 ? 3.0 : k == 1.0 ? 5.0 : k == 2.0 ? 8.0 : k == 3.0 ? 11.0 : 14.0;
		marks = max(marks, dot_mark(p, vec2(board_x(bb, bw), approach_dots_at), 0.055));
		marks = max(marks, dot_mark(p, vec2(board_x(40.0 - bb, bw), approach_dots_at), 0.055));
		// Guide dots, just past the foul line.
		marks = max(marks, dot_mark(p, vec2(board_x(bb, bw), guide_dots_at), 0.045));
		marks = max(marks, dot_mark(p, vec2(board_x(40.0 - bb, bw), guide_dots_at), 0.045));
	}
	marks = max(marks, dot_mark(p, vec2(0.0, approach_dots_at), 0.055));
	// The foul line, right across.
	marks = max(marks, 1.0 - smoothstep(0.03, 0.04, abs(p.y - foul_line_at)));
	// Seven arrows in a V, the middle one furthest down the lane.
	for (float k = 0.0; k < 7.0; k += 1.0) {
		float off = abs(k - 3.0);
		float bb = 5.0 + k * 5.0;
		vec2 tip = vec2(board_x(bb, bw), arrows_at + 1.2 - off * 0.3);
		arrows = max(arrows, arrow_mark(p, tip, 0.55, bw * 0.75));
	}
	// Range finders: two long thin marks a little before the pins.
	float rf = lane_length - 13.0;
	if (rf > arrows_at + 6.0) {
		for (float s = -1.0; s <= 1.0; s += 2.0) {
			float x = board_x(20.0 + s * 10.0, bw);
			float on = step(abs(p.x - x), bw * 0.18) * step(abs(p.y - rf), 1.2);
			marks = max(marks, on);
		}
	}

	vec3 col = mix(wood, ink, marks * 0.9);
	col = mix(col, arrow_color, arrows * 0.95);

	// Oil Slick: darker, wet-looking wood with a rainbow film swirling on it,
	// fading in and out at the ends.
	float oil = 0.0;
	for (int k = 0; k < 4; k++) {
		if (oil_to[k] > oil_from[k]) {
			float edge = min(p.y - oil_from[k], oil_to[k] - p.y);
			oil = max(oil, smoothstep(0.0, 1.2, edge));
		}
	}
	if (oil > 0.0) {
		float swirl = sin(p.x * 3.1 + sin(p.y * 1.7 + TIME * 0.6) * 2.0 + p.y * 0.9);
		swirl += sin(p.y * 2.3 - p.x * 1.4 + TIME * 0.4) * 0.6;
		vec3 film = 0.5 + 0.5 * cos(6.2831 * (swirl * 0.35 + vec3(0.0, 0.33, 0.67)));
		vec3 wet = col * 0.62;
		col = mix(col, mix(wet, film, 0.28), oil);
	}
	ALBEDO = col;
	// Polished and oiled: shiny, with a clear-coat sheen. Glassy on a slick.
	ROUGHNESS = mix(0.3, 0.05, oil);
	SPECULAR = mix(0.6, 0.9, oil);
	CLEARCOAT = mix(0.4, 1.0, oil);
	CLEARCOAT_ROUGHNESS = mix(0.2, 0.02, oil);
}
