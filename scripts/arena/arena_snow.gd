class_name SnowArena
extends Arena
## FROSTY VILLAGE: a snowy valley at the end of a winter afternoon. Pine
## forests with snow on every branch, colourful cottages with glowing
## windows and smoking chimneys, a little church with a clock tower,
## snowmen, a frozen pond with marbles skating round it, lamp posts,
## big snowy mountains all round, and snow falling the whole time.

const GROUND := preload("res://shaders/snow_ground.gdshader")
const SNOW := Color(0.96, 0.97, 1.0)
const PINE := Color(0.18, 0.4, 0.3)
const BARK := Color(0.4, 0.28, 0.2)
const HOUSES := [Color(0.85, 0.3, 0.28), Color(0.3, 0.5, 0.75), Color(0.95, 0.8, 0.4),
		Color(0.55, 0.75, 0.5), Color(0.62, 0.45, 0.32), Color(0.9, 0.6, 0.65)]
const WINDOW := Color(1.0, 0.75, 0.4)


func _init() -> void:
	id = "snow"
	track_floor = Color(0.82, 0.86, 0.94)
	track_wall = Color(0.82, 0.22, 0.22)
	track_support = Color(0.42, 0.3, 0.24)
	lamp_color = Color(1.0, 0.78, 0.45)
	start_color = Color(0.2, 0.6, 0.45)
	finish_color = Color(0.85, 0.2, 0.22)


func make_environment() -> Environment:
	var env := sky_env(Color(0.36, 0.52, 0.82), Color(0.95, 0.84, 0.86), Color(0.9, 0.92, 0.98), 0.5,
			Color(0.85, 0.87, 0.95), 0.0012)
	env.tonemap_exposure = 0.9
	env.fog_sky_affect = 0.3
	return env


func light_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(-0.38, 0.6, 0)
	sun.light_color = Color(1.0, 0.82, 0.68)
	sun.light_energy = 1.0


func fall_burst(parent: Node, at: Vector3, color: Color) -> void:
	# A puff of powder snow.
	_burst(parent, Vector3(at.x, GROUND_Y + 0.2, at.z), Color(0.97, 0.98, 1.0), 45, 0.14, 2.0, 5.0, Vector3(0, -3, 0))


func _build_scene() -> void:
	_ground(GROUND)
	var reach := _reach()
	for i in 9:
		var p = _spot(10.0, reach + 25.0, 9.0)
		if p != null:
			_cottage(p, i)
	var cp = _spot(reach * 0.5, reach + 30.0, 14.0)
	if cp != null:
		_church(cp)
	var pp = _spot(reach * 0.3, reach + 30.0, 16.0)
	if pp != null:
		_pond(pp)
	for i in 6:
		var p = _spot(5.0, reach + 15.0, 4.0)
		if p != null:
			_snowman(p)
	for i in 16:
		var p = _spot(5.0, reach + 30.0, 5.0)
		if p != null:
			_lamp(p)
	for i in 22:
		var p = _spot(8.0, reach + 40.0, 7.0)
		if p != null:
			_pine_clump(p)
	_forest(reach)
	_mountains(reach)
	_drift(Color(1, 1, 1, 0.9), 1600, 0.16, 1.6, 0.0, reach + 30.0, 35.0)
	_clouds(14, 150, 260, 50, 80, 5.0, 8.0)


## A pine: tiers of cones, each with a snowy top.
func _pine(b: MeshBatch, at: Vector3, h: float) -> void:
	b.cyl(0.15 * h / 5.0, 0.22 * h / 5.0, h * 0.25, at + Vector3(0, h * 0.12, 0), BARK, 6)
	var tiers := 4
	for k in tiers:
		var y := h * (0.2 + 0.2 * k)
		var r := h * (0.32 - 0.06 * k)
		b.cyl(0.0, r, h * 0.32, at + Vector3(0, y + h * 0.16, 0), PINE.lightened(k * 0.03), 8)
		b.cyl(0.0, r * 0.62, h * 0.14, at + Vector3(0, y + h * 0.27, 0), SNOW, 8)


