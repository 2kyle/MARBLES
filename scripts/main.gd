extends Node3D
## Runs a local match. Each frame goes:
## Before a match, everyone picks their marble's look in the locker (and
## can buy new looks with coins). Then each frame goes:
##   Draft (pick a piece from the crate) -> Build (place it on the lane)
##   -> Countdown -> Roll -> Results
## Placed pieces stay on the lane for the rest of the match.
##
## Built with online play in mind: this script (with DraftBuild) is the
## "referee". Everything that decides an outcome happens here. Player input
## only reaches the game through `_gather_inputs()` (marble lean) and
## `_gather_build_inputs()` (draft and build requests). When online play
## arrives, the host runs this script and those two functions read each
## player's input from the network instead of the keyboard.

enum State { WAITING, DRAFT, BUILD, COUNTDOWN, ROLLING, RESULTS, MATCH_OVER }

const PLAYER_COLORS := [
	Color(0.95, 0.3, 0.55),  # pink
	Color(1.0, 0.8, 0.15),   # yellow
	Color(0.7, 0.45, 0.95),  # violet
	Color(0.6, 0.95, 0.3),   # lime
]
const PLAYER_NAMES := ["Player 1", "Player 2", "Player 3", "Player 4"]
## Where each marble starts across the lane, metres from the centre.
const SPAWN_X := [-1.5, 1.5, -0.5, 0.5]

## Marbles in the match (1 to 4). Each extra player uses the next key set.
@export_range(1, 4) var player_count := 2
## Make a new random track layout at the start of every match. Turn off
## to play on the hand-drawn curve in scenes/course.tscn (Track/Path).
@export var random_track := true
## Marbles bump into each other. Press C in game to flip it.
@export var marbles_collide := true
## Frames in a match.
@export var frames_per_match := 10
## Seconds to pick a piece from the crate.
@export var draft_time := 15.0
## Seconds to place it on the lane.
@export var build_time := 30.0
## How fast build cursors glide, metres per second.
@export var cursor_speed := 7.0
## How fast draft pointers move, in cards per second.
@export var pointer_speed := 2.6
## Degrees per rotate tap (hold to keep turning).
@export var rotate_step := 15.0
## Extra pieces in the crate beyond one per player.
@export var crate_extra := 2
## Longest a roll can last, in seconds.
@export var roll_time_limit := 45.0
## After the last marble reaches the pins (or falls out), wait this long
## for pins to finish falling before scoring.
@export var settle_time := 4.0
## A marble below this height has fallen off the course (into the water).
@export var out_of_bounds_y := -3.7
## Seconds the camera watches the pins after a marble reaches them.
@export var pin_cam_time := 2.5
## A marble that barely moves for this many seconds (wedged in a corner)
## gets a little hop down the lane.
@export var stuck_time := 2.0
## A marble that hasn't got any further down the track for this many
## seconds is lifted out and put back a little further on.
@export var rescue_time := 6.0
## Seconds a marble sits still after falling into a gap in the track.
@export var missed_jump_wait := 1.5

## Who the rolling camera keeps on screen. ALL_MARBLES frames every marble
## still rolling (couch play). ONE_MARBLE follows only `camera_player`'s
## marble, for online play where each screen shows its own player.
enum CameraFollow { ALL_MARBLES, ONE_MARBLE }
@export var camera_follow := CameraFollow.ALL_MARBLES
@export var camera_player := 0
## How hard big crashes and landings shake the camera (0 = never).
@export_range(0.0, 2.0) var camera_shake := 1.0

## When each player last missed a jump (roll time), for the HUD.
var missed_jumps: Array = []

@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")

var state := State.WAITING
## Coins, bought looks and equipped looks for each seat (saved to disk).
var profiles := Profiles.new()
## Each player's marble colour this match (from their locker choice).
var player_colors: Array = PLAYER_COLORS.duplicate()
## Locker screen: which row (color/style/trail) each player is on, and the
## item they're looking at in that row (may not be bought yet).
var locker_row: Array = [0, 0, 0, 0]
var locker_browse: Array = [{}, {}, {}, {}]
var locker_message: Array = ["", "", "", ""]
## Coins each player earned in the last frame / match, for the scoreboard.
var coins_earned: Array = [0, 0, 0, 0]
var match_coins: Array = [0, 0, 0, 0]
var frame := 1
var totals: Array = []
var marbles: Array[Marble] = []
var arrival_order: Array = []
var sweep_player := -1
var last_result: Dictionary = {}
## Points each player scored in each finished frame: frame_points[frame][player].
var frame_points: Array = []

