extends SceneTree
## Online test, client side (see net_host.gd). Joins 127.0.0.1, steers the
## draft pointer onto a card with fake key presses, and after two frames
## checks this copy of the game matches what the host printed.

var game: Node
var _fails := 0
var _ticks := 0
var _draft_ticks := 0
var _result_frames := {}
var _quit_at := -1


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print("CLIENT " + ("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 30:
		game._on_join_requested("127.0.0.1")
	if _ticks > 120 * 200:
		print("CLIENT timed out in state %d" % game.state)
		return _finish()
	if _quit_at > 0 and _ticks >= _quit_at:
		return _finish()
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
	check("saw two frames' results", _result_frames.size() >= 2)
	print("CLIENT " + ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	game.net.leave()
	quit(1 if _fails > 0 else 0)
	return true
