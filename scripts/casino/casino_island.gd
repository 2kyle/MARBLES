class_name CasinoIsland
extends Node3D
## THE GROOVY MARBLE: an indoor seventies casino on its own island, over a
## bridge off the west side of the practice island.
##
## Inside:
##   - the Marble Derby (horse racing, see horse_race.gd) down the left
##   - a blackjack table with four seats (see blackjack.gd)
##   - a bar: roll onto the gold plate to order a fizzy drink (your marble
##     gets the hiccups for a while)
##   - the Loot Crates machine by the door (see crate_screen.gd)
##   - a roulette wheel, slot machines, a dance floor under a spinning
##     disco ball, lava lamps, and dealers in shady sunglasses
##
## Everything is built in code by build(). Pressure plates come from the
## practice island (hub.gd), which tells main.gd who rolled onto what.

const RADIUS := 30.0
## The building: half its width (x) and depth (z), and its height.
const HALF := Vector2(22.0, 16.0)
const HEIGHT := 7.5
const DOOR_HALF := 2.6
const DOOR_H := 4.5
## How much wider a mountain rock's foot is than the rock itself.
const FOOT := 1.35

## Where things are, in this island's own space.
const DERBY_POS := Vector3(-15, 0, 12)
const BET_PLATE := Vector3(-5.5, 0, 13.0)
const TABLE_POS := Vector3(3, 0, -7)
const SEAT_ANGLES := [-0.95, -0.32, 0.32, 0.95]
const SEAT_RADIUS := 3.3
const BAR_PLATE := Vector3(14.5, 0, -10.0)
const CRATE_PLATE := Vector3(15.5, 0, 9.0)
const ROULETTE_POS := Vector3(3, 0, 8.5)
const DANCE_POS := Vector3(3, 0, 0.8)

## The bar's menu. Pricier drinks fizz for longer and hiccup harder.
const DRINKS := [
	{"name": "Fizzy Lemonade", "price": 5, "color": Color(1.0, 0.92, 0.35), "time": 15.0, "hop": 1.0},
	{"name": "Root Beer Float", "price": 10, "color": Color(0.55, 0.3, 0.15), "time": 25.0, "hop": 1.3},
	{"name": "Galaxy Soda", "price": 20, "color": Color(0.65, 0.35, 1.0), "time": 40.0, "hop": 1.7},
]

const ORANGE := Color(0.95, 0.5, 0.15)
const MUSTARD := Color(0.92, 0.72, 0.2)
const BROWN := Color(0.4, 0.22, 0.14)
const TEAL := Color(0.12, 0.55, 0.55)
const PLUM := Color(0.32, 0.14, 0.3)
const GOLD := Color(1.0, 0.8, 0.3)
const FELT := Color(0.1, 0.45, 0.25)
const NEON := [Color(1.0, 0.3, 0.65), Color(0.3, 0.9, 1.0), Color(1.0, 0.75, 0.25), Color(0.6, 1.0, 0.4)]

var derby: HorseRace
var blackjack: Blackjack
var profiles: Profiles:
	set(v):
		profiles = v
		if derby:
			derby.profiles = v
		if blackjack:
			blackjack.profiles = v
## Bar: which drink each player is looking at, and a line of news.
var drink_pick: Array = [0, 0, 0, 0]
var bar_message: Array = ["", "", "", ""]

var _fizzy := {}   # marble -> {left, next, drink}
var _movers: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _bulbs: Array = []   # [material A, material B] for the blinking marquee
var _hub_marbles: Array = []


## Build it all. `bridge_from_x` is where the bridge from the practice
## island lands (this island's space); `plate` makes a pressure plate:
## plate.call(position in the hub's space, colour, Callable(player), way out).
## The hub places and turns this island before calling build().
func build(hub_plate: Callable, on_table: Callable, on_crates: Callable) -> void:
	# Plates are made in this island's own space; turn that into the hub's.
	# `out` is the way you roll off afterwards, in this island's space.
	var plate := func(at: Vector3, color: Color, on_enter: Callable, out: Vector3) -> void:
		hub_plate.call(transform * at, color, on_enter, transform.basis * out)
	_rng.seed = 1977
	_island()
	_building()
	_carpet()
	_derby(plate, on_table)
	_blackjack(plate, on_table)
	_bar(plate, on_table)
	_crates(plate, on_crates)
	_roulette()
	_dance_floor()
	_slots()
	_lounge()
	_lights()
	_party_lights()
	_front()
	_mountain()


## Where a marble pops back up if it falls off this island.
func spawn_point() -> Vector3:
	return to_global(Vector3(HALF.x + 4.0, 0.5, 0))


## Called every physics tick while the practice island is open.
func update(delta: float, marbles: Array) -> void:
	_hub_marbles = marbles
	derby.update(delta)
	blackjack.update(delta)
	for m in _fizzy.keys():
		if not is_instance_valid(m):
			_fizzy.erase(m)
			continue
		var f: Dictionary = _fizzy[m]
		f.left -= delta
		f.next -= delta
		if f.next <= 0.0 and not (m as Marble).freeze:
			f.next = _rng.randf_range(1.0, 2.2)
			(m as Marble).apply_central_impulse(Vector3.UP * 2.2 * f.hop * (m as Marble).mass)
			_bubbles(m, f.color, 10)
		if f.left <= 0.0:
			_fizzy.erase(m)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for mv in _movers:
		(mv as Callable).call(_time, delta)
	# Marquee bulbs chase: the two halves take turns, fading softly
	# rather than snapping on and off.
	var w := 0.5 + 0.5 * sin(_time * 5.0)
	if _bulbs.size() == 2:
		(_bulbs[0] as StandardMaterial3D).emission_energy_multiplier = 0.4 + 3.6 * w
		(_bulbs[1] as StandardMaterial3D).emission_energy_multiplier = 0.4 + 3.6 * (1.0 - w)


# ------------------------------------------------------------ The bar

func request_drink_pick(p: int, step: int) -> void:
	drink_pick[p] = wrapi(drink_pick[p] + step, 0, DRINKS.size())
	bar_message[p] = ""


