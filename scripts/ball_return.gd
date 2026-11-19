class_name BallReturn
extends Node3D
## The bowling-alley end of the track, on the pin deck: a polished maple
## lane with arrows and pin spots, gutters down both sides, a dark pit
## behind the pins with a curtain, a lit hood over it, and a ball return.
##
## Marbles that end up in the pit are picked up (out of sight, behind the
## pit wall), pop out onto the return rail and roll back along the side of
## the lane to sit on the ball-return machine, like real bowling balls.
## That part is just for show: the frame is already scored the same way.
##
## It lives under the Deck node (course.tscn), so everything here is in the
## deck's own space: the lane starts at z = 0 and runs toward -z.

## Total width of the lane plus both gutters, metres.
const ALLEY_WIDTH := 7.3
const LANE_HALF := 2.8
const GUTTER_OUT := 3.55
const DECK_LEN := 11.5
const PIT_FRONT := -11.4
const PIT_BACK := -19.2
## The return rail runs along the right of the lane at this x and height.
const RAIL_X := 4.5
const RAIL_Y := 0.75
## Where returned marbles wait on the machine: the first spot, then each
## next one this much closer to the lane.
const REST_Z := 2.4
const REST_STEP := 0.72
## How fast marbles travel along the return, metres per second.
const RETURN_SPEED := 5.0

const MAPLE := Color(0.86, 0.66, 0.42)
const MAPLE_DARK := Color(0.78, 0.57, 0.35)
const GUTTER := Color(0.3, 0.32, 0.36)
const PIT := Color(0.1, 0.1, 0.12)

## Marbles on their way back: {marble, path (PackedVector3Array, deck
## space), at (metres along it), slot}.
var _returning: Array = []
var _waiting := {}   # marble -> seconds it has sat in the pit
var _slots := 0
var _hood_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_build()


## A new roll: forget the old marbles (main.gd frees them).
func reset() -> void:
	_returning.clear()
	_waiting.clear()
	_slots = 0


## Called every physics tick while marbles roll (host only; online guests
## see the result through the usual marble positions).
func update(marbles: Array, delta: float) -> void:
	_time += delta
	for m in marbles:
		var mb := m as Marble
		if mb == null or mb.freeze or _is_returning(mb):
			continue
		var local := to_local(mb.global_position)
		if local.z < PIT_FRONT - 0.2 and local.y < -1.6:
			_waiting[mb] = _waiting.get(mb, 0.0) + delta
			if _waiting[mb] > 0.6:
				_start_return(mb, local)
	for r in _returning:
		var m: Marble = r.marble
		if not is_instance_valid(m):
			continue
		var path: PackedVector3Array = r.path
		r.at = minf(r.at + RETURN_SPEED * delta, _length(path))
		var before := m.global_position
		m.global_position = to_global(_sample(path, r.at))
		var moved := m.global_position - before
		if moved.length() > 0.001:
			# Spin as if rolling along the rail.
			var axis := moved.cross(Vector3.UP).normalized()
			if axis.length() > 0.5:
				m.get_node("Mesh").rotate(axis, -moved.length() / 0.3)


func _is_returning(m: Marble) -> bool:
	for r in _returning:
		if r.marble == m:
			return true
	return false


func _start_return(m: Marble, from: Vector3) -> void:
	m.freeze = true
	m.linear_velocity = Vector3.ZERO
	var slot := _slots
	_slots += 1
	var rest := Vector3(RAIL_X, RAIL_Y + 0.3, REST_Z - (slot % 4) * REST_STEP)
	var path := PackedVector3Array([
		from,
		Vector3(RAIL_X - 1.0, -2.6, PIT_FRONT - 1.5),     # into the corner of the pit
		Vector3(RAIL_X, -1.0, PIT_FRONT - 0.9),           # up inside the return (hidden)
		Vector3(RAIL_X, RAIL_Y + 0.2, PIT_FRONT - 0.5),   # pops out of the hood
		Vector3(RAIL_X, RAIL_Y + 0.25, -2.0),             # rolls along the rail
		rest,
	])
	_returning.append({"marble": m, "path": path, "at": 0.0, "slot": slot})


static func _length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


static func _sample(path: PackedVector3Array, at: float) -> Vector3:
	var left := at
	for i in range(1, path.size()):
		var seg := path[i].distance_to(path[i - 1])
		if left <= seg:
			return path[i - 1].lerp(path[i], left / maxf(seg, 0.001))
		left -= seg
	return path[path.size() - 1]


func _process(delta: float) -> void:
	if _hood_mat:
		# The hood's light strip slowly pulses.
		_hood_mat.emission_energy_multiplier = 2.2 + sin(Time.get_ticks_msec() / 500.0) * 0.6


# ------------------------------------------------------------ Building

func _build() -> void:
	var b := MeshBatch.new()
	_lane(b)
	_gutters(b)
	_pit(b)
	_return_rail(b)
	var mi := b.make(2.6)
	add_child(mi)
	_solid()
	_hood()


