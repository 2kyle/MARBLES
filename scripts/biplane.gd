class_name Biplane
extends Node3D
## A little vintage biplane parked on the lookout islet. Roll into it and
## your ball hops into the cockpit and takes off; then fly round the island:
##   left / right   turn
##   forward / back nose down / nose up
##   place key      a burst of speed
##   turn key       hop out (you land back on the lookout)
## It flies itself at a steady speed and won't go too low or too far, so
## you can't crash it. Just for fun: nothing is saved.
##
## Built by hub.gd in the hub's space (this node's parent is the hub). The
## hub calls update() every physics tick; main.gd sets `steer` and calls
## boost() and bail() for whoever is flying.

## Fired when a ball climbs in, and when it hops out.
signal boarded(m: Marble)
signal left_plane(m: Marble)

const SPEED := 13.0
const BOOST_SPEED := 22.0
const TURN_RATE := 1.3        # radians per second at full stick
const PITCH_MAX := 0.55       # radians
const MIN_HEIGHT := 24.0      # above the hub (clears the jungle cliffs)
const MAX_HEIGHT := 60.0
const MAX_RANGE := 100.0      # from the middle of the hub
const TAKEOFF_TIME := 3.0
const CREAM := Color(0.97, 0.92, 0.78)
const CHERRY := Color(0.72, 0.12, 0.14)
const WOOD := Color(0.5, 0.33, 0.2)

## Stick input: x = right, y = back (-1 = forward, like rolling).
var steer := Vector2.ZERO
## The ball flying it, or null.
var pilot: Marble

var _park: Transform3D       # where it waits (hub space)
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _speed := 0.0
var _boost := 0.0
var _flying := 0.0           # seconds since take-off
var _prop: Node3D
var _hub: Node3D


## Build the plane and park it at `at` (hub space) facing `yaw`.
func build(hub: Node3D, at: Vector3, yaw: float) -> void:
	_hub = hub
	_park = Transform3D(Basis(Vector3.UP, yaw), at)
	transform = _park
	_model()
	# Roll into the cockpit to climb in.
	LowPoly.marble_zone(self, Vector3(1.4, 1.4, 1.6), Vector3(0, 0.7, 0.4), _board)
	var sign := LowPoly.label(self, Vector3(0, 2.6, 0.6), "FLY ME!", 48, Color(0.35, 0.05, 0.05), 0.0, true)
	sign.modulate = CREAM
	sign.name = "Sign"


## The plane's own model: cream fuselage with cherry trim, two wings with
## struts, a tail, wheels and a spinning wooden propeller. Nose is -Z.
func _model() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	LowPoly.box(body, Vector3(0.8, 0.75, 3.2), Vector3(0, 0.95, 0.2), CREAM)
	LowPoly.box(body, Vector3(0.82, 0.18, 3.22), Vector3(0, 0.95, 0.2), CHERRY)
	var cowl := LowPoly.cyl(body, 0.42, 0.45, 0.35, Vector3(0, 0.95, -1.5), CHERRY, 10)
	cowl.rotation.x = PI / 2
	# Cockpit hole (dark) where the ball sits.
	LowPoly.box(body, Vector3(0.62, 0.05, 0.8), Vector3(0, 1.33, 0.25), Color(0.12, 0.08, 0.08))
	LowPoly.box(body, Vector3(0.66, 0.25, 0.06), Vector3(0, 1.45, -0.18), Color(0.75, 0.9, 1.0))  # windscreen
	# Wings, upper and lower, with struts.
	for y in [0.62, 1.95]:
		LowPoly.box(body, Vector3(4.6, 0.08, 0.95), Vector3(0, y, -0.55), CHERRY if y > 1.0 else CREAM)
	for x in [-1.7, 1.7]:
		for z in [-0.9, -0.2]:
			LowPoly.box(body, Vector3(0.05, 1.3, 0.05), Vector3(x, 1.28, z), WOOD)
	# Tail: a fin and a little wing.
	LowPoly.box(body, Vector3(1.6, 0.06, 0.6), Vector3(0, 1.05, 1.65), CREAM)
	LowPoly.box(body, Vector3(0.06, 0.7, 0.6), Vector3(0, 1.4, 1.65), CHERRY)
	# Wheels.
	for x in [-0.55, 0.55]:
		LowPoly.box(body, Vector3(0.05, 0.5, 0.05), Vector3(x, 0.4, -0.6), WOOD)
		var wheel := LowPoly.cyl(body, 0.2, 0.2, 0.1, Vector3(x, 0.2, -0.6), Color(0.15, 0.15, 0.15), 10)
		wheel.rotation.z = PI / 2
	# Propeller on the nose.
	_prop = Node3D.new()
	_prop.position = Vector3(0, 0.95, -1.72)
	body.add_child(_prop)
	LowPoly.box(_prop, Vector3(1.5, 0.12, 0.04), Vector3.ZERO, WOOD)
	LowPoly.ball(_prop, Vector3(0, 0, -0.05), 0.1, CREAM, 6)


