class_name CloudsArena
extends Arena
## CLOUD KINGDOM: high above a rolling sea of cloud at golden hour.
## Floating islands carry little castles with pointed roofs and flags,
## marble columns rise out of the clouds, rainbows arch overhead, golden
## orbs bob about, balloons drift past and sparkles float up.

const GROUND := preload("res://shaders/cloud_ground.gdshader")
const MARBLE := Color(0.96, 0.94, 0.9)
const GOLD := Color(1.0, 0.8, 0.35)
const ROOFS := [Color(0.35, 0.5, 0.95), Color(0.95, 0.5, 0.7), Color(0.6, 0.45, 0.9), Color(1.0, 0.75, 0.3)]
const RAINBOW := [Color(1.0, 0.4, 0.45), Color(1.0, 0.65, 0.35), Color(1.0, 0.9, 0.45),
		Color(0.5, 0.9, 0.5), Color(0.45, 0.7, 1.0), Color(0.7, 0.5, 1.0)]


func _init() -> void:
	id = "clouds"
	track_floor = Color(0.86, 0.78, 0.92)
	track_wall = Color(0.98, 0.78, 0.35)
	track_support = Color(0.9, 0.88, 0.85)
	lamp_color = Color(1.0, 0.85, 0.45)
	start_color = Color(0.4, 0.6, 1.0)
	finish_color = Color(1.0, 0.45, 0.65)


func make_environment() -> Environment:
	var env := sky_env(Color(0.3, 0.48, 0.92), Color(1.0, 0.8, 0.72), Color(1.0, 0.95, 0.95), 0.55,
			Color(1.0, 0.88, 0.85), 0.0008)
	env.tonemap_exposure = 0.92
	env.glow_intensity = 0.5
	return env


func light_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(-0.6, -0.5, 0)
	sun.light_color = Color(1.0, 0.88, 0.75)
	sun.light_energy = 1.1


## The pop word when a marble falls off the track and lands here.
func fall_word() -> Array:
	return ["POOF!", Color(1.0, 0.95, 1.0)]


func fall_burst(parent: Node, at: Vector3, color: Color) -> void:
	# A soft puff of cloud.
	_burst(parent, Vector3(at.x, GROUND_Y + 0.5, at.z), Color(1, 1, 1).lerp(color, 0.1), 26, 0.3, 1.0, 3.0, Vector3(0, 0.5, 0))


func _build_scene() -> void:
	_ground(GROUND)
	var reach := _reach()
	# The palace first, so the cloud banks and columns keep out of it.
	_palace(reach)
	_cloud_bumps(reach)
	for i in 5:
		var p = _spot(reach * 0.5, reach + 35.0, 14.0, 9.0)
		if p != null:
			_floating_island(p, _rng.randf_range(5.0, 8.0), _rng.randf_range(4.0, 14.0), false)
	for i in 12:
		var p = _spot(7.0, reach + 30.0, 6.0, 1.6)
		if p != null:
			_column(p)
	for i in 10:
		var p = _spot(6.0, reach + 20.0, 5.0, 1.3)
		if p != null:
			_orb(p)
	_rainbows(reach)
	for i in 5:
		_balloon(i, reach)
	_drift(Color(1.0, 0.9, 0.55, 0.9), 220, 0.14, -0.6, 2.0, reach + 30.0, 25.0)
	# Out past the palace islands and the balloons, so the clouds never
	# drift through them.
	_clouds(30, reach + 185.0, reach + 300.0, 0.0, 60.0, 4.0, 8.0)


## Big lumpy cloud banks poking up out of the cloud sea.
func _cloud_bumps(reach: float) -> void:
	var b := MeshBatch.new()
	for k in 90:
		var s := _rng.randf_range(3.0, 9.0)
		# Each bank is three puffs up to `s` from its middle, so it needs
		# about 2.5 s of room (and as much clear of the lane).
		var p = _spot(14.0, reach + 160.0, maxf(10.0, s * 2.5), s * 2.5)
		if p == null:
			continue
		for j in 3:
			b.ball(v3(p, GROUND_Y + s * 0.1) + Vector3(_rng.randf_range(-s, s), 0, _rng.randf_range(-s, s)),
					s * _rng.randf_range(0.6, 1.0), Color(1.0, 0.99, 0.98), 10, Vector3(1.0, 0.55, 1.0))
	_put(b, Vector3.ZERO, 0.0, 1.0)


