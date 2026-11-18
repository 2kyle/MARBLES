class_name Thumbnails
extends Node
## Live little pictures of every piece, for the draft cards. Each piece gets
## its own tiny 3D world (a SubViewport) with a camera and a light, so the
## pictures always match the real piece scenes, spinner spinning and all.

## Picture size in pixels.
@export var picture_size := 128

var _textures := {}


func _ready() -> void:
	for id in PieceCatalog.ids():
		_textures[id] = _make(id)


func texture_for(id: String) -> Texture2D:
	return _textures.get(id)


func _make(id: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(picture_size, picture_size)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var info := PieceCatalog.info(id)
	var piece: Node3D = load(info.scene).instantiate()
	piece.rotation.y = deg_to_rad(info.base_rotation)
	# A plain floor tile under the piece so flat pieces read clearly.
	var floor_tile := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	var r: float = maxf(info.radius, 0.6)
	floor_mesh.size = Vector3(r * 2.4, 0.05, r * 2.4)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.72, 0.55, 0.36)
	floor_mesh.material = floor_mat
	floor_tile.mesh = floor_mesh
	floor_tile.position.y = -0.03
	if not PieceCatalog.is_track(id):
		vp.add_child(floor_tile)
	vp.add_child(piece)

	var cam := Camera3D.new()
	cam.fov = 40.0
	var d := r * 2.6 + 0.8
	cam.position = Vector3(0, d * 0.85, d * 0.75)
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.2, 0))

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0)
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	return vp.get_texture()