func _board(m: Marble) -> void:
	if pilot != null or m.freeze:
		return
	if _hub.get("mirror") or not (_hub.get("marbles") as Array).has(m):
		return
	pilot = m
	m.freeze = true
	m.linear_velocity = Vector3.ZERO
	_yaw = rotation.y
	_pitch = 0.0
	_speed = 4.0
	_flying = 0.0
	_boost = 0.0
	steer = Vector2.ZERO
	(get_node("Sign") as Node3D).visible = false
	boarded.emit(m)


## A burst of speed.
func boost() -> void:
	if pilot:
		_boost = 1.5


## Hop out: the ball lands back on the lookout and the plane goes home.
func bail() -> void:
	if pilot == null:
		return
	var m := pilot
	pilot = null
	transform = _park
	(get_node("Body") as Node3D).rotation = Vector3.ZERO
	(get_node("Sign") as Node3D).visible = true
	if not is_instance_valid(m):
		return
	m.global_position = _hub.to_global(_park.origin + _park.basis.z * 3.2 + Vector3.UP * 0.6)
	m.freeze = false
	m.linear_velocity = Vector3.ZERO
	m.angular_velocity = Vector3.ZERO
	left_plane.emit(m)


func update(delta: float) -> void:
	_prop.rotate_z(delta * (40.0 if pilot else 0.0))
	if pilot == null:
		return
	if not is_instance_valid(pilot):
		bail()
		return
	_flying += delta
	_boost = maxf(_boost - delta, 0.0)
	var want_speed := BOOST_SPEED if _boost > 0.0 else SPEED
	_speed = move_toward(_speed, want_speed, delta * 8.0)
	# Steering: turn with left/right, pitch with forward/back.
	var turn := steer.x
	var want_pitch := steer.y * PITCH_MAX
	var pos := position
	if _flying < TAKEOFF_TIME:
		want_pitch = 0.5   # climb away from the islet
	else:
		# Keep it in the sky: pull up when low, nose down when too high.
		if pos.y < MIN_HEIGHT:
			want_pitch = maxf(want_pitch, clampf((MIN_HEIGHT - pos.y) * 0.15, 0.0, PITCH_MAX))
		elif pos.y > MAX_HEIGHT:
			want_pitch = minf(want_pitch, -0.2)
		# Too far out: the plane turns itself back toward the island.
		if Vector2(pos.x, pos.z).length() > MAX_RANGE:
			var off := angle_difference(_yaw, atan2(pos.x, pos.z))
			if absf(off) > 0.15:
				turn = -signf(off)
	_yaw -= turn * TURN_RATE * delta
	_pitch = lerpf(_pitch, want_pitch, clampf(delta * 3.0, 0.0, 1.0))
	_roll = lerpf(_roll, -turn * 0.6, clampf(delta * 4.0, 0.0, 1.0))
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	pos += -b.z * _speed * delta
	transform = Transform3D(b, pos)
	(get_node("Body") as Node3D).rotation.z = _roll
	# The ball sits in the cockpit.
	pilot.global_position = to_global(Vector3(0, 1.45, 0.25))


## Back on the ground (leaving the hub).
func reset() -> void:
	if pilot:
		bail()
	transform = _park