var _countdown := 0.0
var _phase_left := 0.0
var _roll_time := 0.0
var _settle_left := 0.0
var _settling := false
var _overhead_camera := false
var _last_arrival_time := -100.0
var _rng := RandomNumberGenerator.new()
var _repeat := {}  # held-key repeat timers for build cursors

@onready var course: Node3D = $Course
@onready var rack: Rack = $Rack
@onready var camera: CameraRig = $Camera
@onready var hud: Hud = $Hud
@onready var arrival_line: Area3D = $Course/Deck/ArrivalLine
@onready var deck: Node3D = $Course/Deck
@onready var track: Track = $Course/Track
@onready var builder: CourseBuilder = $Course/Track/Placed
@onready var draft_build: DraftBuild = $DraftBuild


func _ready() -> void:
	Controls.setup()
	_rng.randomize()
	builder.track_reshaped.connect(_on_track_reshaped)
	rack.swept.connect(_on_rack_swept)
	arrival_line.body_entered.connect(_on_arrival_line_body_entered)
	profiles.load_from_disk()
	draft_build.setup(builder, player_count, player_colors)
	hud.thumbnails = $Thumbnails
	_new_match()


func _new_match() -> void:
	frame = 1
	totals.resize(player_count)
	totals.fill(0)
	frame_points.clear()
	last_result = {}
	builder.clear()
	if random_track:
		_new_track()
	_place_deck()
	state = State.WAITING
	match_coins = [0, 0, 0, 0]
	for p in player_count:
		locker_row[p] = 0
		locker_message[p] = ""
		locker_browse[p] = {}
		for slot in Cosmetics.SLOTS:
			locker_browse[p][slot] = profiles.equipped(p, slot)
	_refresh_colors()
	_prepare_roll()


## A fresh random track, centred over the water.
func _new_track() -> void:
	var layout := TrackGen.random_layout(_rng)
	var pts := TrackGen.points(layout)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	($Course/Decor as TrackDecor).seed = _rng.randi()
	track.apply_layout(layout, -(lo + hi) / 2.0)


func _put_marbles_at_gate() -> void:
	for m in marbles:
		var gate := track.world_frame_at(1.0, SPAWN_X[m.player_id])
		m.global_position = gate.origin + gate.basis.y * 0.32
		m.linear_velocity = Vector3.ZERO
		m.angular_velocity = Vector3.ZERO


func _on_track_reshaped() -> void:
	_place_deck()
	if state != State.ROLLING:
		_put_marbles_at_gate()
		rack.reset()


## Move the pin deck (and the rack) to wherever the track ends.
func _place_deck() -> void:
	var end := track.global_transform * track.end_transform()
	deck.global_transform = Transform3D(end.basis, end.origin + Vector3(0, -TrackGen.END_Y, 0))
	rack.global_transform = ($Course/Deck/RackSpot as Node3D).global_transform
	($Course/Decor as TrackDecor).rebuild(track, deck)


func _prepare_roll() -> void:
	## Put fresh marbles at the start gate (frozen) and a fresh rack of pins.
	for m in marbles:
		remove_child(m)
		m.queue_free()
	marbles.clear()
	arrival_order.clear()
	sweep_player = -1
	_roll_time = 0.0
	missed_jumps = []
	for i in player_count:
		missed_jumps.append(-10.0)
	_settling = false
	_last_arrival_time = -100.0

	for i in player_count:
		var m: Marble = marble_scene.instantiate()
		m.player_id = i
		m.look = profiles.look(i)
		m.preview = state == State.WAITING
		m.freeze = true
		add_child(m)
		m.set_marble_collision(marbles_collide)
		m.landed.connect(_on_marble_impact.bind(9.0))
		m.bumped.connect(_on_marble_impact.bind(7.0))
		marbles.append(m)

	_put_marbles_at_gate()
	rack.reset()
	_update_camera()
	camera.snap_to(camera.target)


# ------------------------------------------------------------ Phases

func _start_draft() -> void:
	draft_build.start_draft(player_count + crate_extra, _rng)
	_phase_left = draft_time
	state = State.DRAFT


func _start_build() -> void:
	draft_build.auto_pick_remaining()
	draft_build.start_build()
	_phase_left = build_time
	_repeat.clear()
	state = State.BUILD


