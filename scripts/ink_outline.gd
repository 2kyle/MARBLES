class_name InkOutline
extends MeshInstance3D
## The ink outlines (shaders/ink_outline.gdshader): a screen-sized quad
## that rides along in front of a camera. Add one to a camera with attach().

const SHADER := preload("res://shaders/ink_outline.gdshader")

var material: ShaderMaterial


static func attach(cam: Camera3D) -> InkOutline:
	var ink := InkOutline.new()
	ink.name = "InkOutline"
	cam.add_child(ink)
	return ink


func _init() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	material = ShaderMaterial.new()
	material.shader = SHADER
	# Draw after the see-through things (water, ghosts) too.
	material.render_priority = 100
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader puts the quad over the whole screen itself, so never let the
	# engine think it's off camera.
	extra_cull_margin = 16384.0
	position = Vector3(0, 0, -0.5)
