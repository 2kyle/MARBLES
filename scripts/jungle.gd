class_name Jungle
extends Node3D
## The jungle on the practice island (hub.gd builds it). It turns the
## floating island into a jungle valley:
##   - tall rock mountain walls all round the edge, with gorges where the
##     bridges go out, a low gap on the plaza side so you can see the sky,
##     and a gap where the pond's stream spills over
##   - far-off jungle mountains all round, so the islands sit in a valley
##   - things to roll over, climb and jump on: temple ruins, a stepped
##     climb up the cliff, bouncy giant mushrooms, a hollow log, grassy
##     hills, broken pillars and a waterfall
##   - six SECRET GEMS hidden round the island. Roll into one to collect
##     it: the first time a player finds each gem they get some coins
##     (main.gd pays out and remembers it in profiles.cfg)
##   - life: jungle trees, palms, ferns, big leaves, vines, parrots, frogs
##     on lily pads, a monkey, fireflies and falling leaves
##
## Almost all of the scenery is glued into one mesh (MeshBatch), and every
## solid bit lives on one StaticBody3D, so it stays cheap to draw.
##
## Angles below are degrees round the island, the same way the hub uses
## them: 0 is east (+X), 90 is the plaza side (+Z), 180 west, 270 north.

const GEM_COUNT := 6
## The gems' names, in id order (shown when you find one).
const GEM_NAMES := ["SKY LEDGE", "MUSHROOM TOP", "TEMPLE SHRINE", "HOLLOW LOG", "CRYSTAL CAVE", "BEHIND THE FALLS"]
const GEM_COLORS := [Color(0.35, 0.85, 1.0), Color(1.0, 0.35, 0.45), Color(1.0, 0.82, 0.25),
		Color(0.55, 1.0, 0.45), Color(0.8, 0.45, 1.0), Color(0.3, 1.0, 0.85)]

## Where the cliff wall stands (the middle of its rocks).
const WALL_R := 39.6
## Openings in the wall: [angle, half-width in degrees].
const GAPS := [[Hub.CASINO_ANGLE, 8.0], [270.0, 6.0], [Hub.SPORTS_ANGLE, 8.0], [45.0, 5.0],
		[300.0, 4.5], [-8.0, 3.5]]
## The plaza side, where the wall drops to scattered boulders.
const LOW_FROM := 66.0
const LOW_TO := 114.0

const ROCK := Color(0.43, 0.37, 0.31)
const MOSS := Color(0.32, 0.56, 0.26)
const LEAF := Color(0.2, 0.48, 0.22)
const BARK := Color(0.42, 0.3, 0.2)
const STONE := Color(0.62, 0.58, 0.49)

## The places below, all in the hub's space.
const TEMPLE := Vector3(-26, 0, -1)
const LOG := Vector3(-9, 0, -31.5)
const LOG_LENGTH := 9.0
const LOG_RADIUS := 1.35
const MUSHROOM_PAD := Vector3(22.5, 0, 2.5)
## The giant mushrooms' caps: [position of the top, cap radius].
const CAPS := [[Vector3(27, 2.2, 6.5), 1.7], [Vector3(30.5, 3.8, 12), 1.6], [Vector3(26.5, 5.6, 17.8), 1.7]]
const CLIMB_FROM := 122.0
const CLIMB_STEP := 3.0
const CLIMB_COUNT := 14
const CLIMB_R := 35.0
const STEP_H := 0.45
const CAVE_ANGLE := 300.0
const FALLS_ANGLE := -8.0
const HILLS := [[Vector3(0, 0, 31), 4.5, 1.3], [Vector3(-25, 0, 12), 4.2, 1.5]]

## Places the jungle uses: [position, radius]. The hub keeps its own trees
## out of these.
var busy: Array = []

var _hub: Hub
var _rng := RandomNumberGenerator.new()
var _batch := MeshBatch.new()
var _far := MeshBatch.new()
var _body: StaticBody3D
var _gems: Array = []      # {node, id, at, taken, mat}
## How a gem you've already found looks: faint see-through glass.
var _ghost_mat: StandardMaterial3D
var _parrots: Array = []   # {node, wings, radius, y, speed, angle, center}
var _frogs: Array = []     # {node, pads, from, to, t, wait}
var _caps: Array = []      # [cap node, squash]
var _monkey_arm: Node3D
var _cooldown := {}        # marble -> seconds before a mushroom throws it again
var _time := 0.0


## True if `at` is inside one of the jungle's places (plus `r` metres).
func is_busy(at: Vector3, r: float) -> bool:
	for b in busy:
		if Vector2(at.x - b[0].x, at.z - b[0].z).length() < b[1] + r:
			return true
	return false


func build(hub: Hub) -> void:
	_hub = hub
	_rng.seed = 2468
	_body = StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.1
	_body.physics_material_override = pm
	add_child(_body)
	busy = [[TEMPLE, 7.5], [LOG, 5.5], [MUSHROOM_PAD, 1.5], [CAPS[0][0], 2.0], [CAPS[1][0], 2.0],
			[CAPS[2][0], 2.0], [_on_ring(CAVE_ANGLE, 33.0), 5.0], [_on_ring(FALLS_ANGLE, 34.0), 3.5]]
	for k in CLIMB_COUNT:
		busy.append([_on_ring(CLIMB_FROM + k * CLIMB_STEP, CLIMB_R), 1.6])
	for h in HILLS:
		busy.append([h[0], h[1]])

	_walls()
	_far_mountains()
	_climb()
	_temple()
	_mushrooms()
	_hollow_log()
	_cave()
	_waterfall()
	_hills()
	_plants()
	_hint_sign()
	add_child(_batch.make(2.5))
	var far := _far.make(1.5, false)
	add_child(far)
	_parrots_fly()
	_frogs_hop()
	_monkey()
	_fireflies()
	_falling_leaves()


## Put every gem back (each visit to the island). Gems in `found` (found
## already by everyone playing here) come back as a faint glassy ghost, so
## you can see your progress; they don't pay again.
func reset(found: Array = []) -> void:
	for g in _gems:
		g.taken = false
		var node: Node3D = g.node
		node.visible = true
		var ghost := found.has(g.id)
		for c in node.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = _ghost_mat if ghost else g.mat
			elif c is Light3D or c is CPUParticles3D:
				c.visible = not ghost
	_cooldown.clear()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for g in _gems:
		var n: Node3D = g.node
		n.rotation.y = _time * 1.6 + g.id
		n.position.y = g.at.y + 0.55 + sin(_time * 2.2 + g.id) * 0.12
	for p in _parrots:
		var a: float = p.angle + _time * p.speed
		var c: Vector3 = p.center
		var node: Node3D = p.node
		node.position = c + Vector3(cos(a) * p.radius, p.y + sin(_time * 0.7 + p.angle) * 1.2, sin(a) * p.radius)
		node.rotation.y = -a - (PI / 2.0 if p.speed > 0 else -PI / 2.0)
		var flap := sin(_time * 14.0 + p.angle * 3.0) * 0.6
		p.wings[0].rotation.z = flap
		p.wings[1].rotation.z = -flap
	for f in _frogs:
		_frog_update(f, delta)
	for c in _caps:
		c[1] = maxf(c[1] - delta * 3.0, 0.0)
		(c[0] as Node3D).scale = Vector3(1.0 + c[1] * 0.25, 1.0 - c[1] * 0.3, 1.0 + c[1] * 0.25)
	if _monkey_arm:
		_monkey_arm.rotation.z = 2.3 + sin(_time * 5.0) * 0.5
	for m in _cooldown.keys():
		_cooldown[m] -= delta
		if _cooldown[m] <= 0.0:
			_cooldown.erase(m)