## Order the drink the player is looking at. `m` is their marble.
func request_drink(p: int, m: Marble) -> void:
	var d: Dictionary = DRINKS[drink_pick[p]]
	if profiles == null or profiles.coins(p) < d.price:
		bar_message[p] = "Not enough coins"
		return
	profiles.add_coins(p, -d.price)
	profiles.save_to_disk()
	bar_message[p] = "One %s! Cheers!" % d.name
	_fizzy[m] = {"left": d.time, "next": 1.5, "hop": d.hop, "color": d.color}
	_serve_glass(p, d.color)


## True if this marble has the hiccups from a drink.
func is_fizzy(m: Marble) -> bool:
	return _fizzy.has(m)


func _serve_glass(p: int, color: Color) -> void:
	var glass := Node3D.new()
	add_child(glass)
	var at := BAR_PLATE + Vector3((p - 1.5) * 0.5, 1.2, -2.0)
	glass.position = at + Vector3(2.5, 0, 0)
	var cup := LowPoly.cyl(glass, 0.14, 0.11, 0.34, Vector3(0, 0.17, 0), Color(0.85, 0.95, 1.0), 10)
	var cm := LowPoly.own_mat(cup)
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_color = Color(0.85, 0.95, 1.0, 0.35)
	var drink := LowPoly.cyl(glass, 0.12, 0.1, 0.24, Vector3(0, 0.13, 0), color, 10)
	var dm := LowPoly.own_mat(drink)
	dm.emission_enabled = true
	dm.emission = color * 0.6
	LowPoly.cyl(glass, 0.01, 0.01, 0.4, Vector3(0.05, 0.35, 0), Color(1, 0.3, 0.4), 4).rotation.z = 0.3
	LowPoly.ball(glass, Vector3(-0.08, 0.32, 0), 0.05, Color(1, 0.2, 0.25), 6)
	# Slid down the counter by the bartender, then gone after a while.
	var tw := glass.create_tween()
	tw.tween_property(glass, "position", at, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(12.0)
	tw.tween_property(glass, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(glass.queue_free)


func _bubbles(m: Node3D, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.2
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.6, 0)
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	s.radial_segments = 6
	s.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.lightened(0.4), 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color * 0.5
	s.material = mat
	p.mesh = s
	add_child(p)
	p.global_position = m.global_position + Vector3.UP * 0.3
	p.emitting = true
	p.finished.connect(p.queue_free)


# ------------------------------------------------------------ Building

func _island() -> void:
	var body := StaticBody3D.new()
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.bounce = 0.1
	body.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = -1.0
	body.add_child(shape)
	add_child(body)
	var b := MeshBatch.new()
	b.cyl(RADIUS, RADIUS - 0.3, 0.4, Vector3(0, -0.2, 0), Color(0.36, 0.66, 0.3), 40)
	b.cyl(RADIUS - 0.3, RADIUS - 2.0, 1.8, Vector3(0, -1.3, 0), Color(0.55, 0.38, 0.24), 40)
	var rock := Color(0.48, 0.44, 0.42)
	b.cyl(RADIUS - 2.0, RADIUS * 0.55, 5.0, Vector3(0, -4.7, 0), rock, 11)
	b.cyl(RADIUS * 0.55, 3.0, 9.0, Vector3(0, -11.7, 0), rock.darkened(0.15), 9)
	# Palms and flower beds round the outside of the building.
	for k in 14:
		var a := TAU * k / 14.0 + 0.2
		var at := Vector3(cos(a) * (RADIUS - 3.0), 0, sin(a) * (RADIUS - 3.0))
		if absf(at.x) < HALF.x + 1.5 and absf(at.z) < HALF.y + 1.5:
			continue
		if at.x < HALF.x + 2.0 or absf(at.z) < 5.0:
			continue   # only on the front lawn (the mountain is round the rest), off the path
		_palm(b, at)
	add_child(b.make())


func _palm(b: MeshBatch, at: Vector3) -> void:
	var p := at
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	for k in 6:
		var step := Vector3.UP * 0.8 + lean * k * 0.05
		b.beam(p, p + step, 0.22 - k * 0.02, Color(0.58, 0.42, 0.26))
		p += step
	for k in 7:
		var a := TAU * k / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var leaf := BoxMesh.new()
		leaf.size = Vector3(0.5, 0.05, 2.0)
		b.shape(leaf, Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -0.45), p + dir * 0.9 + Vector3.DOWN * 0.35, Color(0.27, 0.62, 0.3))


## Walls, roof and the inside decoration (wood panels, a stripy seventies
## band, wall lamps), with collision so marbles stay in and the camera
## stays under the roof.
func _building() -> void:
	var outside := Jungle.ROCK.darkened(0.15)   # mostly hidden in the mountain
	var b := MeshBatch.new()
	var solid := []
	var t := 0.5
	# North and south walls.
	for side in [-1.0, 1.0]:
		var z: float = side * HALF.y
		b.box(Vector3(HALF.x * 2 + t, HEIGHT, t), Vector3(0, HEIGHT / 2.0, z), outside)
		solid.append([Vector3(HALF.x * 2 + t, HEIGHT, t), Vector3(0, HEIGHT / 2.0, z)])
	# West wall, and the east wall with the doorway.
	b.box(Vector3(t, HEIGHT, HALF.y * 2), Vector3(-HALF.x, HEIGHT / 2.0, 0), outside)
	solid.append([Vector3(t, HEIGHT, HALF.y * 2), Vector3(-HALF.x, HEIGHT / 2.0, 0)])
	var seg := HALF.y - DOOR_HALF
	for side in [-1.0, 1.0]:
		var z: float = side * (DOOR_HALF + seg / 2.0)
		b.box(Vector3(t, HEIGHT, seg), Vector3(HALF.x, HEIGHT / 2.0, z), outside)
		solid.append([Vector3(t, HEIGHT, seg), Vector3(HALF.x, HEIGHT / 2.0, z)])
	b.box(Vector3(t, HEIGHT - DOOR_H, DOOR_HALF * 2), Vector3(HALF.x, (HEIGHT + DOOR_H) / 2.0, 0), outside)
	# Roof (a lip all round) and the dark ceiling inside.
	b.box(Vector3(HALF.x * 2 + 1.6, 0.6, HALF.y * 2 + 1.6), Vector3(0, HEIGHT + 0.3, 0), outside.darkened(0.1))
	solid.append([Vector3(HALF.x * 2 + 1.6, 0.6, HALF.y * 2 + 1.6), Vector3(0, HEIGHT + 0.3, 0)])
	b.box(Vector3(HALF.x * 2 - 0.2, 0.1, HALF.y * 2 - 0.2), Vector3(0, HEIGHT - 0.05, 0), Color(0.1, 0.06, 0.14))
	# Inside walls: wood panelling low down, plum above, stripes between.
	var inner := t / 2.0 + 0.03
	var walls := [
		[Vector3(0, 0, -HALF.y + inner), Vector3(HALF.x * 2 - 0.6, 0, 0.06)],
		[Vector3(0, 0, HALF.y - inner), Vector3(HALF.x * 2 - 0.6, 0, 0.06)],
		[Vector3(-HALF.x + inner, 0, 0), Vector3(0.06, 0, HALF.y * 2 - 0.6)],
	]
	for side in [-1.0, 1.0]:
		walls.append([Vector3(HALF.x - inner, 0, side * (DOOR_HALF + seg / 2.0)), Vector3(0.06, 0, seg - 0.4)])
	for w in walls:
		var at: Vector3 = w[0]
		var size: Vector3 = w[1]
		b.box(size + Vector3(0, 1.4, 0), at + Vector3(0, 0.7, 0), BROWN)
		b.box(size + Vector3(0, HEIGHT - 3.4, 0), at + Vector3(0, 3.4 + (HEIGHT - 3.4) / 2.0, 0), PLUM)
		var band := [ORANGE, MUSTARD, Color(0.85, 0.35, 0.15), TEAL]
		for k in band.size():
			b.box(size + Vector3(0.02 if size.x < 1 else 0, 0.48, 0.02 if size.z < 1 else 0), at + Vector3(0, 1.64 + k * 0.48, 0), band[k])
	# Glowing wall lamps all round, like little sunbursts.
	for k in 10:
		var x := -HALF.x + 3.0 + k * (HALF.x * 2 - 6.0) / 9.0
		for z in [-HALF.y + 0.4, HALF.y - 0.4]:
			b.glow_box(Vector3(0.7, 0.35, 0.12), Vector3(x, 4.6, z), Color(1.0, 0.75, 0.4))
	add_child(b.make(2.0))
	var body := StaticBody3D.new()
	body.name = "CasinoWalls"
	add_child(body)
	for s in solid:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = s[0]
		shape.shape = box
		shape.position = s[1]
		body.add_child(shape)
	# Neon signs over each corner of the room.
	_neon(Vector3(TABLE_POS.x, 5.6, -HALF.y + 0.5), "BLACKJACK", NEON[0], 0.0)
	_neon(Vector3(BAR_PLATE.x, 5.6, -HALF.y + 0.5), "THE BAR", NEON[1], 0.0)
	_neon(Vector3(-HALF.x + 0.5, 5.6, DERBY_POS.z - 9.0), "BALL DERBY", NEON[2], PI / 2)
	_neon(Vector3(CRATE_PLATE.x, 5.6, HALF.y - 0.5), "LOOT CRATES", NEON[3], PI)


func _neon(at: Vector3, text: String, color: Color, yaw: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = LowPoly.TITLE_FONT
	l.font_size = 120
	l.pixel_size = 0.009
	l.outline_size = 22
	l.modulate = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8)
	l.outline_modulate = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.9)
	l.shaded = false
	l.position = at
	l.rotation.y = yaw
	add_child(l)
	# Neon breathes: a slow, soft glow up and down, each sign at its own pace.
	var base := l.modulate
	var phase := _rng.randf() * TAU
	_movers.append(func(t: float, _d: float) -> void:
		var k := 0.82 + 0.18 * sin(t * 1.3 + phase)
		l.modulate = Color(base.r * k, base.g * k, base.b * k))


