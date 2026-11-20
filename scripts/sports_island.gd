class_name SportsIsland
extends Node3D

## A goal went in (`team` is who scored). main.gd hands out achievements and,
## online, tells everyone else to show it too.
signal goal_scored(team: String)
## A marble dropped through the hoop.
signal basket_made(player: int)
## The sports island, joined to the east side of the practice island by a
## bridge. Built in code the first time the practice island is opened.
##
## What's on it:
##   - a little soccer pitch with a big ball and two goals. Push the ball
##     into a goal with your marble. The scoreboard keeps BLUE vs ORANGE:
##     BLUE scores in the orange goal and ORANGE in the blue goal.
##   - a trampoline set into the ground. Roll onto it and it throws your
##     marble at the basketball hoop. Sink it for a shower of confetti.
##
## Everything here is just for fun: no coins, nothing is saved.

const RADIUS := 19.0

## Soccer pitch: middle, half length (along x) and half width (along z).
const PITCH := Vector3(0, 0, -6.5)
const PITCH_HALF := Vector2(8.5, 5.0)
const GOAL_HALF_WIDTH := 1.6
const BALL_RADIUS := 0.55
## The trampoline, and the hoop it aims at (rim middle).
const TRAMPOLINE := Vector3(9, 0, 11)
const RIM := Vector3(9, 3.2, 5.9)
const RIM_RADIUS := 0.62
## How long a throw takes from the trampoline to the hoop, in seconds.
const FLIGHT_TIME := 1.1

const GRASS := Color(0.36, 0.66, 0.3)
const BLUE := Color(0.3, 0.6, 1.0)
const ORANGE := Color(1.0, 0.55, 0.2)
const WOOD := Color(0.62, 0.45, 0.3)

var score := {"blue": 0, "orange": 0}
var baskets := 0

var _ball: RigidBody3D
var _board: Label3D
var _shout: Label3D
var _shout_time := 0.0
var _hoop_label: Label3D
var _reset_wait := -1.0
var _cooldown := {}   # marble -> seconds before the trampoline throws it again
var _basket_wait := {}  # marble -> seconds before it can score another basket
var _tramp_mat: StandardMaterial3D
var _tramp_squash := 0.0
var _rng := RandomNumberGenerator.new()


## Build everything. `bridge_from_x` is where the bridge starts on the
## practice island's edge, in this island's own coordinates.
func build(bridge_from_x: float) -> void:
	_rng.seed = 77
	_island()
	_fence()
	_pitch()
	_scoreboard()
	_make_ball()
	_trampoline()
	_hoop()
	_scenery()
	_entrance(bridge_from_x)


## Where a marble pops back up if it falls off this island.
func spawn_point() -> Vector3:
	return to_global(Vector3(-RADIUS + 3.0, 0.5, 0))


## Called every physics tick while the practice island is open.
func update(delta: float) -> void:
	for timers in [_cooldown, _basket_wait]:
		for m in timers.keys():
			timers[m] -= delta
			if timers[m] <= 0.0:
				timers.erase(m)
	_tramp_squash = maxf(_tramp_squash - delta * 4.0, 0.0)
	if _shout_time > 0.0:
		_shout_time -= delta
		_shout.modulate.a = clampf(_shout_time * 2.0, 0.0, 1.0)
		_shout.scale = Vector3.ONE * (1.0 + maxf(_shout_time - 1.2, 0.0))
	if _reset_wait >= 0.0:
		_reset_wait -= delta
		if _reset_wait < 0.0:
			_kick_off()
	# The ball fell off or got stuck outside the pitch: put it back.
	var local := to_local(_ball.global_position) - PITCH
	if local.y < -4.0 or absf(local.x) > PITCH_HALF.x + 4.0 or absf(local.z) > PITCH_HALF.y + 4.0:
		_kick_off()


# ------------------------------------------------------------ Soccer

func _kick_off() -> void:
	_reset_wait = -1.0
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO
	_ball.global_position = to_global(PITCH + Vector3(0, BALL_RADIUS + 1.2, 0))


func _on_goal(team: String) -> void:
	if _reset_wait >= 0.0:
		return  # already scored, the ball is just rolling about in the net
	score[team] += 1
	show_goal(team, score)
	_reset_wait = 2.0
	goal_scored.emit(team)


