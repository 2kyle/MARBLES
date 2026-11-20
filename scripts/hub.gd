class_name Hub
extends Node3D
## The practice hub: a small floating island to mess about on before a
## match. Everything is built in code the first time it's opened.
##
## What's on it:
##   - a practice run: a winding track down from a tall start tower, with
##     a gap to hop and a drop. A pad at the bottom sends you back to the
##     top, and the PRACTICE RUN pad on the plaza takes you up too.
##   - a CUSTOMIZE pressure plate: roll onto it to open the closet
##   - the casino island over the west bridge (casino/casino_island.gd):
##     the Marble Derby, blackjack, the bar and the loot crates
##   - a trophy stand for anyone who's won the Golden Marble Trophy
##   - hurdles to practise hopping, and a few pieces to bump into
##   - a PLAY arch that starts a real match (online, rolling through it
##     marks you READY; the match starts once everyone is)
## Fall off the island and you pop back on the plaza (no penalty here).
##
## Like the match, the hub never reads the keyboard: main.gd sets each
## marble's lean and asks for hops, and listens for the signals below.

## A player rolled onto the Customize plate.
signal customize_requested(player: int)
## Someone rolled through the PLAY arch.
signal play_requested(player: int)
## A player rolled onto a casino game's plate: `kind` is "derby",
## "blackjack" or "bar".
signal table_requested(player: int, kind: String)
## A player rolled onto the Loot Crates plate.
signal crates_requested(player: int)
## A player found one of the jungle's secret gems (`id` 0..Jungle.GEM_COUNT-1).
signal secret_found(player: int, id: int, at: Vector3)

const ISLAND_RADIUS := 40.0
## Where the side islands sit round the practice island: the direction
## (degrees round from east; +90 is the plaza side) and the gap left for
## the bridge. Both are swung round towards the north so the three islands
## huddle together, and turned so their entrances face the middle of the
## practice island.
const CASINO_ANGLE := 212.0
const SPORTS_ANGLE := 328.0
const BRIDGE_GAP := 5.0
## Coins for finding a secret gem for the first time.
const SECRET_COINS := 25
const SPAWN := Vector3(0, 0.4, 12)
const PLATE_POS := Vector3(-8, 0, 8)
const LIFT_POS := Vector3(8, 0, 8)
const PORTAL_POS := Vector3(0, 0, 21)
## Where Golden Marble Trophies stand (one per player who's won one).
const TROPHY_POS := Vector3(10.8, 0, 11.2)
## The practice pieces (and their ITEMS sign), in a little yard behind the
## start tower, out of the way of the plaza: [piece, spot, extra turn].
const PLAYGROUND := [
	["bumper_post", Vector3(15.0, 0, -10.0), 0.0],
	["bumper_post", Vector3(18.0, 0, -12.0), 0.0],
	["booster_pad", Vector3(12.0, 0, -8.0), 180.0],
	["spinner", Vector3(17.0, 0, -5.5), 0.0],
	["ramp_jump", Vector3(12.0, 0, -13.0), 0.0],
]
const ITEMS_SIGN := Vector3(15.0, 0, -3.2)
const BENCHES := [[Vector3(-5, 0, 18.8), 0.0], [Vector3(5, 0, 18.8), 0.0], [Vector3(-14, 0, 11), PI / 2], [Vector3(11, 0, 23.5), -0.4]]
## Spots hub things stand on ([centre, radius]), so trees, ferns and rocks
## don't grow through them (see is_reserved()).
var reserved: Array = []
const TITLE_FONT := preload("res://fonts/ChakraPetch-Bold.ttf")
## How high a player's name tag floats over their marble.
const TAG_HEIGHT := 0.85
const FLOWER_COLORS := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.3), Color(0.7, 0.5, 1),
		Color(1, 1, 1), Color(1, 0.55, 0.25)]

var marbles: Array[Marble] = []
var built := false
## Online guests show the host's island: their marbles and the soccer ball
## are moved by the host, so nothing here bumps, triggers or scores.
var mirror := false
## Players whose marble is sitting on the Customize plate right now.
var on_plate: Array = [false, false, false, false]
## The casino island (west), and its horse race.
var casino: CasinoIsland
var derby: HorseRace
## The sports island off the east edge (soccer and basketball).
var sports: SportsIsland
## The jungle: cliff walls, ruins, mushrooms, secrets and critters.
var jungle: Jungle

## Which plate each player is parked on (its position).
var _plate_of: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## Which way each player rolls off their plate when they're done.
var _plate_out: Array = [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK]
var _plates: Array = []   # [top mesh, position]

var _course: Track
var _run_points := PackedVector3Array()
var _top: Marker3D
var _spinners: Array = []   # [node, axis, speed] things that turn forever
var _clouds: Array = []
var _bobbers: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _trophies: Array = []   # trophy nodes on the island right now
var _tags: Array = []      # per marble: the floating "P1" tag over it


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for s in _spinners:
		(s[0] as Node3D).rotate_object_local(s[1], s[2] * delta)
	for c in _clouds:
		var node: Node3D = c.node
		var a: float = c.angle + _time * c.speed
		node.position = Vector3(cos(a) * c.radius, c.y + sin(_time * 0.3 + c.angle) * 0.6, sin(a) * c.radius)
		node.rotation.y = -(a + PI / 2)  # face the way it's drifting
	for t in _trophies:
		var ball := (t as Node3D).get_node("Trophy/Ball") as Node3D
		ball.position.y = 1.14 + sin(_time * 2.0) * 0.05
		ball.rotate_y(delta)
	for b in _bobbers:
		(b.node as Node3D).position.y = b.y + sin(_time * b.speed + b.phase) * b.amount
	var cam := get_viewport().get_camera_3d()
	for i in mini(_tags.size(), marbles.size()):
		var tag: Node3D = _tags[i]
		var at := marbles[i].global_position
		# Grow with distance so the tag stays readable when the camera
		# pulls back to fit everyone in.
		var grow := clampf(cam.global_position.distance_to(at) / 9.0, 1.0, 4.0) if cam else 1.0
		tag.scale = Vector3.ONE * grow
		tag.global_position = at + Vector3.UP * (TAG_HEIGHT + 0.25 * (grow - 1.0) + sin(_time * 3.0 + i) * 0.05)
	for plate in _plates:
		var pressed := false
		for p in 4:
			if on_plate[p] and _plate_of[p] == plate[1]:
				pressed = true
		var top: MeshInstance3D = plate[0]
		top.position.y = lerpf(top.position.y, 0.03 if pressed else 0.1, 0.2)


# ------------------------------------------------------------ Start / stop

## Put a marble on the island for each player (building the island first
## if needed). `looks` holds each seat's look (people and bots).
func start(count: int, looks: Array, marble_scene: PackedScene, names: Array = []) -> void:
	if not built:
		_build()
	visible = true
	stop_marbles()
	on_plate = [false, false, false, false]
	sync_marbles(count, looks, marble_scene, names)
	sports.set_mirror(mirror)
	jungle.reset()


