class_name LowPoly
extends RefCounted
## Small helpers for building scenery out of simple shapes in code: boxes,
## cylinders, balls, floating labels, solid (rollable) shapes and confetti.
## The practice island, the sports island, the derby and the crate screen
## all use these, so the look stays the same everywhere.
##
## Materials are shared by colour (one material per colour, not one per
## shape), which keeps things fast. If you want to change a shape's material
## afterwards (make it glow, shine and so on), call own_mat() first so the
## change only affects that shape.

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const CONFETTI_COLORS := [Color(1, 0.4, 0.55), Color(1, 0.85, 0.3), Color(0.45, 0.8, 1),
		Color(0.6, 0.95, 0.5), Color(0.8, 0.55, 1)]

static var _mats := {}


## A soft matte material in `color`, shared by every shape of that colour.
static func mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_mats[color] = m
	return _mats[color]


## Give a shape its own copy of its material (to change just that shape).
static func own_mat(mi: GeometryInstance3D) -> StandardMaterial3D:
	var m: StandardMaterial3D = mi.material_override.duplicate()
	mi.material_override = m
	return m


static func _shape(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _shape(parent, mesh, pos, color)
	mi.rotation.y = yaw
	return mi


## A cylinder (or a cone, with `top` 0) standing on its middle at `pos`.
static func cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, color: Color, sides := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	return _shape(parent, mesh, pos, color)


static func ball(parent: Node3D, pos: Vector3, r: float, color: Color, segments := 10) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 3)
	return _shape(parent, mesh, pos, color)


## Chunky outlined text in the game's title font.
static func label(parent: Node3D, pos: Vector3, text: String, size: int, outline: Color, yaw := 0.0, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TITLE_FONT
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 14
	l.outline_modulate = outline
	l.position = pos
	l.rotation.y = yaw
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	parent.add_child(l)
	return l


## An invisible solid box marbles roll on or bump into.
static func solid_box(parent: Node3D, size: Vector3, pos: Vector3, yaw := 0.0, bounce := 0.1) -> StaticBody3D:
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.6
	body.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	return body


## An invisible solid cylinder.
static func solid_cyl(parent: Node3D, r: float, h: float, pos: Vector3, bounce := 0.1) -> StaticBody3D:
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	body.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	shape.shape = c
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	return body


## A trigger zone that calls `on_marble(marble)` when a marble rolls in.
static func marble_zone(parent: Node3D, size: Vector3, pos: Vector3, on_marble: Callable) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	area.add_child(shape)
	area.position = pos
	parent.add_child(area)
	area.body_entered.connect(func(body):
		if body is Marble:
			on_marble.call(body))
	return area


## A one-off burst of little paper squares that flutter down.
static func confetti(parent: Node3D, at: Vector3, amount := 70) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 2.2
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, -6.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.particle_flag_rotate_y = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray(CONFETTI_COLORS)
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = ramp
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