## The groovy carpet over the whole floor.
func _carpet() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(HALF.x * 2 - 0.4, 0.04, HALF.y * 2 - 0.4)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/groovy_carpet.gdshader")
	box.material = m
	mi.mesh = box
	mi.position.y = 0.02
	add_child(mi)


# ------------------------------------------------------------ Games

func _derby(plate: Callable, on_table: Callable) -> void:
	derby = HorseRace.new()
	derby.name = "MarbleDerby"
	derby.position = DERBY_POS
	add_child(derby)
	var b := MeshBatch.new()
	b.cyl(1.3, 1.4, 0.12, BET_PLATE + Vector3.UP * 0.06, Color(0.3, 0.22, 0.12), 24)
	for x in [-1.6, 1.6]:
		b.box(Vector3(0.18, 2.6, 0.18), BET_PLATE + Vector3(x, 1.3, -1.2), GOLD)
	for k in 6:
		b.box(Vector3(3.6 / 6.0, 0.12, 1.4), BET_PLATE + Vector3(-1.5 + k * 0.6, 2.65, -0.7),
				Color(0.9, 0.25, 0.25) if k % 2 == 0 else Color.WHITE)
	add_child(b.make())
	plate.call(BET_PLATE, GOLD, func(p): on_table.call(p, "derby"), Vector3.BACK)
	LowPoly.label(self, BET_PLATE + Vector3(0, 3.45, -1.2), "PLACE BETS", 54, Color(0.5, 0.3, 0.05))
	# The bookie, in shades of course.
	_dealer(BET_PLATE + Vector3(-2.6, 0, -1.4), 0.6, Color(0.95, 0.75, 0.3))