## The GOAL! shout, confetti and new score (also run on online guests,
## who see the host's game).
func show_goal(team: String, new_score: Dictionary) -> void:
	score = new_score.duplicate()
	_refresh_board()
	var color: Color = BLUE if team == "blue" else ORANGE
	_say("GOAL!", color)
	LowPoly.confetti(self, _ball.global_position + Vector3.UP * 0.5, 90)


## Online guests: the ball is moved by the host, so it doesn't fall or
## bump into anything here.
func set_mirror(on: bool) -> void:
	_ball.freeze = on
	_ball.collision_layer = 0 if on else 4


func ball() -> RigidBody3D:
	return _ball


func _refresh_board() -> void:
	_board.text = "BLUE  %d  -  %d  ORANGE" % [score.blue, score.orange]


func _say(text: String, color: Color) -> void:
	_shout.text = text
	_shout.modulate = color
	_shout_time = 1.8


func _pitch() -> void:
	# Mown stripes, then the white lines on top.
	var stripes := 8
	var w := PITCH_HALF.x * 2.0 / stripes
	for k in stripes:
		var x := -PITCH_HALF.x + (k + 0.5) * w
		var col := GRASS.lightened(0.12) if k % 2 == 0 else GRASS.lightened(0.04)
		LowPoly.box(self, Vector3(w, 0.04, PITCH_HALF.y * 2.0), PITCH + Vector3(x, 0.02, 0), col)
	var line := Color(0.97, 0.97, 0.95)
	var y := 0.05
	for side in [-1.0, 1.0]:
		LowPoly.box(self, Vector3(PITCH_HALF.x * 2.0, 0.02, 0.1), PITCH + Vector3(0, y, side * (PITCH_HALF.y - 0.1)), line)
		LowPoly.box(self, Vector3(0.1, 0.02, PITCH_HALF.y * 2.0), PITCH + Vector3(side * (PITCH_HALF.x - 0.1), y, 0), line)
		# The box in front of each goal.
		var bx: float = side * (PITCH_HALF.x - 1.6)
		LowPoly.box(self, Vector3(0.1, 0.02, 4.4), PITCH + Vector3(bx, y, 0), line)
		for z in [-2.2, 2.2]:
			LowPoly.box(self, Vector3(1.5, 0.02, 0.1), PITCH + Vector3(side * (PITCH_HALF.x - 0.85), y, z), line)
	LowPoly.box(self, Vector3(0.1, 0.02, PITCH_HALF.y * 2.0), PITCH + Vector3(0, y, 0), line)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.55
	torus.rings = 24
	torus.ring_segments = 3
	ring.mesh = torus
	ring.material_override = LowPoly.mat(line)
	ring.scale = Vector3(1, 0.1, 1)
	ring.position = PITCH + Vector3(0, y, 0)
	add_child(ring)

	# Low boards all round, with an opening in the middle of each long side
	# so marbles can roll in. You can hop the boards too.
	var board_h := 0.45
	var gap := 1.2
	for side in [-1.0, 1.0]:
		var z: float = side * (PITCH_HALF.y + 0.1)
		for half in [-1.0, 1.0]:
			var length := PITCH_HALF.x - gap
			var x: float = half * (gap + length / 2.0)
			_board_piece(Vector3(length, board_h, 0.15), PITCH + Vector3(x, board_h / 2.0, z), side)
		# The end boards either side of each goal.
		var x_end: float = side * (PITCH_HALF.x + 0.1)
		var end_len := PITCH_HALF.y - GOAL_HALF_WIDTH
		for half in [-1.0, 1.0]:
			_board_piece(Vector3(0.15, board_h, end_len), PITCH + Vector3(x_end, board_h / 2.0, half * (GOAL_HALF_WIDTH + end_len / 2.0)), side)
	_goal(-1.0, "orange", BLUE)    # the blue goal, on the left: orange scores here
	_goal(1.0, "blue", ORANGE)     # the orange goal, on the right


func _board_piece(size: Vector3, pos: Vector3, side: float) -> void:
	LowPoly.box(self, size, pos, Color.WHITE if side < 0.0 else Color(0.95, 0.93, 0.88))
	LowPoly.box(self, Vector3(size.x + 0.02, 0.08, size.z + 0.02), pos + Vector3.UP * size.y * 0.25,
			Color(0.95, 0.3, 0.3))
	LowPoly.solid_box(self, size, pos, 0.0, 0.5)


