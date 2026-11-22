class_name PopText
extends Label3D
## Little comic-book words that pop out of the world and float away:
## "POP!" off a pop bumper, "BOING!" off a bounce pad, "THUD!" on a big
## landing. Always faces the camera and draws over the scenery.
##
##   PopText.spawn(some_node, where, "BOING!", Color.ORANGE)

const FONT := preload("res://fonts/Righteous-Regular.ttf")
## Seconds on screen.
const LIFE := 0.8

var _age := 0.0
var _tilt := 0.0


## Show `text` at world position `at`. `parent` is any node in the world
## (it's only used to find the world; the word frees itself when done).
static func spawn(parent: Node, at: Vector3, text: String, color: Color, size := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := PopText.new()
	p.text = text
	p.modulate = color
	p.pixel_size = 0.006 * size
	p.font = FONT
	p.font_size = 64
	p.outline_size = 18
	p.outline_modulate = Color(0.08, 0.04, 0.12)
	p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	p.no_depth_test = true
	p.render_priority = 5
	p.outline_render_priority = 4
	p._tilt = randf_range(-0.25, 0.25)
	# Straight under the viewport, so a scaled piece doesn't stretch it.
	parent.get_viewport().add_child(p)
	p.global_position = at


func _process(delta: float) -> void:
	_age += delta
	var t := _age / LIFE
	if t >= 1.0:
		queue_free()
		return
	# Pop in big, settle, drift up, fade out.
	var pop := 1.0 + 0.6 * exp(-t * 14.0) * cos(t * 30.0)
	scale = Vector3.ONE * pop
	rotation.z = _tilt
	position.y += delta * 1.1
	var a := 1.0 - smoothstep(0.6, 1.0, t)
	modulate.a = a
	outline_modulate.a = a