func _blackjack(plate: Callable, on_table: Callable) -> void:
	blackjack = Blackjack.new()
	blackjack.name = "Blackjack"
	blackjack.position = TABLE_POS
	add_child(blackjack)
	var b := MeshBatch.new()
	# A half-moon table: felt top, padded rail, a pedestal.
	b.cyl(2.5, 2.5, 0.12, TABLE_POS + Vector3(0, 0.96, 0.2), FELT, 28)
	b.cyl(2.75, 2.75, 0.14, TABLE_POS + Vector3(0, 0.9, 0.2), BROWN, 28)
	b.cyl(0.5, 0.8, 0.9, TABLE_POS + Vector3(0, 0.45, 0.2), BROWN.darkened(0.2), 12)
	b.box(Vector3(5.6, 1.1, 1.6), TABLE_POS + Vector3(0, 0.5, -1.9), BROWN)
	b.box(Vector3(5.6, 0.1, 1.6), TABLE_POS + Vector3(0, 1.08, -1.9), FELT.darkened(0.2))
	# Chip racks in front of the dealer.
	for k in 6:
		b.cyl(0.12, 0.12, 0.18, TABLE_POS + Vector3(-0.9 + k * 0.36, 1.18, -1.4), NEON[k % 4], 10)
	b.box(Vector3(0.5, 0.3, 0.4), TABLE_POS + Vector3(1.8, 1.25, -1.5), Color(0.2, 0.2, 0.22))
	# Gold seat plates' surrounds.
	for k in 4:
		var at := _seat(k)
		b.cyl(1.0, 1.1, 0.1, at + Vector3.UP * 0.05, Color(0.25, 0.12, 0.08), 20)
		plate.call(at, NEON[k], func(p):
			blackjack.seat_of[p] = k
			on_table.call(p, "blackjack"), ((at - TABLE_POS) * Vector3(1, 0, 1)).normalized())
	add_child(b.make())
	_dealer(TABLE_POS + Vector3(0, 0, -2.9), 0.0, Color(0.85, 0.85, 0.9))


func _seat(k: int) -> Vector3:
	var a: float = SEAT_ANGLES[k]
	return TABLE_POS + Vector3(sin(a), 0, cos(a)) * SEAT_RADIUS


func _bar(plate: Callable, on_table: Callable) -> void:
	var b := MeshBatch.new()
	var z := BAR_PLATE.z - 2.4
	# Counter with a padded front and a shiny top.
	b.box(Vector3(12.0, 1.15, 1.1), Vector3(BAR_PLATE.x, 0.58, z), BROWN)
	b.box(Vector3(12.2, 0.12, 1.3), Vector3(BAR_PLATE.x, 1.2, z), Color(0.15, 0.1, 0.1))
	for k in 12:
		b.box(Vector3(0.85, 0.9, 0.08), Vector3(BAR_PLATE.x - 5.5 + k, 0.55, z + 0.58), ORANGE if k % 2 == 0 else MUSTARD)
	b.glow_box(Vector3(12.2, 0.05, 0.05), Vector3(BAR_PLATE.x, 1.13, z + 0.66), NEON[1])
	# Stools in front.
	for k in 6:
		var at := Vector3(BAR_PLATE.x - 5.0 + k * 2.0, 0, z + 1.3)
		if absf(at.x - BAR_PLATE.x) < 1.4:
			continue
		b.cyl(0.08, 0.1, 0.8, at + Vector3(0, 0.4, 0), Color(0.8, 0.8, 0.85), 8)
		b.cyl(0.38, 0.35, 0.16, at + Vector3(0, 0.85, 0), Color(0.85, 0.2, 0.25), 12)
	# Shelves of glowing bottles on the back wall.
	var back := -HALF.y + 0.6
	for row in 3:
		b.box(Vector3(10.0, 0.08, 0.5), Vector3(BAR_PLATE.x, 1.6 + row * 0.9, back), Color(0.3, 0.2, 0.15))
		for k in 16:
			var col: Color = [Color(0.4, 0.9, 0.5), Color(0.9, 0.5, 0.2), Color(0.5, 0.6, 1.0), Color(1.0, 0.4, 0.6), Color(1.0, 0.9, 0.5)][(k + row) % 5]
			var h := _rng.randf_range(0.4, 0.6)
			b.cyl(0.08, 0.1, h, Vector3(BAR_PLATE.x - 4.6 + k * 0.6, 1.64 + row * 0.9 + h / 2.0, back), col, 6, true)
	b.glow_box(Vector3(10.2, 3.0, 0.05), Vector3(BAR_PLATE.x, 2.7, back - 0.3), Color(0.25, 0.12, 0.3))
	b.cyl(1.0, 1.1, 0.1, BAR_PLATE + Vector3.UP * 0.05, Color(0.25, 0.12, 0.08), 20)
	add_child(b.make(1.6))
	plate.call(BAR_PLATE, NEON[1], func(p): on_table.call(p, "bar"), Vector3.BACK)
	_dealer(Vector3(BAR_PLATE.x, 0, z - 1.4), 0.0, Color(0.95, 0.95, 0.95), true)


func _crates(plate: Callable, on_crates: Callable) -> void:
	var b := MeshBatch.new()
	b.cyl(1.3, 1.4, 0.12, CRATE_PLATE + Vector3.UP * 0.06, Color(0.3, 0.2, 0.12), 24)
	# The crate machine: a cabinet with a glowing window and a big crate on top.
	var m := CRATE_PLATE + Vector3(0, 0, 3.2)
	b.box(Vector3(3.0, 2.4, 1.6), m + Vector3(0, 1.2, 0), Color(0.2, 0.15, 0.35))
	b.glow_box(Vector3(2.2, 1.2, 0.05), m + Vector3(0, 1.5, -0.81), Color(0.4, 0.2, 0.7))
	b.box(Vector3(3.2, 0.2, 1.8), m + Vector3(0, 2.5, 0), GOLD)
	for x in [-1.55, 1.55]:
		b.glow_box(Vector3(0.1, 2.4, 0.1), m + Vector3(x, 1.2, -0.82), NEON[3])
	add_child(b.make(2.2))
	# The machine is solid (you used to be able to roll right into it).
	var body := StaticBody3D.new()
	body.name = "CrateMachine"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.6, 1.8)
	shape.shape = box
	body.position = m + Vector3(0, 1.3, 0)
	body.add_child(shape)
	add_child(body)
	var crate := ItemIcons.crate_model()
	crate.position = m + Vector3(0, 3.1, 0)
	crate.scale = Vector3.ONE * 1.3
	add_child(crate)
	_movers.append(func(t: float, _d: float):
		crate.rotation.y = sin(t * 0.7) * 0.5
		crate.position.y = 3.1 + sin(t * 1.8) * 0.12)
	# Roll off away from the machine, back toward the room.
	plate.call(CRATE_PLATE, Color(1.0, 0.6, 0.2), func(p): on_crates.call(p), Vector3(-0.6, 0, -0.8))
	LowPoly.label(self, m + Vector3(0, 1.5, -0.86), "%d COINS" % LootCrates.PRICE, 48, Color(0.2, 0.05, 0.3), PI)


# ------------------------------------------------------------ Atmosphere