## Online: people came or went, or changed their look. Adds and removes
## marbles to match, without moving anyone who's already here.
func sync_marbles(count: int, looks: Array, marble_scene: PackedScene, names: Array = []) -> void:
	while marbles.size() > count:
		marbles.pop_back().queue_free()
		_tags.pop_back().queue_free()
	for p in count:
		var name_text: String = names[p] if p < names.size() and names[p] != "" else "P%d" % (p + 1)
		if p < marbles.size():
			if marbles[p].look != looks[p]:
				marbles[p].look = looks[p]
			set_tag(p, name_text, looks[p].color.color)
			continue
		var m: Marble = marble_scene.instantiate()
		m.player_id = p
		m.look = looks[p]
		# On open ground forward should be as strong as sideways.
		m.lean_forward_force = m.lean_side_force
		if mirror:
			m.freeze = true
			m.collision_layer = 0
			m.collision_mask = 0
		add_child(m)
		m.global_position = spawn_point(p)
		marbles.append(m)
		var tag := _name_tag(name_text, looks[p].color.color)
		add_child(tag)
		_tags.append(tag)


## Change the words (and colour) over a player's marble, like "Sam  READY".
func set_tag(p: int, text: String, color: Color) -> void:
	if p >= _tags.size():
		return
	var label: Label3D = _tags[p].get_child(0)
	label.text = text
	label.modulate = color.lightened(0.15)
	(_tags[p].get_child(1) as MeshInstance3D).material_override.albedo_color = color.lightened(0.15)


func stop() -> void:
	stop_marbles()
	visible = false


## The island's own sky: bright and open, with a sea of clouds below
## instead of the match's lake and hills.
func make_environment() -> Environment:
	return ArtStyle.environment(Color(0.93, 0.95, 1.0))


func stop_marbles() -> void:
	for m in marbles:
		m.queue_free()
	marbles.clear()
	for t in _tags:
		t.queue_free()
	_tags.clear()


## A floating "P1" with a little arrow pointing down at the marble, in the
## player's colour. It always faces the camera and shows through walls.
func _name_tag(text: String, color: Color) -> Node3D:
	var tag := Node3D.new()
	tag.top_level = true
	var label := Label3D.new()
	label.text = text
	label.font = TITLE_FONT
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 18
	label.modulate = color.lightened(0.15)
	label.outline_modulate = Color(0.06, 0.05, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 0.32
	tag.add_child(label)
	var arrow := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.13, 0.1, 0), Vector3(0.13, 0.1, 0), Vector3(0, -0.08, 0)]:
		st.add_vertex(v)
	arrow.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = color.lightened(0.15)
	arrow.material_override = mat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tag.add_child(arrow)
	return tag


func spawn_point(p: int) -> Vector3:
	return to_global(SPAWN + Vector3((p - 1.5) * 1.2, 0, 0))


## Called every physics tick while the hub is open.
func physics_update(delta: float) -> void:
	casino.update(delta, marbles)
	sports.update(delta)
	for m in marbles:
		if m.global_position.y < global_position.y - 8.0:
			# Back onto whichever island they fell off (the nearest one).
			var at := to_local(m.global_position)
			var flat := Vector2(at.x, at.z)
			var back := spawn_point(m.player_id)
			if flat.distance_to(Vector2(sports.position.x, sports.position.z)) < SportsIsland.RADIUS + 3.0:
				back = sports.spawn_point()
			elif flat.distance_to(Vector2(casino.position.x, casino.position.z)) < CasinoIsland.RADIUS + 3.0:
				back = casino.spawn_point()
			m.global_position = back + Vector3.UP * 1.5
			_poof(m.global_position)
			m.linear_velocity = Vector3.ZERO
			m.angular_velocity = Vector3.ZERO


## The player is done customizing: let their marble roll off the plate.
func release_from_plate(p: int) -> void:
	if p >= marbles.size():
		return
	var m := marbles[p]
	m.freeze = false
	m.preview = false
	on_plate[p] = false
	var out: Vector3 = _plate_out[p]
	m.global_position = to_global(_plate_of[p] + out * 1.8 + Vector3(0, 0.4, 0))
	m.linear_velocity = global_basis * out * 2.0


# ------------------------------------------------------------ Building

func _build() -> void:
	built = true
	_rng.seed = 4242
	_reserve()
	_island()
	_practice_run()
	jungle = Jungle.new()
	jungle.name = "Jungle"
	add_child(jungle)
	jungle.build(self)
	_customize_plate()
	_casino_island()
	_sports_island()
	_play_portal()
	_hurdles()
	_playground()
	_windmill(Vector3(-17, 0, -23))
	_pond(Vector3(17, 0, 17))
	_trees()
	_flowers()
	_signs()
	_sky_life()
	_cloud_sea()
	_lookout()
	_cottage(Vector3(20, 0, -22))
	_bunting()
	_benches()
	_balloons()
	_birds()


## Mark where the plaza things, signs, benches, pieces and posts stand,
## before anything is scattered round the island.
func _reserve() -> void:
	for p in PLAYGROUND:
		reserved.append([p[1], 2.2])
	reserved.append([ITEMS_SIGN, 1.2])
	for b in BENCHES:
		reserved.append([b[0], 1.4])
	for spot in [[PLATE_POS, 2.6], [LIFT_POS, 2.4], [PORTAL_POS, 3.4], [TROPHY_POS + Vector3(0.9, 0, 0.9), 2.4],
			[Vector3(-4.6, 0, 13.5), 1.8], [Vector3(14, 0, 1.6), 2.6], [Vector3(14, 0, 5.4), 1.0]]:
		reserved.append(spot)
	for pole in BUNTING_POLES:
		reserved.append([pole * Vector3(1, 0, 1), 0.8])


## True if `at` (on the ground) is within `r` of something reserved.
func is_reserved(at: Vector3, r: float) -> bool:
	for s in reserved:
		if Vector2(at.x - s[0].x, at.z - s[0].z).length() < s[1] + r:
			return true
	return false


