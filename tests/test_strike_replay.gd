extends SceneTree
## Checks the slow-motion STRIKE REPLAY: a strike plays a replay before the
## scores, everything is frozen while it plays and put back exactly where it
## ended afterwards, any key skips it, it can be switched off in Settings,
## and a frame without a strike has no replay.
##   godot --headless --fixed-fps 120 --script res://tests/test_strike_replay.gd

var game: Node
var _fails := 0
var _step := 0
var _wait := 0
var _ticks := 0
var _replay_ticks := 0
var _saved_setting := true
## Where everything was at the end of the roll (to check it's put back).
var _end_pins: Array = []
var _end_freeze: Array = []


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_saved_setting = game.settings.strike_replay
	game.settings.strike_replay = true


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


## Start a roll straight away (no draft or build) on a fresh rack.
func start_roll() -> void:
	game._prepare_roll()
	game._release_marbles()


## Knock every pin flat, all credited to player 1, so it counts as a strike.
func knock_all_pins() -> void:
	for pin in game.rack.pins:
		pin.credited_to = 0
		var t: Transform3D = pin.global_transform
		pin.global_transform = Transform3D(t.basis.rotated(Vector3.RIGHT, PI / 2), t.origin + Vector3(0, -0.3, 0))
		pin.linear_velocity = Vector3(0, 0, -1)


func remember_end() -> void:
	_end_pins.clear()
	_end_freeze.clear()
	for pin in game.rack.pins:
		_end_pins.append(pin.global_transform)
	for m in game.marbles:
		_end_freeze.append(m.freeze)


func put_back_ok() -> bool:
	for i in game.rack.pins.size():
		if game.rack.pins[i].global_transform.origin.distance_to(_end_pins[i].origin) > 0.1:
			return false
	for i in game.marbles.size():
		if game.marbles[i].freeze != _end_freeze[i]:
			return false
	return true


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks > 120 * 90:
		check("finished in time", false)
		return _done()
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			if game.state == game.State.MENU:
				game._on_play_requested()
			if game.state == game.State.WAITING:
				game.auto_how_to_play = false
				game.frames_per_match = 20
				start_roll()
				_wait = 120   # one second of rolling
				_step = 1
		1:
			knock_all_pins()
			_wait = 120 * 2   # let the pins notice they're down, keep recording
			_step = 2
		2:
			check("all pins down", game.rack.standing_count() == 0)
			check("a strike is on tape", game.replay.has_clip())
			check("the clip is a few seconds long",
					game.replay.clip_length() > 0.5 and game.replay.clip_length() <= StrikeReplay.MAX_LENGTH + 0.01)
			print("  clip %.2fs of play, %.2fs to watch" % [game.replay.clip_length(), game.replay.play_time()])
			remember_end()
			game._finish_frame()
			check("strike starts the replay", game.state == game.State.REPLAY)
			check("the frame is scored before the replay", game.frame_points.size() == 1)
			var frozen := true
			for b in game.marbles + game.rack.pins:
				frozen = frozen and b.freeze
			check("everything is frozen during the replay", frozen)
			check("the pins are back standing at the start of the clip", game.rack.pins[0].global_basis.y.dot(Vector3.UP) > 0.9)
			_replay_ticks = 0
			_step = 3
		3:
			_replay_ticks += 1
			if game.state == game.State.REPLAY:
				return false
			var seconds := _replay_ticks / 120.0
			print("  replay played for %.2fs" % seconds)
			check("replay ends on its own in a few seconds", seconds > 1.0 and seconds < 12.0)
			check("then on to the scores", game.state == game.State.RESULTS)
			check("STRIKE! banner after the replay", game.hud._strike != null and game.hud._strike.visible)
			check("everything put back how the roll ended", put_back_ok())
			# Second strike: skip it with a key press.
			start_roll()
			_wait = 120
			_step = 4
		4:
			knock_all_pins()
			_wait = 120 * 2
			_step = 5
		5:
			remember_end()
			game._finish_frame()
			check("second strike replays too", game.state == game.State.REPLAY)
			_wait = 30
			_step = 6
		6:
			var key := InputEventKey.new()
			key.keycode = KEY_X
			key.pressed = true
			game._unhandled_input(key)
			check("any key skips the replay", game.state == game.State.RESULTS)
			check("skipping puts everything back too", put_back_ok())
			# Switched off in Settings: straight to the scores.
			game.settings.strike_replay = false
			start_roll()
			_wait = 120
			_step = 7
		7:
			knock_all_pins()
			_wait = 120 * 2
			_step = 8
		8:
			game._finish_frame()
			check("no replay when switched off", game.state == game.State.RESULTS)
			game.settings.strike_replay = true
			# No strike (pins left standing): no replay.
			start_roll()
			_wait = 120 * 2
			_step = 9
		9:
			check("no strike, nothing on tape", not game.replay.has_clip())
			game._finish_frame()
			check("no replay without a strike", game.state != game.State.REPLAY)
			return _done()
	return false


func _done() -> bool:
	game.settings.strike_replay = _saved_setting
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
