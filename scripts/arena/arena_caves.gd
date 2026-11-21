class_name CavesArena
extends Arena
## CRYSTAL CAVERNS: deep underground. A dark cavern floor with glowing
## cracks and pools, clusters of huge gems lighting everything up, rock
## pillars and hanging stalactites, glowing mushrooms, and an old mine
## with carts full of gems trundling round on their rails.

const GROUND := preload("res://shaders/cave_ground.gdshader")
const ROCK := Color(0.24, 0.21, 0.28)
const ROCK_LIGHT := Color(0.36, 0.31, 0.4)
const TIMBER := Color(0.45, 0.3, 0.2)
const GEMS := [Color(1.0, 0.35, 0.75), Color(0.35, 0.85, 1.0), Color(0.7, 0.45, 1.0),
		Color(0.35, 1.0, 0.6), Color(1.0, 0.7, 0.25)]


func _init() -> void:
	id = "caves"
	track_floor = Color(0.66, 0.6, 0.7)
	track_wall = Color(0.58, 0.4, 0.26)
	track_support = Color(0.4, 0.28, 0.2)
	lamp_color = Color(1.0, 0.7, 0.3)
	start_color = Color(0.55, 0.3, 0.9)
	finish_color = Color(0.95, 0.3, 0.6)


func make_environment() -> Environment:
	var env := sky_env(Color(0.03, 0.02, 0.06), Color(0.1, 0.07, 0.16), Color(0.05, 0.04, 0.08), 0.0,
			Color(0.12, 0.08, 0.2), 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.7)
	env.ambient_light_energy = 0.85
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_sky_affect = 1.0
	return env


func light_sun(sun: DirectionalLight3D) -> void:
	# Faint cold light from far above, like light through a crack.
	sun.rotation = Vector3(-1.2, 0.4, 0)
	sun.light_color = Color(0.6, 0.7, 1.0)
	sun.light_energy = 0.45


func fall_burst(parent: Node, at: Vector3, color: Color) -> void:
	# A shower of glowing sparkles.
	_burst(parent, Vector3(at.x, GROUND_Y + 0.1, at.z), Color(0.6, 0.95, 1.0).lerp(color, 0.4), 45, 0.07, 3.0, 7.0,
			Vector3(0, -6, 0), true)


func _build_scene() -> void:
	_ground(GROUND)
	var reach := _reach()
	# Nothing on the mine railway (see _mine), or the carts drive through it.
	_keep_off_rings.append([reach + 22.0, 2.2])
	# The cavern wall first, so the things below keep out of its boulders.
	_walls(reach)
	for i in 14:
		var p = _spot(8.0, reach + 25.0, 7.0, 2.6)
		if p != null:
			_gem_cluster(p, _rng.randf_range(0.8, 2.2), i < 6)
	for i in 18:
		var p = _spot(10.0, reach + 50.0, 6.0, 3.5)
		if p != null:
			_stalagmite(p)
	for i in 10:
		var p = _spot(6.0, reach + 20.0, 4.0, 1.6)
		if p != null:
			_mushrooms(p)
	_giant_gems(reach)
	_mine(reach)
	_drift(Color(0.6, 0.9, 1.0, 0.8), 260, 0.12, 0.4, 2.0, reach + 30.0, 30.0)


## A clump of glowing six-sided crystals sticking out of a rock.
func _gem_cluster(p: Vector2, size: float, lit: bool) -> void:
	var col: Color = GEMS[_rng.randi() % GEMS.size()]
	var b := MeshBatch.new()
	b.ball(Vector3.ZERO, size * 1.2, ROCK, 6, Vector3(1.3, 0.5, 1.1))
	for k in _rng.randi_range(4, 8):
		var tilt := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.6))
		var h := size * _rng.randf_range(1.2, 3.2)
		var r := size * _rng.randf_range(0.18, 0.35)
		_crystal(b, tilt, Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5)) * size, h, r,
				col.lightened(_rng.randf_range(-0.1, 0.2)))
	_put(b, v3(p, GROUND_Y), _rng.randf() * TAU, 2.2, size * 2.0)
	if lit:
		_light(v3(p, GROUND_Y + size * 2.0), col, 2.5, size * 7.0)


## One crystal: a hexagonal prism with a pointed tip.
func _crystal(b: MeshBatch, tilt: Basis, base: Vector3, h: float, r: float, col: Color) -> void:
	var body := CylinderMesh.new()
	body.top_radius = r
	body.bottom_radius = r * 0.9
	body.height = h
	body.radial_segments = 6
	body.rings = 1
	b.shape(body, tilt, base + tilt * Vector3(0, h / 2.0, 0), col, true)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = r
	tip.height = r * 1.8
	tip.radial_segments = 6
	tip.rings = 1
	b.shape(tip, tilt, base + tilt * Vector3(0, h + r * 0.9, 0), col.lightened(0.25), true)