func _island() -> void:
	var body := StaticBody3D.new()
	var mat := PhysicsMaterial.new()
	mat.friction = 0.7
	mat.bounce = 0.1
	body.physics_material_override = mat
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ISLAND_RADIUS
	cyl.height = 2.0
	shape.shape = cyl
	shape.position.y = -1.0
	body.add_child(shape)
	add_child(body)

	LowPoly.cyl(self, ISLAND_RADIUS, ISLAND_RADIUS - 0.3, 0.4, Vector3(0, -0.2, 0), Color(0.36, 0.66, 0.3), 40)
	LowPoly.cyl(self, ISLAND_RADIUS - 0.3, ISLAND_RADIUS - 2.0, 1.8, Vector3(0, -1.3, 0), Color(0.55, 0.38, 0.24), 40)
	# Rocky underside, a few low-poly layers getting narrower.
	var rock := Color(0.48, 0.44, 0.42)
	LowPoly.cyl(self, ISLAND_RADIUS - 2.0, ISLAND_RADIUS * 0.55, 5.0, Vector3(0, -4.7, 0), rock, 11)
	LowPoly.cyl(self, ISLAND_RADIUS * 0.55, 3.0, 9.0, Vector3(0, -11.7, 0), rock.darkened(0.15), 9)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var r := ISLAND_RADIUS * _rng.randf_range(0.35, 0.6)
		var h := _rng.randf_range(3.0, 7.0)
		LowPoly.cyl(self, _rng.randf_range(1.5, 2.6), 0.3, h, Vector3(cos(a) * r, -7.2 - h / 2.0, sin(a) * r), rock.darkened(0.1), 6)
	# Hanging vines.
	for i in 24:
		var a := _rng.randf() * TAU
		var r := ISLAND_RADIUS - 1.2
		var h := _rng.randf_range(1.5, 5.0)
		LowPoly.cyl(self, 0.06, 0.04, h, Vector3(cos(a) * r, -1.6 - h / 2.0, sin(a) * r), Color(0.3, 0.55, 0.25), 4)


## The practice run: a real track (the same kind as in a match) coming
## down from a tower, with a gap to hop.
func _practice_run() -> void:
	var gap := [{"len": 3.0, "turn": 0.0, "grade": 0.3}, TrackGen.gap(), {"len": 3.0, "turn": 0.0, "grade": 0.25}]
	var layout: Array = [TrackGen.START.duplicate(), TrackGen.bend(120.0, 0.22)] + gap \
			+ [TrackGen.bend(120.0, 0.22), TrackGen.drop(), {"len": 4.0, "turn": 0.0, "grade": 0.25}]
	_course = Track.new()
	_course.name = "PracticeRun"
	_course.support_bottom_y = -0.3
	_course.floor_color = Color(0.86, 0.66, 0.42)
	_course.wall_color = Color(0.36, 0.62, 0.86)
	var path := Path3D.new()
	path.name = "Path"
	_course.add_child(path)
	add_child(_course)
	# A tower behind the plaza; the run curls round and ends on the plaza.
	_course.apply_layout(layout, Vector2(8.0, -3.0))
	_run_points = TrackGen.points(layout, Vector2(8.0, -3.0))

	# Top of the run: where the lift and the loop pad drop you.
	var start := _course.frame_at(1.2)
	_top = Marker3D.new()
	_top.transform = start
	_course.add_child(_top)
	_start_tower(start)
	var top_pad: Node3D = load("res://scenes/pieces/teleporter.tscn").instantiate()
	top_pad.is_exit = true
	top_pad.transform = _course.frame_at(1.8).scaled_local(Vector3.ONE * 1.3)
	_course.add_child(top_pad)

	# Bottom: a pad past the end that sends you back to the top.
	var end := _course.end_transform()
	var bottom_pad: Node3D = load("res://scenes/pieces/teleporter.tscn").instantiate()
	bottom_pad.reusable = true
	bottom_pad.partner = _top
	# Big, so a marble flying off the end can't miss it.
	bottom_pad.transform = Transform3D(end.basis, end.origin - end.basis.z * 3.2 + Vector3.UP * 0.02) \
			.scaled_local(Vector3.ONE * 3.0)
	_course.add_child(bottom_pad)

	# The lift on the plaza.
	var lift: Node3D = load("res://scenes/pieces/teleporter.tscn").instantiate()
	lift.reusable = true
	lift.partner = _top
	lift.position = LIFT_POS + Vector3.UP * 0.01
	lift.scale = Vector3.ONE * 1.6
	add_child(lift)


## A little stone tower with a flag behind the top of the run.
func _start_tower(start: Transform3D) -> void:
	var back := start.basis.z
	back.y = 0.0
	back = back.normalized()
	var at := Vector3(start.origin.x, 0, start.origin.z) + back * 2.2
	var h := start.origin.y - 0.25
	var stone := Color(0.78, 0.74, 0.68)
	LowPoly.cyl(self, 1.9, 2.3, h, at + Vector3.UP * h / 2.0, stone, 10)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.2
	cyl.height = h
	shape.shape = cyl
	body.position = at + Vector3.UP * h / 2.0
	body.add_child(shape)
	add_child(body)
	# Stripes of darker stone and little windows going up.
	for k in int(h / 3.0):
		LowPoly.cyl(self, 1.95 + 0.03 * k, 1.95 + 0.03 * k, 0.25, at + Vector3.UP * (2.0 + k * 3.0), stone.darkened(0.15), 10)
		var a := k * 1.3
		LowPoly.box(self, Vector3(0.45, 0.7, 0.1), at + Vector3(sin(a), 0, cos(a)) * 2.1 + Vector3.UP * (1.2 + k * 3.0 + 1.3),
				Color(0.25, 0.2, 0.3), a)
	# Battlements round the top.
	for k in 10:
		var a := TAU * k / 10.0
		LowPoly.box(self, Vector3(0.5, 0.5, 0.35), at + Vector3(sin(a), 0, cos(a)) * 1.75 + Vector3.UP * (h + 0.25),
				stone.lightened(0.1), a)
	# A flag that flaps (spins gently on its pole).
	LowPoly.cyl(self, 0.05, 0.05, 2.6, at + Vector3.UP * (h + 1.3), Color(0.4, 0.3, 0.2), 6)
	var flag := Node3D.new()
	flag.position = at + Vector3.UP * (h + 2.2)
	add_child(flag)
	LowPoly.box(flag, Vector3(1.1, 0.6, 0.04), Vector3(0.6, 0, 0), Color(0.95, 0.35, 0.3), 0.0)
	_bobbers.append({"node": flag, "y": flag.position.y, "speed": 2.0, "phase": 0.0, "amount": 0.05})
	_spinners.append([flag, Vector3.UP, 0.4])
	LowPoly.label(self, Vector3(start.origin.x, start.origin.y + 2.4, start.origin.z) + back * 0.3, "START", 72,
			Color(0.1, 0.3, 0.5), 0.0, true)


