class_name Biplane
extends Node3D
## A little vintage biplane parked on the lookout islet. Roll into it and
## your ball hops into the cockpit and takes off; then fly round the island:
##   left / right   turn
##   forward / back nose down / nose up
##   place key      a burst of speed
##   turn key       hop out (you land back on the lookout)
## It flies itself at a steady speed and won't go too low or too far, so
## you can't crash it.
##
## SKY RINGS: eight big rings float in a loop round the island. Fly through
## them in order (the next one glows gold, with an arrow on the plane
## pointing to it) for a little race against the clock. Clearing all eight
## pays RING_COINS.
##
## Built by hub.gd in the hub's space (this node's parent is the hub). The
## hub calls update() every physics tick; main.gd sets `steer` and calls
## boost() and bail() for whoever is flying.

## Fired when a ball climbs in, and when it hops out.
signal boarded(m: Marble)
signal left_plane(m: Marble)
## Fired when the pilot clears the last ring: how long the lap took.
signal rings_finished(m: Marble, seconds: float)

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
## The ring course: how many rings, their size and where they float
## (a loop this far from the middle of the hub, about this high).
const RING_COUNT := 8
const RING_RADIUS := 5.0
const RING_LOOP := 60.0
const RING_HEIGHT := 32.0
const RING_COINS := 20
const RING_GOLD := Color(1.0, 0.8, 0.25)
const RING_DIM := Color(0.55, 0.85, 1.0)

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
## Ring race: rings (hub space), which ring is next (-1 = not racing yet,
## so ring 0 is next and starts the clock), seconds since ring 0.
var rings: Array = []
var ring_next := 0
var ring_time := -1.0
var best_lap := 0.0
var _ring_mats: Array = []
var _pointer: MeshInstance3D


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
	_build_rings()


## Where ring `k` floats (hub space) and which way it faces (along the loop).
static func ring_xform(k: int) -> Transform3D:
	# Starts just north of the lookout and goes round anticlockwise seen
	# from above, rising and dipping as it goes.
	var a := -PI / 2.0 - TAU * k / RING_COUNT
	var at := Vector3(cos(a) * RING_LOOP, RING_HEIGHT + sin(a * 2.0) * 7.0 + (k % 2) * 3.0, sin(a) * RING_LOOP)
	var tangent := Vector3(sin(a), 0, -cos(a))
	return Transform3D(Basis.looking_at(tangent, Vector3.UP), at)


func _build_rings() -> void:
	for k in RING_COUNT:
		var xf := ring_xform(k)
		var mi := MeshInstance3D.new()
		mi.name = "Ring%d" % k
		var tm := TorusMesh.new()
		tm.inner_radius = RING_RADIUS - 0.35
		tm.outer_radius = RING_RADIUS + 0.35
		tm.rings = 28
		tm.ring_segments = 8
		mi.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = RING_DIM
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A torus lies flat; stand it up facing along the loop.
		mi.transform = Transform3D(xf.basis * Basis(Vector3.RIGHT, PI / 2.0), xf.origin)
		var num := Label3D.new()
		num.text = str(k + 1)
		num.font = LowPoly.TITLE_FONT
		num.font_size = 160
		num.pixel_size = 0.02
		num.outline_size = 24
		num.modulate = CREAM
		num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		num.position = xf.origin + Vector3.UP * (RING_RADIUS + 1.6)
		num.name = "RingNumber%d" % k
		_hub.add_child.call_deferred(mi)
		_hub.add_child.call_deferred(num)
		rings.append(xf)
		_ring_mats.append(mat)
	# An arrow on the plane's nose that points to the next ring.
	_pointer = MeshInstance3D.new()
	_pointer.name = "RingPointer"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.8
	cone.radial_segments = 8
	cone.rings = 0
	_pointer.mesh = cone
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = RING_GOLD
	_pointer.material_override = pm
	_pointer.top_level = true
	_pointer.visible = false
	add_child(_pointer)
	_show_rings()


## Light the next ring gold and dim the rest.
func _show_rings() -> void:
	for k in _ring_mats.size():
		var mat: StandardMaterial3D = _ring_mats[k]
		var next := k == ring_next and pilot != null
		mat.albedo_color = Color(RING_GOLD, 0.95) if next else Color(RING_DIM, 0.45 if pilot else 0.3)


## "RINGS 3/8  12.4s" while racing, or "" (for the HUD).
func race_text() -> String:
	if pilot == null:
		return ""
	var t := "SKY RINGS  %d/%d" % [maxi(ring_next, 0), RING_COUNT]
	if ring_time >= 0.0:
		t += "  %.1fs" % ring_time
	else:
		t += "  (fly through ring 1)"
	if best_lap > 0.0:
		t += "  BEST %.1fs" % best_lap
	return t


## Did the plane fly through ring `k` going from `a` to `b` (hub space)?
func _through(k: int, a: Vector3, b: Vector3) -> bool:
	var xf: Transform3D = rings[k]
	var n := -xf.basis.z
	var da := (a - xf.origin).dot(n)
	var db := (b - xf.origin).dot(n)
	if signf(da) == signf(db) and da != 0.0:
		return false
	var t := da / (da - db) if da != db else 0.0
	var hit := a.lerp(b, t)
	return hit.distance_to(xf.origin) < RING_RADIUS + 0.6


func _update_rings(delta: float, from: Vector3, to: Vector3) -> void:
	if ring_time >= 0.0:
		ring_time += delta
	if _through(ring_next, from, to):
		var at: Vector3 = _hub.to_global((rings[ring_next] as Transform3D).origin)
		if ring_next == 0:
			ring_time = 0.0
		ring_next += 1
		if ring_next >= RING_COUNT:
			var lap := ring_time
			if best_lap <= 0.0 or lap < best_lap:
				best_lap = lap
			PopText.spawn(_hub, at, "LAP! %.1fs" % lap, RING_GOLD, 2.2)
			LowPoly.confetti(_hub, _hub.to_local(at), 60)
			rings_finished.emit(pilot, lap)
			ring_next = 0
			ring_time = -1.0
		else:
			PopText.spawn(_hub, at, "%d / %d" % [ring_next, RING_COUNT], RING_GOLD, 2.0)
		_show_rings()
	# The arrow floats over the nose and points at the next ring.
	var aim: Vector3 = _hub.to_global((rings[ring_next] as Transform3D).origin)
	var tip := to_global(Vector3(0, 2.4, -0.6))
	_pointer.visible = true
	var dir := (aim - tip).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	# The cone points along its +Y: turn +Y onto `dir`.
	var bx := side.normalized()
	_pointer.global_transform = Transform3D(Basis(bx, dir, bx.cross(dir)), tip)


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
	ring_next = 0
	ring_time = -1.0
	_show_rings()
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
	ring_next = 0
	ring_time = -1.0
	_pointer.visible = false
	_show_rings()
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
	var was := pos
	pos += -b.z * _speed * delta
	transform = Transform3D(b, pos)
	_update_rings(delta, was, pos)
	(get_node("Body") as Node3D).rotation.z = _roll
	# The ball sits in the cockpit.
	pilot.global_position = to_global(Vector3(0, 1.45, 0.25))


## Back on the ground (leaving the hub).
func reset() -> void:
	if pilot:
		bail()
	transform = _park