## A rock island floating in the sky with a little castle on it.
func _floating_island(p: Vector2, r: float, lift: float, big: bool) -> void:
	var b := MeshBatch.new()
	b.cyl(r, r * 0.95, 1.0, Vector3(0, 0, 0), Color(0.45, 0.75, 0.4), 14)
	b.cyl(r * 0.95, r * 0.15, r * 1.3, Vector3(0, -r * 0.65 - 0.5, 0), Color(0.62, 0.52, 0.45), 9)
	b.cyl(r * 0.5, 0.0, r * 0.7, Vector3(r * 0.2, -r * 1.4, 0.3), Color(0.55, 0.46, 0.4), 7)
	_castle(b, Vector3(0, 0.5, 0), r * (0.9 if big else 0.6))
	var node := _put(b, v3(p, GROUND_Y + lift), _rng.randf() * TAU, 2.5, r + 1.0)
	if big:
		# The palace islands: keep the cloud banks and columns from poking
		# up through them (the ones from _spot() are counted already).
		_taken.append([p, r + 2.0])
	var phase := _rng.randf() * TAU
	var y := node.position.y
	_movers.append(func(t: float, _d: float): node.position.y = y + sin(t * 0.4 + phase) * 0.5)


## Walls and round towers with pointed roofs and flags.
func _castle(b: MeshBatch, at: Vector3, s: float) -> void:
	var roof: Color = ROOFS[_rng.randi() % ROOFS.size()]
	b.box(Vector3(s * 1.4, s * 1.0, s * 1.4), at + Vector3(0, s * 0.5, 0), MARBLE)
	# Battlements.
	for k in 6:
		for side in [-1.0, 1.0]:
			b.box(Vector3(s * 0.15, s * 0.18, s * 0.15), at + Vector3((k - 2.5) * s * 0.25, s * 1.08, side * s * 0.68), MARBLE)
	b.glow_box(Vector3(s * 0.3, s * 0.45, 0.05), at + Vector3(0, s * 0.25, s * 0.71), GOLD)
	for k in 4:
		var c := at + Vector3((-1.0 if k % 2 == 0 else 1.0) * s * 0.75, 0, (-1.0 if k < 2 else 1.0) * s * 0.75)
		var th := s * _rng.randf_range(1.6, 2.4)
		b.cyl(s * 0.28, s * 0.3, th, c + Vector3(0, th / 2.0, 0), MARBLE, 10)
		b.cyl(0.0, s * 0.38, s * 0.9, c + Vector3(0, th + s * 0.45, 0), roof, 10)
		b.glow_box(Vector3(s * 0.1, s * 0.2, 0.04), c + Vector3(0, th * 0.7, s * 0.3), GOLD)
		b.beam(c + Vector3(0, th + s * 0.85, 0), c + Vector3(0, th + s * 1.4, 0), 0.05, Color(0.5, 0.45, 0.4))
		var flag := PrismMesh.new()
		flag.size = Vector3(s * 0.4, s * 0.25, 0.03)
		flag.left_to_right = 0.0
		b.shape(flag, Basis(Vector3.FORWARD, -PI / 2), c + Vector3(s * 0.12, th + s * 1.3, 0), RAINBOW[_rng.randi() % RAINBOW.size()])
	# The keep in the middle.
	b.cyl(s * 0.4, s * 0.45, s * 2.6, at + Vector3(0, s * 1.3, 0), MARBLE, 12)
	b.cyl(0.0, s * 0.55, s * 1.3, at + Vector3(0, s * 3.25, 0), roof, 12)
	b.ball(at + Vector3(0, s * 3.95, 0), s * 0.1, GOLD, 6, Vector3.ONE, true)


## A white marble column rising out of the cloud, sometimes broken off.
func _column(p: Vector2) -> void:
	var b := MeshBatch.new()
	var h := _rng.randf_range(5.0, 16.0)
	b.cyl(0.9, 0.9, 0.5, Vector3(0, 0.25, 0), MARBLE, 12)
	b.cyl(0.6, 0.65, h, Vector3(0, h / 2.0 + 0.5, 0), MARBLE, 12)
	if _rng.randf() < 0.7:
		b.cyl(0.95, 0.7, 0.45, Vector3(0, h + 0.7, 0), MARBLE, 12)
		b.box(Vector3(2.0, 0.3, 2.0), Vector3(0, h + 1.05, 0), MARBLE)
		b.ball(Vector3(0, h + 1.8, 0), 0.5, GOLD, 10, Vector3.ONE, true)
	else:
		b.cyl(0.62, 0.6, 0.4, Vector3(0.0, h + 0.7, 0.0), MARBLE.darkened(0.05), 7)
	_put(b, v3(p, GROUND_Y), 0.0, 2.5, 1.5)