## Maple boards, the guide arrows and dots, and pin spots.
func _lane(b: MeshBatch) -> void:
	var boards := 16
	var w := LANE_HALF * 2.0 / boards
	for k in boards:
		var col := MAPLE if k % 2 == 0 else MAPLE_DARK
		if k > 3 and k < 12 and k % 3 == 0:
			col = col.lightened(0.04)
		b.box(Vector3(w - 0.01, 0.4, DECK_LEN), Vector3(-LANE_HALF + (k + 0.5) * w, -0.2, -DECK_LEN / 2.0), col)
	# Guide arrows (a V of seven) and two rows of dots, like a real lane.
	var dark := Color(0.35, 0.18, 0.12)
	for k in 7:
		var x := (k - 3) * w * 2.0
		var z := -0.6 - absf(k - 3) * 0.32
		var arrow := PrismMesh.new()
		arrow.size = Vector3(0.18, 0.4, 0.012)
		b.shape(arrow, Basis(Vector3.RIGHT, -PI / 2), Vector3(x, 0.006, z), dark)
	for row in [0.25, -0.15]:
		for k in 5:
			b.cyl(0.04, 0.04, 0.012, Vector3((k - 2) * w * 2.5, 0.006, row), dark, 6)


## A rounded gutter down each side, and the low wall beyond it.
func _gutters(b: MeshBatch) -> void:
	for side in [-1.0, 1.0]:
		var mid: float = side * (LANE_HALF + GUTTER_OUT) / 2.0
		var gw := GUTTER_OUT - LANE_HALF
		b.box(Vector3(gw, 0.08, DECK_LEN), Vector3(mid, -0.34, -DECK_LEN / 2.0), GUTTER)
		# Curved sides suggested by two tilted strips.
		var strip := BoxMesh.new()
		strip.size = Vector3(0.22, 0.04, DECK_LEN)
		b.shape(strip, Basis(Vector3.BACK, side * 0.7), Vector3(side * (LANE_HALF + 0.08), -0.2, -DECK_LEN / 2.0), GUTTER.lightened(0.15))
		b.shape(strip, Basis(Vector3.BACK, -side * 0.7), Vector3(side * (GUTTER_OUT - 0.08), -0.2, -DECK_LEN / 2.0), GUTTER.lightened(0.15))
		# Capping wall (the "kickback") with a stripe of light.
		b.box(Vector3(0.2, 1.3, DECK_LEN), Vector3(side * (GUTTER_OUT + 0.1), 0.27, -DECK_LEN / 2.0), Color(0.18, 0.18, 0.22))
		b.glow_box(Vector3(0.22, 0.06, DECK_LEN), Vector3(side * (GUTTER_OUT + 0.1), 0.95, -DECK_LEN / 2.0), Color(0.3, 0.8, 1.0))
		# Legs down to the ground under the lane.
		for z in [-1.0, -6.0, -10.5]:
			b.beam(Vector3(side * 2.4, -0.4, z), Vector3(side * 2.4, Arena.GROUND_Y - 0.5, z), 0.4, Color(0.25, 0.25, 0.3))


## The dark pit behind the pins, a black curtain and side panels.
func _pit(b: MeshBatch) -> void:
	var mid_z := (PIT_FRONT + PIT_BACK) / 2.0
	var len := PIT_FRONT - PIT_BACK
	b.box(Vector3(10.0, 0.4, len), Vector3(0, -3.0, mid_z), PIT)
	b.box(Vector3(10.0, 2.8, 0.3), Vector3(0, -1.6, PIT_FRONT), PIT.lightened(0.05))
	# Curtain: folds of dark cloth hanging from the hood to the pit floor.
	for k in 20:
		var x := -5.0 + (k + 0.5) * 0.5
		b.box(Vector3(0.5, 6.6, 0.25), Vector3(x, 0.4, PIT_BACK + (0.12 if k % 2 == 0 else 0.0)),
				Color(0.1, 0.08, 0.16) if k % 2 == 0 else Color(0.16, 0.12, 0.22))
	b.box(Vector3(10.6, 0.5, 0.5), Vector3(0, 3.8, PIT_BACK), Color(0.16, 0.18, 0.28))
	for side in [-1.0, 1.0]:
		b.box(Vector3(0.3, 4.1, len + 0.5), Vector3(side * 5.1, -1.05, mid_z), Color(0.16, 0.18, 0.28))
		b.glow_box(Vector3(0.32, 0.12, len + 0.5), Vector3(side * 5.1, 1.0, mid_z), Color(1.0, 0.35, 0.65))
		# Posts holding the hood.
		b.box(Vector3(0.35, 7.5, 0.35), Vector3(side * 5.1, 0.75, PIT_FRONT - 0.4), Color(0.16, 0.18, 0.28))


