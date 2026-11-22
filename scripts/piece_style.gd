class_name PieceStyle
extends RefCounted
## Paints the lane pieces in the game's toy style (shaders/toy_paint.gdshader):
## candy-striped bumpers, hazard stripes, chevrons that point the way a
## piece pushes, checks, dots and wood grain. Call dress() on a piece right
## after it's made; every place that makes pieces does (the course builder,
## the draft card pictures and the practice island).
##
## To restyle a piece, change its entry in STYLES. Each entry maps a part of
## the piece (its node name) to how it's painted:
##   base, accent   the two paint colours
##   pattern        "plain", "stripes", "checks", "dots", "chevrons", "wood"
##   scale          pattern repeats per metre
##   axis           which way stripes, chevrons and grain run
##   rough          0 = shiny, 1 = chalky
##   glow           how much it lights itself up
## Parts not listed keep their colour but still get the painted finish,
## except glowing and see-through ones (teleporter swirls, fan streaks),
## which are left alone.

const SHADER := preload("res://shaders/toy_paint.gdshader")
const PATTERNS := {"plain": 0, "stripes": 1, "checks": 2, "dots": 3, "chevrons": 4, "wood": 5}

const WHITE := Color(0.98, 0.97, 0.94)
const GOLD := Color(1.0, 0.8, 0.3)
const INK := Color(0.16, 0.15, 0.2)

const STYLES := {
	"bumper_post": {
		"Mesh": {"base": Color(0.95, 0.3, 0.36), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP, "rough": 0.35},
		"Ring": {"base": GOLD, "rough": 0.3},
	},
	"angled_rail": {
		"Mesh": {"base": Color(0.25, 0.5, 0.95), "accent": WHITE, "pattern": "stripes", "scale": 3.0, "axis": Vector3(0, 1, 1)},
	},
	"ramp_jump": {
		"Mesh": {"base": Color(0.3, 0.72, 0.42), "accent": Color(1.0, 0.8, 0.28), "pattern": "chevrons", "scale": 1.6, "axis": Vector3(0, 0, -1)},
	},
	"carpet_strip": {
		"Mesh": {"base": Color(0.8, 0.25, 0.32), "accent": Color(0.98, 0.7, 0.35), "pattern": "stripes", "scale": 4.0, "axis": Vector3(1, 0, 0), "rough": 1.0},
	},
	"booster_pad": {
		"Mesh": {"base": Color(0.12, 0.52, 0.95), "accent": Color(0.6, 0.9, 1.0), "pattern": "chevrons", "scale": 2.4, "axis": Vector3(0, 0, -1), "glow": 0.35},
		"Arrow": {"base": WHITE, "glow": 0.8},
	},
	"spinner": {
		"Mesh": {"base": Color(1.0, 0.5, 0.2), "accent": WHITE, "pattern": "stripes", "scale": 3.0, "axis": Vector3(1, 0, 0)},
		"Hub/Mesh": {"base": Color(0.62, 0.43, 0.28), "accent": Color(0.42, 0.28, 0.18), "pattern": "wood", "scale": 6.0},
	},
	"gutter_cut": {
		"Rim": {"base": Color(1.0, 0.35, 0.3), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3(1, 0, 1)},
		"Hole": {"base": Color(0.1, 0.08, 0.14), "rough": 1.0},
	},
	"curve": {
		"*": {"base": Color(0.25, 0.5, 0.95), "accent": WHITE, "pattern": "stripes", "scale": 6.0, "axis": Vector3.UP},
	},
	"drop_step": {
		"RampMesh": {"base": Color(0.2, 0.62, 0.7), "accent": Color(0.6, 0.88, 0.92), "pattern": "chevrons", "scale": 1.8, "axis": Vector3(0, 0, -1)},
		"LedgeMesh": {"base": Color(0.66, 0.48, 0.32), "accent": Color(0.46, 0.32, 0.2), "pattern": "wood", "scale": 4.0, "axis": Vector3(1, 0, 0)},
		"Edge": {"base": Color(1.0, 0.82, 0.3), "accent": INK, "pattern": "stripes", "scale": 8.0, "axis": Vector3(1, 0, 0.6)},
	},
	"hump": {
		"Mesh": {"base": Color(0.35, 0.72, 0.42), "accent": Color(0.7, 0.92, 0.5), "pattern": "stripes", "scale": 2.5, "axis": Vector3.UP},
	},
	"washboard": {
		"Mesh0": {"base": Color(0.35, 0.72, 0.35), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP},
		"Mesh1": {"base": Color(1.0, 0.72, 0.2), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP},
		"Mesh2": {"base": Color(0.35, 0.72, 0.35), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP},
		"Mesh3": {"base": Color(1.0, 0.72, 0.2), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP},
		"Mesh4": {"base": Color(0.35, 0.72, 0.35), "accent": WHITE, "pattern": "stripes", "scale": 5.0, "axis": Vector3.UP},
	},
	"tilt_table": {
		"Mesh": {"base": Color(0.55, 0.4, 0.9), "accent": Color(0.85, 0.8, 1.0), "pattern": "checks", "scale": 2.2},
		"Stripe": {"base": GOLD},
	},
	"pop_bumper": {
		"Base": {"base": WHITE, "accent": Color(1.0, 0.25, 0.45), "pattern": "stripes", "scale": 6.0, "axis": Vector3.UP, "rough": 0.3},
		"Skirt": {"base": INK, "rough": 0.4},
	},
	"pendulum": {
		"*": {"base": Color(0.62, 0.43, 0.28), "accent": Color(0.42, 0.28, 0.18), "pattern": "wood", "scale": 6.0},
		"Bar": {"base": Color(1.0, 0.82, 0.3), "accent": INK, "pattern": "stripes", "scale": 4.0, "axis": Vector3(1, 0, 0.6)},
		"Swing/Ball": {"base": Color(0.22, 0.12, 0.5), "accent": Color(0.45, 0.2, 0.75), "pattern": "dots", "scale": 7.0, "rough": 0.12},
		"Arm/Rod": {"base": Color(0.75, 0.77, 0.8), "rough": 0.3},
		"Swing/Ball/Hole0": {"base": Color(0.03, 0.03, 0.05), "rough": 1.0},
		"Swing/Ball/Hole1": {"base": Color(0.03, 0.03, 0.05), "rough": 1.0},
		"Swing/Ball/Hole2": {"base": Color(0.03, 0.03, 0.05), "rough": 1.0},
	},
	"magnet": {
		"Disc": {"base": Color(0.28, 0.3, 0.4), "accent": Color(0.35, 0.38, 0.5), "pattern": "checks", "scale": 3.0, "rough": 0.8},
		"Shoe": {"base": Color(0.92, 0.18, 0.2), "rough": 0.35},
	},
	"bounce_pad": {
		"Mat": {"base": Color(1.0, 0.35, 0.3), "accent": Color(1.0, 0.55, 0.45), "pattern": "dots", "scale": 6.0, "rough": 0.9},
		"Frame": {"base": INK, "accent": Color(1.0, 0.8, 0.3), "pattern": "stripes", "scale": 10.0, "axis": Vector3(1, 0, 1)},
	},
	"bomb": {
		"Body": {"base": Color(0.18, 0.18, 0.26), "accent": Color(0.28, 0.28, 0.38), "pattern": "dots", "scale": 5.0, "rough": 0.3},
		"Cap": {"base": Color(0.8, 0.65, 0.42)},
		"Fuse": {"base": Color(0.62, 0.43, 0.28), "accent": Color(0.45, 0.3, 0.2), "pattern": "wood", "scale": 12.0},
	},
	"teleporter": {"skip": true},
	"teleporter_exit": {"skip": true},
}

