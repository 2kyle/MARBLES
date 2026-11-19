shader_type spatial;
// Scenery glued together by MeshBatch: each shape's colour comes from its
// vertices. Soft and matte like the rest of the game, a touch darker near
// the ground so things sit in the world.
render_mode cull_back;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