func _pine_clump(p: Vector2) -> void:
	var b := MeshBatch.new()
	for k in _rng.randi_range(2, 5):
		_pine(b, Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5)), _rng.randf_range(4.0, 8.0))
	_put(b, v3(p, GROUND_Y), 0.0, 2.0, 4.0)


## A cottage: coloured walls, a snowy pitched roof, glowing windows, a
## chimney with smoke and a string of lights.
func _cottage(p: Vector2, i: int) -> void:
	var b := MeshBatch.new()
	var wall: Color = HOUSES[i % HOUSES.size()]
	var w := _rng.randf_range(4.0, 6.0)
	var d := _rng.randf_range(3.5, 5.0)
	var h := _rng.randf_range(2.6, 3.4)
	b.box(Vector3(w, h, d), Vector3(0, h / 2.0, 0), wall)
	b.box(Vector3(w + 0.1, 0.3, d + 0.1), Vector3(0, 0.15, 0), wall.darkened(0.3))
	var roof := PrismMesh.new()
	roof.size = Vector3(d + 1.0, 2.2, w + 0.8)
	b.shape(roof, Basis(Vector3.UP, PI / 2), Vector3(0, h + 1.1, 0), Color(0.55, 0.25, 0.2))
	var snow_roof := PrismMesh.new()
	snow_roof.size = Vector3(d + 1.1, 2.0, w + 0.9)
	b.shape(snow_roof, Basis(Vector3.UP, PI / 2), Vector3(0, h + 1.25, 0), SNOW)
	b.box(Vector3(0.6, 1.8, 0.6), Vector3(w * 0.25, h + 1.6, -d * 0.2), Color(0.55, 0.5, 0.5))
	b.box(Vector3(0.7, 0.15, 0.7), Vector3(w * 0.25, h + 2.5, -d * 0.2), SNOW)
	# Door and glowing windows on the front.
	b.box(Vector3(0.9, 1.7, 0.08), Vector3(0, 0.85, d / 2.0 + 0.03), Color(0.4, 0.25, 0.18))
	for x in [-w * 0.3, w * 0.3]:
		b.glow_box(Vector3(0.8, 0.8, 0.06), Vector3(x, h * 0.55, d / 2.0 + 0.03), WINDOW)
		b.box(Vector3(1.0, 0.12, 0.2), Vector3(x, h * 0.55 - 0.48, d / 2.0 + 0.1), SNOW)
	for z in [-d * 0.2, d * 0.2]:
		b.glow_box(Vector3(0.06, 0.7, 0.7), Vector3(w / 2.0 + 0.03, h * 0.55, z), WINDOW)
	# Fairy lights along the roof edge.
	for k in 9:
		var x := lerpf(-w / 2.0, w / 2.0, k / 8.0)
		var col: Color = [Color(1, 0.3, 0.3), Color(0.3, 1, 0.4), Color(1, 0.85, 0.3), Color(0.4, 0.6, 1)][k % 4]
		b.ball(Vector3(x, h - 0.05 - sin(k / 8.0 * PI) * 0.15, d / 2.0 + 0.45), 0.07, col, 6, Vector3.ONE, true)
	var yaw := atan2(_center.x - p.x, _center.y - p.y) + _rng.randf_range(-0.5, 0.5)
	_put(b, v3(p, GROUND_Y), yaw, 2.5, maxf(w, d))
	_chimney_smoke(v3(p, GROUND_Y) + Basis(Vector3.UP, yaw) * Vector3(w * 0.25, h + 2.6, -d * 0.2))


func _chimney_smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 4.0
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0.25, 0.1, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.85, 0.9, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	p.mesh = s
	p.position = at
	add_child(p)


