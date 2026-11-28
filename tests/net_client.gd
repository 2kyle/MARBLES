extends SceneTree
## Online test, client side (see net_host.gd). Joins 127.0.0.1, steers the
## draft pointer onto a card with fake key presses, and after two frames
## checks this copy of the game matches what the host printed.
## With "-- replay" (the host makes a strike in frame 1) it checks it
## watches the host's strike replay: bars on, pins moving, then the scores.

var game: Node
var _fails := 0
var _ticks := 0
var _draft_ticks := 0
var _result_frames := {}
var _quit_at := -1
var _hub_seen := false
var _lean_on := false
var _steam_mode := OS.get_cmdline_user_args().has("steam")
var _replay_mode := OS.get_cmdline_user_args().has("replay")
var _replay_ticks := 0
var _replay_progress := 0.0
var _pin_path := 0.0
var _pin_last := Vector3.ZERO
var _left_replay_to := -1
var fake: Object


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	if _steam_mode:
		fake = load("res://tests/fake_steam.gd").new()
		fake.nick = "Guesty"
		game.steam_backend = fake
	Achievements.save_path = "user://test_achievements_client.cfg"
	Achievements.reset()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print("CLIENT " + ("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 30:
		if _steam_mode:
			# What Steam does when you accept a friend's invite.
			fake.join_requested.emit(fake.LOBBY_BASE + fake.PORT, fake.HOST_ID)
		else:
			game._on_join_requested("127.0.0.1")
	if _ticks == 120 and _steam_mode:
		check("accepting the invite joined the game over Steam", game.net.is_client() and game.net.over_steam)
	if _ticks > 120 * 200:
		print("CLIENT timed out in state %d" % game.state)
		return _finish()
	if _quit_at > 0 and _ticks >= _quit_at:
		return _finish()
	if game.state == game.State.HUB and not _hub_seen:
		_hub_seen = true
		check("joining puts me on the host's island", game.net.is_client())
		Input.action_press(Controls.action_name(0, "forward"))
		_lean_on = true
	if _lean_on and game.state != game.State.HUB:
		Input.action_release(Controls.action_name(0, "forward"))
		_lean_on = false
	if game.state == game.State.DRAFT:
		# Push the pointer up onto the cards, then grab.
		_draft_ticks += 1
		var up := Controls.action_name(0, "forward")
		var grab := Controls.action_name(0, "confirm")
		if _draft_ticks == 20:
			Input.action_press(up)
		elif _draft_ticks == 80:
			Input.action_release(up)
		elif _draft_ticks % 20 == 0 and _draft_ticks > 80:
			Input.action_press(grab)
		elif _draft_ticks % 20 == 2:
			Input.action_release(grab)
	else:
		_draft_ticks = 0
	if game.state == game.State.REPLAY:
		_replay_ticks += 1
		_replay_progress = maxf(_replay_progress, game.replay_progress())
		# The host moves the pins back through the strike; they move here too.
		var pin_at: Vector3 = game.rack.pins[0].global_position
		if _replay_ticks > 1:
			_pin_path += pin_at.distance_to(_pin_last)
		_pin_last = pin_at
		if _replay_ticks == 60:
			# A guest's key doesn't skip: only the host can.
			var key := InputEventKey.new()
			key.keycode = KEY_X
			key.pressed = true
			game._unhandled_input(key)
			check("a guest's key press doesn't skip the replay", game.state == game.State.REPLAY)
	elif _replay_ticks > 0 and _left_replay_to < 0:
		_left_replay_to = game.state
	if game.state == game.State.RESULTS and not _result_frames.has(game.frame):
		_result_frames[game.frame] = true
		print("CLIENT frame %d totals %s pieces %d" % [game.frame, game.totals, game.builder.placed.size()])
		if game.frame == 1:
			check("I'm seat 2", game.net.my_seat == 1)
			check("3 seats, seat 3 shown as a bot", game.player_count == 3 and game.seat_name(2) == "BOT" and game.is_bot(2))
		if game.frame == 2:
			_quit_at = _ticks + 120
	return false


func _finish() -> bool:
	check("was on the island before the match", _hub_seen)
	check("saw two frames' results", _result_frames.size() >= 2)
	check("first-frame achievement on this computer too", Achievements.has("FIRST_FRAME"))
	if _replay_mode:
		check("watched the host's strike replay (%.1fs)" % (_replay_ticks / 120.0), _replay_ticks > 120)
		check("the replay's red line moved along (%.2f)" % _replay_progress, _replay_progress > 0.5)
		check("the pins moved during the replay (%.2f m)" % _pin_path, _pin_path > 0.1)
		check("after the replay, on to the scores", _left_replay_to == game.State.RESULTS)
		check("the hint says only the host can skip", game.hud._replay_skip.text == "The host can skip")
	print("CLIENT " + ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	game.net.leave()
	quit(1 if _fails > 0 else 0)
	return true
