class_name BeachArena
extends Arena
## SUNNY LAGOON: the original lake, upgraded. A turquoise lagoon with sandy
## islands, palm trees, beach huts and umbrellas, a striped lighthouse with
## a turning beam, a pier, sailboats, bobbing buoys, gulls and far-off
## green islands with a volcano.

const WATER := preload("res://shaders/water.gdshader")
const SAND := Color(0.93, 0.83, 0.6)
const WET_SAND := Color(0.8, 0.68, 0.48)
const PALM_TRUNK := Color(0.58, 0.42, 0.26)
const PALM_LEAF := Color(0.27, 0.62, 0.3)
const ROCK := Color(0.5, 0.48, 0.46)
const WOOD := Color(0.6, 0.43, 0.28)
const BRIGHTS := [Color(0.95, 0.3, 0.3), Color(1.0, 0.8, 0.2), Color(0.3, 0.7, 0.95),
		Color(0.95, 0.5, 0.75), Color(0.45, 0.85, 0.5)]


func _init() -> void:
	id = "beach"
	watery = true


func make_environment() -> Environment:
	return sky_env(Color(0.25, 0.55, 0.92), Color(0.75, 0.88, 0.97), Color(0.2, 0.6, 0.7), 0.8)


func light_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(-0.75, 0.9, 0)
	sun.light_color = Color(1, 0.93, 0.8)
	sun.light_energy = 1.05


func _build_scene() -> void:
	_ground(WATER, {"deep_color": Color(0.05, 0.4, 0.58), "shallow_color": Color(0.25, 0.75, 0.78)})
	var reach := _reach()
	# Sandy islands near the track, each with something on it.
	for i in 6:
		var p = _spot(reach * 0.4, reach + 30.0, 16.0)
		if p != null:
			_island(p, _rng.randf_range(5.0, 9.0), i)
	for i in 14:
		var p = _spot(8.0, reach + 40.0, 6.0)
		if p != null:
			_rock(p, _rng.randf_range(0.7, 2.2))
	for i in 10:
		var p = _spot(6.0, reach + 10.0, 5.0)
		if p != null:
			_buoy(p, i)
	var lp = _spot(reach + 15.0, reach + 35.0, 20.0)
	if lp != null:
		_lighthouse(lp)
	for i in 5:
		_sailboat(i)
	_far_islands(reach)
	_gulls()
	_clouds(26, 110, 230, 22, 50)


## A round sandy island with palms, and maybe a hut, umbrella or pier.
func _island(p: Vector2, r: float, kind: int) -> void:
	var b := MeshBatch.new()
	b.cyl(r * 0.85, r, 1.0, Vector3(0, 0.0, 0), SAND, 18)
	b.cyl(r, r * 1.08, 0.6, Vector3(0, -0.5, 0), WET_SAND, 18)
	b.ball(Vector3(r * 0.2, 0.4, -r * 0.1), r * 0.55, Color(0.4, 0.66, 0.32), 10, Vector3(1, 0.35, 1))
	for t in _rng.randi_range(2, 4):
		var a := _rng.randf() * TAU
		_palm(b, Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r * 0.15, r * 0.6) + Vector3(0, 0.5, 0))
	match kind % 3:
		0: _hut(b, Vector3(-r * 0.35, 0.5, r * 0.25), _rng.randf() * TAU)
		1: _umbrellas(b, Vector3(-r * 0.3, 0.5, r * 0.35))
		2:
			_umbrellas(b, Vector3(r * 0.1, 0.5, r * 0.45))
			_pier(b, r)
	_put(b, v3(p, GROUND_Y), _rng.randf() * TAU, 2.5, r + 2.0)
	_foam(v3(p, GROUND_Y + 0.04), r * 1.08)
	_shallows(v3(p, GROUND_Y + 0.02), r * 1.6)