func _end_build() -> void:
	draft_build.auto_place_remaining()
	draft_build.end_build()
	_start_countdown()


func _start_countdown() -> void:
	_countdown = 3.0
	state = State.COUNTDOWN


func _release_marbles() -> void:
	for m in marbles:
		m.freeze = false
	state = State.ROLLING


func _process(delta: float) -> void:
	if state == State.DRAFT or state == State.BUILD:
		_gather_build_inputs(delta)
	elif state == State.WAITING:
		_gather_locker_inputs()
	_update_camera()
	hud.refresh(self)


func _physics_process(delta: float) -> void:
	match state:
		State.DRAFT:
			_phase_left -= delta
			if _phase_left <= 0.0 or draft_build.all_picked():
				_start_build()
		State.BUILD:
			_phase_left -= delta
			if _phase_left <= 0.0 or draft_build.all_placed():
				_end_build()
		State.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				_release_marbles()
		State.ROLLING:
			_gather_inputs()
			_update_roll(delta)


# ------------------------------------------------------------ Input

func _gather_inputs() -> void:
	## The only place player input reaches the marbles.
	## Online play: replace Controls.read_lean(i) with the lean the host
	## last received from player i.
	for m in marbles:
		m.lean = Controls.read_lean(m.player_id)
		m.lane_basis = _lane_frame(m.global_position).basis
		# The place key doubles as hop while rolling.
		if Input.is_action_just_pressed(Controls.action_name(m.player_id, "confirm")):
			m.request_hop()


func _gather_build_inputs(delta: float) -> void:
	## The only place player input reaches the draft and build.
	## Online play: each player's game sends these requests to the host.
	for p in player_count:
		if state == State.DRAFT:
			# Move the pointer over the cards (screen up = card space up).
			var dir := Controls.read_lean(p)
			if dir != Vector2.ZERO:
				draft_build.request_pointer_move(p, dir * pointer_speed * delta)
			if Input.is_action_just_pressed(Controls.action_name(p, "confirm")):
				draft_build.request_pick(p)
		else:
			# Glide the cursor while keys are held (lean keys double as
			# cursor keys: forward moves toward the pins).
			var dir := Controls.read_lean(p)
			if dir != Vector2.ZERO:
				draft_build.request_cursor_move(p, dir * cursor_speed * delta)
			var rotate := Controls.action_name(p, "rotate")
			if PieceCatalog.is_track(draft_build.picks[p]):
				# Track cards flip left/right: one flip per tap.
				if Input.is_action_just_pressed(rotate):
					draft_build.request_rotate(p, 180.0)
			elif _pressed_or_repeat(rotate, delta, 0.04):
				draft_build.request_rotate(p, rotate_step)
			if Input.is_action_just_pressed(Controls.action_name(p, "confirm")):
				draft_build.request_place(p)


func _gather_locker_inputs() -> void:
	## Locker and store. Up/down picks a row, left/right flips through looks,
	## place key buys the one you're looking at (or wears it if you own it).
	for p in player_count:
		if Input.is_action_just_pressed(Controls.action_name(p, "forward")):
			locker_row[p] = wrapi(locker_row[p] - 1, 0, Cosmetics.SLOTS.size())
		if Input.is_action_just_pressed(Controls.action_name(p, "back")):
			locker_row[p] = wrapi(locker_row[p] + 1, 0, Cosmetics.SLOTS.size())
		var step := 0
		if Input.is_action_just_pressed(Controls.action_name(p, "left")):
			step = -1
		if Input.is_action_just_pressed(Controls.action_name(p, "right")):
			step = 1
		if step != 0:
			request_locker_browse(p, step)
		if Input.is_action_just_pressed(Controls.action_name(p, "confirm")):
			request_locker_buy(p)


## Show the next/previous look in the player's current row. Owned looks are
## worn straight away; others are shown with their price until bought.
func request_locker_browse(p: int, step: int) -> void:
	var slot: String = Cosmetics.SLOTS[locker_row[p]]
	var list := Cosmetics.items(slot)
	var i := wrapi(Cosmetics.index_of(slot, locker_browse[p][slot]) + step, 0, list.size())
	var id: String = list[i].id
	locker_browse[p][slot] = id
	locker_message[p] = ""
	if profiles.owns(p, slot, id):
		profiles.equip(p, slot, id)
	_preview_look(p)