## A roulette table with a spinning wheel and its own croupier.
func _roulette() -> void:
	var b := MeshBatch.new()
	var at := ROULETTE_POS
	b.box(Vector3(5.0, 1.0, 2.6), at + Vector3(0, 0.5, 0), BROWN)
	b.box(Vector3(4.8, 0.06, 2.4), at + Vector3(0, 1.03, 0), FELT)
	for k in 12:
		for r in 3:
			b.box(Vector3(0.24, 0.02, 0.3), at + Vector3(-0.2 + k * 0.26, 1.07, -0.5 + r * 0.33),
					Color(0.8, 0.12, 0.15) if (k + r) % 2 == 0 else Color(0.08, 0.08, 0.1))
	add_child(b.make())
	var wheel := Node3D.new()
	wheel.position = at + Vector3(-1.5, 1.12, 0)
	add_child(wheel)
	LowPoly.cyl(wheel, 0.85, 0.9, 0.12, Vector3.ZERO, BROWN.darkened(0.2), 24)
	for k in 18:
		var a := TAU * k / 18.0
		LowPoly.box(wheel, Vector3(0.28, 0.03, 0.14), Vector3(cos(a), 0.07, sin(a)) * 0.6,
				Color(0.8, 0.12, 0.15) if k % 2 == 0 else Color(0.08, 0.08, 0.1), -a)
	LowPoly.cyl(wheel, 0.15, 0.2, 0.2, Vector3(0, 0.12, 0), GOLD, 8)
	var ball := LowPoly.ball(self, Vector3.ZERO, 0.05, Color.WHITE, 6)
	_movers.append(func(t: float, d: float):
		wheel.rotate_y(d * 1.4)
		var a := -t * 3.1
		ball.position = wheel.position + Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75))
	_dealer(at + Vector3(0, 0, -2.0), 0.0, Color(0.95, 0.6, 0.7))


## A light-up dance floor under a spinning mirror ball.
func _dance_floor() -> void:
	var tiles: Array = []
	for x in 5:
		for z in 4:
			var tile := LowPoly.box(self, Vector3(1.1, 0.06, 1.1), DANCE_POS + Vector3((x - 2) * 1.15, 0.05, (z - 1.5) * 1.15), Color.WHITE)
			var m := LowPoly.own_mat(tile)
			m.emission_enabled = true
			tiles.append([m, x, z])
	var ball := Node3D.new()
	ball.position = DANCE_POS + Vector3(0, HEIGHT - 1.4, 0)
	add_child(ball)
	LowPoly.cyl(self, 0.02, 0.02, 1.0, DANCE_POS + Vector3(0, HEIGHT - 0.5, 0), Color(0.7, 0.7, 0.75), 4)
	var mirror := LowPoly.ball(ball, Vector3.ZERO, 0.6, Color(0.85, 0.88, 0.95), 12)
	var mm := LowPoly.own_mat(mirror)
	mm.metallic = 1.0
	mm.roughness = 0.15
	mm.emission_enabled = true
	mm.emission = Color(0.3, 0.3, 0.4)
	# Coloured spots sweeping the room from the ball.
	var spots: Array = []
	for k in 3:
		var l := OmniLight3D.new()
		l.light_color = NEON[k]
		l.light_energy = 3.0
		l.omni_range = 7.0
		add_child(l)
		spots.append(l)
	_movers.append(func(t: float, d: float):
		ball.rotate_y(d * 0.8)
		for i in spots.size():
			var a := t * 0.7 + TAU * i / 3.0
			(spots[i] as OmniLight3D).position = DANCE_POS + Vector3(cos(a) * 3.5, 1.6, sin(a) * 3.5)
		for tl in tiles:
			var k := int(t * 2.0 + tl[1] * 0.7 + tl[2] * 1.3) % NEON.size()
			(tl[0] as StandardMaterial3D).albedo_color = NEON[k]
			(tl[0] as StandardMaterial3D).emission = NEON[k] * 0.9)


## A row of slot machines along the south wall, reels flickering.
func _slots() -> void:
	var b := MeshBatch.new()
	var screens: Array = []
	for k in 7:
		var at := Vector3(-3.0 + k * 1.7, 0, HALF.y - 1.2)
		var col: Color = [Color(0.85, 0.2, 0.25), Color(0.2, 0.45, 0.85), Color(0.95, 0.65, 0.2)][k % 3]
		b.box(Vector3(1.2, 1.9, 0.9), at + Vector3(0, 0.95, 0), col)
		b.box(Vector3(1.25, 0.5, 1.0), at + Vector3(0, 2.15, 0), col.darkened(0.3))
		b.box(Vector3(1.0, 0.2, 0.4), at + Vector3(0, 0.9, -0.55), Color(0.15, 0.15, 0.18))
		b.beam(at + Vector3(0.68, 1.2, 0), at + Vector3(0.68, 1.9, 0), 0.06, Color(0.8, 0.8, 0.85))
		b.ball(at + Vector3(0.68, 1.95, 0), 0.1, Color(0.9, 0.15, 0.2), 6)
		b.glow_box(Vector3(1.0, 0.3, 0.05), at + Vector3(0, 2.15, -0.51), GOLD)
		var screen := LowPoly.box(self, Vector3(0.9, 0.5, 0.05), at + Vector3(0, 1.45, -0.46), Color.WHITE)
		var sm := LowPoly.own_mat(screen)
		sm.emission_enabled = true
		screens.append(sm)
		# A little stool in front of each.
		b.cyl(0.3, 0.3, 0.12, at + Vector3(0, 0.7, -1.3), Color(0.85, 0.2, 0.25), 10)
		b.cyl(0.06, 0.08, 0.65, at + Vector3(0, 0.33, -1.3), Color(0.8, 0.8, 0.85), 6)
	add_child(b.make(2.0))
	_movers.append(func(t: float, _d: float):
		for i in screens.size():
			var k := int(t * (4.0 + i) + i * 3.0) % NEON.size()
			(screens[i] as StandardMaterial3D).emission = NEON[k] * 1.2)


