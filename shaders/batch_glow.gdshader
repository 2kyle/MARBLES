shader_type spatial;
// The glowing half of a MeshBatch (windows, neon, crystals, lamps): it
// lights itself in its own colour, so it shows up at night and blooms.
render_mode cull_back;

uniform float energy = 2.5;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * energy;
	ROUGHNESS = 0.4;
}
