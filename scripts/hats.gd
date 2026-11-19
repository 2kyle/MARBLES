class_name Hats
extends RefCounted
## Builds the hat meshes. Every hat is made from a few simple low-poly
## shapes, sized for a ball of radius 1 whose middle is at (0, 0, 0), so the
## hat sits around y = 1. The marble scales it down to its own size.
## The hat faces -Z (the way the marble is rolling).
##
## To add a hat: add it to Cosmetics.HATS and add a `match` branch below.


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Hat"
	match id:
		"party":
			_add(root, _cone(0.42, 1.1, 8), Vector3(0, 1.45, 0), Color(0.3, 0.75, 1.0), Vector3(-0.15, 0, 0.1))
			_add(root, _ball(0.13), Vector3(0.08, 2.0, -0.1), Color(1.0, 0.85, 0.2))
			_add(root, _ring(0.4, 0.06, 8), Vector3(0, 1.0, 0), Color(1.0, 0.4, 0.6), Vector3(-0.15, 0, 0.1))
		"beanie":
			_add(root, _dome(0.88, 0.62), Vector3(0, 0.62, 0), Color(0.9, 0.3, 0.3))
			_add(root, _cyl(0.9, 0.9, 0.22, 12), Vector3(0, 0.62, 0), Color(0.95, 0.95, 0.95))
			_add(root, _ball(0.2), Vector3(0, 1.38, 0), Color(0.95, 0.95, 0.95))
		"cap":
			_add(root, _dome(0.85, 0.55), Vector3(0, 0.62, 0), Color(0.2, 0.45, 0.9))
			_add(root, _box(Vector3(0.9, 0.06, 0.6)), Vector3(0, 0.66, -0.95), Color(0.15, 0.32, 0.7), Vector3(0.12, 0, 0))
			_add(root, _ball(0.08), Vector3(0, 1.18, 0), Color(0.95, 0.95, 0.95))
		"cone":
			_add(root, _box(Vector3(1.3, 0.1, 1.3)), Vector3(0, 0.92, 0), Color(1.0, 0.45, 0.1))
			_add(root, _cone(0.48, 1.1, 8), Vector3(0, 1.52, 0), Color(1.0, 0.45, 0.1))
			_add(root, _cyl(0.33, 0.37, 0.18, 8), Vector3(0, 1.5, 0), Color(0.97, 0.97, 0.97))
		"tophat":
			_add(root, _cyl(1.0, 1.0, 0.08, 14), Vector3(0, 0.88, 0), Color(0.12, 0.12, 0.15))
			_add(root, _cyl(0.6, 0.62, 0.9, 14), Vector3(0, 1.35, 0), Color(0.12, 0.12, 0.15))
			_add(root, _cyl(0.63, 0.65, 0.16, 14), Vector3(0, 1.02, 0), Color(0.85, 0.2, 0.25))
		"cowboy":
			_add(root, _cyl(1.25, 1.25, 0.07, 12), Vector3(0, 0.86, 0), Color(0.62, 0.4, 0.22))
			_add(root, _ring(1.2, 0.12, 12), Vector3(0, 0.92, 0), Color(0.62, 0.4, 0.22))
			_add(root, _cyl(0.5, 0.62, 0.6, 10), Vector3(0, 1.18, 0), Color(0.62, 0.4, 0.22))
			_add(root, _cyl(0.64, 0.64, 0.1, 10), Vector3(0, 0.97, 0), Color(0.3, 0.18, 0.1))
		"chef":
			_add(root, _cyl(0.7, 0.66, 0.5, 12), Vector3(0, 1.08, 0), Color(0.97, 0.97, 0.97))
			for k in 5:
				var a := k * TAU / 5.0
				_add(root, _ball(0.42), Vector3(cos(a) * 0.38, 1.55, sin(a) * 0.38), Color(0.97, 0.97, 0.97))
			_add(root, _ball(0.45), Vector3(0, 1.7, 0), Color(0.97, 0.97, 0.97))
		"bunny":
			_add(root, _ring(0.72, 0.1, 12), Vector3(0, 0.72, 0), Color(0.95, 0.55, 0.75))
			for side in [-1.0, 1.0]:
				_add(root, _capsule(0.2, 1.1), Vector3(side * 0.32, 1.35, 0), Color(0.98, 0.95, 0.95), Vector3(0, 0, -side * 0.2))
				_add(root, _capsule(0.11, 0.8), Vector3(side * 0.34, 1.38, -0.12), Color(1.0, 0.6, 0.75), Vector3(0, 0, -side * 0.2))
		"flowers":
			_add(root, _ring(0.7, 0.09, 12), Vector3(0, 0.74, 0), Color(0.35, 0.7, 0.3))
			var petals := [Color(1.0, 0.5, 0.65), Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 1.0), Color(1.0, 0.98, 0.95)]
			for k in 8:
				var a := k * TAU / 8.0
				var c: Color = petals[k % petals.size()]
				_add(root, _ball(0.2), Vector3(cos(a) * 0.7, 0.8, sin(a) * 0.7), c)
				_add(root, _ball(0.08), Vector3(cos(a) * 0.76, 0.86, sin(a) * 0.76), Color(1.0, 0.8, 0.2))
		"propeller":
			_add(root, _dome(0.85, 0.55), Vector3(0, 0.62, 0), Color(1.0, 0.85, 0.2))
			_add(root, _cyl(0.06, 0.06, 0.3, 6), Vector3(0, 1.3, 0), Color(0.3, 0.3, 0.35))
			var spin := Node3D.new()
			spin.name = "Spin"
			spin.position = Vector3(0, 1.46, 0)
			root.add_child(spin)
			_add(spin, _box(Vector3(1.5, 0.04, 0.22)), Vector3.ZERO, Color(0.9, 0.25, 0.3))
			_add(spin, _box(Vector3(0.22, 0.04, 1.5)), Vector3.ZERO, Color(0.25, 0.55, 1.0))
		"pirate":
			_add(root, _dome(0.88, 0.5), Vector3(0, 0.66, 0), Color(0.15, 0.13, 0.15))
			_add(root, _box(Vector3(2.0, 0.55, 0.12)), Vector3(0, 1.1, 0), Color(0.15, 0.13, 0.15), Vector3(0, 0, 0))
			_add(root, _ball(0.12), Vector3(0, 1.12, -0.09), Color(0.95, 0.95, 0.95))
			_add(root, _box(Vector3(2.0, 0.06, 0.13)), Vector3(0, 1.36, 0), Color(0.95, 0.8, 0.25))
		"viking":
			_add(root, _dome(0.9, 0.7), Vector3(0, 0.55, 0), Color(0.62, 0.64, 0.7))
			_add(root, _ring(0.9, 0.08, 12), Vector3(0, 0.6, 0), Color(0.8, 0.6, 0.25))
			for side in [-1.0, 1.0]:
				_add(root, _cone(0.18, 0.8, 6), Vector3(side * 0.95, 1.25, 0), Color(0.97, 0.94, 0.85), Vector3(0, 0, -side * 0.6))
		"duck":
			_add(root, _ball(0.55), Vector3(0, 1.3, 0.1), Color(1.0, 0.85, 0.15), Vector3.ZERO, Vector3(1, 0.8, 1.2))
			_add(root, _ball(0.36), Vector3(0, 1.85, -0.3), Color(1.0, 0.85, 0.15))
			_add(root, _box(Vector3(0.3, 0.1, 0.3)), Vector3(0, 1.8, -0.7), Color(1.0, 0.5, 0.1))
			for side in [-1.0, 1.0]:
				_add(root, _ball(0.06), Vector3(side * 0.2, 1.95, -0.58), Color(0.1, 0.1, 0.1))
		"wizard":
			_add(root, _cyl(1.15, 1.15, 0.07, 10), Vector3(0, 0.86, 0), Color(0.3, 0.25, 0.75))
			_add(root, _cone(0.62, 1.6, 8), Vector3(0, 1.68, 0.12), Color(0.3, 0.25, 0.75), Vector3(0.2, 0, 0))
			for k in 3:
				_add(root, _star(), Vector3(-0.3 + k * 0.3, 1.25 + k * 0.32, -0.45 + k * 0.08), Color(1.0, 0.88, 0.3), Vector3(0.2, 0, 0))
		"crown":
			_add(root, _cyl(0.72, 0.68, 0.32, 10), Vector3(0, 1.0, 0), Color(1.0, 0.78, 0.2))
			for k in 6:
				var a := k * TAU / 6.0
				_add(root, _cone(0.18, 0.4, 4), Vector3(cos(a) * 0.62, 1.34, sin(a) * 0.62), Color(1.0, 0.78, 0.2))
				var gem := Color(0.9, 0.15, 0.3) if k % 2 == 0 else Color(0.2, 0.5, 1.0)
				_add(root, _ball(0.09), Vector3(cos(a) * 0.73, 1.0, sin(a) * 0.73), gem, Vector3.ZERO, Vector3.ONE, 0.6)
		"halo":
			_add(root, _ring(0.62, 0.09, 16), Vector3(0, 1.55, 0), Color(1.0, 0.92, 0.5), Vector3.ZERO, Vector3.ONE, 1.6)
	return root


## Spin a propeller cap's blades. Call every frame with the hat node.
static func animate(hat: Node3D, delta: float, speed := 1.0) -> void:
	var spin := hat.get_node_or_null("Spin") as Node3D
	if spin:
		spin.rotate_y(delta * (4.0 + speed * 2.0))


# ---------------------------------------------------------------- shapes

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, sides: int) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


static func _cone(r: float, h: float, sides: int) -> Mesh:
	return _cyl(0.0, r, h, sides)


static func _ball(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m


## The top half of a ball: a cap for beanies, helmets and so on.
static func _dome(r: float, h: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h * 2.0
	m.is_hemisphere = true
	m.radial_segments = 12
	m.rings = 4
	return m


static func _ring(r: float, thick: float, sides: int) -> Mesh:
	var m := TorusMesh.new()
	m.inner_radius = r - thick
	m.outer_radius = r + thick
	m.rings = sides
	m.ring_segments = 4
	return m


static func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _capsule(r: float, h: float) -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 2
	return m


static func _star() -> Mesh:
	var m := PrismMesh.new()
	m.size = Vector3(0.22, 0.22, 0.05)
	return m