## A goal at one end. `side` -1 left, +1 right. A ball inside it scores
## for `team`.
func _goal(side: float, team: String, color: Color) -> void:
	var x: float = side * (PITCH_HALF.x + 0.9)
	var depth := 1.6
	var h := 1.5
	var post := Color(0.97, 0.97, 0.97)
	for z in [-GOAL_HALF_WIDTH, GOAL_HALF_WIDTH]:
		LowPoly.box(self, Vector3(0.14, h, 0.14), PITCH + Vector3(side * PITCH_HALF.x, h / 2.0, z), post)
		LowPoly.solid_box(self, Vector3(0.14, h, 0.14), PITCH + Vector3(side * PITCH_HALF.x, h / 2.0, z))
		# Side panels of the net.
		LowPoly.box(self, Vector3(depth, h, 0.05), PITCH + Vector3(x, h / 2.0, z), color.lightened(0.2))
		LowPoly.solid_box(self, Vector3(depth, h, 0.1), PITCH + Vector3(x, h / 2.0, z))
	LowPoly.box(self, Vector3(0.14, 0.14, GOAL_HALF_WIDTH * 2.0 + 0.14), PITCH + Vector3(side * PITCH_HALF.x, h, 0), post)
	# Back and roof of the net, tinted in the goal's colour.
	LowPoly.box(self, Vector3(0.05, h, GOAL_HALF_WIDTH * 2.0), PITCH + Vector3(x + side * depth / 2.0, h / 2.0, 0), color)
	LowPoly.solid_box(self, Vector3(0.1, h, GOAL_HALF_WIDTH * 2.0), PITCH + Vector3(x + side * depth / 2.0, h / 2.0, 0))
	LowPoly.box(self, Vector3(depth, 0.05, GOAL_HALF_WIDTH * 2.0), PITCH + Vector3(x, h, 0), color.lightened(0.2))
	LowPoly.solid_box(self, Vector3(depth, 0.1, GOAL_HALF_WIDTH * 2.0), PITCH + Vector3(x, h, 0))
	LowPoly.box(self, Vector3(depth, 0.03, GOAL_HALF_WIDTH * 2.0), PITCH + Vector3(x, 0.03, 0), color.darkened(0.1))
	# The scoring zone: just behind the goal line.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(depth - 0.2, h - 0.1, GOAL_HALF_WIDTH * 2.0 - 0.2)
	shape.shape = b
	area.add_child(shape)
	area.position = PITCH + Vector3(x + side * 0.15, h / 2.0, 0)
	add_child(area)
	area.body_entered.connect(func(body):
		if body == _ball:
			_on_goal(team))


func _make_ball() -> void:
	_ball = RigidBody3D.new()
	_ball.name = "SoccerBall"
	_ball.mass = 0.6
	_ball.collision_layer = 4
	_ball.collision_mask = 7
	_ball.linear_damp = 0.4
	_ball.angular_damp = 0.6
	_ball.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55
	pm.friction = 0.6
	_ball.physics_material_override = pm
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	shape.shape = sphere
	_ball.add_child(shape)
	# White ball with dark patches, low-poly like everything else.
	LowPoly.ball(_ball, Vector3.ZERO, BALL_RADIUS, Color(0.97, 0.97, 0.97), 12)
	var patch := Color(0.12, 0.12, 0.16)
	for dir in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
			Vector3(1, 1, 1), Vector3(-1, 1, -1), Vector3(1, -1, -1), Vector3(-1, -1, 1)]:
		var spot := LowPoly.cyl(_ball, 0.17, 0.17, 0.06, Vector3.ZERO, patch, 5)
		var n: Vector3 = dir.normalized()
		spot.basis = Basis.looking_at(n, Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI / 2.0)
		spot.position = n * (BALL_RADIUS - 0.015)
	add_child(_ball)
	_kick_off()


