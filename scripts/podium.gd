class_name Podium
extends Node3D
## The FINAL STANDINGS screen at the end of a match: a dark little stage,
## like the back of an old bowling alley after closing, with velvet
## curtains, a marquee of light bulbs, spotlights and two giant pins.
##
## The balls drop onto it one at a time, last place first: fourth lands in
## a trash can (shaking its head), then third, second and finally the
## winner, who gets a gold medal and confetti and bounces happily.
##
## The balls here are display copies (no physics), so it looks the same on
## every computer online. main.gd calls show_for() when the match ends and
## clear() when a new one starts. The stage sits far away from the course
## (main.gd puts it there), so nothing else is in shot.

## Each place's block: x across the stage, height, colour.
const BLOCKS := [
	{"x": 0.0, "h": 1.2, "color": Color(1.0, 0.8, 0.25), "label": "1ST"},
	{"x": -1.55, "h": 0.8, "color": Color(0.78, 0.8, 0.86), "label": "2ND"},
	{"x": 1.55, "h": 0.5, "color": Color(0.85, 0.55, 0.3), "label": "3RD"},
]
const BLOCK_SIZE := Vector3(1.45, 0.0, 1.3)
const TRASH_AT := Vector3(3.4, 0.0, 0.3)
const R := 0.3   # ball radius
const GOLD := Color(1.0, 0.8, 0.2)
## Seconds after the screen opens that each place drops in (4th first).
const REVEAL_AT := [2.6, 1.8, 1.1, 0.4]
const DROP_HEIGHT := 3.0
const DROP_TIME := 0.55

## Stage colours: dark velvet, warm maple boards and cream trim.
const VELVET := Color(0.42, 0.06, 0.1)
const MAPLE := Color(0.86, 0.66, 0.42)
const MAPLE_DARK := Color(0.74, 0.53, 0.32)
const CREAM := Color(0.98, 0.93, 0.8)
const DARK := Color(0.03, 0.025, 0.04)

## Seconds since the podium appeared (the coins screen waits a moment).
var age := 0.0

var _marbles: Array = []      # {place, ball, rest (Vector3), tag (Label3D)}
var _env: Environment
var _medal: Node3D
var _confetti_wait := 0.0


## Build the podium for this ranking. `order` lists seats best first.
func show_for(order: Array, looks: Array, colors: Array, names: Array, scene: PackedScene) -> void:
	clear()
	visible = true
	age = 0.0
	_confetti_wait = 2.0
	_build_stage()
	for place in order.size():
		var p: int = order[place]
		var m: Marble = scene.instantiate()
		m.player_id = p
		m.look = looks[p]
		m.freeze = true
		m.face_camera = true
		m.collision_layer = 0
		m.collision_mask = 0
		add_child(m)
		var rest: Vector3
		var tag: Label3D
		if place < BLOCKS.size():
			var b: Dictionary = BLOCKS[place]
			_block(b, colors[p])
			rest = Vector3(b.x, b.h + R, 0)
			tag = LowPoly.label(self, Vector3(b.x, b.h + 1.15, 0), names[p], 34, Color(0, 0, 0, 0.7), 0.0, true)
			tag.modulate = (colors[p] as Color).lightened(0.3)
		else:
			_trash_can()
			rest = TRASH_AT + Vector3(0, 0.8, 0)
			tag = LowPoly.label(self, TRASH_AT + Vector3(0, 1.55, 0), names[p], 28, Color(0, 0, 0, 0.7), 0.0, true)
			tag.modulate = Color(0.75, 0.75, 0.75)
		m.visible = false
		tag.visible = false
		m.position = rest + Vector3.UP * DROP_HEIGHT
		_marbles.append({"place": place, "ball": m, "rest": rest, "tag": tag})
	_medal = _make_medal()
	_medal.visible = false
	add_child(_medal)


## The stage's lighting: a dark room lit by its own spotlights. main.gd
## swaps this in (and dims the sun) while the stage shows.
func environment() -> Environment:
	if _env == null:
		_env = Environment.new()
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = DARK
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0.8, 0.72, 0.7)
		_env.ambient_light_energy = 0.55
		_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_env.glow_enabled = true
		_env.glow_intensity = 0.5
		_env.glow_hdr_threshold = 1.2
	return _env


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_marbles.clear()
	_medal = null
	visible = false