## Round booths, potted plants and bubbling lava lamps.
func _lounge() -> void:
	var b := MeshBatch.new()
	var lamps: Array = []
	for at in [Vector3(15, 0, 0.0), Vector3(-3, 0, -13.5), Vector3(-19.5, 0, -13.5), Vector3(19.5, 0, 14.0)]:
		b.cyl(1.6, 1.6, 0.6, at + Vector3(0, 0.3, 0), ORANGE.darkened(0.1), 16)
		b.cyl(0.7, 0.7, 0.8, at + Vector3(0, 0.4, 0), BROWN, 12)
		b.cyl(0.8, 0.8, 0.06, at + Vector3(0, 0.82, 0), Color(0.95, 0.9, 0.8), 12)
		var lamp: Vector3 = at + Vector3(0, 0.85, 0)
		b.cyl(0.12, 0.18, 0.25, lamp + Vector3(0, 0.12, 0), GOLD, 8)
		b.cyl(0.18, 0.12, 0.5, lamp + Vector3(0, 0.5, 0), Color(1.0, 0.4, 0.3), 8, true)
		b.cyl(0.0, 0.12, 0.15, lamp + Vector3(0, 0.82, 0), GOLD, 8)
		lamps.append(lamp)
	for at in [Vector3(HALF.x - 1.2, 0, DOOR_HALF + 1.2), Vector3(HALF.x - 1.2, 0, -DOOR_HALF - 1.2), Vector3(-HALF.x + 1.2, 0, HALF.y - 1.2)]:
		b.cyl(0.4, 0.3, 0.7, at + Vector3(0, 0.35, 0), TEAL, 10)
		for k in 6:
			var a := TAU * k / 6.0
			b.ball(at + Vector3(cos(a) * 0.35, 1.2 + k * 0.05, sin(a) * 0.35), 0.4, Color(0.25, 0.6, 0.3), 6)
	add_child(b.make(2.2))
	# Blobs drifting up and down inside the lava lamps.
	for lamp in lamps:
		for k in 2:
			var blob := LowPoly.ball(self, lamp, 0.07, Color(1.0, 0.85, 0.3), 6)
			var bm := LowPoly.own_mat(blob)
			bm.emission_enabled = true
			bm.emission = Color(1.0, 0.7, 0.2)
			bm.emission_energy_multiplier = 2.0
			var phase := _rng.randf() * TAU
			var base: Vector3 = lamp
			_movers.append(func(t: float, _d: float):
				blob.position = base + Vector3(0, 0.5 + sin(t * 0.6 + phase) * 0.17, 0))


func _lights() -> void:
	for at in [Vector3(-14, 6, -6), Vector3(-14, 6, 8), Vector3(TABLE_POS.x, 5.5, TABLE_POS.z),
			Vector3(BAR_PLATE.x, 5.0, BAR_PLATE.z - 1), Vector3(CRATE_PLATE.x, 5.0, CRATE_PLATE.z + 1),
			Vector3(ROULETTE_POS.x, 5.5, ROULETTE_POS.z)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.55)
		l.light_energy = 1.8
		l.omni_range = 12.0
		l.position = at
		add_child(l)


## Soft party lights: a ring of coloured bulbs round the top of the room
## that glow up and down in slow waves, and four coloured lights that wash the
## room in pink, blue, gold and green, gently fading in and out.
func _party_lights() -> void:
	var mats: Array = []
	for c in NEON:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mats.append(m)
	var bulb := SphereMesh.new()
	bulb.radius = 0.1
	bulb.height = 0.2
	bulb.radial_segments = 8
	bulb.rings = 4
	# Just under the ceiling, a hand's width off each wall (inside the room).
	var y := HEIGHT - 0.35
	var inset := 0.55
	var spots: Array = []
	var x := -HALF.x + 1.0
	while x <= HALF.x - 1.0:
		spots.append(Vector3(x, y, -HALF.y + inset))
		spots.append(Vector3(x, y, HALF.y - inset))
		x += 1.2
	var z := -HALF.y + 1.6
	while z <= HALF.y - 1.6:
		spots.append(Vector3(-HALF.x + inset, y, z))
		if absf(z) > DOOR_HALF + 0.4:
			spots.append(Vector3(HALF.x - inset, y, z))
		z += 1.2
	for i in spots.size():
		var mi := MeshInstance3D.new()
		mi.mesh = bulb
		mi.material_override = mats[i % mats.size()]
		mi.position = spots[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var washes: Array = []
	var corners := [Vector3(-12, 6.2, -10), Vector3(12, 6.2, -10), Vector3(12, 6.2, 10), Vector3(-12, 6.2, 10)]
	for k in corners.size():
		var l := OmniLight3D.new()
		l.light_color = NEON[k]
		l.light_energy = 0.6
		l.omni_range = 14.0
		l.position = corners[k]
		add_child(l)
		washes.append(l)
	# Each colour fades in and out on a slow wave (about 3 seconds round),
	# a quarter of a wave after the one before, so the glow drifts round.
	_movers.append(func(t: float, _d: float) -> void:
		for k in mats.size():
			var w := 0.5 + 0.5 * sin(t * 2.0 - k * PI / 2.0)
			(mats[k] as StandardMaterial3D).emission_energy_multiplier = 0.5 + 2.5 * w
			(washes[k] as OmniLight3D).light_energy = 0.25 + 0.7 * w)


## The front: red carpet, rope posts, and a big marquee sign with chasing
## bulbs over the door.
func _front() -> void:
	var b := MeshBatch.new()
	var x0 := HALF.x
	b.box(Vector3(RADIUS - x0 - 0.5, 0.04, DOOR_HALF * 2 - 0.6), Vector3((x0 + RADIUS) / 2.0, 0.02, 0), Color(0.75, 0.1, 0.15))
	for side in [-1.0, 1.0]:
		for k in 4:
			var at := Vector3(x0 + 1.5 + k * 1.8, 0, side * (DOOR_HALF - 0.1))
			b.cyl(0.06, 0.1, 1.0, at + Vector3(0, 0.5, 0), GOLD, 8)
			b.ball(at + Vector3(0, 1.05, 0), 0.1, GOLD, 6)
			if k < 3:
				b.beam(at + Vector3(0, 0.85, 0), at + Vector3(1.8, 0.85, 0), 0.07, Color(0.7, 0.1, 0.2))
		# Pillars either side of the door.
		b.cyl(0.45, 0.5, DOOR_H + 0.6, Vector3(x0 + 0.5, (DOOR_H + 0.6) / 2.0, side * (DOOR_HALF + 0.5)), GOLD, 12)
	# Awning over the door.
	b.box(Vector3(3.0, 0.3, DOOR_HALF * 2 + 2.0), Vector3(x0 + 1.5, DOOR_H + 0.4, 0), Color(0.7, 0.1, 0.25))
	# Sign board on the roof facing the bridge, hung on the front of the
	# roof's edge (which sticks out 0.8 past the wall) so the roof doesn't
	# hide the bottom of the words.
	b.box(Vector3(0.4, 3.4, 15.0), Vector3(x0 + 1.0, HEIGHT + 2.0, 0), Color(0.15, 0.08, 0.2))
	b.box(Vector3(0.5, 0.25, 15.4), Vector3(x0 + 1.0, HEIGHT + 3.75, 0), GOLD)
	b.box(Vector3(0.5, 0.25, 15.4), Vector3(x0 + 1.0, HEIGHT + 0.25, 0), GOLD)
	add_child(b.make())
	var sign := Label3D.new()
	sign.text = "THE GROOVY\nGUTTER"
	sign.font = LowPoly.TITLE_FONT
	sign.font_size = 150
	sign.pixel_size = 0.011
	sign.line_spacing = -30
	sign.outline_size = 26
	sign.modulate = Color(1.9, 1.3, 0.6)
	sign.outline_modulate = Color(0.6, 0.1, 0.4)
	sign.shaded = false
	sign.position = Vector3(x0 + 1.22, HEIGHT + 2.0, 0)
	sign.rotation.y = PI / 2
	add_child(sign)
	var casino := LowPoly.label(self, Vector3(x0 + 3.05, DOOR_H + 0.4, 0), "CASINO", 64, Color(0.3, 0.0, 0.1), PI / 2)
	casino.modulate = Color(1.6, 1.4, 1.0)
	# Chasing bulbs round the sign: two sets that take turns to light.
	var mats := [StandardMaterial3D.new(), StandardMaterial3D.new()]
	for m in mats:
		m.albedo_color = Color(1.0, 0.9, 0.6)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.45)
	_bulbs = mats
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	bulb.radial_segments = 8
	bulb.rings = 4
	var k := 0
	for z in range(-7, 8):
		for y in [HEIGHT + 0.55, HEIGHT + 3.45]:
			var mi := MeshInstance3D.new()
			mi.mesh = bulb
			mi.material_override = mats[k % 2]
			mi.position = Vector3(x0 + 1.25, y, z)
			add_child(mi)
			k += 1