# ------------------------------------------------------------ Helpers

func _on_ring(angle: float, r: float) -> Vector3:
	var a := deg_to_rad(angle)
	return Vector3(cos(a) * r, 0, sin(a) * r)


func _in_gap(angle: float, extra := 0.0) -> bool:
	for g in GAPS:
		if absf(angle_difference(deg_to_rad(angle), deg_to_rad(g[0]))) < deg_to_rad(g[1] + extra):
			return true
	return false


## A solid box (in the hub's space), turned `yaw` round up.
func _solid_box(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = pos
	shape.rotation.y = yaw
	_body.add_child(shape)


## A solid upright cylinder standing on its middle at `pos`.
func _solid_cyl(r: float, h: float, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	shape.shape = c
	shape.position = pos
	_body.add_child(shape)


## A craggy rock: a tapered six-sided column turned a random way.
func _rock(batch: MeshBatch, pos: Vector3, r: float, h: float, color: Color, lean := 0.0) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r * _rng.randf_range(0.4, 0.65)
	m.bottom_radius = r
	m.height = h
	m.radial_segments = _rng.randi_range(5, 7)
	m.rings = 1
	var basis := Basis(Vector3.UP, _rng.randf() * TAU)
	if lean != 0.0:
		basis = Basis(Vector3(pos.z, 0, -pos.x).normalized(), lean) * basis
	batch.shape(m, basis, pos, color)


## A box with a full turn (for tilted leaves, planks and so on).
func _tilted_box(batch: MeshBatch, size: Vector3, basis: Basis, pos: Vector3, color: Color) -> void:
	var m := BoxMesh.new()
	m.size = size
	batch.shape(m, basis, pos, color)


func _rock_color() -> Color:
	return ROCK.lerp(Color(0.38, 0.35, 0.32), _rng.randf()).lerp(MOSS, _rng.randf() * 0.3)


# ------------------------------------------------------------ The cliff wall

func _walls() -> void:
	var angle := 0.0
	while angle < 360.0:
		var step := _rng.randf_range(2.6, 3.6)
		if _in_gap(angle):
			angle += 1.0
			continue
		var low := angle > LOW_FROM and angle < LOW_TO
		var at := _on_ring(angle, WALL_R + _rng.randf_range(-0.4, 1.2))
		if low:
			# Boulders, with gaps between, so you can see out (and hop off).
			if _rng.randf() < 0.55:
				var r := _rng.randf_range(1.0, 1.8)
				var h := _rng.randf_range(1.2, 2.6)
				_rock(_batch, at + Vector3.UP * (h - 1.0) / 2.0, r, h + 1.0, _rock_color())
				_batch.ball(at + Vector3.UP * (h + 0.1), r * 0.6, MOSS.darkened(_rng.randf() * 0.2), 6, Vector3(1, 0.5, 1))
				_solid_cyl(r * 0.85, h, at + Vector3.UP * h / 2.0)
			angle += step * 1.6
			continue
		# How tall the wall is here: tallest round the back (north), lower
		# towards the plaza side.
		var north := (1.0 - cos(deg_to_rad(angle - 270.0))) / 2.0   # 0 at the north, 1 at the plaza
		var h := lerpf(15.0, 7.0, north) + _rng.randf_range(-1.5, 2.5)
		var r := _rng.randf_range(2.3, 3.1)
		# Each column runs well below the grass so the cliffs carry on
		# down the island's sides.
		_rock(_batch, at + Vector3.UP * (h - 6.0) / 2.0, r, h + 6.0, _rock_color(), _rng.randf_range(-0.06, 0.06))
		_solid_cyl(r * 0.9, h, at + Vector3.UP * h / 2.0)
		# A smaller crag in front or behind, and moss on top.
		var crag := at + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) \
				+ at.normalized() * _rng.randf_range(-0.6, 1.4)
		var ch := h * _rng.randf_range(0.45, 0.8)
		_rock(_batch, crag + Vector3.UP * (ch - 3.0) / 2.0, r * 0.75, ch + 3.0, _rock_color().darkened(0.06))
		# A wide rocky foot, so it reads as a mountain and not a post.
		_rock(_batch, at + at.normalized() * 1.2 + Vector3.UP * 0.6, r * 1.7, 3.2, _rock_color().darkened(0.08))
		# Darker bands of rock part-way up.
		for k in _rng.randi_range(0, 2):
			var y := _rng.randf_range(2.0, h - 1.5)
			var t := y / (h + 6.0)
			var band_r := lerpf(r, r * 0.5, (y + 6.0) / (h + 6.0)) + 0.12
			_batch.cyl(band_r - 0.05, band_r, 0.35, at + Vector3.UP * y, _rock_color().darkened(0.18), 6)
		# Jungle growing over the top, and moss down the face.
		var green := LEAF.lerp(MOSS, _rng.randf())
		_batch.cyl(0.0, r * 0.55, 1.0, at + Vector3.UP * (h + 0.3), MOSS.darkened(_rng.randf() * 0.25), 6)
		for k in _rng.randi_range(1, 3):
			_batch.ball(at + Vector3(_rng.randf_range(-1, 1), h + _rng.randf_range(0.2, 0.8), _rng.randf_range(-1, 1)),
					_rng.randf_range(0.9, 1.6), green.lightened(_rng.randf() * 0.15), 7, Vector3(1, 0.7, 1))
		for k in _rng.randi_range(1, 3):
			var face := at - at.normalized() * (r * 0.72) + Vector3(-at.z, 0, at.x).normalized() * _rng.randf_range(-1.0, 1.0)
			_batch.ball(face + Vector3.UP * _rng.randf_range(1.0, h * 0.8), _rng.randf_range(0.4, 0.8), MOSS.darkened(0.1), 5,
					Vector3(1.3, 0.8, 1.3))
		# Vines hanging down the inside face.
		var inner := at - at.normalized() * (r * 0.75)
		for k in _rng.randi_range(1, 3):
			var side := Vector3(-at.z, 0, at.x).normalized() * _rng.randf_range(-1.2, 1.2)
			var top := inner + side + Vector3.UP * (h - 0.6)
			var len := _rng.randf_range(2.5, h * 0.75)
			_batch.beam(top, top + Vector3.DOWN * len, 0.07, Color(0.25, 0.45, 0.2))
			for j in int(len / 0.7):
				var off := Vector3(-at.z, 0, at.x).normalized() * (0.12 if j % 2 == 0 else -0.12)
				_batch.ball(top + Vector3.DOWN * (j * 0.7 + 0.35) + off - at.normalized() * 0.08, 0.17,
						LEAF.lightened(_rng.randf() * 0.3), 5)
		angle += step
	# The gorges either side of each bridge get two big gateposts.
	for g in [[Hub.CASINO_ANGLE, 8.0], [270.0, 6.0], [Hub.SPORTS_ANGLE, 8.0]]:
		for s: float in [-1.0, 1.0]:
			var at := _on_ring(g[0] + s * (g[1] + 1.0), WALL_R - 0.5)
			var h := _rng.randf_range(10.0, 13.0)
			_rock(_batch, at + Vector3.UP * (h - 6.0) / 2.0, 3.0, h + 6.0, _rock_color())
			_batch.cyl(0.0, 1.5, 1.2, at + Vector3.UP * (h + 0.4), MOSS, 6)
			_solid_cyl(2.7, h, at + Vector3.UP * h / 2.0)


## Far-off jungle mountains in a ring round all three islands, and a few
## waterfalls down them. Fog softens them into the distance.
func _far_mountains() -> void:
	var center := Vector3(0, 0, -25)
	var n := 44
	for i in n:
		var a := TAU * i / n + _rng.randf_range(-0.05, 0.05)
		var r := _rng.randf_range(175.0, 230.0)
		var at := center + Vector3(cos(a) * r, 0, sin(a) * r)
		var h := _rng.randf_range(65.0, 115.0)
		var w := _rng.randf_range(30.0, 48.0)
		var base := -75.0
		var m := CylinderMesh.new()
		m.top_radius = w * _rng.randf_range(0.22, 0.4)
		m.bottom_radius = w
		m.height = h
		m.radial_segments = 7
		m.rings = 1
		var rock := Color(0.4, 0.42, 0.36).lerp(Color(0.33, 0.4, 0.32), _rng.randf())
		_far.shape(m, Basis(Vector3.UP, _rng.randf() * TAU), at + Vector3.UP * (base + h / 2.0), rock)
		# Jungle covering the lower slopes.
		for k in 9:
			var t := _rng.randf_range(0.2, 0.85)
			var ra := _rng.randf() * TAU
			var pr := lerpf(w, m.top_radius, t) * 0.9
			_far.ball(at + Vector3(cos(ra) * pr, base + h * t, sin(ra) * pr), w * _rng.randf_range(0.22, 0.36),
					Color(0.22, 0.42, 0.24).lerp(Color(0.32, 0.52, 0.28), _rng.randf()), 7, Vector3(1, 0.6, 1))
		# A jungle cap on the summit.
		_far.ball(at + Vector3.UP * (base + h), m.top_radius * 1.15, Color(0.26, 0.46, 0.26), 8, Vector3(1, 0.45, 1))
		if i % 7 == 2:
			# A thin white waterfall down the face nearest the islands.
			var face := center + Vector3(cos(a), 0, sin(a)) * (r - w * 0.55)
			_far.beam(face + Vector3.UP * (base + h * 0.75), face + Vector3.UP * -50.0, 2.5, Color(0.9, 0.97, 1.0), true)


# ------------------------------------------------------------ Things to explore

## Rock steps up the inside of the cliff (south-west) to a high ledge with
## a gem. Each step is a little higher than the last: hop up them.
func _climb() -> void:
	for k in CLIMB_COUNT:
		var at := _on_ring(CLIMB_FROM + k * CLIMB_STEP, CLIMB_R)
		var h := STEP_H * (k + 1)
		var col := _rock_color()
		_batch.cyl(1.4, 1.55, h, at + Vector3.UP * h / 2.0, col, 7)
		_batch.cyl(1.2, 1.42, 0.1, at + Vector3.UP * (h + 0.04), MOSS.lerp(col, 0.35 if k % 2 == 0 else 0.6), 7)
		_solid_cyl(1.45, h, at + Vector3.UP * h / 2.0)
	# The ledge at the top, set into the cliff.
	var top_h := STEP_H * CLIMB_COUNT
	var a := CLIMB_FROM + CLIMB_COUNT * CLIMB_STEP + 2.6
	var at := _on_ring(a, CLIMB_R + 0.6)
	var yaw := -deg_to_rad(a)
	_batch.box(Vector3(4.2, top_h, 5.0), at + Vector3.UP * top_h / 2.0, _rock_color(), yaw)
	_batch.box(Vector3(4.3, 0.12, 5.1), at + Vector3.UP * top_h, MOSS.lightened(0.05), yaw)
	for k in 3:
		_rock(_batch, at - at.normalized() * 1.9 + Vector3(-at.z, 0, at.x).normalized() * (k - 1) * 1.5 + Vector3.UP * top_h * 0.45,
				1.0, top_h * 0.9, _rock_color())
	_solid_box(Vector3(4.2, top_h, 5.0), at + Vector3.UP * top_h / 2.0, yaw)
	# A little lip so you don't roll straight off the front.
	var front := at - at.normalized() * 2.0
	_batch.box(Vector3(0.25, 0.3, 4.6), front + Vector3.UP * (top_h + 0.15), STONE.darkened(0.1), yaw)
	_solid_box(Vector3(0.25, 0.3, 4.6), front + Vector3.UP * (top_h + 0.15), yaw)
	# A tattered flag, so it catches your eye from the plaza.
	var pole := at + at.normalized() * 1.3 + Vector3(0, top_h, 0)
	_batch.cyl(0.05, 0.05, 2.6, pole + Vector3.UP * 1.3, BARK, 6)
	_batch.box(Vector3(0.04, 0.6, 1.0), pole + Vector3(0, 2.2, 0) + Vector3(-at.z, 0, at.x).normalized() * 0.5,
			Color(0.95, 0.4, 0.3), yaw)
	_gem(0, at + Vector3.UP * top_h)
	# A small carved arrow at the bottom step hinting the way up.
	var first := _on_ring(CLIMB_FROM - 3.0, CLIMB_R - 1.0)
	_batch.box(Vector3(0.6, 0.6, 0.15), first + Vector3.UP * 0.3, STONE, -deg_to_rad(CLIMB_FROM))
	var l := LowPoly.label(self, first + Vector3.UP * 0.32 - first.normalized() * 0.09, "^", 90,
			Color(0.2, 0.15, 0.1), atan2(-first.x, -first.z))
	l.modulate = Color(1.0, 0.85, 0.4)


## Stepped temple ruins (west) with a shrine and a gem on top, a big stone
## head, and broken pillars to hop on.
func _temple() -> void:
	var t := TEMPLE
	for k in 4:
		var size := 10.0 - k * 2.2
		var top := 0.5 * (k + 1)
		var col := STONE.darkened(0.08 * k).lerp(MOSS, 0.08)
		_batch.box(Vector3(size, 0.5, size), t + Vector3.UP * (top - 0.25), col)
		_solid_box(Vector3(size, top, size), t + Vector3.UP * top / 2.0)
		# Moss creeping over the edges.
		for j in 4:
			var side := Vector3([1, -1, 0, 0][j], 0, [0, 0, 1, -1][j]) * size / 2.0
			var along := Vector3(side.z, 0, side.x).normalized() * _rng.randf_range(-size / 3.0, size / 3.0)
			_batch.ball(t + side + along + Vector3.UP * top, _rng.randf_range(0.35, 0.6), MOSS, 5, Vector3(1.4, 0.35, 1.4))
	# The shrine on the top step.
	var floor_y := 2.0
	for x: float in [-1.25, 1.25]:
		for z: float in [-1.25, 1.25]:
			var p := t + Vector3(x, floor_y + 0.9, z)
			_batch.box(Vector3(0.4, 1.8, 0.4), p, STONE.lightened(0.05))
			_solid_box(Vector3(0.4, 1.8, 0.4), p)
	_batch.box(Vector3(3.3, 0.3, 3.3), t + Vector3.UP * (floor_y + 1.95), STONE.darkened(0.1))
	_batch.box(Vector3(2.4, 0.3, 2.4), t + Vector3.UP * (floor_y + 2.25), STONE)
	_batch.box(Vector3(1.4, 0.35, 1.4), t + Vector3.UP * (floor_y + 2.55), STONE.darkened(0.05))
	_batch.ball(t + Vector3(1.1, floor_y + 2.3, 0.9), 0.6, MOSS, 5, Vector3(1.2, 0.5, 1.0))
	_gem(2, t + Vector3.UP * floor_y)
	# A giant stone head watching the plaza.
	var head := t + Vector3(6.8, 0, 4.0)
	_batch.box(Vector3(2.2, 2.6, 2.0), head + Vector3.UP * 1.3, STONE.darkened(0.12), 0.5)
	var face := Basis(Vector3.UP, 0.5)
	for side: float in [-0.5, 0.5]:
		_batch.box(Vector3(0.45, 0.35, 0.15), head + face * Vector3(side, 1.75, 1.02), Color(0.18, 0.16, 0.15), 0.5)
	_batch.box(Vector3(0.35, 0.6, 0.35), head + face * Vector3(0, 1.25, 1.1), STONE.darkened(0.2), 0.5)
	_batch.box(Vector3(1.1, 0.18, 0.12), head + face * Vector3(0, 0.65, 1.02), Color(0.25, 0.2, 0.18), 0.5)
	_batch.ball(head + Vector3(0, 2.65, 0), 1.0, MOSS, 6, Vector3(1.2, 0.35, 1.1))
	_solid_box(Vector3(2.2, 2.6, 2.0), head + Vector3.UP * 1.3, 0.5)
	busy.append([head, 2.0])
	# Broken pillars, each a hop higher than the last, leading up the side.
	for k in 4:
		var p := t + Vector3(7.0 - k * 0.0, 0, -2.5 - k * 1.7)
		p = t + Vector3(6.2 - k * 0.9, 0, -3.8 - k * 1.2)
		var h := 0.5 + k * 0.5
		_batch.cyl(0.6, 0.65, h, p + Vector3.UP * h / 2.0, STONE.darkened(0.1), 8)
		_batch.cyl(0.5, 0.6, 0.12, p + Vector3.UP * (h + 0.04), STONE, 8)
		_solid_cyl(0.65, h, p + Vector3.UP * h / 2.0)
	# Fallen columns lying in the grass.
	for f in [[t + Vector3(-2, 0, 7.5), 0.4], [t + Vector3(4.5, 0, 7.0), 1.9], [t + Vector3(-7, 0, -6), 1.1]]:
		var m := CylinderMesh.new()
		m.top_radius = 0.55
		m.bottom_radius = 0.55
		m.height = 3.6
		m.radial_segments = 8
		m.rings = 1
		var basis := Basis(Vector3.UP, f[1]) * Basis(Vector3.RIGHT, PI / 2.0)
		_batch.shape(m, basis, f[0] + Vector3.UP * 0.5, STONE.darkened(0.15))
		var shape := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.55
		c.height = 3.6
		shape.shape = c
		shape.transform = Transform3D(basis, f[0] + Vector3.UP * 0.5)
		_body.add_child(shape)


## Giant mushrooms (east). Roll onto the little red one and it bounces you
## up onto the first cap, which bounces you onto the next, and so on up to
## a gem on the tallest.
func _mushrooms() -> void:
	var red := Color(0.92, 0.25, 0.25)
	var spots := Color(1.0, 0.95, 0.88)
	# The launcher at the bottom.
	var pad := MUSHROOM_PAD
	_batch.cyl(0.35, 0.4, 0.3, pad + Vector3.UP * 0.15, spots, 8)
	var pad_cap := Node3D.new()
	pad_cap.position = pad + Vector3.UP * 0.3
	add_child(pad_cap)
	var c := LowPoly.ball(pad_cap, Vector3.ZERO, 1.0, red, 12)
	c.scale = Vector3(1, 0.4, 1)
	for k in 5:
		var a := TAU * k / 5.0
		LowPoly.ball(pad_cap, Vector3(cos(a) * 0.6, 0.3, sin(a) * 0.6), 0.14, spots, 6)
	_caps.append([pad_cap, 0.0])
	LowPoly.marble_zone(self, Vector3(1.8, 0.8, 1.8), pad + Vector3.UP * 0.5, func(m): _bounce(m, 0, pad_cap))
	# The big ones. Stems are solid; caps are solid platforms on top.
	var colors := [Color(0.95, 0.55, 0.2), Color(0.85, 0.3, 0.55), Color(0.45, 0.4, 0.95)]
	for i in CAPS.size():
		var top: Vector3 = CAPS[i][0]
		var r: float = CAPS[i][1]
		var base := Vector3(top.x, 0, top.z)
		var stem_h := top.y - 0.35
		_batch.cyl(0.4, 0.55, stem_h, base + Vector3.UP * stem_h / 2.0, Color(0.95, 0.92, 0.82), 8)
		_solid_cyl(0.5, stem_h, base + Vector3.UP * stem_h / 2.0)
		var cap := Node3D.new()
		cap.position = top + Vector3.DOWN * 0.35
		add_child(cap)
		var dome := LowPoly.ball(cap, Vector3.ZERO, r, colors[i], 14)
		dome.scale = Vector3(1, 0.32, 1)
		LowPoly.cyl(cap, r * 0.95, r * 0.95, 0.08, Vector3.UP * 0.02, colors[i].lightened(0.25), 14)
		for k in 6:
			var a := TAU * k / 6.0 + i
			LowPoly.ball(cap, Vector3(cos(a) * r * 0.62, r * 0.22, sin(a) * r * 0.62), 0.16, spots, 6)
		_caps.append([cap, 0.0])
		# A flat solid top to land on.
		_solid_cyl(r * 0.95, 0.35, top + Vector3.DOWN * 0.18)
		if i < CAPS.size() - 1:
			var next := i + 1
			LowPoly.marble_zone(self, Vector3(r * 1.4, 0.7, r * 1.4), top + Vector3.UP * 0.35,
					func(m): _bounce(m, next, cap))
		else:
			# The top one is soft and spongy: it soaks up your speed so you
			# stop on it instead of flying off the far side.
			LowPoly.marble_zone(self, Vector3(r * 1.6, 0.9, r * 1.6), top + Vector3.UP * 0.45, func(m: Marble):
				if _hub.marbles.has(m) and not _hub.mirror:
					m.linear_velocity *= Vector3(0.1, 0.3, 0.1)
					for sq in _caps:
						if sq[0] == cap:
							sq[1] = 0.6)
	_gem(1, CAPS[CAPS.size() - 1][0])
	LowPoly.label(self, pad + Vector3(0, 1.6, 0), "BOING!", 48, Color(0.45, 0.05, 0.1), 0.0, true)


## Throw a marble from a mushroom onto cap `to`.
func _bounce(m: Marble, to: int, cap: Node3D) -> void:
	if _hub.mirror or not _hub.marbles.has(m) or m.freeze or _cooldown.has(m):
		return
	_cooldown[m] = 0.7
	for c in _caps:
		if c[0] == cap:
			c[1] = 1.0
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity") * m.gravity_scale
	var target := to_global(CAPS[to][0] + Vector3.UP * 0.4)
	var t := 0.95
	m.linear_velocity = (target - m.global_position) / t + Vector3.UP * 0.5 * g * t
	m.angular_velocity = Vector3.ZERO
	m.no_steer_time = t + 0.15


## A big hollow fallen log (north) you can roll right through. There's a
## gem inside.
func _hollow_log() -> void:
	var n := 12
	var mid := LOG + Vector3.UP * (LOG_RADIUS - 0.2)
	for i in n:
		var a := TAU * (i + 0.5) / n
		var normal := Vector3(0, sin(a), cos(a))
		var width := 2.0 * LOG_RADIUS * tan(PI / n) + 0.08
		var basis := Basis(Vector3.RIGHT, a)
		var pos := mid + normal * LOG_RADIUS
		_tilted_box(_batch, Vector3(LOG_LENGTH, 0.28, width), basis, pos, BARK.darkened(0.25).lerp(BARK, float(i % 3) / 3.0))
		# Pale cut wood round each end.
		for e: float in [-1.0, 1.0]:
			_tilted_box(_batch, Vector3(0.1, 0.3, width), basis, pos + Vector3(e * LOG_LENGTH / 2.0, 0, 0), Color(0.85, 0.7, 0.5))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(LOG_LENGTH, 0.28, width)
		shape.shape = box
		shape.transform = Transform3D(basis, pos)
		_body.add_child(shape)
	# Moss and little mushrooms on top.
	for k in 5:
		var p := mid + Vector3(_rng.randf_range(-3.5, 3.5), LOG_RADIUS + 0.1, _rng.randf_range(-0.4, 0.4))
		_batch.ball(p, _rng.randf_range(0.35, 0.6), MOSS, 5, Vector3(1.5, 0.4, 1.0))
	for k in 4:
		var p := mid + Vector3(-3.0 + k * 1.6, LOG_RADIUS + 0.15, 0.6)
		_batch.cyl(0.04, 0.05, 0.25, p + Vector3.UP * 0.12, Color(0.95, 0.92, 0.85), 5)
		_batch.ball(p + Vector3.UP * 0.27, 0.13, Color(0.95, 0.6, 0.2), 6, Vector3(1, 0.5, 1))
	_gem(3, LOG + Vector3.UP * 0.05)


## A crystal cave cut into the north-east cliff, glowing inside, with a gem
## at the back.
func _cave() -> void:
	var a := deg_to_rad(CAVE_ANGLE)
	var out := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-out.z, 0, out.x)
	var yaw := atan2(out.x, out.z)
	var mouth := out * 36.5
	var depth := 7.5
	var mid := mouth + out * depth / 2.0
	# Floor (it pokes out past the island's edge), walls and a roof.
	_batch.box(Vector3(5.4, 1.0, depth), mid + Vector3.DOWN * 0.5, ROCK.darkened(0.3), yaw)
	_solid_box(Vector3(5.4, 1.0, depth), mid + Vector3.DOWN * 0.5, yaw)
	for s: float in [-1.0, 1.0]:
		var p := mid + side * s * 2.9 + Vector3.UP * 2.0
		_batch.box(Vector3(1.2, 5.0, depth + 1.0), p + Vector3.DOWN * 0.5, ROCK.darkened(0.12), yaw)
		_solid_box(Vector3(1.2, 4.0, depth + 1.0), p, yaw)
	_batch.box(Vector3(6.6, 5.0, 1.2), mouth + out * (depth + 0.4) + Vector3.UP * 2.0, ROCK.darkened(0.2), yaw)
	_solid_box(Vector3(6.6, 4.0, 1.2), mouth + out * (depth + 0.4) + Vector3.UP * 2.0, yaw)
	_batch.box(Vector3(7.0, 1.4, depth + 1.6), mid + Vector3.UP * 3.6 + out * 0.3, ROCK.darkened(0.08), yaw)
	_solid_box(Vector3(7.0, 1.4, depth + 1.6), mid + Vector3.UP * 3.6 + out * 0.3, yaw)
	# Big rocks piled on top so it looks like part of the mountain.
	for k in 3:
		var p := mid + side * (k - 1) * 2.4 + out * _rng.randf_range(-0.5, 1.5)
		var h := _rng.randf_range(8.0, 12.0)
		_rock(_batch, p + Vector3.UP * (4.0 + h / 2.0), 2.6, h, _rock_color())
	_rock(_batch, mid + out * 1.5 + Vector3.DOWN * 4.0, 4.0, 7.0, ROCK.darkened(0.2))
	# A dark doorway frame and glowing crystals inside.
	for s: float in [-1.0, 1.0]:
		_rock(_batch, mouth + side * s * 2.8 + Vector3.UP * 1.6, 0.9, 4.2, ROCK.darkened(0.05))
	var crystal := [Color(0.75, 0.45, 1.0), Color(0.4, 0.9, 1.0), Color(1.0, 0.5, 0.85)]
	for k in 14:
		var p := mouth + out * _rng.randf_range(1.0, depth - 0.5) + side * (2.15 if k % 2 == 0 else -2.15)
		p.y = _rng.randf_range(0.0, 2.8)
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = _rng.randf_range(0.12, 0.25)
		m.height = _rng.randf_range(0.6, 1.3)
		m.radial_segments = 5
		m.rings = 1
		var lean := Basis(out, (-1.0 if k % 2 == 0 else 1.0) * _rng.randf_range(0.5, 1.2))
		_batch.shape(m, lean, p, crystal[k % 3], true)
	for k in 5:
		var p := mouth + out * _rng.randf_range(1.0, depth - 1.0) + side * _rng.randf_range(-1.6, 1.6)
		_batch.cyl(0.03, 0.04, 0.2, p + Vector3.UP * 0.1, Color(0.9, 0.95, 1.0), 5)
		_batch.ball(p + Vector3.UP * 0.22, 0.12, Color(0.4, 1.0, 0.85), 6, Vector3(1, 0.5, 1), true)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.5, 1.0)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position = mid + Vector3.UP * 1.8
	add_child(light)
	_gem(4, mouth + out * (depth - 1.4))