static var _cache := {}


## Paint every part of `piece` (a piece with id `id`) in its toy style.
static func dress(piece: Node3D, id: String) -> void:
	var styles: Dictionary = STYLES.get(id, {})
	if styles.get("skip", false):
		return
	_dress_node(piece, piece, id, styles)


static func _dress_node(node: Node, piece: Node3D, id: String, styles: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var old := _current_material(mi)
		var path := str(piece.get_path_to(mi))
		var named: bool = styles.has(path) or styles.has(mi.name)
		# Parts named in STYLES are always painted; other glowing or
		# see-through parts are effects and stay as they are.
		if old and (named or not _leave_alone(old)):
			var style: Dictionary = styles.get(path, styles.get(mi.name, styles.get("*", {})))
			mi.material_override = _material(id, path, style, old.albedo_color, _height_in(mi, piece))
	for child in node.get_children():
		_dress_node(child, piece, id, styles)


static func _current_material(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi.material_override is StandardMaterial3D:
		return mi.material_override
	if mi.mesh and mi.mesh.get_surface_count() > 0 and mi.mesh.surface_get_material(0) is StandardMaterial3D:
		return mi.mesh.surface_get_material(0)
	return null


## Glowing, see-through and unshaded parts are effects: keep them as they are.
static func _leave_alone(m: StandardMaterial3D) -> bool:
	return m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			or (m.emission_enabled and m.emission.get_luminance() > 0.2)


## How high the middle of a part is above the bottom of the piece.
static func _height_in(mi: Node3D, piece: Node3D) -> float:
	var y := 0.0
	var n: Node = mi
	while n != piece and n is Node3D:
		y += (n as Node3D).position.y
		n = n.get_parent()
	return y


## One material per part per piece type, shared by every copy.
static func _material(id: String, path: String, style: Dictionary, fallback: Color, height: float) -> ShaderMaterial:
	var key := "%s/%s" % [id, path]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var base: Color = style.get("base", fallback)
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("accent_color", style.get("accent", base.lightened(0.25)))
	m.set_shader_parameter("pattern", PATTERNS[style.get("pattern", "plain")])
	m.set_shader_parameter("pattern_scale", style.get("scale", 3.0))
	m.set_shader_parameter("pattern_axis", style.get("axis", Vector3(0, 0, 1)))
	m.set_shader_parameter("roughness_amount", style.get("rough", 0.55))
	m.set_shader_parameter("glow", style.get("glow", 0.0))
	m.set_shader_parameter("height_offset", height)
	TextureSlots.dress(m, "pieces")   # an artist's picture, if there is one
	_cache[key] = m
	return m
