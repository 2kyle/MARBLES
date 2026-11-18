class_name MarbleTrail
extends Node3D
## The effect that follows a marble around: a ribbon, sparkles, bubbles,
## flames or a rainbow. Add it as a child of a Marble and call setup().

## How long a ribbon trail lasts, in seconds.
const RIBBON_TIME := 0.7
const RIBBON_WIDTH := 0.4

var kind := "none"
var color := Color.WHITE
## Show the effect even when standing still (for the locker screen).
var preview := false

var _points: Array = []   # [{pos, t}]
var _ribbon: MeshInstance3D
var _imesh: ImmediateMesh
var _particles: CPUParticles3D
var _time := 0.0


func setup(p_kind: String, p_color: Color) -> void:
	kind = p_kind
	color = p_color
	for c in get_children():
		c.queue_free()
	_ribbon = null
	_particles = null
	_points.clear()
	match kind:
		"ribbon", "rainbow":
			_imesh = ImmediateMesh.new()
			_ribbon = MeshInstance3D.new()
			_ribbon.mesh = _imesh
			_ribbon.top_level = true
			_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.vertex_color_use_as_albedo = true
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			_ribbon.material_override = mat
			add_child(_ribbon)
		"sparkles":
			_particles = _make_particles(0.05, 0.6, Color(1, 1, 0.85), true)
			_particles.amount = 40
			_particles.initial_velocity_min = 0.3
			_particles.initial_velocity_max = 1.2
			_particles.gravity = Vector3(0, -2, 0)
			var ramp := Gradient.new()
			ramp.set_color(0, color.lightened(0.6))
			ramp.set_color(1, Color(1, 1, 1, 0))
			_particles.color_ramp = ramp
		"bubbles":
			_particles = _make_particles(0.07, 0.9, Color(0.8, 0.95, 1.0, 0.6), false)
			_particles.amount = 24
			_particles.gravity = Vector3(0, 1.2, 0)
			_particles.scale_amount_min = 0.5
			_particles.scale_amount_max = 1.5
		"flame":
			_particles = _make_particles(0.12, 0.45, Color(1, 0.6, 0.1), true)
			_particles.amount = 60
			_particles.gravity = Vector3(0, 2.5, 0)
			_particles.scale_amount_min = 0.6
			_particles.scale_amount_max = 1.3
			var curve := Curve.new()
			curve.add_point(Vector2(0, 1))
			curve.add_point(Vector2(1, 0))
			_particles.scale_amount_curve = curve
			var ramp := Gradient.new()
			ramp.set_color(0, Color(1, 0.95, 0.5))
			ramp.add_point(0.4, Color(1, 0.45, 0.05, 0.9))
			ramp.set_color(ramp.get_point_count() - 1, Color(0.3, 0.05, 0.02, 0))
			_particles.color_ramp = ramp


func _make_particles(size: float, life: float, tint: Color, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.local_coords = false
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size) * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	if glow:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = tint
	mesh.material = mat
	p.mesh = mesh
	p.color = tint
	add_child(p)
	return p


func _process(delta: float) -> void:
	_time += delta
	var body := get_parent() as RigidBody3D
	var moving := preview or (body != null and body.visible and body.linear_velocity.length() > 1.0)
	if _particles:
		_particles.emitting = moving
	if _ribbon:
		_update_ribbon(moving)


func _update_ribbon(moving: bool) -> void:
	var now := _time
	if moving:
		_points.append({"pos": global_position, "t": now})
	while not _points.is_empty() and now - _points[0].t > RIBBON_TIME:
		_points.pop_front()
	_imesh.clear_surfaces()
	if _points.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else global_position + Vector3.UP * 5.0
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var p: Vector3 = _points[i].pos
		var nxt: Vector3 = _points[mini(i + 1, _points.size() - 1)].pos
		var prv: Vector3 = _points[maxi(i - 1, 0)].pos
		var along := (nxt - prv).normalized()
		var side := along.cross((eye - p).normalized()).normalized()
		var age: float = (now - _points[i].t) / RIBBON_TIME
		var w := RIBBON_WIDTH * (1.0 - age)
		var c := color
		if kind == "rainbow":
			c = Color.from_hsv(fmod(_points[i].t * 0.8, 1.0), 0.8, 1.0)
		c.a = (1.0 - age) * 0.8
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(p - side * w)
		_imesh.surface_set_color(c)
		_imesh.surface_add_vertex(p + side * w)
	_imesh.surface_end()