func _customize_plate() -> void:
	# A round pressure plate under a little wardrobe arch with a mirror.
	LowPoly.cyl(self, 1.3, 1.4, 0.12, PLATE_POS + Vector3.UP * 0.06, Color(0.25, 0.22, 0.3), 24)
	_pressure_plate(PLATE_POS, Color(0.85, 0.35, 0.9), func(p): customize_requested.emit(p))
	var frame_col := Color(0.95, 0.9, 0.85)
	LowPoly.box(self, Vector3(0.25, 3.0, 0.25), PLATE_POS + Vector3(-1.8, 1.5, -0.6), frame_col, 0.0)
	LowPoly.box(self, Vector3(0.25, 3.0, 0.25), PLATE_POS + Vector3(1.8, 1.5, -0.6), frame_col, 0.0)
	LowPoly.box(self, Vector3(3.9, 0.5, 0.3), PLATE_POS + Vector3(0, 3.1, -0.6), Color(0.85, 0.35, 0.9), 0.0)
	var mirror := LowPoly.box(self, Vector3(1.2, 1.8, 0.06), PLATE_POS + Vector3(0, 1.3, -1.4), Color(0.75, 0.88, 0.95), 0.0)
	var mm := LowPoly.own_mat(mirror)
	mm.metallic = 1.0
	mm.roughness = 0.05
	LowPoly.box(self, Vector3(1.4, 2.0, 0.05), PLATE_POS + Vector3(0, 1.3, -1.44), frame_col, 0.0)
	LowPoly.label(self, PLATE_POS + Vector3(0, 3.1, -0.42), "CUSTOMIZE", 64, Color(0.4, 0.1, 0.45))



## Put a Golden Marble Trophy on the island for each player who owns one.
func refresh_trophies(profiles: Profiles, count: int) -> void:
	for t in _trophies:
		t.queue_free()
	_trophies.clear()
	var owners := []
	for p in count:
		if profiles.has_trophy(p):
			owners.append(p)
	for i in owners.size():
		var p: int = owners[i]
		var col: Color = Cosmetics.find("color", profiles.equipped(p, "color")).color
		var holder := Node3D.new()
		holder.position = TROPHY_POS + Vector3((i % 2) * 1.8, 0, floori(i / 2.0) * 1.8)
		holder.add_child(ItemIcons.trophy_model(col, "P%d" % (p + 1)))
		holder.scale = Vector3.ONE * 1.2
		add_child(holder)
		_trophies.append(holder)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.8, 0.35)
		glow.light_energy = 0.8
		glow.omni_range = 3.0
		glow.position = Vector3(0, 1.4, 0.4)
		holder.add_child(glow)


## A round plate that sinks when a marble rolls on. The marble is parked
## on it and `on_enter(player)` is called. `out` is the way the marble
## rolls off again afterwards (in the island's space).
func _pressure_plate(at: Vector3, color: Color, on_enter: Callable, out := Vector3.BACK) -> void:
	var top := LowPoly.cyl(self, 1.0, 1.05, 0.12, at + Vector3.UP * 0.1, color, 24)
	var mat := LowPoly.own_mat(top)
	mat.emission_enabled = true
	mat.emission = color.darkened(0.4)
	_plates.append([top, at])
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 0.8
	shape.shape = cyl
	shape.position = at + Vector3.UP * 0.4
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body):
		if body is Marble and marbles.has(body) and not on_plate[body.player_id]:
			on_plate[body.player_id] = true
			_plate_of[body.player_id] = at
			_plate_out[body.player_id] = out
			_hold_on_plate.call_deferred(body)
			on_enter.call(body.player_id))


func _hold_on_plate(m: Marble) -> void:
	# Park the marble in the middle of the plate, spinning like a display.
	var spots := [Vector3(-0.35, 0, -0.35), Vector3(0.35, 0, -0.35), Vector3(-0.35, 0, 0.35), Vector3(0.35, 0, 0.35)]
	m.global_position = to_global(_plate_of[m.player_id] + Vector3.UP * 0.5 + spots[m.player_id % 4])
	m.linear_velocity = Vector3.ZERO
	m.angular_velocity = Vector3.ZERO
	m.freeze = true
	m.preview = true


func _play_portal() -> void:
	# A big glowing arch. Roll through it to start a real match.
	var gold := Color(1.0, 0.8, 0.25)
	LowPoly.box(self, Vector3(0.5, 4.2, 0.5), PORTAL_POS + Vector3(-2.3, 2.1, 0), Color(0.95, 0.93, 0.88), 0.0)
	LowPoly.box(self, Vector3(0.5, 4.2, 0.5), PORTAL_POS + Vector3(2.3, 2.1, 0), Color(0.95, 0.93, 0.88), 0.0)
	LowPoly.box(self, Vector3(5.6, 0.9, 0.55), PORTAL_POS + Vector3(0, 4.3, 0), gold, 0.0)
	LowPoly.label(self, PORTAL_POS + Vector3(0, 4.3, -0.3), "PLAY", 110, Color(0.45, 0.25, 0.05), PI)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.1, 3.8)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.35)
	quad.material = mat
	glow.mesh = quad
	glow.position = PORTAL_POS + Vector3(0, 1.95, 0)
	add_child(glow)
	_sparkles(PORTAL_POS + Vector3(0, 2.0, 0), Vector3(2.0, 1.8, 0.2), Color(1, 0.9, 0.5), 30)

	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.6)
	shape.shape = box
	shape.position = PORTAL_POS + Vector3.UP * 1.5
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body):
		if body is Marble and marbles.has(body):
			play_requested.emit(body.player_id))


func _hurdles() -> void:
	# Three low bars in a row on the east lawn: roll forward and hop them.
	for i in 3:
		var at := Vector3(14, 0, 4 - i * 2.4)
		LowPoly.box(self, Vector3(0.12, 0.5, 0.12), at + Vector3(-1.3, 0.25, 0), Color.WHITE, 0.0)
		LowPoly.box(self, Vector3(0.12, 0.5, 0.12), at + Vector3(1.3, 0.25, 0), Color.WHITE, 0.0)
		LowPoly.box(self, Vector3(2.6, 0.08, 0.08), at + Vector3(0, 0.38, 0),
				Color(0.95, 0.3, 0.25) if i % 2 == 0 else Color.WHITE, 0.0)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.6, 0.12, 0.12)
		shape.shape = box
		body.position = at + Vector3(0, 0.38, 0)
		body.add_child(shape)
		add_child(body)


func _playground() -> void:
	# A few real pieces to bump into and try out, behind the start tower.
	for p in PLAYGROUND:
		var info := PieceCatalog.info(p[0])
		var node: Node3D = load(info.scene).instantiate()
		PieceStyle.dress(node, p[0])
		node.position = p[1]
		node.rotation.y = deg_to_rad(info.base_rotation + p[2])
		node.scale = Vector3.ONE * PieceCatalog.scale_of(p[0])
		add_child(node)