## A waterfall pouring down the east cliff into a little pool. There's a
## hollow behind the falling water, and a gem in it.
func _waterfall() -> void:
	var a := deg_to_rad(FALLS_ANGLE)
	var out := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-out.z, 0, out.x)
	var yaw := atan2(out.x, out.z)
	var lip := out * 37.0
	var top := 11.0
	# The hollow behind: a floor, walls and a roof of rock.
	var mid := lip + out * 3.0
	_batch.box(Vector3(4.6, 1.0, 6.0), mid + Vector3.DOWN * 0.5, ROCK.darkened(0.25), yaw)
	_solid_box(Vector3(4.6, 1.0, 6.0), mid + Vector3.DOWN * 0.5, yaw)
	for s: float in [-1.0, 1.0]:
		_batch.box(Vector3(1.0, 4.0, 6.0), mid + side * s * 2.5 + Vector3.UP * 1.6, ROCK.darkened(0.1), yaw)
		_solid_box(Vector3(1.0, 3.2, 6.0), mid + side * s * 2.5 + Vector3.UP * 1.6, yaw)
	_batch.box(Vector3(6.0, 3.6, 1.0), mid + out * 3.2 + Vector3.UP * 1.6, ROCK.darkened(0.15), yaw)
	_solid_box(Vector3(6.0, 3.2, 1.0), mid + out * 3.2 + Vector3.UP * 1.6, yaw)
	# The cliff above the hollow, which the water pours off.
	_batch.box(Vector3(6.4, top - 3.0, 7.0), mid + out * 0.3 + Vector3.UP * (3.0 + (top - 3.0) / 2.0), _rock_color(), yaw)
	_solid_box(Vector3(6.4, 1.0, 7.0), mid + Vector3.UP * 3.6, yaw)
	for s: float in [-1.0, 1.0]:
		_rock(_batch, lip + side * s * 3.2 + out * 1.5 + Vector3.UP * (top - 4.0) / 2.0, 2.4, top + 4.0, _rock_color())
		_solid_cyl(2.0, top, lip + side * s * 3.4 + out * 1.5 + Vector3.UP * top / 2.0)
	_batch.cyl(0.0, 1.6, 1.0, mid + Vector3.UP * (top + 0.4), MOSS, 6)
	# The water: a see-through sheet with drops racing down it.
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, top)
	sheet.mesh = quad
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet.material_override = wm
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = lip - out * 0.2 + Vector3.UP * top / 2.0
	sheet.rotation.y = yaw
	add_child(sheet)
	var drops := CPUParticles3D.new()
	drops.amount = 90
	drops.lifetime = 1.3
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drops.emission_box_extents = Vector3(1.4, 0.1, 0.1)
	drops.direction = Vector3.DOWN
	drops.spread = 3.0
	drops.initial_velocity_min = 2.0
	drops.initial_velocity_max = 3.0
	drops.gravity = Vector3(0, -6.0, 0)
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.4
	drops.mesh = _drop_mesh(Color(0.9, 0.97, 1.0, 0.85), 0.1)
	drops.position = lip - out * 0.3 + Vector3.UP * (top - 0.2)
	drops.rotation.y = yaw
	add_child(drops)
	var splash := CPUParticles3D.new()
	splash.amount = 40
	splash.lifetime = 0.8
	splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	splash.emission_box_extents = Vector3(1.4, 0.05, 0.3)
	splash.direction = Vector3.UP
	splash.spread = 50.0
	splash.initial_velocity_min = 1.0
	splash.initial_velocity_max = 2.2
	splash.gravity = Vector3(0, -6.0, 0)
	splash.mesh = _drop_mesh(Color(1, 1, 1, 0.8), 0.12)
	splash.position = lip - out * 0.6 + Vector3.UP * 0.1
	splash.rotation.y = yaw
	add_child(splash)
	# The pool at the bottom, ringed with stones.
	var pool := lip - out * 3.0
	var water := LowPoly.cyl(self, 2.8, 2.8, 0.05, pool + Vector3.UP * 0.03, Color(0.3, 0.65, 0.9), 20)
	var pm := LowPoly.own_mat(water)
	pm.roughness = 0.05
	pm.metallic = 0.3
	for k in 8:
		var ang := TAU * k / 8.0
		var p := pool + Vector3(cos(ang), 0, sin(ang)) * 3.0
		if (p - lip).length() < 2.2:
			continue
		_batch.ball(p + Vector3.UP * 0.1, _rng.randf_range(0.35, 0.55), STONE.darkened(0.15), 6, Vector3(1.2, 0.6, 1.0))
	_gem(5, mid + out * 1.2)