## A little church: a long hall, a clock tower and a pointed steeple.
func _church(p: Vector2) -> void:
	var b := MeshBatch.new()
	var stone := Color(0.85, 0.82, 0.78)
	b.box(Vector3(6.0, 4.5, 10.0), Vector3(0, 2.25, 0), stone)
	var roof := PrismMesh.new()
	roof.size = Vector3(7.0, 3.0, 10.6)
	b.shape(roof, Basis.IDENTITY, Vector3(0, 6.0, 0), SNOW)
	b.box(Vector3(3.2, 10.0, 3.2), Vector3(0, 5.0, 6.2), stone)
	b.cyl(0.0, 2.4, 6.0, Vector3(0, 13.0, 6.2), Color(0.3, 0.42, 0.6), 4)
	b.cyl(0.0, 1.4, 2.0, Vector3(0, 13.8, 6.2), SNOW, 4)
	b.beam(Vector3(0, 16, 6.2), Vector3(0, 17.4, 6.2), 0.12, Color(1, 0.85, 0.4))
	b.beam(Vector3(-0.5, 16.9, 6.2), Vector3(0.5, 16.9, 6.2), 0.12, Color(1, 0.85, 0.4))
	# Clock faces and glowing arched windows.
	b.cyl(1.0, 1.0, 0.1, Vector3(0, 8.5, 7.82), Color(0.97, 0.95, 0.88), 16)
	b.box(Vector3(0.08, 0.7, 0.05), Vector3(0, 8.75, 7.9), Color(0.1, 0.1, 0.1))
	b.box(Vector3(0.5, 0.08, 0.05), Vector3(0.2, 8.5, 7.9), Color(0.1, 0.1, 0.1))
	for z in [-3.0, -0.5, 2.0]:
		for x in [-3.03, 3.03]:
			b.glow_box(Vector3(0.06, 1.8, 0.9), Vector3(x, 2.6, z), Color(1.0, 0.7, 0.35))
	b.glow_box(Vector3(1.2, 2.2, 0.06), Vector3(0, 1.1, 7.82), Color(1.0, 0.75, 0.4))
	var yaw := atan2(_center.x - p.x, _center.y - p.y)
	_put(b, v3(p, GROUND_Y), yaw, 2.5, 9.0)


## A frozen pond with three marbles skating round it.
func _pond(p: Vector2) -> void:
	var ice := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 9.0
	disc.height = 0.1
	disc.radial_segments = 28
	ice.mesh = disc
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 0.95)
	m.roughness = 0.08
	m.metallic = 0.3
	ice.material_override = m
	ice.position = v3(p, GROUND_Y + 0.25)
	add_child(ice)
	_props.append([ice, p, 9.0])
	var b := MeshBatch.new()
	for k in 20:
		var a := TAU * k / 20.0
		b.ball(Vector3(cos(a) * 9.3, 0.2, sin(a) * 9.3), _rng.randf_range(0.5, 0.9), SNOW, 6, Vector3(1.2, 0.5, 1.0))
	_put(b, v3(p, GROUND_Y), 0.0, 2.0, 9.5)
	for i in 3:
		var sk := MeshBatch.new()
		var col: Color = [Color(0.95, 0.3, 0.4), Color(0.3, 0.6, 1.0), Color(1.0, 0.8, 0.2)][i]
		sk.ball(Vector3(0, 0.45, 0), 0.45, col, 10)
		sk.cyl(0.47, 0.47, 0.18, Vector3(0, 0.75, 0), Color(0.95, 0.95, 0.95), 10)
		sk.ball(Vector3(0, 1.0, 0), 0.12, Color(0.95, 0.95, 0.95), 6)
		var node := _put(sk)
		var r := 3.0 + i * 1.8
		var c := v3(p, GROUND_Y + 0.3)
		var speed := 0.6 - i * 0.12
		_movers.append(func(t: float, _d: float):
			var a := t * speed + i * 2.0
			node.position = c + Vector3(cos(a) * r, 0, sin(a) * r)
			node.rotation.y = -a)