## A golden orb bobbing in the air.
func _orb(p: Vector2) -> void:
	var b := MeshBatch.new()
	b.ball(Vector3.ZERO, 0.7, GOLD, 12, Vector3.ONE, true)
	b.cyl(1.0, 1.0, 0.06, Vector3.ZERO, Color(1, 1, 1), 16)
	var y := _rng.randf_range(2.0, 10.0)
	var node := _put(b, v3(p, GROUND_Y + y), 0.0, 2.0, 1.5)
	var phase := _rng.randf() * TAU
	_movers.append(func(t: float, d: float):
		node.position.y = GROUND_Y + y + sin(t * 1.1 + phase) * 0.6
		node.rotate_y(d * 0.8))


## The big palace on its own island far out, with a golden gate.
func _palace(reach: float) -> void:
	var a := _rng.randf() * TAU
	var p := _ring(reach + 70.0, a)
	_floating_island(p, 20.0, 18.0, true)
	for k in 3:
		var q := _ring(reach + _rng.randf_range(90.0, 150.0), a + _rng.randf_range(0.6, 2.5) * (1 if k % 2 == 0 else -1))
		_floating_island(q, _rng.randf_range(8.0, 14.0), _rng.randf_range(10.0, 30.0), true)
	# A golden archway standing in the clouds, facing the track.
	var g := _ring(reach + 25.0, a + 0.5)
	var b := MeshBatch.new()
	for side in [-5.0, 5.0]:
		b.cyl(0.8, 0.9, 14.0, Vector3(side, 7.0, 0), GOLD, 12)
		b.ball(Vector3(side, 14.5, 0), 1.0, GOLD, 10, Vector3.ONE, true)
	var arch := TorusMesh.new()
	arch.inner_radius = 4.3
	arch.outer_radius = 5.7
	arch.rings = 24
	arch.ring_segments = 8
	b.shape(arch, Basis(Vector3.RIGHT, PI / 2), Vector3(0, 14.0, 0), GOLD)
	_put(b, v3(g, GROUND_Y), atan2(_center.x - g.x, _center.y - g.y), 2.2, 7.0)


## Two rainbows arching up out of the clouds.
func _rainbows(reach: float) -> void:
	for k in 2:
		var a := _rng.randf() * TAU
		var at := v3(_ring(reach + _rng.randf_range(60.0, 110.0), a), GROUND_Y - 4.0)
		var big := _rng.randf_range(45.0, 70.0)
		var b := MeshBatch.new()
		for i in RAINBOW.size():
			var band := TorusMesh.new()
			band.inner_radius = big - i * 2.0 - 2.0
			band.outer_radius = big - i * 2.0
			band.rings = 48
			band.ring_segments = 4
			b.add(band, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO), RAINBOW[i], true)
		var node := b.make(0.7, false)
		node.position = at
		node.rotation.y = a + PI / 2
		add_child(node)


## Hot-air balloons drifting slowly round.
func _balloon(i: int, reach: float) -> void:
	var b := MeshBatch.new()
	var c0: Color = RAINBOW[i % RAINBOW.size()]
	var c1: Color = RAINBOW[(i + 3) % RAINBOW.size()]
	for k in 8:
		var gore := SphereMesh.new()
		gore.radius = 3.0
		gore.height = 7.0
		gore.radial_segments = 16
		gore.rings = 8
		b.add(gore, Transform3D(Basis(Vector3.UP, TAU * k / 8.0).scaled(Vector3(0.3, 1, 1)), Vector3(0, 6, 0)), c0 if k % 2 == 0 else c1)
	b.cyl(1.0, 0.6, 1.2, Vector3(0, 2.5, 0), c1, 10)
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			b.beam(Vector3(x, 0.6, z), Vector3(x * 1.4, 2.8, z * 1.4), 0.05, Color(0.4, 0.3, 0.2))
	b.box(Vector3(1.2, 0.9, 1.2), Vector3(0, 0.45, 0), Color(0.6, 0.42, 0.25))
	var node := _put(b)
	# Between the golden arch and the palace (so they never float through
	# the castle), and higher than the arch's top.
	var radius := reach + _rng.randf_range(32.0, 44.0)
	var a0 := _rng.randf() * TAU
	var y := _rng.randf_range(18.0, 35.0)
	var c := _center
	_movers.append(func(t: float, _d: float):
		var a := a0 + t * 0.008
		node.position = Vector3(c.x + cos(a) * radius, y + sin(t * 0.3 + a0) * 2.0, c.y + sin(a) * radius))
