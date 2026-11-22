class_name TextureSlots
extends RefCounted
## Empty slots for hand-made textures. The game's look is painted in code,
## and every slot below is ready for a real picture from Kyle or an artist:
## drop a file named after the slot into assets/textures/ (for example
## assets/textures/lane.png) and it shows up in the game, no code needed.
## With no file, the slot does nothing.
##
## How each picture is used, sizes and tips: assets/textures/README.md.
## Remember a row in assets/CREDITS.md for anything you didn't make.

const FOLDER := "res://assets/textures/"
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]

## id: what it covers, how many times it repeats per metre, how strongly it
## shows (0..1).
const SLOTS := {
	"lane": {"about": "the wooden bowling lane floor", "scale": 0.5, "strength": 0.7},
	"pieces": {"about": "every lane piece (bumpers, ramps, rails...)", "scale": 1.5, "strength": 0.5},
	"scenery": {"about": "rocks, cliffs, trees, ruins and buildings everywhere", "scale": 0.35, "strength": 0.45},
	"marble": {"about": "the marbles (bowling balls)", "scale": 2.0, "strength": 0.35},
	"hub_grass": {"about": "the grass on top of the hub island", "scale": 0.25, "strength": 1.0},
}

static var _cache := {}


## The picture in a slot, or null if there isn't one yet.
static func texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [FOLDER, id, ext]
		if ResourceLoader.exists(path):
			tex = load(path)
			break
	_cache[id] = tex
	return tex


## Put a slot's picture on a material, if there is one. Works on the
## game's shaders (they share shaders/detail.gdshaderinc) and on plain
## StandardMaterial3Ds (the picture multiplies the colour, wrapped round
## the shape in world space).
static func dress(mat: Material, id: String) -> void:
	var tex := texture(id)
	if tex == null or mat == null:
		return
	var slot: Dictionary = SLOTS[id]
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		sm.set_shader_parameter("detail_tex", tex)
		sm.set_shader_parameter("use_detail", true)
		sm.set_shader_parameter("detail_scale", slot.scale)
		sm.set_shader_parameter("detail_strength", slot.strength)
	elif mat is StandardMaterial3D:
		var st := mat as StandardMaterial3D
		st.albedo_texture = tex
		st.uv1_triplanar = true
		st.uv1_world_triplanar = true
		st.uv1_scale = Vector3.ONE * float(slot.scale)