func _scoreboard() -> void:
	var at := PITCH + Vector3(0, 0, -PITCH_HALF.y - 2.2)
	for x in [-2.6, 2.6]:
		LowPoly.box(self, Vector3(0.25, 3.4, 0.25), at + Vector3(x, 1.7, 0), Color(0.3, 0.3, 0.35))
	LowPoly.box(self, Vector3(6.0, 1.5, 0.3), at + Vector3(0, 3.4, 0), Color(0.12, 0.13, 0.18))
	LowPoly.box(self, Vector3(6.2, 0.18, 0.4), at + Vector3(0, 4.2, 0), Color(1.0, 0.8, 0.25))
	LowPoly.box(self, Vector3(1.0, 1.5, 0.32), at + Vector3(-2.5, 3.4, 0.01), BLUE.darkened(0.2))
	LowPoly.box(self, Vector3(1.0, 1.5, 0.32), at + Vector3(2.5, 3.4, 0.01), ORANGE.darkened(0.2))
	_board = LowPoly.label(self, at + Vector3(0, 3.45, 0.17), "", 50, Color(0.05, 0.05, 0.1))
	_board.modulate = Color(1.0, 0.95, 0.75)
	_refresh_board()
	_shout = LowPoly.label(self, PITCH + Vector3(0, 2.6, 0), "", 150, Color(0.05, 0.05, 0.1), 0.0, true)
	_shout.no_depth_test = true
	_shout.modulate.a = 0.0
	LowPoly.label(self, at + Vector3(0, 4.6, 0.1), "SOCCER", 56, Color(0.1, 0.25, 0.1))


# ------------------------------------------------------------ Basketball

## A trampoline sunk into the ground: roll onto it and it throws you at
## the hoop.
func _trampoline() -> void:
	var at := TRAMPOLINE
	LowPoly.cyl(self, 1.35, 1.35, 0.06, at + Vector3.UP * 0.03, Color(0.95, 0.35, 0.35), 20)
	var mat := LowPoly.cyl(self, 1.1, 1.1, 0.07, at + Vector3.UP * 0.04, Color(0.2, 0.25, 0.35), 20)
	_tramp_mat = LowPoly.own_mat(mat)
	LowPoly.cyl(self, 0.55, 0.55, 0.075, at + Vector3.UP * 0.042, Color(0.3, 0.6, 1.0), 16)
	for k in 10:
		var a := TAU * k / 10.0
		LowPoly.box(self, Vector3(0.12, 0.08, 0.25), at + Vector3(cos(a), 0, sin(a)) * 1.23 + Vector3.UP * 0.05,
				Color(0.97, 0.97, 0.97), -a)
	LowPoly.marble_zone(self, Vector3(2.0, 0.6, 2.0), at + Vector3.UP * 0.3, _launch)
	var jump := LowPoly.label(self, at + Vector3(0, 0.08, 1.9), "JUMP!", 60, Color(0.4, 0.05, 0.05))
	jump.rotation.x = -PI / 2.0


func _launch(m: Marble) -> void:
	if _cooldown.has(m) or m.freeze:
		return
	_cooldown[m] = 0.8
	_tramp_squash = 1.0
	# Work out the throw that drops the marble through the hoop, then add a
	# little wobble so it isn't a sure thing.
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity") * m.gravity_scale
	var target := to_global(RIM + Vector3(_rng.randf_range(-0.55, 0.55), 0.25, _rng.randf_range(-0.5, 0.55)))
	var from := m.global_position
	var t := FLIGHT_TIME
	var v := (target - from) / t + Vector3.UP * 0.5 * g * t
	m.linear_velocity = v
	m.angular_velocity = Vector3.ZERO
	m.no_steer_time = t + 0.3
	_poof_ring(to_global(TRAMPOLINE + Vector3.UP * 0.1))