func _drop_mesh(color: Color, r: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	return mesh


## Grassy hills to roll up and over.
func _hills() -> void:
	for h in HILLS:
		var at: Vector3 = h[0]
		var r: float = h[1]
		var height: float = h[2]
		_batch.ball(at, 1.0, Color(0.36, 0.64, 0.3), 16, Vector3(r, height, r))
		var pts := PackedVector3Array()
		for ring in 6:
			var e := PI / 2.0 * ring / 5.0
			var count := 1 if ring == 5 else 16
			for s in count:
				var phi := TAU * s / 16.0
				pts.append(Vector3(cos(e) * cos(phi) * r, sin(e) * height, cos(e) * sin(phi) * r))
		for s in 16:
			var phi := TAU * s / 16.0
			pts.append(Vector3(cos(phi) * r, -0.5, sin(phi) * r))
		var shape := CollisionShape3D.new()
		var cs := ConvexPolygonShape3D.new()
		cs.points = pts
		shape.shape = cs
		shape.position = at
		_body.add_child(shape)
		# Flowers and a rock on top.
		for k in 6:
			var ang := _rng.randf() * TAU
			var d := _rng.randf_range(0.5, r * 0.7)
			var y := height * sqrt(maxf(1.0 - pow(d / r, 2.0), 0.0))
			_batch.ball(at + Vector3(cos(ang) * d, y + 0.06, sin(ang) * d), 0.1, Hub.FLOWER_COLORS[k % 5], 5)


# ------------------------------------------------------------ Plants

func _plants() -> void:
	# Big jungle trees with wide flat canopies, round the edge.
	var tall := 0
	var tries := 0
	while tall < 14 and tries < 200:
		tries += 1
		var ang := _rng.randf() * 360.0
		if _in_gap(ang, 6.0) or (ang > LOW_FROM - 5.0 and ang < LOW_TO + 5.0):
			continue
		var at := _on_ring(ang, _rng.randf_range(29.0, 34.0))
		if _free(at, 3.0):
			_jungle_tree(at)
			busy.append([at, 2.5])
			tall += 1
	# Palms, ferns and big-leaf plants scattered all over the green.
	var palms := 0
	tries = 0
	while palms < 12 and tries < 300:
		tries += 1
		var at := _on_ring(_rng.randf() * 360.0, _rng.randf_range(18.0, 35.0))
		if _free(at, 2.0) and not _in_gap(rad_to_deg(atan2(at.z, at.x)), 4.0):
			_palm(at)
			busy.append([at, 1.2])
			palms += 1
	var ferns := 0
	tries = 0
	while ferns < 70 and tries < 600:
		tries += 1
		var at := _on_ring(_rng.randf() * 360.0, _rng.randf_range(14.0, 36.5))
		if _free(at, 0.6, true):
			if _rng.randf() < 0.65:
				_fern(at)
			else:
				_big_leaves(at)
			ferns += 1
	# Mossy boulders.
	for k in 18:
		var at := _on_ring(_rng.randf() * 360.0, _rng.randf_range(20.0, 35.0))
		if not _free(at, 1.0, true):
			continue
		var r := _rng.randf_range(0.5, 1.1)
		_batch.ball(at + Vector3.UP * r * 0.3, r, STONE.darkened(0.25), 6, Vector3(1.3, 0.7, 1.0))
		_batch.ball(at + Vector3.UP * r * 0.75, r * 0.7, MOSS, 5, Vector3(1.3, 0.4, 1.0))
		_solid_cyl(r * 1.0, r * 0.9, at + Vector3.UP * r * 0.45)


## True if nothing else is near `at`: the practice run, the plaza, the
## bridges' paths, and the jungle's own places (unless `small`).
func _free(at: Vector3, r: float, small := false) -> bool:
	if _hub._near_run(at, r + 2.0):
		return false
	if Vector2(at.x, at.z - 13.0).length() < 15.0 + r:
		return false   # the plaza
	if Vector2(at.x - 17.0, at.z - 17.0).length() < 4.5 + r:
		return false   # the pond
	if Vector2(at.x - 20.0, at.z + 22.0).length() < 5.0 + r or Vector2(at.x + 17.0, at.z + 23.0).length() < 3.0 + r:
		return false   # the cottage and the windmill
	for ang in [Hub.CASINO_ANGLE, 270.0, Hub.SPORTS_ANGLE, 45.0]:
		var dir := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		var along := at.dot(dir)
		if along > 8.0 and (at - dir * along).length() < 3.5 + r:
			return false   # the way to a bridge (or the pond's stream)
	if not small or r > 0.5:
		return not is_busy(at, r)
	return not is_busy(at, 0.0)


func _jungle_tree(at: Vector3) -> void:
	var h := _rng.randf_range(7.0, 10.0)
	var lean := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	var top := at + Vector3.UP * h + lean
	_batch.beam(at + Vector3.DOWN * 0.3, top, 0.7, BARK)
	_solid_cyl(0.45, h, at + Vector3.UP * h / 2.0)
	# Buttress roots.
	for k in 4:
		var a := TAU * k / 4.0 + _rng.randf()
		var d := Vector3(cos(a), 0, sin(a))
		_batch.beam(at + d * 1.2, at + Vector3.UP * 1.6 + d * 0.2, 0.25, BARK.darkened(0.1))
	# A wide, layered canopy.
	var leaf := LEAF.lerp(Color(0.3, 0.58, 0.25), _rng.randf())
	_batch.ball(top + Vector3.UP * 0.4, _rng.randf_range(3.0, 3.8), leaf, 9, Vector3(1, 0.38, 1))
	_batch.ball(top + Vector3(1.4, 1.1, -0.6), _rng.randf_range(1.8, 2.4), leaf.lightened(0.1), 8, Vector3(1, 0.45, 1))
	_batch.ball(top + Vector3(-1.2, 0.9, 1.0), _rng.randf_range(1.6, 2.2), leaf.darkened(0.1), 8, Vector3(1, 0.45, 1))
	# A side branch with its own tuft.
	var b := at + Vector3.UP * h * 0.6 + lean * 0.6
	var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	_batch.beam(b, b + dir * 2.4 + Vector3.UP * 1.2, 0.3, BARK)
	_batch.ball(b + dir * 2.6 + Vector3.UP * 1.5, 1.3, leaf, 7, Vector3(1, 0.5, 1))
	# Vines dangling from the canopy.
	for k in 3:
		var a := _rng.randf() * TAU
		var p := top + Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
		_batch.beam(p, p + Vector3.DOWN * _rng.randf_range(2.0, 4.5), 0.06, Color(0.28, 0.48, 0.22))


func _palm(at: Vector3) -> void:
	var h := _rng.randf_range(3.5, 5.5)
	var bend := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.6, 1.4)
	var prev := at
	var segs := 6
	for k in segs:
		var t := float(k + 1) / segs
		var p := at + Vector3.UP * h * t + bend * t * t
		_batch.beam(prev, p, 0.28 - t * 0.08, Color(0.6, 0.47, 0.3).darkened(0.08 * (k % 2)))
		prev = p
	_solid_cyl(0.18, h * 0.5, at + Vector3.UP * h * 0.25)
	for k in 7:
		var a := TAU * k / 7.0 + _rng.randf() * 0.3
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.45)
		var dir := basis * Vector3.BACK
		_tilted_box(_batch, Vector3(0.5, 0.05, 2.2), basis, prev + dir * 1.0 + Vector3.DOWN * 0.25,
				Color(0.3, 0.62, 0.28).lerp(Color(0.45, 0.7, 0.3), _rng.randf()))
	for k in 3:
		_batch.ball(prev + Vector3(cos(k * 2.1) * 0.25, -0.3, sin(k * 2.1) * 0.25), 0.16, Color(0.45, 0.32, 0.18), 6)