func _snowman(p: Vector2) -> void:
	var b := MeshBatch.new()
	b.ball(Vector3(0, 0.6, 0), 0.75, SNOW, 10)
	b.ball(Vector3(0, 1.55, 0), 0.52, SNOW, 10)
	b.ball(Vector3(0, 2.25, 0), 0.38, SNOW, 10)
	b.cyl(0.0, 0.07, 0.4, Vector3(0, 2.25, 0.5), Color(1.0, 0.5, 0.15), 6)
	for x in [-0.13, 0.13]:
		b.ball(Vector3(x, 2.35, 0.33), 0.05, Color(0.08, 0.08, 0.1), 5)
	b.cyl(0.22, 0.22, 0.4, Vector3(0, 2.75, 0), Color(0.1, 0.1, 0.12), 10)
	b.cyl(0.36, 0.36, 0.05, Vector3(0, 2.57, 0), Color(0.1, 0.1, 0.12), 10)
	b.cyl(0.4, 0.42, 0.14, Vector3(0, 1.95, 0), Color(0.85, 0.2, 0.22), 10)
	b.box(Vector3(0.14, 0.5, 0.06), Vector3(0.25, 1.75, 0.38), Color(0.85, 0.2, 0.22))
	b.beam(Vector3(0.45, 1.6, 0), Vector3(1.1, 2.0, 0), 0.06, BARK)
	b.beam(Vector3(-0.45, 1.6, 0), Vector3(-1.0, 2.1, 0.1), 0.06, BARK)
	_put(b, v3(p, GROUND_Y + 0.1), atan2(_center.x - p.x, _center.y - p.y), 2.0, 1.5)


func _lamp(p: Vector2) -> void:
	var b := MeshBatch.new()
	b.cyl(0.08, 0.12, 3.4, Vector3(0, 1.7, 0), Color(0.15, 0.15, 0.18), 6)
	b.box(Vector3(0.5, 0.6, 0.5), Vector3(0, 3.65, 0), Color(0.15, 0.15, 0.18))
	b.glow_box(Vector3(0.38, 0.44, 0.52), Vector3(0, 3.65, 0), lamp_color)
	b.cyl(0.0, 0.42, 0.3, Vector3(0, 4.1, 0), SNOW, 6)
	b.cyl(0.25, 0.25, 0.15, Vector3(0, 3.0, 0), Color(0.15, 0.6, 0.3), 8)
	_put(b, v3(p, GROUND_Y), 0.0, 3.0, 1.0)


## A thick band of pine forest round the valley.
func _forest(reach: float) -> void:
	var b := MeshBatch.new()
	for k in 260:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(reach + 45.0, reach + 130.0)
		_pine(b, v3(_ring(r, a), GROUND_Y), _rng.randf_range(6.0, 14.0))
	_put(b, Vector3.ZERO, 0.0, 2.0)


## Snow-capped mountains on the horizon.
func _mountains(reach: float) -> void:
	var b := MeshBatch.new()
	var n := 16
	for k in n:
		var a := TAU * k / n + _rng.randf_range(-0.1, 0.1)
		var at := v3(_ring(reach + _rng.randf_range(170.0, 240.0), a), GROUND_Y)
		var h := _rng.randf_range(60.0, 120.0)
		var r := h * _rng.randf_range(0.7, 1.0)
		b.cyl(0.0, r, h, at + Vector3(0, h / 2.0, 0), Color(0.52, 0.56, 0.66), 7)
		b.cyl(0.0, r * 0.42, h * 0.42, at + Vector3(0, h * 0.79 + 0.3, 0), SNOW, 7)
		b.cyl(r * 0.42, r * 0.5, h * 0.06, at + Vector3(0, h * 0.58 + 0.3, 0), SNOW.darkened(0.05), 7)
	_put(b, Vector3.ZERO, 0.0, 2.0)