func _hoop() -> void:
	var post := Color(0.3, 0.3, 0.35)
	# The hoop faces +Z (towards the trampoline), so its board and post
	# stand behind it on the -Z side.
	var base := RIM + Vector3(0, 0, -1.4)
	LowPoly.cyl(self, 0.12, 0.14, RIM.y + 1.0, Vector3(base.x, (RIM.y + 1.0) / 2.0, base.z), post, 8)
	LowPoly.solid_cyl(self, 0.14, RIM.y + 1.0, Vector3(base.x, (RIM.y + 1.0) / 2.0, base.z))
	LowPoly.box(self, Vector3(0.12, 0.12, 0.8), Vector3(base.x, RIM.y + 0.6, base.z + 0.4), post)
	# Backboard with a red square.
	var board := RIM + Vector3(0, 0.6, -0.85)
	LowPoly.box(self, Vector3(2.2, 1.5, 0.1), board, Color(0.97, 0.97, 0.97))
	LowPoly.box(self, Vector3(0.8, 0.6, 0.11), board + Vector3(0, -0.25, 0.005), Color(0.95, 0.3, 0.25))
	LowPoly.box(self, Vector3(0.62, 0.44, 0.12), board + Vector3(0, -0.25, 0.01), Color(0.97, 0.97, 0.97))
	LowPoly.solid_box(self, Vector3(2.2, 1.5, 0.12), board, 0.0, 0.4)
	LowPoly.box(self, Vector3(0.08, 0.08, 0.3), RIM + Vector3(0, 0, -RIM_RADIUS - 0.12), Color(1.0, 0.45, 0.1))
	# The rim: an orange ring with small solid bumps round it to rattle off.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RIM_RADIUS - 0.04
	torus.outer_radius = RIM_RADIUS + 0.04
	torus.rings = 16
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = LowPoly.mat(Color(1.0, 0.45, 0.1))
	rim.position = RIM
	add_child(rim)
	for k in 12:
		var a := TAU * k / 12.0
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.05
		shape.shape = s
		body.add_child(shape)
		body.position = RIM + Vector3(cos(a), 0, sin(a)) * RIM_RADIUS
		add_child(body)
	# A see-through net hanging under the rim.
	var net := LowPoly.cyl(self, RIM_RADIUS, RIM_RADIUS * 0.6, 0.6, RIM + Vector3.DOWN * 0.3, Color.WHITE, 12)
	var nm := LowPoly.own_mat(net)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.albedo_color = Color(1, 1, 1, 0.45)
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	(net.mesh as CylinderMesh).cap_top = false
	(net.mesh as CylinderMesh).cap_bottom = false
	# Through the hoop (going down) = a basket.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RIM_RADIUS - 0.15
	cyl.height = 0.2
	shape.shape = cyl
	area.add_child(shape)
	area.position = RIM + Vector3.DOWN * 0.35
	add_child(area)
	area.body_entered.connect(func(body):
		if body is Marble and body.linear_velocity.y < 0.0:
			_basket(body))
	_hoop_label = LowPoly.label(self, board + Vector3(0, 1.1, 0), "", 48, Color(0.35, 0.1, 0.0), 0.0, true)
	_refresh_hoop()


func _basket(m: Marble) -> void:
	if _basket_wait.has(m):
		return
	_basket_wait[m] = 1.0
	baskets += 1
	show_basket(baskets)
	m.wince(4.0)
	basket_made.emit(m.player_id)


## The SWISH!, confetti and new count (also run on online guests).
func show_basket(count: int) -> void:
	baskets = count
	_refresh_hoop()
	LowPoly.confetti(self, to_global(RIM + Vector3.UP * 0.4))
	_say_at_hoop()


func _refresh_hoop() -> void:
	_hoop_label.text = "BASKETS  %d" % baskets


