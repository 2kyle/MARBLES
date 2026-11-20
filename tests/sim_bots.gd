extends SceneTree
## Plays two frames with one (idle) person and three bots, and checks the
## bots draft, build and roll on their own, before the timers run out.
##   godot --headless --fixed-fps 120 --script res://tests/sim_bots.gd

var game: Node
var _fails := 0
var _ticks := 0
var _frames := 0
var _picked_early := {}
var _placed_early := {}
var _arrived := {}
var _last_state := -1


func _initialize() -> void:
	# Keep test achievements out of the real save file.
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.draft_time = 12.0
	game.build_time = 25.0


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 2:
		game.settings.player_count = 1
		game.settings.bot_count = 3
		game.settings.bot_level = int(OS.get_environment("BOT_LEVEL")) if OS.get_environment("BOT_LEVEL") != "" else 1
		game._on_play_requested()
		check("1 person + 3 bots = 4 seats", game.player_count == 4)
		check("seat 2-4 are bots", game.is_bot(1) and game.is_bot(2) and game.is_bot(3) and not game.is_bot(0))
		check("bots are named BOT2..BOT4", game.seat_name(1) == "BOT2" and game.seat_name(3) == "BOT4")
		check("bot marbles have eyes", game.look_for(1).eyes.id != "none")
		return false
	if _ticks < 4:
		return false
	var st: int = game.state
	if st != _last_state:
		_last_state = st
	var db: DraftBuild = game.draft_build
	match st:
		game.State.WAITING, game.State.RESULTS:
			if _ticks % 60 == 0:
				if st == game.State.RESULTS:
					_frames += 1
					print("Frame %d: totals %s  arrivals %s" % [_frames, game.totals, game.arrival_order])
					for p in game.arrival_order:
						_arrived[p] = true
					if _frames >= 2:
						return _finish()
				game.request_next()
		game.State.DRAFT:
			for p in [1, 2, 3]:
				if db.picks[p] != "" and game._phase_left > 0.5:
					_picked_early[p] = true
		game.State.BUILD:
			for p in [1, 2, 3]:
				if db.has_placed.size() > p and db.has_placed[p] and game._phase_left > 0.5:
					_placed_early[p] = true
	if _ticks > 120 * 300:
		print("timed out in state %d" % st)
		return _finish()
	return false


func _finish() -> bool:
	check("every bot drafted before the timer " + str(_picked_early.keys()), _picked_early.size() == 3)
	check("every bot built before the timer " + str(_placed_early.keys()), _placed_early.size() == 3)
	check("bots reached the pins " + str(_arrived.keys()), _arrived.size() >= 2)
	print("All bot tests passed" if _fails == 0 else "%d bot test(s) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