func _windmill(at: Vector3) -> void:
	LowPoly.cyl(self, 1.0, 1.5, 5.0, at + Vector3.UP * 2.5, Color(0.95, 0.9, 0.82), 8)
	LowPoly.cyl(self, 0.05, 1.7, 1.5, at + Vector3.UP * 5.75, Color(0.8, 0.3, 0.25), 8)
	LowPoly.box(self, Vector3(0.6, 1.0, 0.1), at + Vector3(0, 0.5, 1.4), Color(0.45, 0.3, 0.2), 0.0)
	var hub := Node3D.new()
	hub.position = at + Vector3(0, 5.0, 1.3)
	add_child(hub)
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.z = TAU * k / 4.0
		hub.add_child(arm)
		LowPoly.box(arm, Vector3(0.12, 3.2, 0.06), Vector3(0, 1.6, 0), Color(0.55, 0.4, 0.28), 0.0)
		LowPoly.box(arm, Vector3(0.7, 2.4, 0.03), Vector3(0.4, 1.9, 0), Color(0.97, 0.95, 0.9), 0.0)
	_spinners.append([hub, Vector3.FORWARD, 0.6])


func _pond(at: Vector3) -> void:
	# A little pond that spills over the edge as a waterfall.
	var water := LowPoly.cyl(self, 3.2, 3.2, 0.06, at + Vector3.UP * 0.02, Color(0.3, 0.65, 0.9), 24)
	var wm := LowPoly.own_mat(water)
	wm.roughness = 0.05
	wm.metallic = 0.3
	for i in 9:
		var a := TAU * i / 9.0
		_rock(at + Vector3(cos(a), 0, sin(a)) * 3.4, _rng.randf_range(0.4, 0.7))
	var dir := Vector3(at.x, 0, at.z).normalized()
	var edge := dir * (ISLAND_RADIUS + 0.2)
	var fall := CPUParticles3D.new()
	fall.amount = 120
	fall.lifetime = 2.2
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fall.emission_box_extents = Vector3(0.8, 0.1, 0.8)
	fall.direction = dir
	fall.spread = 8.0
	fall.initial_velocity_min = 1.0
	fall.initial_velocity_max = 1.6
	fall.gravity = Vector3(0, -9.0, 0)
	fall.scale_amount_min = 0.8
	fall.scale_amount_max = 1.6
	var drop := SphereMesh.new()
	drop.radius = 0.12
	drop.height = 0.24
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.75, 0.9, 1.0, 0.75)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = dm
	fall.mesh = drop
	fall.position = edge + Vector3.UP * 0.1
	add_child(fall)
	# A stream from the pond to the edge.
	var mid := (at + edge) / 2.0
	LowPoly.box(self, Vector3(1.2, 0.05, at.distance_to(edge) - 2.5), mid + Vector3.UP * 0.02,
			Color(0.3, 0.65, 0.9), atan2(dir.x, dir.z))


func _trees() -> void:
	var spots := [Vector3(-20, 0, 4), Vector3(-21, 0, -6), Vector3(-12, 0, 19), Vector3(20, 0, 6),
		Vector3(21, 0, -5), Vector3(-6, 0, 23), Vector3(7, 0, 23), Vector3(-19, 0, -14),
		Vector3(19, 0, -15), Vector3(-2, 0, 4), Vector3(12, 0, 21), Vector3(-16, 0, 21),
		Vector3(28, 0, -12), Vector3(-14, 0, 28), Vector3(14, 0, 28), Vector3(6, 0, -28),
		Vector3(-11, 0, -27), Vector3(24, 0, 19), Vector3(13, 0, -27), Vector3(29, 0, 11),
		Vector3(-24, 0, 21), Vector3(-25, 0, -18)]
	for at in spots:
		if _near_run(at, 3.5) or jungle.is_busy(at, 1.5) or is_reserved(at, 1.7):
			continue
		var h := _rng.randf_range(2.2, 3.4)
		LowPoly.cyl(self, 0.15, 0.25, h, at + Vector3.UP * h / 2.0, Color(0.45, 0.3, 0.18), 6)
		var leaf := Color(0.25, 0.55, 0.28).lerp(Color(0.5, 0.7, 0.3), _rng.randf())
		if _rng.randf() < 0.5:
			# Round tree.
			LowPoly.ball(self, at + Vector3.UP * (h + 0.6), _rng.randf_range(1.2, 1.7), leaf)
			LowPoly.ball(self, at + Vector3(0.6, h + 0.2, 0.3), 0.9, leaf.darkened(0.1))
		else:
			# Pine.
			for k in 3:
				LowPoly.cyl(self, 0.05, 1.5 - k * 0.35, 1.2, at + Vector3.UP * (h - 0.3 + k * 0.75), leaf.darkened(0.15), 7)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.25
		cyl.height = h
		shape.shape = cyl
		body.position = at + Vector3.UP * h / 2.0
		body.add_child(shape)
		add_child(body)
	# Mushrooms.
	for i in 10:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(16.0, 31.0)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		if _near_run(at, 2.5) or jungle.is_busy(at, 0.5) or is_reserved(at, 0.3):
			continue
		LowPoly.cyl(self, 0.06, 0.08, 0.3, at + Vector3.UP * 0.15, Color(0.95, 0.92, 0.85), 6)
		var cap := LowPoly.ball(self, at + Vector3.UP * 0.32, 0.2, Color(0.9, 0.2, 0.2))
		cap.scale = Vector3(1, 0.55, 1)


func _flowers() -> void:
	# Hundreds of little flowers and grass tufts, drawn with MultiMeshes
	# so they cost almost nothing.
	var flower := SphereMesh.new()
	flower.radius = 0.08
	flower.height = 0.12
	flower.radial_segments = 6
	flower.rings = 3
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	flower.material = fm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = flower
	mm.instance_count = 420
	for i in mm.instance_count:
		var cluster := i / 14
		_rng.seed = 900 + cluster
		var ca := _rng.randf() * TAU
		var cr := _rng.randf_range(5.0, ISLAND_RADIUS - 2.0)
		var color: Color = FLOWER_COLORS[cluster % FLOWER_COLORS.size()]
		_rng.seed = 5000 + i
		var p := Vector3(cos(ca) * cr, 0, sin(ca) * cr) + Vector3(_rng.randf_range(-1.2, 1.2), 0.1, _rng.randf_range(-1.2, 1.2))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_color(i, color)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var tuft := PrismMesh.new()
	tuft.size = Vector3(0.12, 0.28, 0.05)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.32, 0.6, 0.28)
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tuft.material = tm
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.mesh = tuft
	gm.instance_count = 700
	_rng.seed = 77
	for i in gm.instance_count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (ISLAND_RADIUS - 1.0)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.4))
		gm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, 0.14, sin(a) * r)))
	var gi := MultiMeshInstance3D.new()
	gi.multimesh = gm
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gi)
	_rng.seed = 4243