func _fern(at: Vector3) -> void:
	var n := _rng.randi_range(6, 8)
	var col := Color(0.25, 0.55, 0.25).lerp(Color(0.4, 0.68, 0.3), _rng.randf())
	var size := _rng.randf_range(0.7, 1.3)
	for k in n:
		var a := TAU * k / n + _rng.randf() * 0.3
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.55)
		_tilted_box(_batch, Vector3(0.22, 0.03, 1.0) * size, basis, at + basis * Vector3(0, 0, 0.5 * size) + Vector3.UP * 0.1, col)


func _big_leaves(at: Vector3) -> void:
	var col := Color(0.2, 0.5, 0.25).lerp(Color(0.35, 0.6, 0.25), _rng.randf())
	for k in _rng.randi_range(3, 5):
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var stem_top := at + dir * 0.4 + Vector3.UP * _rng.randf_range(0.6, 1.1)
		_batch.beam(at, stem_top, 0.05, col.darkened(0.2))
		var basis := Basis(Vector3.UP, -a + PI / 2.0) * Basis(Vector3.RIGHT, 0.5)
		_batch.shape(_leaf_mesh(), basis, stem_top + dir * 0.35, col)


static var _leaf: SphereMesh
static func _leaf_mesh() -> SphereMesh:
	if _leaf == null:
		_leaf = SphereMesh.new()
		_leaf.radius = 0.35
		_leaf.height = 0.06
		_leaf.radial_segments = 8
		_leaf.rings = 2
	return _leaf


