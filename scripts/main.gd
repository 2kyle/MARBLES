extends Node3D
## Runs a local match: spawns marbles, runs each frame (countdown, roll,
## score), and keeps the scoreboard.
##
## Built with online play in mind: this script is the "referee". Everything
## that decides an outcome (physics, arrival order, pin credit, scoring)
## happens here and in the nodes it owns. Player input only ever reaches a
## marble through `_gather_inputs()`. When online play arrives, the host runs
## this script, and `_gather_inputs()` reads each player's lean from the
## network instead of the keyboard.

enum State { WAITING, COUNTDOWN, ROLLING, RESULTS, MATCH_OVER }

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
## Longest a roll can last, in seconds.
@export var roll_time_limit := 30.0
## After the last marble reaches the pins (or falls out), wait this long
## for pins to finish falling before scoring.
@export var settle_time := 4.0
## A marble below this height has fallen off the course.
@export var out_of_bounds_y := -6.0
## Seconds the camera watches the pins after a marble reaches them.
@export var pin_cam_time := 2.5

@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")

var state := State.WAITING
var frame := 1
var totals: Array = []
var marbles: Array[Marble] = []
var arrival_order: Array = []
var sweep_player := -1
var last_result: Dictionary = {}

var _countdown := 0.0
var _roll_time := 0.0
var _settle_left := 0.0
var _settling := false
var _overhead_camera := false
var _last_arrival_time := -100.0

@onready var course: Node3D = $Course
@onready var rack: Rack = $Rack
@onready var camera: CameraRig = $Camera
@onready var hud: Hud = $Hud
@onready var arrival_line: Area3D = $Course/ArrivalLine


func _ready() -> void:
	Controls.setup()
	rack.global_position = ($Course/RackSpot as Node3D).global_position
	rack.swept.connect(_on_rack_swept)
	arrival_line.body_entered.connect(_on_arrival_line_body_entered)
	_new_match()


func _new_match() -> void:
	frame = 1
	totals.resize(player_count)
	totals.fill(0)
	last_result = {}
	_prepare_frame()


func _prepare_frame() -> void:
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
	state = State.WAITING


func _start_countdown() -> void:
	_countdown = 3.0
	state = State.COUNTDOWN


func _release_marbles() -> void:
	for m in marbles:
		m.freeze = false
	state = State.ROLLING


func _process(_delta: float) -> void:
	_update_camera()
	hud.refresh(self)


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				_release_marbles()
		State.ROLLING:
			_gather_inputs()
			_update_roll(delta)


func _gather_inputs() -> void:
	## The only place player input reaches the marbles.
	## Online play: replace Controls.read_lean(i) with the lean the host
	## last received from player i.
	for m in marbles:
		m.lean = Controls.read_lean(m.player_id)


func _update_roll(delta: float) -> void:
	_roll_time += delta

	for m in marbles:
		if not m.out and not m.arrived and m.global_position.y < out_of_bounds_y:
			m.out = true
			m.freeze = true

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


func _finish_frame() -> void:
	for m in marbles:
		m.lean = Vector2.ZERO
	last_result = Scoring.score_frame(player_count, arrival_order,
			rack.fallen_credits(), sweep_player)
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
		if state != State.MATCH_OVER:
			_prepare_frame()
	elif event.is_action_pressed("roll"):
		match state:
			State.WAITING:
				_start_countdown()
			State.RESULTS:
				frame += 1
				_prepare_frame()
				_start_countdown()
			State.MATCH_OVER:
				_new_match()


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
	if _overhead_camera:
		camera.follow_offset = Vector3(0, 30, 6)
		camera.look_ahead = Vector3(0, 0, -0.1)
		camera.target = Vector3(0, 0, -24)
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


# Helpers the HUD reads.

func time_left() -> float:
	return maxf(0.0, roll_time_limit - _roll_time)


func countdown_value() -> int:
	return ceili(_countdown)
