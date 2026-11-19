shader_type spatial;
render_mode specular_schlick_ggx;
// Water under the track: a calm pastel lake. Two slow swells move the
// surface and a cheap sparkle pattern catches the light. Kept simple on
// purpose (see ArtStyle). Change the colours or wave size below.

uniform vec4 deep_color : source_color = vec4(0.14, 0.4, 0.54, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.34, 0.64, 0.74, 1.0);
uniform float wave_height = 0.1;
uniform float wave_speed = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += (sin(world_pos.x * 0.3 + t) + sin(world_pos.z * 0.37 - t * 0.8)) * 0.5 * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	// A gentle tilt of the normal from the same two swells.
	vec3 n = normalize(vec3(-cos(p.x * 0.3 + t) * 0.06, 1.0, cos(p.y * 0.37 - t * 0.8) * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, fresnel);
	ROUGHNESS = 0.35;
	SPECULAR = 0.3;
}