## Points the camera should keep in shot.
func frame_points() -> Array:
	return [to_global(Vector3(-2.4, 0.2, 0.6)), to_global(Vector3(TRASH_AT.x + 0.6, 0.2, 0.6)),
			to_global(Vector3(0, BLOCKS[0].h + 1.4, 0))]


func _process(delta: float) -> void:
	if not visible or _marbles.is_empty():
		return
	age += delta
	for e in _marbles:
		var m: Marble = e.ball
		if not is_instance_valid(m):
			continue
		var place: int = e.place
		var since: float = age - REVEAL_AT[mini(place, 3)]
		if since < 0.0:
			continue
		if not m.visible:
			_land(e)
		var rest: Vector3 = e.rest
		if since < DROP_TIME:
			# Fall in and bounce once.
			var k := since / DROP_TIME
			m.position = rest + Vector3.UP * DROP_HEIGHT * _drop(k)
			continue
		match place:
			0:
				# A happy little hop every so often, a gentle bob otherwise.
				var t := fmod(since - DROP_TIME, 1.6)
				var hop := sin(t / 0.45 * PI) * 0.22 if t < 0.45 else 0.0
				m.position = rest + Vector3.UP * (hop + sin(since * 2.2) * 0.02)
			1, 2:
				m.position = rest
				m.look_offset = sin(age * 1.6 + place) * 0.25
			_:
				# In the bin, shaking its head with eyes squeezed shut.
				m.look_offset = sin(age * 7.0) * 0.45 * clampf(sin(age * 0.9) * 2.0, 0.0, 1.0)
				m.position = rest + Vector3.UP * sin(age * 3.0) * 0.015
				if fmod(age, 2.2) < delta:
					m.wince(6.0)
		if place == 0:
			_place_medal(m)
	# A light sprinkle of confetti over the winner every few seconds.
	if age > REVEAL_AT[0] + 1.0:
		_confetti_wait -= delta
		if _confetti_wait <= 0.0:
			_confetti_wait = 2.6
			LowPoly.confetti(self, to_global(Vector3(0, BLOCKS[0].h + 2.2, 0)), 18)


## A ball lands: show it and its name, with a puff for the winner.
func _land(e: Dictionary) -> void:
	(e.ball as Marble).visible = true
	(e.tag as Label3D).visible = true
	var tag: Label3D = e.tag
	tag.scale = Vector3.ONE * 0.2
	create_tween().tween_property(tag, "scale", Vector3.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if e.place == 0:
		_medal.visible = true
		LowPoly.confetti(self, to_global(Vector3(0, BLOCKS[0].h + 0.6, 0)), 60)


## Height (0..1 of the drop) `k` of the way through a drop: a fall, then
## one small bounce.
static func _drop(k: float) -> float:
	if k < 0.7:
		var f := k / 0.7
		return 1.0 - f * f
	var b := (k - 0.7) / 0.3
	return 0.12 * sin(b * PI)


# ------------------------------------------------------------ Building

## The stage: a dark room, maple boards, curtains, a marquee and lights.
func _build_stage() -> void:
	# A dark room all round, so nothing of the course shows behind.
	var room := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(60, 30, 60)
	box.flip_faces = true
	room.mesh = box
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = DARK
	room.material_override = dark
	room.position = Vector3(0, 12, 0)
	add_child(room)
	# Maple lane boards running toward the curtain, with a dark gutter each side.
	for i in 22:
		var x := -5.25 + i * 0.5
		LowPoly.box(self, Vector3(0.49, 0.1, 9.0), Vector3(x, -0.05, -0.3), MAPLE if i % 2 == 0 else MAPLE_DARK)
	for side in [-1.0, 1.0]:
		LowPoly.box(self, Vector3(0.6, 0.12, 9.0), Vector3(side * 5.8, -0.08, -0.3), Color(0.12, 0.1, 0.1))
	# Lane arrows, like on a real lane.
	for k in 5:
		var a := LowPoly.box(self, Vector3(0.12, 0.012, 0.32), Vector3(-2.0 + k, 0.006, 2.4 - absf(k - 2) * 0.35), VELVET)
		a.rotation.y = PI / 4
	# Velvet curtain: a row of folds, with a gold rail.
	for i in 30:
		var x := -7.25 + i * 0.5
		LowPoly.cyl(self, 0.28, 0.3, 6.0, Vector3(x, 3.0, -3.0 - (i % 2) * 0.12), VELVET.darkened(0.15 * (i % 2)), 8)
	LowPoly.box(self, Vector3(15.5, 0.12, 0.12), Vector3(0, 5.9, -2.75), GOLD.darkened(0.3))
	_marquee(Vector3(0, 3.9, -2.55))
	for side in [-1.0, 1.0]:
		_giant_pin(Vector3(side * 5.0, 0, -1.6))
	# Warm spotlights from above the camera, one on each step.
	_spot(Vector3(0, 6.0, 4.0), Vector3(0, BLOCKS[0].h, 0), Color(1.0, 0.9, 0.7), 14.0, 20.0)
	_spot(Vector3(-3.0, 5.5, 3.5), Vector3(-1.55, 0.8, 0), Color(1.0, 0.85, 0.75), 9.0, 20.0)
	_spot(Vector3(3.5, 5.5, 3.5), Vector3(2.6, 0.5, 0), Color(1.0, 0.85, 0.75), 9.0, 26.0)
	# A soft wash over the curtain and the giant pins.
	_spot(Vector3(0, 7.0, 6.0), Vector3(0, 2.5, -3.0), Color(1.0, 0.6, 0.55), 5.0, 45.0)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.8, 0.7)
	fill.light_energy = 0.5
	fill.omni_range = 9.0
	fill.position = Vector3(0, 2.5, -1.5)
	add_child(fill)