## The casino is built into a mountain, like the cliffs round the jungle:
## rock columns with moss and vines all round the sides and back, craggy
## mounds over the roof, and only the front (marquee, door and neon) showing,
## like an old club carved into the rock.
func _mountain() -> void:
	var b := MeshBatch.new()
	var body := StaticBody3D.new()
	body.name = "Mountain"
	add_child(body)
	# Every rock stands fully outside the walls (centre at least its own
	# radius, plus its wider foot, beyond them) so none poke into the room.
	var spots := []   # [position, radius]
	var gap := 0.35
	# Down both long sides and across the back.
	var x := -HALF.x - 1.0
	while x < HALF.x + 1.0:
		for side in [-1.0, 1.0]:
			var r := _rng.randf_range(2.2, 3.0)
			spots.append([Vector3(x, 0, side * (HALF.y + gap + r * FOOT)), r])
		x += _rng.randf_range(3.0, 4.0)
	var z := -HALF.y
	while z <= HALF.y:
		var r := _rng.randf_range(2.2, 3.0)
		spots.append([Vector3(-HALF.x - gap - r * FOOT, 0, z), r])
		z += _rng.randf_range(3.0, 4.0)
	# Either side of the front, framing the marquee.
	for side in [-1.0, 1.0]:
		for k in 3:
			var r := _rng.randf_range(2.2, 2.8)
			spots.append([Vector3(HALF.x + gap + r * FOOT + k * 0.4, 0, side * (10.8 + k * 2.6)), r])
	for spot in spots:
		var at: Vector3 = spot[0]
		var r: float = spot[1]
		var h := HEIGHT + _rng.randf_range(1.5, 9.0)
		Jungle.rock_shape(b, _rng, at + Vector3.UP * (h - 8.0) / 2.0, r, h + 8.0, Jungle.rock_tint(_rng))
		# A wide rocky foot, so it reads as a mountain and not a post.
		Jungle.rock_shape(b, _rng, at + Vector3.UP * 1.0, r * FOOT, 4.0, Jungle.rock_tint(_rng).darkened(0.08))
		b.cyl(0.0, r * 0.55, 1.0, at + Vector3.UP * (h + 0.3), Jungle.MOSS.darkened(_rng.randf() * 0.25), 6)
		b.ball(at + Vector3(_rng.randf_range(-0.8, 0.8), h + 0.5, _rng.randf_range(-0.8, 0.8)), _rng.randf_range(1.0, 1.6),
				Jungle.LEAF.lerp(Jungle.MOSS, _rng.randf()), 7, Vector3(1, 0.7, 1))
		# Vines down the outside face.
		var out := Vector3(signf(at.x) if absf(at.x) > HALF.x else 0.0, 0, signf(at.z) if absf(at.z) > HALF.y else 0.0).normalized()
		for k in _rng.randi_range(1, 2):
			var top := at + out * r * 0.7 + Vector3(_rng.randf_range(-1, 1), h - 0.8, _rng.randf_range(-1, 1)) * Vector3(1, 1, 1)
			var len := _rng.randf_range(3.0, h * 0.7)
			b.beam(top, top + Vector3.DOWN * len, 0.07, Color(0.25, 0.45, 0.2))
			for j in int(len / 0.8):
				b.ball(top + Vector3.DOWN * (j * 0.8 + 0.4), 0.18, Jungle.LEAF.lightened(_rng.randf() * 0.3), 5)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r * 0.85
		cyl.height = h
		shape.shape = cyl
		shape.position = at + Vector3.UP * h / 2.0
		body.add_child(shape)
	# Craggy mounds over the roof, with jungle on top (the front stays clear
	# for the sign).
	for gx in range(-18, int(HALF.x) - 5, 6):
		for gz in range(-12, 13, 6):
			var r := _rng.randf_range(3.5, 5.0)
			var squash := _rng.randf_range(0.35, 0.7)
			# Sits on the roof: its underside never dips below the ceiling.
			var at := Vector3(gx + _rng.randf_range(-1.5, 1.5), HEIGHT + r * squash, gz + _rng.randf_range(-1.5, 1.5))
			b.ball(at, r, Jungle.rock_tint(_rng), 7, Vector3(1, squash, 1))
			b.ball(at + Vector3(_rng.randf_range(-1, 1), r * 0.35, _rng.randf_range(-1, 1)), r * 0.5,
					Jungle.MOSS.darkened(_rng.randf() * 0.2), 6, Vector3(1, 0.5, 1))
			if _rng.randf() < 0.5:
				b.ball(at + Vector3(0, r * 0.55, 0), _rng.randf_range(1.0, 1.6), Jungle.LEAF, 7, Vector3(1, 0.8, 1))
	# A carved frame round the front, so the marquee sits in the rock.
	for side in [-1.0, 1.0]:
		Jungle.rock_shape(b, _rng, Vector3(HALF.x + 1.4, HEIGHT / 2.0 + 1.0, side * 9.4), 1.5, HEIGHT + 4.0, Jungle.rock_tint(_rng))
	b.box(Vector3(1.2, 1.4, 18.0), Vector3(HALF.x - 0.2, HEIGHT + 4.3, 0), Jungle.ROCK.darkened(0.05))
	for k in 5:
		b.ball(Vector3(HALF.x - 0.4, HEIGHT + 5.0, -7.2 + k * 3.6), _rng.randf_range(1.1, 1.6),
				Jungle.LEAF.lerp(Jungle.MOSS, _rng.randf()), 6, Vector3(1, 0.6, 1))
	add_child(b.make())