## A carved stone near the spawn telling you there's something to find.
func _hint_sign() -> void:
	var at := Vector3(4.6, 0, 13.5)
	_batch.box(Vector3(2.4, 1.5, 0.35), at + Vector3.UP * 0.75, STONE.darkened(0.1))
	_batch.box(Vector3(2.6, 0.2, 0.45), at + Vector3.UP * 1.55, STONE)
	_batch.ball(at + Vector3(0.9, 1.65, 0), 0.35, MOSS, 5, Vector3(1.2, 0.5, 1))
	_solid_box(Vector3(2.4, 1.5, 0.35), at + Vector3.UP * 0.75)
	LowPoly.label(self, at + Vector3(0, 0.85, 0.19), "%d SECRET GEMS\nARE HIDDEN IN\nTHE JUNGLE..." % GEM_COUNT, 30,
			Color(0.15, 0.12, 0.08))


# ------------------------------------------------------------ Secrets

func _gem(id: int, at: Vector3) -> void:
	var node := Node3D.new()
	node.position = at + Vector3.UP * 0.55
	add_child(node)
	var color: Color = GEM_COLORS[id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.metallic = 0.4
	mat.roughness = 0.15
	for s: float in [1.0, -1.0]:
		var cone := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.28
		m.height = 0.32 if s > 0 else 0.42
		m.radial_segments = 6
		m.rings = 1
		cone.mesh = m
		cone.material_override = mat
		cone.position.y = s * m.height / 2.0
		cone.rotation.x = 0.0 if s > 0 else PI
		node.add_child(cone)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	node.add_child(light)
	var glints := CPUParticles3D.new()
	glints.amount = 10
	glints.lifetime = 1.2
	glints.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glints.emission_sphere_radius = 0.5
	glints.direction = Vector3.UP
	glints.spread = 40.0
	glints.initial_velocity_min = 0.2
	glints.initial_velocity_max = 0.5
	glints.gravity = Vector3.ZERO
	glints.mesh = _drop_mesh(color.lightened(0.5), 0.04)
	node.add_child(glints)
	var gem := {"node": node, "id": id, "at": at, "taken": false, "mat": mat}
	if _ghost_mat == null:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.roughness = 0.1
	_gems.append(gem)
	LowPoly.marble_zone(self, Vector3(1.3, 1.4, 1.3), at + Vector3.UP * 0.6, func(m): _take(gem, m))


func _take(gem: Dictionary, m: Marble) -> void:
	if gem.taken or _hub.mirror or not _hub.marbles.has(m):
		return
	gem.taken = true
	(gem.node as Node3D).visible = false
	LowPoly.confetti(self, gem.at + Vector3.UP * 0.6, 50)
	_hub.secret_found.emit(m.player_id, gem.id, gem.at)


## A message that floats up from where a gem was and fades away.
func pop_text(at: Vector3, text: String, color: Color) -> void:
	var l := LowPoly.label(self, at + Vector3.UP * 1.4, text, 56, Color(0.08, 0.06, 0.12), 0.0, true)
	l.modulate = color.lightened(0.3)
	l.no_depth_test = true
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 2.2, 2.6)
	tw.tween_property(l, "modulate:a", 0.0, 2.6).set_delay(1.4)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------ Critters