## FINAL STANDINGS on a cream sign with a border of warm bulbs.
func _marquee(at: Vector3) -> void:
	var w := 5.2
	var h := 1.0
	LowPoly.box(self, Vector3(w + 0.3, h + 0.3, 0.12), at, Color(0.18, 0.04, 0.06))
	LowPoly.box(self, Vector3(w, h, 0.14), at, CREAM)
	var title := LowPoly.label(self, at + Vector3(0, 0, 0.09), "FINAL STANDINGS", 120, Color(0, 0, 0, 0))
	title.modulate = VELVET
	title.outline_size = 0
	title.pixel_size = 0.0055
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.85, 0.5)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.75, 0.35)
	bulb.emission_energy_multiplier = 2.5
	var n := 18
	for i in n + 1:
		var x := -w / 2.0 - 0.08 + (w + 0.16) * i / n
		for y in [h / 2.0 + 0.08, -h / 2.0 - 0.08]:
			var b := LowPoly.ball(self, at + Vector3(x, y, 0.1), 0.05, Color.WHITE, 6)
			b.material_override = bulb


## A giant bowling pin: cream with two red neck stripes.
func _giant_pin(at: Vector3) -> void:
	var s := 2.2
	LowPoly.cyl(self, 0.32 * s, 0.22 * s, 0.6 * s, at + Vector3(0, 0.3 * s, 0), CREAM, 14)
	LowPoly.ball(self, at + Vector3(0, 0.62 * s, 0), 0.34 * s, CREAM, 14)
	LowPoly.cyl(self, 0.13 * s, 0.25 * s, 0.4 * s, at + Vector3(0, 1.0 * s, 0), CREAM, 14)
	for k in 2:
		LowPoly.cyl(self, 0.135 * s - k * 0.01, 0.15 * s - k * 0.01, 0.05 * s,
				at + Vector3(0, (1.07 - k * 0.09) * s, 0), Color(0.8, 0.1, 0.12), 14)
	LowPoly.ball(self, at + Vector3(0, 1.3 * s, 0), 0.17 * s, CREAM, 12)


func _spot(from: Vector3, to: Vector3, color: Color, energy: float, angle: float) -> void:
	var s := SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_range = 16.0
	s.spot_angle = angle
	s.spot_attenuation = 0.5
	s.shadow_enabled = true
	add_child(s)
	s.position = from
	s.look_at_from_position(from, to)