func request_locker_buy(p: int) -> void:
	var slot: String = Cosmetics.SLOTS[locker_row[p]]
	var id: String = locker_browse[p][slot]
	if profiles.owns(p, slot, id):
		locker_message[p] = "Owned"
		return
	var item := Cosmetics.find(slot, id)
	if not profiles.buy(p, slot, id):
		locker_message[p] = "Need %d more" % (item.price - profiles.coins(p))
		return
	profiles.equip(p, slot, id)
	profiles.save_to_disk()
	locker_message[p] = "Bought!"
	_preview_look(p)


## The look a player is browsing (even if not bought), shown on their marble.
func _preview_look(p: int) -> void:
	var look := profiles.look(p)
	for slot in Cosmetics.SLOTS:
		look[slot] = Cosmetics.find(slot, locker_browse[p][slot])
	if p < marbles.size():
		marbles[p].look = look
		marbles[p].preview = true
	_refresh_colors()


func _refresh_colors() -> void:
	for p in player_count:
		var id: String = locker_browse[p].get("color", profiles.equipped(p, "color")) \
				if state == State.WAITING else profiles.equipped(p, "color")
		player_colors[p] = Cosmetics.find("color", id).color
	draft_build.colors = player_colors


func _pressed_or_repeat(action: String, delta: float, rate := 0.09) -> bool:
	## True on the first press, then repeatedly while held, so a cursor can
	## glide down the lane.
	if Input.is_action_just_pressed(action):
		_repeat[action] = 0.3
		return true
	if Input.is_action_pressed(action):
		_repeat[action] = _repeat.get(action, 0.3) - delta
		if _repeat[action] <= 0.0:
			_repeat[action] = rate
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("toggle_collision"):
		marbles_collide = not marbles_collide
		for m in marbles:
			m.set_marble_collision(marbles_collide)
	elif event.is_action_pressed("toggle_camera"):
		_overhead_camera = not _overhead_camera
	elif event.is_action_pressed("restart_frame"):
		# Re-roll this frame on the same lane (handy for testing a layout).
		if state in [State.COUNTDOWN, State.ROLLING, State.RESULTS]:
			_prepare_roll()
			_start_countdown()
	elif event.is_action_pressed("roll"):
		match state:
			State.WAITING:
				# Anything browsed but not bought goes back to what's worn.
				for p in player_count:
					for slot in Cosmetics.SLOTS:
						locker_browse[p][slot] = profiles.equipped(p, slot)
					marbles[p].look = profiles.look(p)
					marbles[p].preview = false
				profiles.save_to_disk()
				_start_draft()
				_refresh_colors()
			State.RESULTS:
				frame += 1
				_prepare_roll()
				_start_draft()
			State.MATCH_OVER:
				_new_match()


# ------------------------------------------------------------ Roll

func _update_roll(delta: float) -> void:
	_roll_time += delta

	for m in marbles:
		if not m.out and not m.arrived and m.global_position.y < out_of_bounds_y:
			m.out = true
			m.freeze = true
			_splash(m.global_position, m.color)
		_check_missed_jump(m)
		_unstick(m, delta)

	var all_done := true
	for m in marbles:
		if not (m.arrived or m.out):
			all_done = false

	if all_done and not _settling:
		_settling = true
		_settle_left = settle_time
	if _settling:
		_settle_left -= delta

	if _roll_time >= roll_time_limit or (_settling and _settle_left <= 0.0):
		_finish_frame()


## A marble that drops into a gap in the track is fished out and put down
## just past the gap, where it sits still for a moment. That lost time is
## the price of missing the jump.
func _check_missed_jump(m: Marble) -> void:
	if m.out or m.arrived or m.freeze or m.hold_time > 0.0 or track.gaps.is_empty():
		return
	var d := track.distance_of(m.global_position)
	for g in track.gaps:
		if d < g[0] - 1.5 or d > g[1] + 1.5:
			continue
		var f := track.world_frame_at(d)
		if f.basis.y.dot(m.global_position - f.origin) > -1.0:
			return
		_splash(m.global_position, m.color)
		var spot := track.world_frame_at(g[1] + 1.2)
		m.global_position = spot.origin + spot.basis.y * 0.35
		m.linear_velocity = Vector3.ZERO
		m.angular_velocity = Vector3.ZERO
		m.hold_time = missed_jump_wait
		m.best_distance = g[1] + 1.2
		m.best_time = _roll_time + missed_jump_wait
		missed_jumps[m.player_id] = _roll_time
		return


