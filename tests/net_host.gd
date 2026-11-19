extends SceneTree
## Online test, host side. Run together with net_client.gd (see
## tests/run_net_test.sh): hosts a game with one bot, waits for the client,
## plays two frames, then checks a bot takes over when the client leaves.

var game: Node
var _fails := 0
var _ticks := 0
var _started := false
var _frames := 0
var _client_picked_early := false
var _left_seen := false


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.draft_time = 8.0
	game.build_time = 12.0


func check(what: String, ok: bool) -> void:
	print("HOST " + ("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 2:
		game.settings.bot_count = 1
		game.settings.frames_per_match = 3
		game._on_host_requested()
		check("hosting", game.net.is_host())
	if _ticks > 120 * 240:
		print("HOST timed out in state %d" % game.state)
		return _finish()
	if not _started:
		if game.net.humans() == 2 and game.net.lobby.size() == 3:
			check("lobby: host, player, bot " + str(game.net.lobby.map(func(s): return s.kind)),
					game.net.lobby.map(func(s): return s.kind) == ["host", "player", "bot"])
			_started = true
			game._start_online_match()
			check("3 seats: me, remote, bot", game.player_count == 3 and game.seat_kinds == [0, 2, 1, 0])
		return false
	match game.state:
		game.State.DRAFT:
			if game.draft_build.picks[1] != "" and game._phase_left > 1.0:
				_client_picked_early = true
		game.State.WAITING, game.State.RESULTS, game.State.MATCH_OVER:
			if _ticks % 90 == 0:
				if game.state != game.State.WAITING:
					_frames += 1
					print("HOST frame %d totals %s pieces %d" % [game.frame, game.totals, game.builder.placed.size()])
					if _frames == 3:
						return _finish()
				game.request_next()
	if not _left_seen and game.net.lobby.size() == 3 and game.net.lobby[1].get("left", false):
		_left_seen = true
		check("client's seat handed to a bot", game.is_bot(1))
	return false


func _finish() -> bool:
	check("the client's stick and button picked a card in time", _client_picked_early)
	check("played all 3 frames to the end", _frames == 3 and game.state == game.State.MATCH_OVER)
	check("a bot took over when the client left", _left_seen)
	print("HOST " + ("all passed" if _fails == 0 else "%d FAILED" % _fails))
	quit(1 if _fails > 0 else 0)
	return true