func _block(b: Dictionary, accent: Color) -> void:
	var h: float = b.h
	LowPoly.box(self, Vector3(BLOCK_SIZE.x, h, BLOCK_SIZE.z), Vector3(b.x, h / 2.0, 0), CREAM)
	LowPoly.box(self, Vector3(BLOCK_SIZE.x + 0.04, 0.12, BLOCK_SIZE.z + 0.04), Vector3(b.x, h - 0.06, 0), b.color)
	LowPoly.box(self, Vector3(BLOCK_SIZE.x + 0.02, 0.06, BLOCK_SIZE.z + 0.02), Vector3(b.x, 0.03, 0), accent)
	var num := LowPoly.label(self, Vector3(b.x, h * 0.5, BLOCK_SIZE.z / 2.0 + 0.01), b.label, 64, Color(0, 0, 0, 0))
	num.modulate = (b.color as Color).darkened(0.25)
	num.outline_size = 0
	num.pixel_size = 0.006 if h > 0.6 else 0.0045


## A dented metal bin with its lid knocked off and some rubbish about.
func _trash_can() -> void:
	var at := TRASH_AT
	var metal := Color(0.55, 0.6, 0.62)
	LowPoly.cyl(self, 0.42, 0.36, 0.85, at + Vector3(0, 0.425, 0), metal, 14)
	for k in 3:
		LowPoly.cyl(self, 0.43, 0.43, 0.04, at + Vector3(0, 0.2 + k * 0.25, 0), metal.darkened(0.2), 14)
	LowPoly.cyl(self, 0.37, 0.37, 0.02, at + Vector3(0, 0.84, 0), Color(0.15, 0.15, 0.15), 14)
	var lid := LowPoly.cyl(self, 0.45, 0.45, 0.05, at + Vector3(0.6, 0.12, 0.35), metal.lightened(0.1), 14)
	lid.rotation = Vector3(0.3, 0.0, 1.2)
	LowPoly.box(self, Vector3(0.12, 0.05, 0.08), lid.position + Vector3(0.0, 0.1, 0.0), metal.darkened(0.3))
	# Rubbish: a banana peel, a crumpled paper ball and a can.
	LowPoly.box(self, Vector3(0.28, 0.03, 0.08), at + Vector3(-0.55, 0.02, 0.3), Color(1.0, 0.85, 0.2), 0.6)
	LowPoly.box(self, Vector3(0.22, 0.03, 0.07), at + Vector3(-0.5, 0.02, 0.38), Color(1.0, 0.85, 0.2), -0.4)
	LowPoly.ball(self, at + Vector3(-0.3, 0.08, 0.55), 0.09, Color(0.92, 0.92, 0.88), 6)
	var can := LowPoly.cyl(self, 0.06, 0.06, 0.2, at + Vector3(0.25, 0.06, 0.6), Color(0.85, 0.2, 0.2), 8)
	can.rotation.z = PI / 2


## A gold medal on a red ribbon. The ribbon is a ring a little wider than
## the ball, tipped forward so it hangs low on the front, so it never cuts
## into the ball; the gold disc hangs from its lowest point.
const RIBBON_TILT := 0.5

func _make_medal() -> Node3D:
	var medal := Node3D.new()
	medal.top_level = true
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = R * 1.04
	torus.outer_radius = R * 1.16
	torus.rings = 20
	torus.ring_segments = 6
	torus.material = LowPoly.mat(Color(0.85, 0.15, 0.2))
	ring.mesh = torus
	ring.rotation.x = RIBBON_TILT
	medal.add_child(ring)
	# Lowest front point of the ribbon, and the disc just below it.
	var mid := R * 1.1
	var hang := Vector3(0, -sin(RIBBON_TILT) * mid - 0.02, cos(RIBBON_TILT) * mid + 0.06)
	var disc := LowPoly.cyl(medal, 0.11, 0.11, 0.03, hang, GOLD, 16)
	disc.rotation.x = PI / 2 - 0.15
	var mat := LowPoly.own_mat(disc)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = GOLD
	mat.emission_energy_multiplier = 0.3
	var star := LowPoly.label(medal, hang + Vector3(0, -0.004, 0.02), "★", 32, Color(0, 0, 0, 0))
	star.rotation.x = -0.15
	star.modulate = GOLD.darkened(0.35)
	star.outline_size = 0
	star.pixel_size = 0.004
	return medal


## Keep the medal round the winner, facing the camera like the winner does.
func _place_medal(m: Marble) -> void:
	if _medal == null:
		return
	var cam := get_viewport().get_camera_3d()
	var to_cam := global_basis.z
	if cam:
		to_cam = cam.global_position - m.global_position
	var yaw := atan2(to_cam.x, to_cam.z)
	_medal.global_transform = Transform3D(Basis(Vector3.UP, yaw), m.global_position)