func _stalagmite(p: Vector2) -> void:
	var b := MeshBatch.new()
	var h := _rng.randf_range(3.0, 12.0)
	var r := h * _rng.randf_range(0.15, 0.25)
	b.cyl(0.05, r, h, Vector3(0, h / 2.0, 0), ROCK_LIGHT.darkened(_rng.randf_range(0, 0.3)), 7)
	b.cyl(0.05, r * 0.5, h * 0.5, Vector3(r * 0.9, h * 0.25, 0.2), ROCK, 6)
	b.ball(Vector3.ZERO, r * 1.3, ROCK, 6, Vector3(1, 0.4, 1))
	_put(b, v3(p, GROUND_Y), 0.0, 2.0, r + 1.0)


## A few glowing toadstools.
func _mushrooms(p: Vector2) -> void:
	var b := MeshBatch.new()
	var cap: Color = [Color(0.3, 1.0, 0.8), Color(0.7, 0.5, 1.0), Color(1.0, 0.5, 0.8)][_rng.randi() % 3]
	for k in _rng.randi_range(3, 6):
		var at := Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2))
		var h := _rng.randf_range(0.4, 1.3)
		b.cyl(0.08, 0.12, h, at + Vector3(0, h / 2.0, 0), Color(0.85, 0.82, 0.75), 6)
		b.ball(at + Vector3(0, h, 0), h * 0.45, cap, 8, Vector3(1, 0.5, 1), true)
	_put(b, v3(p, GROUND_Y), 0.0, 1.8, 2.0)


## The big boulders of the cavern wall: [middle, size, how tall (y scale)],
## and the pillars: [xz, radius]. The giant crystals keep out of them.
var _boulders: Array = []
var _pillars: Array = []


## The cavern walls far out, and stalactites hanging from the dark above.
func _walls(reach: float) -> void:
	var b := MeshBatch.new()
	_boulders.clear()
	_pillars.clear()
	var n := 26
	for k in n:
		var a := TAU * k / n + _rng.randf_range(-0.08, 0.08)
		var r := reach + _rng.randf_range(80.0, 110.0)
		var at := v3(_ring(r, a), GROUND_Y)
		var size := _rng.randf_range(28.0, 45.0)
		var tall := _rng.randf_range(1.4, 2.6)
		b.ball(at + Vector3(0, size * 0.6, 0), size, ROCK.lightened(_rng.randf_range(-0.05, 0.1)), 8,
				Vector3(1.0, tall, 1.0))
		_boulders.append([at + Vector3(0, size * 0.6, 0), size, tall])
		# Where it meets the floor, so nothing is put down inside it.
		_taken.append([_ring(r, a), size * sqrt(1.0 - pow(0.6 / tall, 2.0))])
		# Pillars from floor to "ceiling" between the boulders.
		if k % 3 == 0:
			var pr := _ring(r - 30.0, a + 0.1)
			var top_r := _rng.randf_range(3, 5)
			var bottom_r := _rng.randf_range(6, 9)
			b.cyl(top_r, bottom_r, 90.0, v3(pr, GROUND_Y + 45.0), ROCK_LIGHT, 9)
			_pillars.append([pr, bottom_r])
			_taken.append([pr, bottom_r])
	for k in 70:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(reach * 0.6, reach + 100.0)
		var h := _rng.randf_range(6.0, 24.0)
		var top := _rng.randf_range(55.0, 75.0)
		b.cyl(_rng.randf_range(1.2, 3.5), 0.1, h, v3(_ring(r, a), GROUND_Y + top - h / 2.0), ROCK.darkened(0.2), 7)
	_put(b, Vector3.ZERO, 0.0, 2.0)


## Enormous glowing crystals out in the dark: the cave's main lights.
func _giant_gems(reach: float) -> void:
	var b := MeshBatch.new()
	for k in 8:
		var a := TAU * k / 8.0 + _rng.randf_range(-0.2, 0.2)
		var dist := reach + _rng.randf_range(40.0, 70.0)
		var col: Color = GEMS[k % GEMS.size()]
		var crystals := []   # [tilt, offset, height, radius, colour]
		for c in _rng.randi_range(3, 5):
			var tilt := Basis(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.5))
			crystals.append([tilt, Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6)),
					_rng.randf_range(14.0, 34.0), _rng.randf_range(2.0, 4.0), col.lightened(_rng.randf_range(-0.1, 0.2))])
		# Slide the clump in or out (and round a little) to where the fewest
		# bits of crystal are buried in the wall's boulders and pillars or in
		# other things on the floor.
		var at := v3(_ring(dist, a), GROUND_Y)
		var best := 1000
		for turn in [0.0, -0.12, 0.12]:
			for step in [0.0, -4.0, 4.0, -8.0, 8.0, -12.0, 12.0, -16.0, -20.0]:
				var d: float = clampf(dist + step, reach + 28.0, reach + 75.0)
				var spot_at := v3(_ring(d, a + turn), GROUND_Y)
				var buried := 0
				for c in crystals:
					buried += _buried(spot_at + c[1], c[0] * Vector3.UP, c[2], c[3])
				if buried < best:
					best = buried
					at = spot_at
			if best == 0:
				break
		# Any crystal still stuck in the rock is left out.
		var shown := 0
		for c in crystals:
			if _buried(at + c[1], c[0] * Vector3.UP, c[2], c[3]) == 0:
				_crystal(b, c[0], at + c[1], c[2], c[3], c[4])
				shown += 1
		if shown > 0 and k % 2 == 0:
			_light(at + Vector3(0, 18.0, 0), col, 6.0, 55.0)
	_put(b, Vector3.ZERO, 0.0, 2.2)