func _signs() -> void:
	LowPoly.label(self, LIFT_POS + Vector3(0, 2.2, 0), "PRACTICE RUN", 56, Color(0.1, 0.25, 0.5), 0.0, true)
	LowPoly.label(self, Vector3(14, 1.4, 5.4), "HOP!", 56, Color(0.5, 0.1, 0.1), 0.0, true)
	# A little wooden sign for the practice pieces' yard.
	LowPoly.box(self, Vector3(0.15, 1.8, 0.15), ITEMS_SIGN + Vector3(0, 0.9, 0), Color(0.5, 0.35, 0.22), 0.0)
	LowPoly.box(self, Vector3(2.2, 0.7, 0.12), ITEMS_SIGN + Vector3(0, 1.8, 0), Color(0.72, 0.52, 0.32), PI)
	LowPoly.label(self, ITEMS_SIGN + Vector3(0, 1.8, 0.07), "PRACTICE\nPIECES", 32, Color(0.3, 0.18, 0.08))
	# A wooden welcome sign by the spawn.
	LowPoly.box(self, Vector3(0.15, 1.6, 0.15), Vector3(-4.6, 0.8, 13.5), Color(0.5, 0.35, 0.22), 0.0)
	LowPoly.box(self, Vector3(2.8, 0.9, 0.12), Vector3(-4.6, 1.6, 13.5), Color(0.72, 0.52, 0.32), 0.0)
	LowPoly.label(self, Vector3(-4.6, 1.6, 13.57), MainMenu.TITLE + "\nTHE HUB", 40, Color(0.3, 0.18, 0.08))


func _sky_life() -> void:
	# Butterflies drifting over the island.
	var flutter := CPUParticles3D.new()
	flutter.amount = 26
	flutter.lifetime = 7.0
	flutter.preprocess = 7.0
	flutter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flutter.emission_box_extents = Vector3(18, 1.0, 18)
	flutter.direction = Vector3(1, 0.3, 0)
	flutter.spread = 180.0
	flutter.initial_velocity_min = 0.3
	flutter.initial_velocity_max = 0.9
	flutter.gravity = Vector3(0, 0.05, 0)
	flutter.angular_velocity_min = -120
	flutter.angular_velocity_max = 120
	var wing := QuadMesh.new()
	wing.size = Vector2(0.22, 0.14)
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wmat.vertex_color_use_as_albedo = true
	wmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wing.material = wmat
	flutter.mesh = wing
	var colors := Gradient.new()
	colors.set_color(0, Color(1, 0.6, 0.2))
	colors.set_color(1, Color(0.6, 0.6, 1))
	colors.add_point(0.5, Color(1, 1, 0.5))
	flutter.color_initial_ramp = colors
	flutter.position = Vector3(0, 1.4, 0)
	add_child(flutter)

	# Puffy clouds slowly circling the island, some below it.
	var clouds := CloudLayer.new()
	clouds.count = 12
	clouds.radius_min = 46.0
	clouds.radius_max = 70.0
	clouds.height_min = -18.0
	clouds.height_max = 12.0
	clouds.size_min = 1.0
	clouds.size_max = 1.6
	clouds.speed = 0.018
	add_child(clouds)

	# Little rocks floating around the island, bobbing gently.
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var r := ISLAND_RADIUS + _rng.randf_range(6.0, 11.0)
		if jungle._in_gap(rad_to_deg(a), 14.0):
			continue  # keep clear of the bridges
		var rock := Node3D.new()
		rock.position = Vector3(cos(a) * r, _rng.randf_range(-6.0, 2.0), sin(a) * r)
		add_child(rock)
		var size := _rng.randf_range(0.8, 1.8)
		LowPoly.cyl(rock, size, 0.2, size * 2.0, Vector3(0, -size, 0), Color(0.48, 0.44, 0.42), 6)
		LowPoly.cyl(rock, size, size * 0.95, 0.3, Vector3.ZERO, Color(0.36, 0.66, 0.3), 6)
		if _rng.randf() < 0.5:
			LowPoly.ball(self, Vector3(0, 0.6, 0) + rock.position, 0.5, Color(0.3, 0.6, 0.3)).reparent(rock)
		_bobbers.append({"node": rock, "y": rock.position.y, "speed": _rng.randf_range(0.4, 0.8),
				"phase": _rng.randf() * TAU, "amount": _rng.randf_range(0.3, 0.7)})

	# Glowing lanterns on posts round the plaza.
	for i in 6:
		var a := PI * (0.15 + 0.7 * i / 5.0)
		var at := Vector3(cos(a) * 15.0, 0, 10.0 + sin(a) * 6.0)
		if _near_run(at, 2.5) or is_reserved(at, 0.4):
			continue  # not on the practice run or anything else
		LowPoly.box(self, Vector3(0.1, 2.2, 0.1), at + Vector3.UP * 1.1, Color(0.2, 0.18, 0.16), 0.0)
		var bulb := LowPoly.ball(self, at + Vector3.UP * 2.3, 0.18, Color(1.0, 0.75, 0.4))
		var bm := LowPoly.own_mat(bulb)
		bm.emission_enabled = true
		bm.emission = Color(1.0, 0.7, 0.35)
		bm.emission_energy_multiplier = 3.0


# ------------------------------------------------------------ More life