## The ball return: a rail along the right side and the machine at the
## near end, with a hood where marbles pop out of the pit.
func _return_rail(b: MeshBatch) -> void:
	var steel := Color(0.72, 0.74, 0.8)
	var body := Color(0.2, 0.45, 0.8)
	# Two rails the marbles roll along, on little posts.
	for x in [-0.17, 0.17]:
		b.beam(Vector3(RAIL_X + x, RAIL_Y, PIT_FRONT - 0.4), Vector3(RAIL_X + x, RAIL_Y, REST_Z + 0.4), 0.07, steel)
	var z := PIT_FRONT
	while z < REST_Z:
		b.beam(Vector3(RAIL_X, Arena.GROUND_Y, z), Vector3(RAIL_X, RAIL_Y - 0.05, z), 0.12, Color(0.3, 0.3, 0.35))
		b.box(Vector3(0.5, 0.06, 0.1), Vector3(RAIL_X, RAIL_Y - 0.05, z), Color(0.3, 0.3, 0.35))
		z += 2.0
	# Hood at the pit end that marbles roll out of.
	b.box(Vector3(1.2, 1.4, 1.4), Vector3(RAIL_X, RAIL_Y + 0.3, PIT_FRONT - 0.9), body)
	b.cyl(0.6, 0.6, 1.2, Vector3(RAIL_X, RAIL_Y + 1.0, PIT_FRONT - 0.9), body.lightened(0.1), 12)
	b.box(Vector3(0.9, 0.6, 0.05), Vector3(RAIL_X, RAIL_Y + 0.25, PIT_FRONT - 0.17), Color(0.05, 0.05, 0.07))
	# The ball-return machine: a rounded hood with a rack on top.
	var m := Vector3(RAIL_X, 0.0, REST_Z - 1.0)
	b.box(Vector3(1.3, RAIL_Y + 0.4, 3.4), m + Vector3(0, (RAIL_Y - 0.4) / 2.0 + 0.0, 0), body)
	b.ball(m + Vector3(0, RAIL_Y - 0.05, 1.7), 0.65, body.lightened(0.1), 12, Vector3(1.0, 0.8, 0.8))
	b.box(Vector3(1.4, 0.1, 3.5), m + Vector3(0, RAIL_Y - 0.05, 0), steel)
	b.glow_box(Vector3(1.42, 0.06, 3.52), m + Vector3(0, RAIL_Y - 0.2, 0), Color(1.0, 0.75, 0.3))
	for side in [-0.66, 0.66]:
		b.beam(m + Vector3(side, RAIL_Y + 0.25, -1.75), m + Vector3(side, RAIL_Y + 0.25, 1.75), 0.06, steel)


## The upright parts marbles and pins can hit.
func _solid() -> void:
	var body := StaticBody3D.new()
	body.name = "Gutters"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.2
	body.physics_material_override = pm
	add_child(body)
	var boxes := []
	for side in [-1.0, 1.0]:
		var mid: float = side * (LANE_HALF + GUTTER_OUT) / 2.0
		boxes.append([Vector3(GUTTER_OUT - LANE_HALF, 0.1, DECK_LEN), Vector3(mid, -0.35, -DECK_LEN / 2.0)])
		boxes.append([Vector3(0.2, 1.3, DECK_LEN), Vector3(side * (GUTTER_OUT + 0.1), 0.27, -DECK_LEN / 2.0)])
		boxes.append([Vector3(0.3, 4.1, PIT_FRONT - PIT_BACK + 0.5), Vector3(side * 5.1, -1.05, (PIT_FRONT + PIT_BACK) / 2.0)])
	for bx in boxes:
		var shape := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = bx[0]
		shape.shape = s
		shape.position = bx[1]
		body.add_child(shape)


## The lit hood over the back of the pins, with the game's name on it.
func _hood() -> void:
	var hood := MeshBatch.new()
	hood.box(Vector3(10.6, 1.8, 1.6), Vector3(0, 0, 0), Color(0.12, 0.12, 0.16))
	hood.box(Vector3(10.8, 0.2, 1.8), Vector3(0, 0.95, 0), Color(0.2, 0.2, 0.25))
	var node := hood.make()
	add_child(node)
	node.position = Vector3(0, 4.6, PIT_FRONT - 0.4)
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(10.4, 0.12, 0.05)
	strip.mesh = sm
	_hood_mat = StandardMaterial3D.new()
	_hood_mat.albedo_color = Color(1.0, 0.85, 0.4)
	_hood_mat.emission_enabled = true
	_hood_mat.emission = Color(1.0, 0.8, 0.35)
	strip.material_override = _hood_mat
	strip.position = Vector3(0, -0.78, 0.82)
	node.add_child(strip)
	var label := Label3D.new()
	label.text = "MARBLES 4P"
	label.font = preload("res://fonts/ChakraPetch-Bold.ttf")
	label.font_size = 120
	label.pixel_size = 0.009
	label.outline_size = 16
	label.modulate = Color(1.6, 1.4, 1.0)
	label.outline_modulate = Color(0.5, 0.2, 0.05)
	label.shaded = false
	label.position = Vector3(0, 0.05, 0.82)
	node.add_child(label)