func _say_at_hoop() -> void:
	var swish := LowPoly.label(self, RIM + Vector3(0, 1.0, 0.5), "SWISH!", 110, Color(0.4, 0.1, 0.0), 0.0, true)
	swish.modulate = Color(1.0, 0.75, 0.25)
	swish.no_depth_test = true
	var tw := swish.create_tween()
	tw.tween_property(swish, "position:y", swish.position.y + 1.2, 1.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(swish, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.tween_callback(swish.queue_free)


func _poof_ring(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = LowPoly.mat(Color(0.75, 0.88, 1.0))
	p.mesh = mesh
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _process(_delta: float) -> void:
	if _tramp_mat:
		# The mat flashes and dips when it throws someone.
		_tramp_mat.albedo_color = Color(0.2, 0.25, 0.35).lerp(Color(0.5, 0.8, 1.0), _tramp_squash)


# ------------------------------------------------------------ The island

func _island() -> void:
	var body := LowPoly.solid_cyl(self, RADIUS, 2.0, Vector3.DOWN, 0.1)
	(body.physics_material_override as PhysicsMaterial).friction = 0.7
	LowPoly.cyl(self, RADIUS, RADIUS - 0.3, 0.4, Vector3(0, -0.2, 0), GRASS, 32)
	LowPoly.cyl(self, RADIUS - 0.3, RADIUS - 1.6, 1.8, Vector3(0, -1.3, 0), Color(0.55, 0.38, 0.24), 32)
	var rock := Color(0.48, 0.44, 0.42)
	LowPoly.cyl(self, RADIUS - 1.6, RADIUS * 0.5, 4.0, Vector3(0, -4.2, 0), rock, 10)
	LowPoly.cyl(self, RADIUS * 0.5, 2.0, 7.0, Vector3(0, -9.7, 0), rock.darkened(0.15), 8)


func _fence() -> void:
	# A low fence round the edge with an opening for the bridge (west).
	var n := 48
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (RADIUS - 0.6)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (RADIUS - 0.6)
		if i == 23 or i == 24:
			continue  # the bridge comes in here
		LowPoly.box(self, Vector3(0.14, 0.7, 0.14), p0 + Vector3.UP * 0.35, WOOD)
		var mid := (p0 + p1) / 2.0
		var yaw := atan2(p1.x - p0.x, p1.z - p0.z)
		var length := p0.distance_to(p1)
		LowPoly.box(self, Vector3(0.08, 0.1, length), mid + Vector3.UP * 0.5, WOOD.lightened(0.1), yaw)
		LowPoly.solid_box(self, Vector3(0.12, 0.55, length), mid + Vector3.UP * 0.28, yaw)


## An arch where the bridge arrives, saying where you are.
func _entrance(bridge_from_x: float) -> void:
	var at := Vector3(-RADIUS + 1.6, 0, 0)
	for z in [-1.8, 1.8]:
		LowPoly.box(self, Vector3(0.35, 3.2, 0.35), at + Vector3(0, 1.6, z), Color(0.97, 0.95, 0.9))
	LowPoly.box(self, Vector3(0.5, 0.8, 4.2), at + Vector3(0, 3.3, 0), BLUE)
	LowPoly.label(self, at + Vector3(-0.27, 3.3, 0), "SPORTS", 72, Color(0.05, 0.15, 0.4), -PI / 2.0)
	LowPoly.label(self, at + Vector3(0.27, 3.3, 0), "SPORTS", 72, Color(0.05, 0.15, 0.4), PI / 2.0)
	# Pennants along the top.
	for k in 6:
		var flag := LowPoly.box(self, Vector3(0.05, 0.4, 0.4), at + Vector3(0, 2.75, -1.25 + k * 0.5),
				ORANGE if k % 2 == 0 else Color(1.0, 0.85, 0.3))
		flag.rotation.x = PI / 4.0
	# A sign on the practice island side of the bridge, pointing over.
	var sign_at := Vector3(bridge_from_x - 2.0, 0, -2.2)
	LowPoly.box(self, Vector3(0.15, 1.6, 0.15), sign_at + Vector3(0, 0.8, 0), WOOD.darkened(0.2))
	LowPoly.box(self, Vector3(0.1, 0.7, 2.4), sign_at + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.35))
	LowPoly.label(self, sign_at + Vector3(-0.06, 1.5, 0), "SPORTS  >", 40, Color(0.35, 0.2, 0.0), -PI / 2.0)


func _scenery() -> void:
	# Bleachers beside the pitch, a few trees, cones and a ball rack.
	for row in 3:
		LowPoly.box(self, Vector3(7.0, 0.3, 0.6), PITCH + Vector3(0, 0.15 + row * 0.3, PITCH_HALF.y + 1.4 + row * 0.6),
				[BLUE, Color(0.97, 0.97, 0.97), ORANGE][row])
		LowPoly.solid_box(self, Vector3(7.0, 0.3 + row * 0.6, 0.6), PITCH + Vector3(0, (0.3 + row * 0.6) / 2.0, PITCH_HALF.y + 1.4 + row * 0.6))
	for at in [Vector3(12, 0, -12), Vector3(14, 0, 4), Vector3(-12, 0, -11), Vector3(-4, 0, 14), Vector3(-10, 0, 12)]:
		var h := _rng.randf_range(2.2, 3.2)
		LowPoly.cyl(self, 0.15, 0.25, h, at + Vector3.UP * h / 2.0, Color(0.45, 0.3, 0.18), 6)
		LowPoly.ball(self, at + Vector3.UP * (h + 0.6), _rng.randf_range(1.1, 1.5), GRASS.lerp(Color(0.5, 0.7, 0.3), _rng.randf()))
		LowPoly.solid_cyl(self, 0.25, h, at + Vector3.UP * h / 2.0)
	for k in 4:
		var at := TRAMPOLINE + Vector3(-3.0 + k * 2.0, 0, -2.0)
		if k == 1 or k == 2:
			continue
		var cone := LowPoly.cyl(self, 0.03, 0.22, 0.5, at + Vector3.UP * 0.25, Color(1.0, 0.5, 0.1), 8)
		LowPoly.cyl(cone, 0.12, 0.16, 0.08, Vector3.ZERO, Color.WHITE, 8)
	LowPoly.label(self, TRAMPOLINE + Vector3(-3.2, 2.0, 0), "HOOPS", 56, Color(0.4, 0.15, 0.0), 0.0, true)
