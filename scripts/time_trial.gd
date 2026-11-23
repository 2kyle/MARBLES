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
##
## GHOST: every run is recorded, and the fastest run ever on this computer
## is kept (in `ghost_path`). Whenever someone starts a run, a see-through
## ghost marble replays that best run beside them, so they can race it.

## A run finished: player, seconds.
signal finished(player: int, seconds: float)

## The clock starts this far down the run (just past the top pad).
const START_AT := 2.4
## How often the ghost recording takes a sample (seconds).
const GHOST_STEP := 1.0 / 30.0
## Where the best run's recording is saved.
static var ghost_path := "user://ghost_run.cfg"

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
var _rec: Array = []       # per player: positions of the run so far (course space)
var _rec_t: Array = []     # per player: seconds since the last sample
## The fastest run's samples (course space), its time and who set it.
var ghost: PackedVector3Array = PackedVector3Array()
var ghost_time := 0.0
var ghost_name := ""
var _ghost_ball: MeshInstance3D
var _ghost_tag: Label3D
var _ghost_t := -1.0       # seconds into the ghost's replay, or -1 when it's resting
## Where the RUN RECORDS board stands (hub space, on the ground).
var board_pos := Vector3.ZERO


## `is_free(at)` says if a spot on the ground is clear for the board.
func setup(p_course: Track, is_free := Callable()) -> void:
	course = p_course
	_build_board(is_free)
	_build_ghost()
	load_ghost()


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
		_rec.append(PackedVector3Array())
		_rec_t.append(0.0)
	_update_ghost(delta)
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
				_rec[i] = PackedVector3Array([_to_course(m.global_position)])
				_rec_t[i] = 0.0
				# The ghost sets off with the first runner (and starts over
				# if it was already near the end of its run).
				if _ghost_t < 0.0 or _ghost_t > ghost_time - 1.0:
					_ghost_t = 0.0 if not ghost.is_empty() else -1.0
			continue
		if not on_run or jumped:
			_running[i] = -1.0   # fell off (or took a shortcut): no time
			continue
		_running[i] += delta
		_rec_t[i] += delta
		if _rec_t[i] >= GHOST_STEP:
			_rec_t[i] -= GHOST_STEP
			_sample(i, m)
		if d >= len - 0.4:
			_last[i] = _running[i]
			_last_age[i] = 0.0
			_sample(i, m)
			if ghost.is_empty() or _running[i] < ghost_time:
				set_ghost(_rec[i], _running[i], _names[i] if i < _names.size() else "P%d" % (i + 1))
				save_ghost()
			finished.emit(i, _running[i])
			_running[i] = -1.0


## Names for the ghost's tag (the hub sets them: "P1", or Steam names).
var _names: Array = []


func set_names(names: Array) -> void:
	_names = names


## Packed arrays are copied, not shared, so take it out, add, put it back.
func _sample(i: int, m: Marble) -> void:
	var r: PackedVector3Array = _rec[i]
	r.append(_to_course(m.global_position))
	_rec[i] = r


func _to_course(p: Vector3) -> Vector3:
	return course.global_transform.affine_inverse() * p


## Make `samples` (taken every GHOST_STEP seconds) the run to race.
func set_ghost(samples: PackedVector3Array, seconds: float, who: String) -> void:
	ghost = samples.duplicate()
	ghost_time = seconds
	ghost_name = who
	if _ghost_tag:
		_ghost_tag.text = "GHOST  %s  %s" % [who, format(seconds)]


func save_ghost() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ghost", "samples", ghost)
	cfg.set_value("ghost", "seconds", ghost_time)
	cfg.set_value("ghost", "name", ghost_name)
	cfg.save(ghost_path)


func load_ghost() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ghost_path) != OK:
		return
	var samples = cfg.get_value("ghost", "samples", PackedVector3Array())
	var secs := float(cfg.get_value("ghost", "seconds", 0.0))
	if samples is PackedVector3Array and samples.size() > 2 and secs > 0.0:
		set_ghost(samples, secs, str(cfg.get_value("ghost", "name", "")))


## Where the ghost is `t` seconds into its run (world space).
func ghost_position(t: float) -> Vector3:
	var k := clampf(t / GHOST_STEP, 0.0, ghost.size() - 1.0)
	var i := int(k)
	var a: Vector3 = ghost[i]
	var b: Vector3 = ghost[mini(i + 1, ghost.size() - 1)]
	return course.global_transform * a.lerp(b, k - i)


## Is the ghost out on the run right now?
func ghost_racing() -> bool:
	return _ghost_t >= 0.0 and _ghost_ball != null and _ghost_ball.visible


func _update_ghost(delta: float) -> void:
	if _ghost_ball == null:
		return
	if _ghost_t < 0.0 or ghost.is_empty():
		_ghost_ball.visible = false
		_ghost_tag.visible = false
		return
	_ghost_t += delta
	# Stays at the finish for a moment, then fades away.
	if _ghost_t > ghost_time + 1.2:
		_ghost_t = -1.0
		return
	var at := ghost_position(minf(_ghost_t, ghost_time))
	var ahead := ghost_position(minf(_ghost_t + 0.1, ghost_time))
	_ghost_ball.visible = true
	_ghost_tag.visible = true
	# Roll the see-through ball the way it's going.
	var move := ahead - at
	if move.length() > 0.001:
		var axis := Vector3.UP.cross(move.normalized())
		if axis.length() > 0.01:
			# move is 0.1 s of travel; turn by this tick's share of it.
			var roll := move.length() * (delta / 0.1) / 0.3
			_ghost_ball.basis = Basis(axis.normalized(), roll) * _ghost_ball.basis.orthonormalized()
	_ghost_ball.global_position = at
	_ghost_tag.global_position = at + Vector3.UP * 0.75


## The ghost: a see-through, softly glowing marble with a name tag.
func _build_ghost() -> void:
	_ghost_ball = MeshInstance3D.new()
	_ghost_ball.name = "Ghost"
	_ghost_ball.top_level = true
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 20
	sm.rings = 10
	_ghost_ball.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.6
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_ghost_ball.material_override = mat
	_ghost_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost_ball.visible = false
	add_child(_ghost_ball)
	_ghost_tag = Label3D.new()
	_ghost_tag.name = "GhostTag"
	_ghost_tag.top_level = true
	_ghost_tag.font = LowPoly.TITLE_FONT
	_ghost_tag.font_size = 30
	_ghost_tag.pixel_size = 0.005
	_ghost_tag.outline_size = 8
	_ghost_tag.modulate = Color(0.75, 0.92, 1.0, 0.85)
	_ghost_tag.outline_modulate = Color(0.05, 0.1, 0.2, 0.8)
	_ghost_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ghost_tag.no_depth_test = true
	_ghost_tag.visible = false
	add_child(_ghost_tag)


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