func _unstick(m: Marble, delta: float) -> void:
	if m.hold_time > 0.0:
		return
	if m.out or m.arrived or m.freeze:
		m.still_time = 0.0
		return
	if m.linear_velocity.length() < 0.3:
		m.still_time += delta
	else:
		m.still_time = 0.0
	# Wedged for good (stuck in a piece, or rocking in a dip): after a few
	# seconds with no progress down the track, put it back on a bit further.
	var d := track.distance_of(m.global_position)
	if d > m.best_distance + 0.5:
		m.best_distance = d
		m.best_time = _roll_time
	elif _roll_time - m.best_time > rescue_time and d < track.length() - 2.0:
		var to := m.best_distance + 3.0
		for g in track.gaps:
			if to > g[0] - 1.0 and to < g[1] + 1.0:
				to = g[1] + 1.2
		var spot := track.world_frame_at(to)
		m.global_position = spot.origin + spot.basis.y * 0.5
		m.linear_velocity = -spot.basis.z * 3.0
		m.angular_velocity = Vector3.ZERO
		m.best_time = _roll_time
		m.still_time = 0.0
		return
	if m.still_time >= stuck_time:
		m.still_time = 0.0
		# Up, toward the middle of the lane, and on toward the pins.
		var lane := _lane_frame(m.global_position)
		var across := lane.basis.x.dot(m.global_position - lane.origin)
		var side := -signf(across) * _rng.randf_range(1.5, 3.0)
		var hop := lane.basis.x * side + Vector3.UP * 4.0 - lane.basis.z * 3.0
		m.apply_central_impulse(hop * m.mass)


func _finish_frame() -> void:
	var knockouts := []
	for m in marbles:
		m.lean = Vector2.ZERO
		if m.out and m.knocked_out_by != -1 and m.knocked_out_by != m.player_id:
			knockouts.append(m.knocked_out_by)
	last_result = Scoring.score_frame(player_count, arrival_order,
			rack.fallen_credits(), sweep_player, knockouts)
	for i in player_count:
		totals[i] += last_result.points[i]
	frame_points.append(last_result.points.duplicate())
	state = State.MATCH_OVER if frame >= frames_per_match else State.RESULTS
	_award_coins()


## Coins: one per point each frame. At the end of a match everyone gets a
## bonus for playing and the winner (or winners, on a tie) gets more.
func _award_coins() -> void:
	for i in player_count:
		coins_earned[i] = last_result.points[i]
		if state == State.MATCH_OVER:
			coins_earned[i] += Profiles.COINS_PER_MATCH
			if totals[i] == totals.max():
				coins_earned[i] += Profiles.COINS_FOR_WIN
		profiles.add_coins(i, coins_earned[i])
		match_coins[i] += coins_earned[i]
	profiles.save_to_disk()


func _on_arrival_line_body_entered(body: Node) -> void:
	if state != State.ROLLING:
		return
	if body is Marble and not body.arrived and not body.out:
		body.arrived = true
		arrival_order.append(body.player_id)
		_last_arrival_time = _roll_time


func _on_rack_swept(player_id: int) -> void:
	if state == State.ROLLING:
		sweep_player = player_id


## Track frame (world space) at the point of the track nearest `pos`.
## Past the end of the track (on the pin deck) it's the frame at the end.
func _lane_frame(pos: Vector3) -> Transform3D:
	return track.world_frame_at(track.distance_of(pos))


## A burst of spray where a marble hits the water.
func _splash(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 40
	p.lifetime = 1.1
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0).lerp(color, 0.15)
	mat.roughness = 0.1
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	p.global_position = Vector3(at.x, _water_level(), at.z)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _water_level() -> float:
	var water := get_node_or_null("Course/Water") as Node3D
	return water.global_position.y if water else out_of_bounds_y


# ------------------------------------------------------------ Camera

## Shake the camera for a hard landing or a marble-on-marble crash.
## `full` is the impact speed that gives the biggest shake.
func _on_marble_impact(strength: float, full: float) -> void:
	if state == State.ROLLING:
		camera.shake(clampf((strength - 2.0) / full, 0.0, 0.6) * camera_shake)


## The marbles the rolling camera should keep on screen.
func _camera_marbles() -> Array:
	var active := []
	for m in marbles:
		if not m.out and not m.arrived:
			active.append(m)
	if camera_follow == CameraFollow.ONE_MARBLE:
		for m in active:
			if m.player_id == camera_player:
				return [m]
	return active