## A soft sea of clouds far below the island, stretching to the horizon.
func _cloud_sea() -> void:
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.25, 0.28, 0.35)
	puff.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	mm.instance_count = 260
	_rng.seed = 31
	for i in mm.instance_count:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 260.0 + 20.0
		var size := _rng.randf_range(10.0, 26.0)
		var b := Basis.IDENTITY.scaled(Vector3(size, size * _rng.randf_range(0.3, 0.5), size * _rng.randf_range(0.8, 1.2)))
		mm.set_instance_transform(i, Transform3D(b, Vector3(cos(a) * r, -48.0 + _rng.randf_range(-4.0, 3.0), sin(a) * r)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_rng.seed = 4244


## A rope bridge off the north edge to a tiny islet with a lookout.
func _lookout() -> void:
	var islet := Vector3(0, 0, -ISLAND_RADIUS - 11.0)
	# The islet itself (you can roll on it).
	LowPoly.solid_cyl(self, 6.0, 2.0, islet + Vector3.DOWN)
	LowPoly.cyl(self, 6.0, 5.8, 0.4, islet + Vector3.DOWN * 0.2, Color(0.36, 0.66, 0.3), 16)
	LowPoly.cyl(self, 5.8, 1.0, 7.0, islet + Vector3.DOWN * 3.9, Color(0.48, 0.44, 0.42), 9)
	_bridge(Vector3(0, 0.05, -ISLAND_RADIUS + 1.0), islet + Vector3(0, 0.05, 5.5))
	# On the islet: a little lookout with a telescope, a chest and a palm.
	LowPoly.cyl(self, 1.4, 1.6, 0.3, islet + Vector3(2.5, 0.15, -2.0), Color(0.75, 0.72, 0.66), 10)
	LowPoly.cyl(self, 0.08, 0.08, 1.0, islet + Vector3(2.5, 0.8, -2.0), Color(0.3, 0.3, 0.32), 6)
	var scope := LowPoly.cyl(self, 0.09, 0.14, 0.9, islet + Vector3(2.5, 1.35, -2.2), Color(0.8, 0.65, 0.3), 10)
	scope.rotation.x = -1.2
	LowPoly.box(self, Vector3(1.0, 0.6, 0.7), islet + Vector3(-2.5, 0.3, -1.5), Color(0.55, 0.35, 0.18), 0.4)
	LowPoly.box(self, Vector3(1.05, 0.12, 0.75), islet + Vector3(-2.5, 0.66, -1.5), Color(0.95, 0.75, 0.25), 0.4)
	LowPoly.cyl(self, 0.12, 0.2, 3.5, islet + Vector3(-1.0, 1.75, -3.5), Color(0.55, 0.4, 0.25), 6)
	for k in 6:
		var leaf := LowPoly.box(self, Vector3(0.35, 0.05, 1.8), islet + Vector3(-1.0, 3.5, -3.5), Color(0.3, 0.65, 0.3), TAU * k / 6.0)
		leaf.rotate_object_local(Vector3.RIGHT, 0.35)
		leaf.translate_object_local(Vector3(0, 0, 0.8))
	LowPoly.label(self, islet + Vector3(0, 2.4, 3.6), "LOOKOUT", 48, Color(0.1, 0.3, 0.45), 0.0, true)


## A plank bridge with rope rails from `start` to `end` (on the ground).
func _bridge(start: Vector3, end: Vector3) -> void:
	var wood := Color(0.6, 0.43, 0.28)
	var length := start.distance_to(end)
	var dir := (end - start).normalized()
	var right := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	var mid := (start + end) / 2.0
	LowPoly.solid_box(self, Vector3(2.4, 0.1, length), mid + Vector3.DOWN * 0.05, yaw)
	for side in [-1.3, 1.3]:
		LowPoly.solid_box(self, Vector3(0.1, 0.5, length), mid + right * side + Vector3.UP * 0.25, yaw)
	var planks := int(length / 0.45)
	for k in planks:
		var at := start + dir * (k + 0.5) * length / planks + right * _rng.randf_range(-0.05, 0.05)
		LowPoly.box(self, Vector3(2.4, 0.08, 0.38), at, wood.lightened(_rng.randf_range(-0.1, 0.1)), yaw + _rng.randf_range(-0.03, 0.03))
	for side in [-1.3, 1.3]:
		for k in 5:
			LowPoly.box(self, Vector3(0.1, 0.7, 0.1), start + dir * k * length / 4.0 + right * side + Vector3.UP * 0.3, wood.darkened(0.2))
		LowPoly.box(self, Vector3(0.04, 0.04, length), mid + right * side + Vector3.UP * 0.5, Color(0.85, 0.75, 0.55), yaw)


## Where a side island's middle goes, `angle` degrees round, so that a
## bridge BRIDGE_GAP long reaches it.
func _island_spot(angle: float, radius: float) -> Vector3:
	var dir := Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
	return dir * (ISLAND_RADIUS + BRIDGE_GAP + radius)


## The casino island (north-west), and a bridge over to it. Its door is on
## its own +X side, so it's turned to face the practice island.
func _casino_island() -> void:
	casino = CasinoIsland.new()
	casino.name = "Casino"
	var a := deg_to_rad(CASINO_ANGLE)
	casino.position = _island_spot(CASINO_ANGLE, CasinoIsland.RADIUS)
	casino.rotation.y = PI - a
	add_child(casino)
	casino.build(_pressure_plate, func(p, kind): table_requested.emit(p, kind), func(p): crates_requested.emit(p))
	derby = casino.derby
	var dir := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-dir.z, 0, dir.x)
	_bridge(dir * (ISLAND_RADIUS - 1.0) + Vector3.UP * 0.05, casino.transform * Vector3(CasinoIsland.RADIUS - 0.8, 0.05, 0))
	# A signpost by the bridge pointing the way.
	var post := dir * (ISLAND_RADIUS - 5.0) + side * 2.6
	var yaw := atan2(-dir.x, -dir.z)
	LowPoly.box(self, Vector3(0.18, 2.6, 0.18), post + Vector3.UP * 1.3, Color(0.5, 0.35, 0.22), yaw)
	LowPoly.box(self, Vector3(2.6, 0.7, 0.12), post + Vector3.UP * 2.3, Color(0.45, 0.22, 0.5), yaw)
	var l := LowPoly.label(self, post + Vector3.UP * 2.3 - dir * 0.07, "CASINO", 44, Color(0.2, 0.0, 0.2), yaw)
	l.modulate = Color(1.0, 0.85, 0.4)


## The sports island (north-east), and the bridge over to it. Its way in is
## on its own +Z side, facing the scoreboard and the stands, so it's turned
## to put that side towards the practice island: you come over the bridge
## and the whole pitch is laid out in front of you.
func _sports_island() -> void:
	sports = SportsIsland.new()
	sports.name = "SportsIsland"
	var a := deg_to_rad(SPORTS_ANGLE)
	var dir := Vector3(cos(a), 0, sin(a))
	sports.position = _island_spot(SPORTS_ANGLE, SportsIsland.RADIUS)
	sports.rotation.y = atan2(-dir.x, -dir.z)
	add_child(sports)
	var from := dir * (ISLAND_RADIUS - 1.0)
	sports.build((sports.transform.affine_inverse() * from).z)
	_bridge(from + Vector3.UP * 0.05, sports.transform * Vector3(0, 0.05, SportsIsland.RADIUS - 0.8))


## A little cottage with a smoking chimney and a garden.
func _cottage(at: Vector3) -> void:
	var walls := Color(0.97, 0.92, 0.82)
	LowPoly.box(self, Vector3(4.0, 2.6, 3.4), at + Vector3.UP * 1.3, walls, 0.3)
	var roof := Node3D.new()
	roof.position = at + Vector3.UP * 2.6
	roof.rotation.y = 0.3
	add_child(roof)
	var prism := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(4.6, 1.8, 3.9)
	prism.mesh = pm
	prism.material_override = LowPoly.mat(Color(0.8, 0.35, 0.28))
	prism.position.y = 0.9
	roof.add_child(prism)
	LowPoly.box(roof, Vector3(0.9, 0.6, 1.2), Vector3(0, -1.0, 1.72), Color(0.45, 0.3, 0.2), 0.0)  # door
	LowPoly.box(roof, Vector3(0.8, 0.7, 0.05), Vector3(-1.3, -0.9, 1.72), Color(0.6, 0.8, 0.95), 0.0)
	LowPoly.box(roof, Vector3(0.8, 0.7, 0.05), Vector3(1.3, -0.9, 1.72), Color(0.6, 0.8, 0.95), 0.0)
	LowPoly.box(roof, Vector3(0.5, 1.4, 0.5), Vector3(1.2, 1.2, -0.6), Color(0.6, 0.45, 0.4), 0.0)  # chimney
	var smoke := CPUParticles3D.new()
	smoke.amount = 16
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0.3, 0.1, 0)
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.2
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.9, 0.9, 0.92, 0.6)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smm
	smoke.mesh = sm
	smoke.position = Vector3(1.2, 2.0, -0.6)
	roof.add_child(smoke)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.6, 3.4)
	shape.shape = box
	body.position = at + Vector3.UP * 1.3
	body.rotation.y = 0.3
	body.add_child(shape)
	add_child(body)
	# A small vegetable garden with a picket fence.
	var garden := at + Vector3(-1.5, 0, 4.5)
	for k in 8:
		LowPoly.box(self, Vector3(0.08, 0.45, 0.08), garden + Vector3(-2.0 + k * 0.57, 0.22, 1.2), Color.WHITE, 0.0)
	for row in 3:
		for k in 5:
			LowPoly.ball(self, garden + Vector3(-1.6 + k * 0.7, 0.15, -0.6 + row * 0.6), 0.16,
					[Color(0.95, 0.5, 0.15), Color(0.3, 0.6, 0.25), Color(0.85, 0.2, 0.25)][row])


