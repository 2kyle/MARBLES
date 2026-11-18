extends Node3D
## Runs a local match. Each frame goes:
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

## Marbles in the match (1 to 4). Each extra player uses the next key set.
@export_range(1, 4) var player_count := 2
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
## Degrees per rotate tap (hold to keep turning).
@export var rotate_step := 15.0
## Extra pieces in the crate beyond one per player.
@export var crate_extra := 2
## Longest a roll can last, in seconds.
@export var roll_time_limit := 30.0
## After the last marble reaches the pins (or falls out), wait this long
## for pins to finish falling before scoring.
@export var settle_time := 4.0
## A marble below this height has fallen off the course.
@export var out_of_bounds_y := -6.0
## Seconds the camera watches the pins after a marble reaches them.
@export var pin_cam_time := 2.5
## A marble that barely moves for this many seconds (wedged in a corner)
## gets a little hop down the lane.
@export var stuck_time := 2.0

@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")

var state := State.WAITING
var frame := 1
var totals: Array = []
var marbles: Array[Marble] = []
var arrival_order: Array = []
var sweep_player := -1
var last_result: Dictionary = {}

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
@onready var arrival_line: Area3D = $Course/ArrivalLine
@onready var builder: CourseBuilder = $Course/Slope/Placed
@onready var draft_build: DraftBuild = $DraftBuild


func _ready() -> void:
	Controls.setup()
	_rng.randomize()
	rack.global_position = ($Course/RackSpot as Node3D).global_position
	rack.swept.connect(_on_rack_swept)
	arrival_line.body_entered.connect(_on_arrival_line_body_entered)
	draft_build.setup(builder, player_count, PLAYER_COLORS)
	hud.thumbnails = $Thumbnails
	_new_match()


func _new_match() -> void:
	frame = 1
	totals.resize(player_count)
	totals.fill(0)
	last_result = {}
	builder.clear()
	_prepare_roll()
	state = State.WAITING


func _prepare_roll() -> void:
	## Put fresh marbles at the start gate (frozen) and a fresh rack of pins.
	for m in marbles:
		remove_child(m)
		m.queue_free()
	marbles.clear()
	arrival_order.clear()
	sweep_player = -1
	_roll_time = 0.0
	_settling = false
	_last_arrival_time = -100.0

	var spawns := $Course/Slope/StartGate.get_children()
	for i in player_count:
		var m: Marble = marble_scene.instantiate()
		m.player_id = i
		m.color = PLAYER_COLORS[i]
		m.freeze = true
		add_child(m)
		m.global_position = (spawns[i] as Node3D).global_position
		m.set_marble_collision(marbles_collide)
		marbles.append(m)

	rack.reset()
	camera.snap_to(_marbles_center())


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


func _gather_build_inputs(delta: float) -> void:
	## The only place player input reaches the draft and build.
	## Online play: each player's game sends these requests to the host.
	for p in player_count:
		var fwd := Controls.action_name(p, "forward")
		var back := Controls.action_name(p, "back")
		if state == State.DRAFT:
			if _pressed_or_repeat(fwd, delta):
				draft_build.request_draft_move(p, -1)
			if _pressed_or_repeat(back, delta):
				draft_build.request_draft_move(p, 1)
			if Input.is_action_just_pressed(Controls.action_name(p, "confirm")):
				draft_build.request_pick(p)
		else:
			# Glide the cursor while keys are held (lean keys double as
			# cursor keys: forward moves toward the pins).
			var dir := Controls.read_lean(p)
			if dir != Vector2.ZERO:
				draft_build.request_cursor_move(p, dir * cursor_speed * delta)
			if _pressed_or_repeat(Controls.action_name(p, "rotate"), delta, 0.04):
				draft_build.request_rotate(p, rotate_step)
			if Input.is_action_just_pressed(Controls.action_name(p, "confirm")):
				draft_build.request_place(p)


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
				_start_draft()
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


func _unstick(m: Marble, delta: float) -> void:
	if m.out or m.arrived or m.freeze:
		m.still_time = 0.0
		return
	if m.linear_velocity.length() < 0.3:
		m.still_time += delta
	else:
		m.still_time = 0.0
	if m.still_time >= stuck_time:
		m.still_time = 0.0
		# Up, toward the middle of the lane, and on toward the pins.
		var side := -signf(m.global_position.x) * _rng.randf_range(1.5, 3.0)
		var hop := Vector3(side, 4.0, -3.0)
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
	state = State.MATCH_OVER if frame >= frames_per_match else State.RESULTS


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


# ------------------------------------------------------------ Camera

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
	if _overhead_camera or state in [State.WAITING, State.DRAFT, State.BUILD]:
		# Whole lane from above, for building.
		camera.follow_offset = Vector3(0, 19, 8)
		camera.look_ahead = Vector3(0, 0, -0.1)
		camera.target = Vector3(0, 2, -15)
		return
	var pin_cam := state == State.RESULTS or state == State.MATCH_OVER
	if state == State.ROLLING:
		# Swing to the pins for each impact, then back to anyone still rolling.
		pin_cam = _no_marbles_rolling() or _roll_time - _last_arrival_time < pin_cam_time
	if pin_cam:
		camera.follow_offset = Vector3(0, 3.2, 6.5)
		camera.look_ahead = Vector3(0, -1.0, -3.0)
		camera.target = rack.global_position + Vector3(0, 0, 1.0)
	else:
		camera.follow_offset = Vector3(0, 8.0, 7.0)
		camera.look_ahead = Vector3(0, -2.0, -10.0)
		camera.target = _marbles_center()


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