## A dealer: a marble on a stool in a waistcoat and bow tie, with a green
## visor and very shady sunglasses. They sway a little and keep an eye on
## the nearest player.
func _dealer(at: Vector3, yaw: float, shirt: Color, bartender := false) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	add_child(root)
	var body := Node3D.new()
	body.position.y = 1.55
	root.add_child(body)
	LowPoly.cyl(root, 0.3, 0.35, 0.95, Vector3(0, 0.47, 0), Color(0.25, 0.25, 0.28), 10)
	var skin := Color(0.98, 0.82, 0.62).lerp(shirt, 0.15)
	LowPoly.ball(body, Vector3.ZERO, 0.6, skin, 16)
	# Waistcoat: a dark band round the lower half, shirt front, bow tie.
	var vest := LowPoly.cyl(body, 0.58, 0.45, 0.45, Vector3(0, -0.32, 0), Color(0.15, 0.1, 0.18) if not bartender else Color(0.55, 0.15, 0.2), 16)
	vest.scale = Vector3(1.04, 1, 1.04)
	LowPoly.box(body, Vector3(0.28, 0.4, 0.05), Vector3(0, -0.28, 0.56), shirt)
	for side in [-1.0, 1.0]:
		var bow := LowPoly.cyl(body, 0.0, 0.1, 0.18, Vector3(side * 0.09, -0.08, 0.6), Color(0.85, 0.1, 0.15), 3)
		bow.rotation.z = side * PI / 2
	LowPoly.ball(body, Vector3(0, -0.08, 0.61), 0.04, Color(0.6, 0.05, 0.1), 6)
	# The shades: two dark lenses with a shine, a bridge and arms.
	var lens := Color(0.03, 0.03, 0.05)
	for side in [-1.0, 1.0]:
		var l := LowPoly.box(body, Vector3(0.24, 0.13, 0.05), Vector3(side * 0.15, 0.14, 0.55), lens)
		l.rotation.y = side * 0.25
		var lm := LowPoly.own_mat(l)
		lm.metallic = 0.6
		lm.roughness = 0.05
		LowPoly.box(body, Vector3(0.06, 0.025, 0.01), Vector3(side * 0.15 - 0.05, 0.17, 0.585), Color(0.9, 0.9, 1.0)).rotation.z = 0.5
		var arm := LowPoly.box(body, Vector3(0.02, 0.03, 0.4), Vector3(side * 0.42, 0.16, 0.3), lens)
		arm.rotation.y = side * 0.5
	LowPoly.box(body, Vector3(0.08, 0.03, 0.03), Vector3(0, 0.17, 0.585), lens)
	# A sly little smirk.
	var smirk := LowPoly.box(body, Vector3(0.16, 0.025, 0.02), Vector3(0.05, -0.04, 0.585), Color(0.35, 0.15, 0.12))
	smirk.rotation.z = 0.25
	if bartender:
		# A curly moustache instead of a visor.
		for side in [-1.0, 1.0]:
			var tache := LowPoly.ball(body, Vector3(side * 0.08, 0.02, 0.58), 0.07, Color(0.25, 0.15, 0.1), 6)
			tache.scale = Vector3(1.3, 0.6, 0.6)
	else:
		var visor := LowPoly.cyl(body, 0.58, 0.58, 0.08, Vector3(0, 0.38, 0), Color(0.1, 0.55, 0.3), 16)
		var vm := LowPoly.own_mat(visor)
		vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		vm.albedo_color = Color(0.1, 0.65, 0.35, 0.7)
		var brim := LowPoly.box(body, Vector3(0.6, 0.03, 0.35), Vector3(0, 0.36, 0.62), Color(0.1, 0.55, 0.3))
		brim.rotation.x = 0.25
	var phase := _rng.randf() * TAU
	var base_yaw := yaw
	_movers.append(func(t: float, _d: float):
		body.position.y = 1.55 + sin(t * 1.6 + phase) * 0.03
		body.rotation.z = sin(t * 0.9 + phase) * 0.05
		# Glance toward the closest marble now and then.
		var look := base_yaw + sin(t * 0.35 + phase) * 0.35
		var near: Variant = _nearest_marble(root.global_position, 8.0)
		if near != null:
			var d: Vector3 = (near as Node3D).global_position - root.global_position
			look = atan2(d.x, d.z)
		root.rotation.y = lerp_angle(root.rotation.y, look, 0.05))


func _nearest_marble(from: Vector3, within: float) -> Variant:
	var best: Variant = null
	var best_d := within
	for m in _hub_marbles:
		if not is_instance_valid(m):
			continue
		var d: float = (m as Node3D).global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = m
	return best