## A curved palm: trunk segments leaning over, fronds drooping off the top.
func _palm(b: MeshBatch, at: Vector3) -> void:
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	var p := at
	var h := _rng.randf_range(3.5, 5.0)
	var segs := 6
	for k in segs:
		var t := float(k) / segs
		var step := Vector3.UP * (h / segs) + lean * (t * t * 0.5)
		b.beam(p, p + step, 0.22 - t * 0.07, PALM_TRUNK.darkened(0.08 * (k % 2)))
		p += step
	b.ball(p, 0.28, PALM_LEAF.darkened(0.25), 6)
	for k in 3:
		b.ball(p + Vector3(cos(k * 2.1), -0.25, sin(k * 2.1)) * 0.22, 0.12, Color(0.45, 0.32, 0.18), 6)
	for k in 7:
		var a := TAU * k / 7.0 + _rng.randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var leaf := BoxMesh.new()
		leaf.size = Vector3(0.5, 0.05, 2.0)
		var basis := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -0.45)
		b.shape(leaf, basis, p + dir * 0.9 + Vector3.DOWN * 0.35, PALM_LEAF.lightened(_rng.randf_range(-0.05, 0.1)))


func _hut(b: MeshBatch, at: Vector3, yaw: float) -> void:
	var rot := Basis(Vector3.UP, yaw)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.beam(at + rot * Vector3(x, 0, z), at + rot * Vector3(x, 2.0, z), 0.15, WOOD)
	b.box(Vector3(2.0, 1.2, 2.0), at + Vector3(0, 0.9, 0), Color(0.85, 0.7, 0.5), yaw)
	b.box(Vector3(0.6, 0.9, 0.05), at + rot * Vector3(0, 0.75, 1.01), WOOD.darkened(0.3), yaw)
	b.cyl(0.0, 1.9, 1.4, at + Vector3(0, 2.6, 0), Color(0.86, 0.72, 0.38), 8)
	b.cyl(1.9, 2.0, 0.12, at + Vector3(0, 1.9, 0), Color(0.75, 0.6, 0.3), 8)


func _umbrellas(b: MeshBatch, at: Vector3) -> void:
	for k in 2:
		var p := at + Vector3(k * 1.8, 0, k * 0.6)
		var col: Color = BRIGHTS[_rng.randi() % BRIGHTS.size()]
		b.beam(p, p + Vector3(0.2, 2.2, 0), 0.06, Color.WHITE)
		b.cyl(0.05, 1.2, 0.5, p + Vector3(0.2, 2.25, 0), col, 8)
		b.box(Vector3(0.7, 0.03, 1.6), p + Vector3(0.9, 0.02, 0.4), BRIGHTS[(k + 2) % BRIGHTS.size()], 0.3)


func _pier(b: MeshBatch, r: float) -> void:
	var len := 7.0
	for k in 10:
		var z := r * 0.8 + k * len / 9.0
		b.box(Vector3(1.6, 0.1, len / 9.0 - 0.05), Vector3(0, 0.55, z), WOOD.lightened(_rng.randf_range(-0.08, 0.08)))
		if k % 3 == 0:
			for x in [-0.75, 0.75]:
				b.beam(Vector3(x, -1.0, z), Vector3(x, 0.9, z), 0.14, WOOD.darkened(0.25))
	# A little rowing boat tied at the end.
	b.ball(Vector3(1.6, 0.0, r * 0.8 + len), 0.55, Color(0.9, 0.35, 0.25), 8, Vector3(1.0, 0.45, 2.2))


func _rock(p: Vector2, size: float) -> void:
	var b := MeshBatch.new()
	b.ball(Vector3.ZERO, size, ROCK, 6, Vector3(_rng.randf_range(0.9, 1.4), _rng.randf_range(0.5, 0.9), _rng.randf_range(0.8, 1.3)))
	if _rng.randf() < 0.5:
		b.ball(Vector3(size * 0.7, -0.2, 0.3), size * 0.5, ROCK.darkened(0.1), 6)
	if _rng.randf() < 0.3:
		b.ball(Vector3(0, size * 0.45, 0), size * 0.55, Color(0.38, 0.55, 0.32), 6, Vector3(1, 0.4, 1))
	_put(b, v3(p, GROUND_Y - size * 0.25), _rng.randf() * TAU, 2.5, size + 1.0)
	_foam(v3(p, GROUND_Y + 0.04), size * 1.2)