## Bright parrots flapping round the island in big loops.
func _parrots_fly() -> void:
	var looks := [[Color(0.95, 0.2, 0.2), Color(1.0, 0.85, 0.2), Color(0.2, 0.5, 1.0)],
			[Color(0.2, 0.5, 1.0), Color(1.0, 0.85, 0.2), Color(0.2, 0.75, 0.4)],
			[Color(0.25, 0.8, 0.35), Color(1.0, 0.4, 0.3), Color(1.0, 0.85, 0.2)],
			[Color(1.0, 0.75, 0.15), Color(0.2, 0.5, 1.0), Color(0.95, 0.2, 0.2)],
			[Color(0.95, 0.2, 0.2), Color(0.2, 0.5, 1.0), Color(0.25, 0.8, 0.35)]]
	for i in looks.size():
		var cols: Array = looks[i]
		var bird := Node3D.new()
		add_child(bird)
		var body := LowPoly.ball(bird, Vector3.ZERO, 0.22, cols[0], 8)
		body.scale = Vector3(0.8, 0.8, 1.4)
		LowPoly.ball(bird, Vector3(0, 0.12, -0.3), 0.15, cols[0], 8)
		LowPoly.cyl(bird, 0.0, 0.06, 0.14, Vector3(0, 0.08, -0.46), Color(0.95, 0.9, 0.7), 5).rotation.x = -PI / 2.0
		LowPoly.box(bird, Vector3(0.12, 0.03, 0.5), Vector3(0, 0.0, 0.45), cols[2])
		var wings: Array = []
		for s: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(s * 0.12, 0.05, 0)
			bird.add_child(pivot)
			LowPoly.box(pivot, Vector3(0.5, 0.03, 0.25), Vector3(s * 0.25, 0, 0), cols[1])
			wings.append(pivot)
		_parrots.append({"node": bird, "wings": wings, "radius": _rng.randf_range(10.0, 30.0),
				"y": _rng.randf_range(5.0, 11.0), "speed": _rng.randf_range(0.18, 0.32) * (1.0 if i % 2 == 0 else -1.0),
				"angle": _rng.randf() * TAU, "center": Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))})


