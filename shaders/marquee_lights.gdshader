shader_type spatial;
render_mode unshaded, cull_disabled;
// Marquee chase lights along the top of the track walls, like the bulb
// borders on an old bowling alley sign. The lights chase down the track
// toward the pins, so they also show which way to roll.
//
// UV.x is the distance down the track in metres, UV.y runs across the
// strip (0..1).

uniform vec3 bulb_a : source_color = vec3(1.0, 0.78, 0.35);
uniform vec3 bulb_b : source_color = vec3(1.0, 0.35, 0.55);
uniform vec3 strip_color : source_color = vec3(0.12, 0.08, 0.1);
// Metres between bulbs.
uniform float spacing = 0.55;
// How fast the chase runs, bulbs per second.
uniform float chase_speed = 6.0;
// Brightness of a lit bulb (above 1 makes it glow).
uniform float brightness = 2.2;

void fragment() {
	float b = UV.x / spacing;
	float idx = floor(b);
	vec2 local = vec2(fract(b) - 0.5, UV.y - 0.5);
	// Round bulbs.
	float bulb = 1.0 - smoothstep(0.26, 0.36, length(local * vec2(1.0, 1.1)));
	// Every third bulb is lit, and the pattern moves down the track.
	float phase = mod(idx - floor(TIME * chase_speed), 3.0);
	float lit = phase < 0.5 ? 1.0 : 0.22;
	vec3 col = mix(bulb_a, bulb_b, step(1.0, mod(floor(idx / 3.0), 2.0)));
	ALBEDO = mix(strip_color, col * mix(0.5, brightness, lit), bulb);
}