func _buoy(p: Vector2, i: int) -> void:
	var b := MeshBatch.new()
	var color: Color = [Color(0.92, 0.22, 0.18), Color(0.98, 0.75, 0.15), Color(0.95, 0.95, 0.95)][i % 3]
	b.cyl(0.25, 0.45, 0.9, Vector3(0, 0.2, 0), color, 10)
	b.cyl(0.33, 0.37, 0.18, Vector3(0, 0.25, 0), Color(0.95, 0.95, 0.95) if i % 3 != 2 else Color(0.92, 0.22, 0.18), 10)
	b.ball(Vector3(0, 0.78, 0), 0.1, lamp_color, 6, Vector3.ONE, true)
	var node := _put(b, v3(p, GROUND_Y), 0.0, 3.0, 1.0)
	var phase := _rng.randf() * TAU
	_movers.append(func(t: float, _d: float):
		node.position.y = GROUND_Y + sin(t * 1.3 + phase) * 0.12
		node.rotation.z = sin(t * 1.1 + phase) * 0.12
		node.rotation.x = cos(t * 0.9 + phase) * 0.1)


## A red and white lighthouse on a rock, its beam sweeping round.
func _lighthouse(p: Vector2) -> void:
	var b := MeshBatch.new()
	b.ball(Vector3(0, -1.0, 0), 6.0, ROCK, 8, Vector3(1.0, 0.45, 1.0))
	b.ball(Vector3(3.5, -0.6, 2.0), 2.5, ROCK.darkened(0.1), 6)
	var h := 16.0
	var bands := 6
	for k in bands:
		var r0 := lerpf(2.0, 1.3, float(k) / bands)
		var r1 := lerpf(2.0, 1.3, float(k + 1) / bands)
		b.cyl(r1, r0, h / bands, Vector3(0, 1.5 + (k + 0.5) * h / bands, 0), Color(0.92, 0.2, 0.18) if k % 2 == 0 else Color(0.97, 0.96, 0.92), 14)
	var top := 1.5 + h
	b.cyl(1.8, 1.8, 0.25, Vector3(0, top + 0.1, 0), Color(0.2, 0.2, 0.24), 14)
	b.cyl(1.1, 1.1, 1.6, Vector3(0, top + 1.0, 0), Color(1.0, 0.9, 0.6), 10, true)
	b.cyl(0.0, 1.4, 1.2, Vector3(0, top + 2.4, 0), Color(0.85, 0.18, 0.15), 10)
	b.ball(Vector3(0, top + 3.1, 0), 0.2, Color(0.2, 0.2, 0.24), 6)
	# A little keeper's house.
	b.box(Vector3(3.0, 2.2, 2.4), Vector3(3.2, 2.1, -1.0), Color(0.97, 0.96, 0.92))
	b.cyl(0.0, 2.2, 1.2, Vector3(3.2, 3.8, -1.0), Color(0.85, 0.18, 0.15), 4)
	b.glow_box(Vector3(0.6, 0.6, 0.05), Vector3(3.2, 2.3, 0.21), Color(1.0, 0.8, 0.45))
	_put(b, v3(p, GROUND_Y), _rng.randf() * TAU, 3.0, 8.0)
	_foam(v3(p, GROUND_Y + 0.04), 6.2)
	# The sweeping beam: a long faint cone that turns.
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.3
	cone.bottom_radius = 4.0
	cone.height = 40.0
	cone.radial_segments = 12
	cone.cap_bottom = false
	cone.cap_top = false
	beam.mesh = cone
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.95, 0.7, 0.12)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	pivot.position = v3(p, GROUND_Y + top + 1.0)
	add_child(pivot)
	pivot.add_child(beam)
	beam.rotation.z = PI / 2
	beam.position.x = 20.0
	_movers.append(func(_t: float, d: float): pivot.rotate_y(d * 0.6))


## Sailboats slowly drifting round in big circles, bobbing.
func _sailboat(i: int) -> void:
	var b := MeshBatch.new()
	var hull: Color = [Color(0.97, 0.96, 0.92), Color(0.3, 0.45, 0.75), Color(0.85, 0.3, 0.25)][i % 3]
	b.ball(Vector3(0, 0.2, 0), 1.0, hull, 8, Vector3(0.9, 0.5, 2.6))
	b.box(Vector3(1.4, 0.15, 3.6), Vector3(0, 0.55, 0), WOOD)
	b.beam(Vector3(0, 0.5, 0.3), Vector3(0, 6.5, 0.3), 0.12, WOOD.darkened(0.2))
	var sail := PrismMesh.new()
	sail.size = Vector3(3.2, 5.6, 0.05)
	sail.left_to_right = 0.0
	b.shape(sail, Basis(Vector3.UP, PI / 2), Vector3(0, 3.7, -1.3), Color(0.98, 0.97, 0.93))
	var jib := PrismMesh.new()
	jib.size = Vector3(1.8, 4.0, 0.05)
	jib.left_to_right = 1.0
	b.shape(jib, Basis(Vector3.UP, PI / 2), Vector3(0, 2.8, 1.3), BRIGHTS[i % BRIGHTS.size()])
	var node := _put(b, Vector3.ZERO)
	var radius := _reach() + _rng.randf_range(35.0, 80.0)
	var a0 := _rng.randf() * TAU
	var speed := _rng.randf_range(0.006, 0.012) * (1.0 if i % 2 == 0 else -1.0)
	var c := _center
	_movers.append(func(t: float, _d: float):
		var a := a0 + t * speed
		node.position = Vector3(c.x + cos(a) * radius, GROUND_Y + sin(t * 0.9 + a0) * 0.15, c.y + sin(a) * radius)
		node.rotation.y = -a if speed > 0 else PI - a
		node.rotation.z = sin(t * 0.7 + a0) * 0.06)