func _marbles_center() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for m in marbles:
		if not m.out and not m.arrived:
			sum += m.global_position
			n += 1
	if n == 0:
		return rack.global_position + Vector3(0, 0, 3)
	return sum / n


func _update_camera() -> void:
	camera.frame_points = []
	if state == State.WAITING and not _overhead_camera:
		# Locker: up close behind the marbles, looking down the track.
		var gate := track.world_frame_at(1.0)
		camera.heading = -gate.basis.z
		camera.follow_offset = Vector3(0, 2.9, 1.3)
		camera.look_ahead = Vector3(0, -0.4, -1.1)
		camera.target = gate.origin + gate.basis.y * 0.3
		return
	if _overhead_camera or state in [State.WAITING, State.DRAFT]:
		# The whole track from high up.
		var box := _course_box()
		var size := maxf(box.size.x, box.size.z)
		camera.heading = Vector3.FORWARD
		camera.follow_offset = Vector3(0, size * 0.72, size * 0.62)
		camera.look_ahead = Vector3(0, 0, -size * 0.08)
		camera.target = box.get_center()
		return
	if state == State.BUILD:
		# Follow the build cursors, facing down the track where they are.
		# Every player's cursor (and its floating label) stays on screen;
		# the camera pulls back when cursors spread out.
		var cursors := draft_build.cursor_world_positions()
		var box := AABB(cursors[0], Vector3.ZERO)
		for c in cursors:
			box = box.expand(c)
			box = box.expand(c + Vector3.UP * 3.0)
		var center := box.get_center()
		center.y = box.position.y
		var d := track.distance_of(center)
		camera.heading = -track.world_frame_at(d + 2.0).basis.z
		camera.follow_offset = Vector3(0, 10.0, 7.5)
		camera.look_ahead = Vector3(0, 0, -2.0)
		camera.target = center
		var back := track.world_frame_at(d).basis.z
		for c in cursors:
			camera.frame_points.append(c)
			camera.frame_points.append(c + Vector3.UP * 3.0)
			# Room behind the cursor too, so the HUD chips don't cover it.
			camera.frame_points.append(c + back * 2.5)
		return
	var pin_cam := state == State.RESULTS or state == State.MATCH_OVER
	if state == State.ROLLING:
		# Swing to the pins for each impact, then back to anyone still rolling.
		pin_cam = _no_marbles_rolling() or _roll_time - _last_arrival_time < pin_cam_time
	if pin_cam:
		camera.heading = -deck.global_basis.z
		camera.follow_offset = Vector3(0, 3.2, 6.5)
		camera.look_ahead = Vector3(0, -1.0, -3.0)
		camera.target = rack.global_position - camera.heading * 1.0
	else:
		camera.follow_offset = Vector3(0, 7.0, 7.5)
		camera.look_ahead = Vector3(0, -2.0, -9.0)
		# Aim at the middle of the pack (leader to last place), and pull
		# back until every marble is in shot.
		var followed := _camera_marbles()
		if followed.is_empty():
			camera.target = _marbles_center()
		else:
			var box := AABB(followed[0].global_position, Vector3.ZERO)
			for m in followed:
				box = box.expand(m.global_position)
				camera.frame_points.append(m.global_position)
			camera.target = box.get_center()
		var d := track.distance_of(camera.target)
		if d < track.length() - 1.0:
			camera.heading = -track.world_frame_at(d + 4.0).basis.z
		else:
			camera.heading = -deck.global_basis.z


## Box around the track and pin deck (world space), for the overview camera.
func _course_box() -> AABB:
	var box := AABB(deck.global_position, Vector3.ZERO)
	var len := track.length()
	var d := 0.0
	while d <= len:
		box = box.expand(track.world_frame_at(d).origin)
		d += 4.0
	box = box.expand(deck.global_transform * Vector3(0, 0, -20))
	return box


func _no_marbles_rolling() -> bool:
	for m in marbles:
		if not m.out and not m.arrived:
			return false
	return true


# ------------------------------------------------------------ HUD helpers

func time_left() -> float:
	return maxf(0.0, roll_time_limit - _roll_time)


func phase_time_left() -> int:
	return ceili(maxf(0.0, _phase_left))


func countdown_value() -> int:
	return ceili(_countdown)