## How many points up a crystal (from `base` going `up` for `h` metres,
## radius `r`) are inside the wall's boulders and pillars, or on something
## else on the floor. 0 means it stands clear.
func _buried(base: Vector3, up: Vector3, h: float, r: float) -> int:
	var count := 0
	for k in 6:
		var p := base + up * (h + r * 1.8) * k / 5.0
		var hit := false
		for bo in _boulders:
			var d: Vector3 = p - bo[0]
			var size: float = bo[1]
			if Vector3(d.x, d.y / bo[2], d.z).length() < size + r:
				hit = true
		for pi in _pillars:
			if Vector2(p.x, p.z).distance_to(pi[0]) < pi[1] + r:
				hit = true
		if k == 0:
			for t in _taken:
				if Vector2(p.x, p.z).distance_to(t[0]) < t[1] + r:
					hit = true
		count += 1 if hit else 0
	return count


## Mine rails in a big loop round the track, timber shaft entrances, and
## carts piled with gems rolling round.
func _mine(reach: float) -> void:
	var r := reach + 22.0
	var b := MeshBatch.new()
	var steps := 120
	for k in steps:
		var a0 := TAU * k / steps
		var a1 := TAU * (k + 1) / steps
		for off in [-0.55, 0.55]:
			b.beam(v3(_ring(r + off, a0), GROUND_Y + 0.15), v3(_ring(r + off, a1), GROUND_Y + 0.15), 0.08, Color(0.55, 0.55, 0.6))
		var mid := (a0 + a1) / 2.0
		b.box(Vector3(1.6, 0.12, 0.3), v3(_ring(r, mid), GROUND_Y + 0.05), TIMBER, -mid)
	# Timber frames over the rails here and there, each with a lantern.
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var c := _ring(r, a)
		var out := Vector2(cos(a), sin(a))
		for side in [-1.3, 1.3]:
			var foot: Vector2 = c + out * side
			b.beam(v3(foot, GROUND_Y), v3(foot, GROUND_Y + 3.4), 0.3, TIMBER)
		b.beam(v3(c - out * 1.6, GROUND_Y + 3.4), v3(c + out * 1.6, GROUND_Y + 3.4), 0.32, TIMBER)
		b.ball(v3(c, GROUND_Y + 2.9), 0.22, lamp_color, 6, Vector3.ONE, true)
	_put(b, Vector3.ZERO, 0.0, 3.0)
	for i in 4:
		var cart := MeshBatch.new()
		cart.box(Vector3(1.4, 0.9, 2.0), Vector3(0, 0.75, 0), Color(0.4, 0.38, 0.42))
		cart.box(Vector3(1.5, 0.12, 2.1), Vector3(0, 1.2, 0), TIMBER)
		for x in [-0.6, 0.6]:
			for z in [-0.65, 0.65]:
				cart.cyl(0.28, 0.28, 0.15, Vector3(x * 1.1, 0.3, z), Color(0.2, 0.2, 0.22), 8)
		for g in 5:
			_crystal(cart, Basis(Vector3(_rng.randf_range(-1, 1), 0, 1).normalized(), 0.4),
					Vector3(_rng.randf_range(-0.4, 0.4), 1.0, _rng.randf_range(-0.6, 0.6)), 0.6, 0.15, GEMS[(i + g) % GEMS.size()])
		var node := _put(cart, Vector3.ZERO, 0.0, 2.5)
		var a0 := TAU * i / 4.0
		var speed := 0.045
		var c := _center
		_movers.append(func(t: float, _d: float):
			var a := a0 + t * speed
			node.position = Vector3(c.x + cos(a) * r, GROUND_Y + 0.15 + absf(sin(t * 9.0 + a0)) * 0.03, c.y + sin(a) * r)
			node.rotation.y = -a)