## Strings of little triangle flags over the plaza.
## Bunting pole tops round the plaza (strings run between them).
const BUNTING_POLES := [Vector3(-12, 3.2, 17), Vector3(-2.3, 4.0, 21), Vector3(2.3, 4.0, 21), Vector3(12, 3.2, 17),
		Vector3(-10, 3.0, 4), Vector3(10, 3.0, 4)]

func _bunting() -> void:
	var colors := [Color(0.95, 0.35, 0.35), Color(1, 0.8, 0.3), Color(0.4, 0.7, 1.0), Color(0.6, 0.85, 0.4), Color(0.85, 0.5, 0.95)]
	var flag := PrismMesh.new()
	flag.size = Vector3(0.3, 0.35, 0.02)
	var poles := BUNTING_POLES
	var lines := [[poles[0], poles[1]], [poles[2], poles[3]], [poles[0], poles[4]], [poles[3], poles[5]]]
	for end: Vector3 in poles:
		LowPoly.box(self, Vector3(0.12, end.y, 0.12), Vector3(end.x, end.y / 2.0, end.z), Color(0.5, 0.36, 0.24), 0.0)
	var k := 0
	for line in lines:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var n := int(a.distance_to(b) / 0.6)
		var yaw := atan2(b.x - a.x, b.z - a.z) + PI / 2
		for i in n:
			var t := (i + 0.5) / n
			var p := a.lerp(b, t) + Vector3.DOWN * sin(PI * t) * 0.6
			var f := MeshInstance3D.new()
			f.mesh = flag
			f.material_override = LowPoly.mat(colors[k % colors.size()])
			f.position = p + Vector3.DOWN * 0.18
			f.rotation = Vector3(PI, yaw, 0)
			add_child(f)
			k += 1


func _benches() -> void:
	var wood := Color(0.62, 0.42, 0.26)
	for spot in BENCHES:
		var at: Vector3 = spot[0]
		var bench := Node3D.new()
		bench.position = at
		bench.rotation.y = spot[1]
		add_child(bench)
		LowPoly.box(bench, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), wood, 0.0)
		LowPoly.box(bench, Vector3(1.8, 0.4, 0.08), Vector3(0, 0.7, -0.24), wood, 0.0)
		for x in [-0.75, 0.75]:
			LowPoly.box(bench, Vector3(0.08, 0.45, 0.45), Vector3(x, 0.22, 0), Color(0.25, 0.25, 0.28), 0.0)


## Hot-air balloons drifting slowly round the island.
func _balloons() -> void:
	var colors := [[Color(0.95, 0.35, 0.3), Color(1, 0.85, 0.35)], [Color(0.35, 0.6, 0.95), Color.WHITE], [Color(0.6, 0.4, 0.9), Color(0.5, 0.9, 0.6)]]
	for i in 3:
		var b := Node3D.new()
		add_child(b)
		for k in 8:
			var seg := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 2.2
			s.height = 5.0
			s.radial_segments = 8
			s.rings = 6
			seg.mesh = s
			seg.material_override = LowPoly.mat(colors[i][k % 2])
			seg.scale = Vector3(0.5, 1, 0.5)
			seg.position = Vector3(cos(TAU * k / 8.0), 0, sin(TAU * k / 8.0)) * 1.1
			b.add_child(seg)
		LowPoly.box(b, Vector3(1.0, 0.8, 1.0), Vector3(0, -4.2, 0), Color(0.55, 0.4, 0.25), 0.0)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4
			LowPoly.box(b, Vector3(0.03, 2.2, 0.03), Vector3(cos(a) * 0.55, -2.9, sin(a) * 0.55), Color(0.3, 0.25, 0.2), 0.0)
		_clouds.append({"node": b, "angle": TAU * i / 3.0, "radius": _rng.randf_range(48.0, 60.0),
				"y": _rng.randf_range(10.0, 22.0), "speed": _rng.randf_range(0.015, 0.03)})


## Little flocks of birds circling overhead.
func _birds() -> void:
	var m := LowPoly.mat(Color(0.2, 0.2, 0.25))
	for f in 3:
		var flock := Node3D.new()
		add_child(flock)
		for k in 5:
			var bird := Node3D.new()
			bird.position = Vector3(-absf(k - 2) * 0.9, randf_range(-0.2, 0.2), (k - 2) * 0.9)
			flock.add_child(bird)
			for side in [-1, 1]:
				var wing := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.15, 0.03, 0.55)
				wing.mesh = bm
				wing.material_override = m
				wing.position = Vector3(0, 0, side * 0.25)
				wing.rotation.x = side * 0.35
				bird.add_child(wing)
			_bobbers.append({"node": bird, "y": bird.position.y, "speed": 6.0, "phase": k * 0.7, "amount": 0.12})
		_clouds.append({"node": flock, "angle": TAU * f / 3.0, "radius": 22.0 + f * 9.0,
				"y": 19.0 + f * 4.0, "speed": 0.08 + f * 0.02})


## True if `at` (on the island) is within `r` metres of the practice run.
func _near_run(at: Vector3, r: float) -> bool:
	for p in _run_points:
		if Vector2(p.x - at.x, p.z - at.z).length() < r:
			return true
	return false


func _rock(pos: Vector3, r: float) -> void:
	var b := LowPoly.ball(self, pos + Vector3.UP * r * 0.3, r, Color(0.55, 0.52, 0.5))
	b.scale = Vector3(1.2, 0.7, 1.0)


func _sparkles(at: Vector3, extents: Vector3, color: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mesh.material = m
	p.mesh = mesh
	p.position = at
	add_child(p)


func _poof(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 20
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
