class_name Podium
extends Node3D
## The victory podium at the end of a match, on the bowling lane in front of
## the pins. First, second and third stand on numbered blocks: the winner
## hops up and down wearing a gold medal, with a little confetti now and then.
## Fourth place sits in a trash can, shaking their head.
##
## The marbles here are display copies (no physics), so the podium looks the
## same on every computer online. main.gd calls show_for() when the match
## ends and clear() when a new one starts.

## Each place's block: x across the lane, height, colour.
const BLOCKS := [
	{"x": 0.0, "h": 1.2, "color": Color(1.0, 0.8, 0.25), "label": "1ST"},
	{"x": -1.55, "h": 0.8, "color": Color(0.78, 0.8, 0.86), "label": "2ND"},
	{"x": 1.55, "h": 0.5, "color": Color(0.85, 0.55, 0.3), "label": "3RD"},
]
const BLOCK_SIZE := Vector3(1.45, 0.0, 1.3)
const TRASH_AT := Vector3(3.4, 0.0, 0.3)
const R := 0.3   # marble radius
const GOLD := Color(1.0, 0.8, 0.2)

## Seconds since the podium appeared (the scoreboard waits a moment).
var age := 0.0

var _marbles: Array = []      # [place, Marble] pairs
var _medal: Node3D
var _confetti_wait := 0.0


## Build the podium for this ranking. `order` lists seats best first.
func show_for(order: Array, looks: Array, colors: Array, names: Array, scene: PackedScene) -> void:
	clear()
	visible = true
	age = 0.0
	_confetti_wait = 0.0
	for place in order.size():
		var p: int = order[place]
		var m: Marble = scene.instantiate()
		m.player_id = p
		m.look = looks[p]
		m.freeze = true
		m.collision_layer = 0
		m.collision_mask = 0
		add_child(m)
		if place < BLOCKS.size():
			var b: Dictionary = BLOCKS[place]
			_block(b, colors[p])
			m.position = Vector3(b.x, b.h + R, 0)
			LowPoly.label(self, Vector3(b.x, b.h + 1.15, 0), names[p], 34, Color(0, 0, 0, 0.7), 0.0, true) \
					.modulate = (colors[p] as Color).lightened(0.3)
		else:
			_trash_can()
			m.position = TRASH_AT + Vector3(0, 0.8, 0)
			LowPoly.label(self, TRASH_AT + Vector3(0, 1.55, 0), names[p], 28, Color(0, 0, 0, 0.7), 0.0, true) \
					.modulate = Color(0.75, 0.75, 0.75)
		_marbles.append([place, m])
	_medal = _make_medal()
	add_child(_medal)
	LowPoly.confetti(self, Vector3(0, BLOCKS[0].h + 0.6, 0), 45)


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_marbles.clear()
	_medal = null
	visible = false


## Middle of the podium in world space, and points the camera should keep
## in shot.
func frame_points() -> Array:
	return [to_global(Vector3(-2.2, 0.2, 0.6)), to_global(Vector3(TRASH_AT.x + 0.5, 0.2, 0.6)),
			to_global(Vector3(0, BLOCKS[0].h + 1.3, 0))]


func _process(delta: float) -> void:
	if not visible or _marbles.is_empty():
		return
	age += delta
	for pair in _marbles:
		var place: int = pair[0]
		var m: Marble = pair[1]
		if not is_instance_valid(m):
			continue
		match place:
			0:
				# Bouncy little hops, squashing a touch on landing.
				var hop := absf(sin(age * 5.0))
				m.position.y = BLOCKS[0].h + R + hop * 0.45
				var mesh := m.get_node_or_null("Mesh") as Node3D
				if mesh:
					var squash := 1.0 - (0.3 - hop) * 0.4 if hop < 0.3 else 1.0
					mesh.scale = Vector3(2.0 - squash, squash, 2.0 - squash)
				_place_medal(m)
			1, 2:
				# Happy enough: a gentle sway.
				m.look_offset = sin(age * 1.6 + place) * 0.25
			_:
				# In the bin, shaking their head with eyes squeezed shut.
				m.look_offset = sin(age * 7.0) * 0.45 * clampf(sin(age * 0.9) * 2.0, 0.0, 1.0)
				m.position.y = TRASH_AT.y + 0.8 + sin(age * 3.0) * 0.015
				if fmod(age, 2.2) < delta:
					m.wince(6.0)
	# A light sprinkle of confetti over the winner every few seconds.
	_confetti_wait -= delta
	if _confetti_wait <= 0.0:
		_confetti_wait = 2.6
		if age > 1.0:
			LowPoly.confetti(self, Vector3(0, BLOCKS[0].h + 2.2, 0), 18)


# ------------------------------------------------------------ Building

func _block(b: Dictionary, accent: Color) -> void:
	var h: float = b.h
	LowPoly.box(self, Vector3(BLOCK_SIZE.x, h, BLOCK_SIZE.z), Vector3(b.x, h / 2.0, 0), Color(0.95, 0.94, 0.9))
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


## A gold medal on a red, white and blue ribbon.
func _make_medal() -> Node3D:
	var medal := Node3D.new()
	medal.top_level = true
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = R * 0.88
	torus.outer_radius = R * 1.0
	torus.rings = 16
	torus.ring_segments = 6
	torus.material = LowPoly.mat(Color(0.85, 0.15, 0.2))
	ring.mesh = torus
	ring.position = Vector3(0, R * 0.35, -0.02)
	ring.rotation.x = 0.35
	medal.add_child(ring)
	var disc := LowPoly.cyl(medal, 0.11, 0.11, 0.03, Vector3(0, -R * 0.05, R * 0.98), GOLD, 14)
	disc.rotation.x = PI / 2
	var mat := LowPoly.own_mat(disc)
	mat.metallic = 0.6
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = GOLD
	mat.emission_energy_multiplier = 0.3
	var star := LowPoly.label(medal, Vector3(0, -R * 0.05, R * 0.98 + 0.02), "★", 32, Color(0, 0, 0, 0))
	star.modulate = GOLD.darkened(0.35)
	star.outline_size = 0
	star.pixel_size = 0.004
	return medal


## Keep the medal round the winner's "neck", facing the camera.
func _place_medal(m: Marble) -> void:
	if _medal == null:
		return
	var cam := get_viewport().get_camera_3d()
	var to_cam := Vector3.BACK
	if cam:
		to_cam = cam.global_position - m.global_position
	var yaw := atan2(to_cam.x, to_cam.z)
	_medal.global_transform = Transform3D(Basis(Vector3.UP, yaw), m.global_position)