## Frogs on lily pads in the pond, hopping from pad to pad.
func _frogs_hop() -> void:
	var pond := Vector3(17, 0, 17)
	var pads: Array = []
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var p := pond + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 2.3)
		pads.append(p + Vector3.UP * 0.08)
		var pad := LowPoly.cyl(self, 0.45, 0.45, 0.03, p + Vector3.UP * 0.065, Color(0.3, 0.6, 0.25), 10)
		pad.rotation.y = _rng.randf() * TAU
		if k % 2 == 0:
			LowPoly.ball(self, p + Vector3(0.15, 0.12, 0.1), 0.08, Color(1.0, 0.75, 0.85), 6)
	for f in 3:
		var frog := Node3D.new()
		add_child(frog)
		var green := Color(0.35, 0.7, 0.25).lerp(Color(0.55, 0.8, 0.2), f / 2.0)
		LowPoly.ball(frog, Vector3(0, 0.1, 0), 0.16, green, 8).scale = Vector3(1.1, 0.7, 1.2)
		for s: float in [-1.0, 1.0]:
			LowPoly.ball(frog, Vector3(s * 0.08, 0.2, -0.1), 0.05, Color.WHITE, 6)
			LowPoly.ball(frog, Vector3(s * 0.08, 0.21, -0.14), 0.025, Color(0.05, 0.05, 0.05), 5)
			LowPoly.ball(frog, Vector3(s * 0.13, 0.04, 0.08), 0.07, green.darkened(0.15), 6)
		var start: int = f * 2
		frog.position = pads[start]
		_frogs.append({"node": frog, "pads": pads, "from": start, "to": start, "t": 1.0, "wait": _rng.randf_range(0.5, 3.0)})


func _frog_update(f: Dictionary, delta: float) -> void:
	var node: Node3D = f.node
	if f.t < 1.0:
		f.t = minf(f.t + delta * 1.6, 1.0)
		var a: Vector3 = f.pads[f.from]
		var b: Vector3 = f.pads[f.to]
		node.position = a.lerp(b, f.t) + Vector3.UP * sin(PI * f.t) * 0.7
		return
	f.wait -= delta
	if f.wait <= 0.0:
		f.from = f.to
		f.to = (f.to + _rng.randi_range(1, 2)) % f.pads.size()
		f.t = 0.0
		f.wait = _rng.randf_range(1.5, 4.0)
		var dir: Vector3 = f.pads[f.to] - f.pads[f.from]
		node.rotation.y = atan2(-dir.x, -dir.z)


## A little monkey sitting on top of the temple shrine, waving.
func _monkey() -> void:
	var m := Node3D.new()
	m.position = TEMPLE + Vector3(0, 4.75, 0)
	m.rotation.y = 0.8
	add_child(m)
	var fur := Color(0.5, 0.32, 0.18)
	var face := Color(0.92, 0.75, 0.58)
	LowPoly.ball(m, Vector3(0, 0.25, 0), 0.25, fur, 8).scale = Vector3(1, 1.1, 0.9)
	LowPoly.ball(m, Vector3(0, 0.62, 0), 0.2, fur, 8)
	LowPoly.ball(m, Vector3(0, 0.58, 0.14), 0.12, face, 8).scale = Vector3(1.1, 0.8, 0.6)
	for s: float in [-1.0, 1.0]:
		LowPoly.ball(m, Vector3(s * 0.2, 0.66, 0), 0.08, face, 6)
		LowPoly.ball(m, Vector3(s * 0.07, 0.68, 0.17), 0.035, Color(0.05, 0.05, 0.05), 5)
		LowPoly.ball(m, Vector3(s * 0.15, 0.05, 0.12), 0.09, fur, 6)
	var arm := Node3D.new()
	arm.position = Vector3(0.2, 0.38, 0)
	m.add_child(arm)
	LowPoly.box(arm, Vector3(0.08, 0.35, 0.08), Vector3(0, -0.17, 0), fur)
	LowPoly.ball(arm, Vector3(0, -0.36, 0), 0.06, face, 6)
	_monkey_arm = arm
	LowPoly.box(m, Vector3(0.08, 0.35, 0.08), Vector3(-0.22, 0.2, 0), fur).rotation.z = -0.3
	# A curly tail.
	LowPoly.box(m, Vector3(0.05, 0.05, 0.5), Vector3(0, 0.1, -0.35), fur).rotation.x = 0.4


## Glowing fireflies drifting low over the grass.
func _fireflies() -> void:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(32, 1.2, 32)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 1.0, 0.45)
	mesh.material = m
	p.mesh = mesh
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.3, 1))
	fade.add_point(Vector2(0.7, 1))
	fade.add_point(Vector2(1, 0))
	p.scale_amount_curve = fade
	p.position = Vector3(0, 1.4, 0)
	add_child(p)


## Leaves drifting down from the canopy.
func _falling_leaves() -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30, 1, 30)
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, -0.9, 0)
	p.angular_velocity_min = -180
	p.angular_velocity_max = 180
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.22, 0.14)
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf.material = m
	p.mesh = leaf
	var colors := Gradient.new()
	colors.set_color(0, Color(0.4, 0.7, 0.3))
	colors.set_color(1, Color(0.85, 0.6, 0.2))
	p.color_initial_ramp = colors
	p.position = Vector3(0, 10, 0)
	add_child(p)
