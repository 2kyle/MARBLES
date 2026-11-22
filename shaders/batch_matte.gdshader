shader_type spatial;
// Scenery glued together by MeshBatch: each shape's colour comes from its
// vertices. Soft and matte like the rest of the game, a touch darker near
// the ground so things sit in the world.
//
// Texture slot "scenery" (assets/textures/README.md) lays an artist's
// picture over all of it, in world space.
render_mode cull_back;

#include "res://shaders/detail.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = apply_detail(COLOR.rgb, world_pos, world_nrm);
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