## Big green islands and a volcano on the horizon.
func _far_islands(reach: float) -> void:
	var b := MeshBatch.new()
	for k in 7:
		var a := TAU * k / 7.0 + _rng.randf_range(-0.2, 0.2)
		var p := _ring(_rng.randf_range(reach + 130.0, reach + 220.0), a)
		var r := _rng.randf_range(18.0, 34.0)
		var at := v3(p, GROUND_Y)
		b.cyl(r, r * 1.1, 1.0, at, SAND, 16)
		b.ball(at + Vector3(0, 0.5, 0), r * 0.85, Color(0.3, 0.58, 0.32), 10, Vector3(1.0, _rng.randf_range(0.35, 0.7), 0.9))
		for t in 6:
			var ta := _rng.randf() * TAU
			_palm(b, at + Vector3(cos(ta), 0, sin(ta)) * r * 0.9 + Vector3(0, 0.4, 0))
		if k == 3:
			# The volcano, with a wisp of smoke.
			b.cyl(r * 0.18, r * 0.75, r * 1.3, at + Vector3(0, r * 0.65, 0), Color(0.45, 0.4, 0.36), 10)
			b.cyl(r * 0.12, r * 0.18, 1.0, at + Vector3(0, r * 1.3, 0), Color(1.0, 0.45, 0.15), 10, true)
			_smoke(at + Vector3(0, r * 1.35, 0))
	_put(b, Vector3.ZERO, 0.0, 2.0)


func _smoke(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 9.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.4, 0.2, 0)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 8
	s.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.85, 0.88, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s.material = m
	p.mesh = s
	p.position = at
	add_child(p)


## Gulls gliding in lazy circles over the lagoon.
func _gulls() -> void:
	for f in 3:
		var flock := Node3D.new()
		add_child(flock)
		for k in 4:
			var bird := MeshBatch.new()
			for side in [-1.0, 1.0]:
				var wing := BoxMesh.new()
				wing.size = Vector3(0.9, 0.04, 0.3)
				bird.shape(wing, Basis(Vector3.FORWARD, side * 0.3), Vector3(side * 0.42, 0.1, 0), Color(0.97, 0.97, 0.97))
			bird.ball(Vector3.ZERO, 0.14, Color.WHITE, 6, Vector3(1, 1, 2))
			var node := bird.make()
			node.position = Vector3(k * 1.6 - 2.4, sin(k) * 0.6, absf(k - 1.5) * 1.3)
			flock.add_child(node)
		var radius := _rng.randf_range(20.0, 45.0)
		var y := _rng.randf_range(14.0, 26.0)
		var a0 := _rng.randf() * TAU
		var c := _center
		_movers.append(func(t: float, _d: float):
			var a := a0 + t * 0.12
			flock.position = Vector3(c.x + cos(a) * radius, y + sin(t * 0.5 + a0) * 1.5, c.y + sin(a) * radius)
			flock.rotation.y = -a
			for bird in flock.get_children():
				(bird as Node3D).rotation.z = sin(t * 5.0 + bird.get_index()) * 0.15)


func _foam(at: Vector3, r: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.92
	ring.outer_radius = r * 1.12
	ring.rings = 24
	ring.ring_segments = 6
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(0.95, 0.98, 1.0, 0.55)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.material_override = foam
	mi.position = at
	mi.scale = Vector3(1, 0.05, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Pale turquoise shallow water round an island.
func _shallows(at: Vector3, r: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.02
	disc.radial_segments = 24
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.92, 0.85, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
