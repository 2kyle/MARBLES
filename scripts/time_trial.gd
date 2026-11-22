class_name TimeTrial
extends Node3D
## TIME TRIAL on the hub's practice run: the clock starts as your marble
## rolls away from the top pad and stops when it reaches the bottom. Fall
## off (or miss the gap) and the run is cancelled. Your best time is saved
## (main.gd puts it in your profile) and the fastest runs go up on the
## RUN RECORDS board by the bottom of the run.
##
## The hub calls update() every physics tick. Only the computer running
## the hub's physics times runs (the host, online).

## A run finished: player, seconds.
signal finished(player: int, seconds: float)

## The clock starts this far down the run (just past the top pad).
const START_AT := 2.4
## How far a marble may stray from the middle of the run before it counts
## as fallen off (metres sideways, metres below the floor).
const OFF_SIDE := 3.6
const OFF_BELOW := 1.6

var course: Track
var _running: Array = []   # per player: seconds so far, or -1
var _at: Array = []        # per player: how far down the run they were last tick
var _last: Array = []      # per player: last finished time (shown for a moment), or -1
var _last_age: Array = []
var _board: Label3D
## Where the RUN RECORDS board stands (hub space, on the ground).
var board_pos := Vector3.ZERO


## `is_free(at)` says if a spot on the ground is clear for the board.
func setup(p_course: Track, is_free := Callable()) -> void:
	course = p_course
	_build_board(is_free)


## Seconds into a player's run, or -1 if they aren't on one.
func time_of(p: int) -> float:
	return _running[p] if p < _running.size() else -1.0


## The time a player just finished with (for a few seconds), or -1.
func just_finished(p: int) -> float:
	if p < _last.size() and _last_age[p] < 4.0:
		return _last[p]
	return -1.0


func update(delta: float, marbles: Array) -> void:
	while _running.size() < marbles.size():
		_running.append(-1.0)
		_at.append(0.0)
		_last.append(-1.0)
		_last_age.append(99.0)
	var len := course.length()
	for i in marbles.size():
		var m: Marble = marbles[i]
		_last_age[i] += delta
		if m.freeze:
			_running[i] = -1.0
			continue
		var d := course.distance_of(m.global_position)
		var f := course.world_frame_at(d)
		var rel := m.global_position - f.origin
		var on_run := absf(rel.dot(f.basis.x)) < OFF_SIDE and rel.dot(f.basis.y) > -OFF_BELOW and rel.dot(f.basis.y) < 4.0
		# No shortcuts: a jump of more than a couple of metres in one tick
		# (a teleport, or dropping in from the side) ends the run.
		var jumped := absf(d - _at[i]) > 2.5
		_at[i] = d
		if _running[i] < 0.0:
			# Start: rolling down from the top pad.
			if on_run and d > START_AT and d < START_AT + 1.5:
				_running[i] = 0.0
			continue
		if not on_run or jumped:
			_running[i] = -1.0   # fell off (or took a shortcut): no time
			continue
		_running[i] += delta
		if d >= len - 0.4:
			_last[i] = _running[i]
			_last_age[i] = 0.0
			finished.emit(i, _running[i])
			_running[i] = -1.0


## Show the best times on the board: an Array of [name, seconds, color].
func show_records(rows: Array) -> void:
	rows.sort_custom(func(a, b): return a[1] < b[1])
	var text := "RUN RECORDS\n"
	if rows.is_empty():
		text += "\nRoll down the\nrun to set one!"
	for k in mini(rows.size(), 4):
		text += "\n%d. %s  %s" % [k + 1, rows[k][0], format(rows[k][1])]
	_board.text = text


static func format(seconds: float) -> String:
	return "%.2fs" % seconds


## A little scoreboard on two posts beside the bottom of the run.
func _build_board(is_free: Callable) -> void:
	var end := course.transform * course.end_transform()
	var side := end.basis.x.normalized()
	# Beside the bottom of the run, on whichever side is clear.
	var at: Vector3 = end.origin + side * 4.6 - end.basis.z * 0.5
	for spot in [end.origin - side * 4.6 - end.basis.z * 0.5, end.origin + side * 4.6 - end.basis.z * 0.5,
			end.origin - side * 6.0 + end.basis.z * 2.0, end.origin + side * 6.0 + end.basis.z * 2.0]:
		if not is_free.is_valid() or is_free.call(spot):
			at = spot
			break
	at.y = 0.0
	board_pos = at
	var face := Basis(Vector3.UP, atan2(side.x, side.z) + PI)
	var wood := Color(0.45, 0.3, 0.18)
	for s in [-1.0, 1.0]:
		LowPoly.box(self, Vector3(0.14, 2.6, 0.14), at + face.x * s * 0.95 + Vector3.UP * 1.3, wood)
		LowPoly.solid_box(self, Vector3(0.16, 2.6, 0.16), at + face.x * s * 0.95 + Vector3.UP * 1.3)
	var panel := LowPoly.box(self, Vector3(2.2, 1.5, 0.12), at + Vector3.UP * 2.0, Color(0.12, 0.1, 0.18))
	panel.basis = face
	LowPoly.solid_box(self, Vector3(2.2, 1.5, 0.14), at + Vector3.UP * 2.0, face.get_euler().y)
	var trim := LowPoly.box(self, Vector3(2.35, 0.12, 0.16), at + Vector3.UP * 2.8, Color(1.0, 0.8, 0.25))
	trim.basis = face
	_board = Label3D.new()
	_board.font = LowPoly.TITLE_FONT
	_board.font_size = 40
	_board.pixel_size = 0.0065
	_board.outline_size = 10
	_board.outline_modulate = Color(0.05, 0.03, 0.08)
	_board.modulate = Color(1.0, 0.92, 0.7)
	_board.position = at + Vector3.UP * 2.0 + face.z * 0.08
	_board.basis = face
	_board.double_sided = true
	add_child(_board)
	show_records([])
