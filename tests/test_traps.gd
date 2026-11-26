extends SceneTree
## Checks TRAPPED! points: the rules on their own (a rival's piece, your
## own piece, too long ago, the last piece wins), the score (+1 and "trap"
## on the scoreboard line) and the TRAPPER match award, then in the game:
## a marble pushed onto P2's piece and dropped off the track gives P2 the
## trap, a marble that just falls off gives nobody anything, and your own
## piece never traps you.
##   godot --headless --fixed-fps 120 --script res://tests/test_traps.gd

var game: Node
var _fails := 0
var _step := 0
var _wait := 0
var _ticks := 0
var _hold := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	_rules()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _rules() -> void:
	var t := Traps.new()
	check("a fall with no touch is not a trap", t.fell(0, 1.0) == -1)
	t.touch(0, 1, 2.0)
	check("rival's piece, then a fall: trapped", t.fell(0, 3.5) == 1)
	check("the trap is counted for the frame", t.frame_traps == [1])
	t.touch(0, 0, 4.0)
	check("your own piece never traps you", t.fell(0, 4.5) == -1)
	t.touch(2, -1, 4.0)
	check("starting pieces (nobody's) don't count", t.fell(2, 4.5) == -1)
	t.touch(3, 1, 1.0)
	check("too long after the touch: no trap", t.fell(3, 1.0 + Traps.WINDOW + 0.1) == -1)
	t.touch(2, 1, 5.0)
	t.touch(2, 3, 5.5)
	check("the last rival piece touched gets it", t.fell(2, 6.0) == 3)
	check("one trap per marble", t.fell(2, 6.1) == -1)
	t.reset_frame()
	check("a new frame forgets everything", t.frame_traps.is_empty() and t.fell(0, 0.0) == -1)

	var r := Scoring.score_frame(2, [0], [0, 0], -1, [], [1])
	check("a trap scores +1", r.traps == [0, 1] and r.points == [5, 1])
	r = Scoring.score_frame(2, [], [], -1, [], [1])
	check("nobody made it: traps score nothing too", r.points == [0, 0])

	var m := MatchAwards.new()
	m.record_trap(2)
	m.record_trap(2)
	m.record_trap(0)
	var res := m.results(3)
	check("TRAPPER award for the most traps", res.size() == 1 and res[0].title == "TRAPPER"
			and res[0].players == [2] and res[0].detail == "2 TRAPS")
	check("one trap says TRAP", MatchAwards._detail("trapped", 1) == "1 TRAP")


func start_roll() -> void:
	game._prepare_roll()
	game._release_marbles()


## Hold marble `p` right on top of the piece at lane spot `pos`.
func hold_on(p: int, pos: Vector2) -> void:
	var m: Marble = game.marbles[p]
	m.global_position = game.builder.lane_xform(pos, 0.0, 0.35).origin
	m.linear_velocity = Vector3.ZERO


## Drop marble `p` below the track (as if it rolled off the edge).
func drop(p: int) -> void:
	var m: Marble = game.marbles[p]
	m.global_position = Vector3(m.global_position.x, game.out_of_bounds_y - 1.0, m.global_position.z)


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
				game.settings.strike_replay = false
				game.frames_per_match = 1
				check("at least two players", game.player_count >= 2)
				game.builder.place("bumper_post", Vector2(0, -12), 0.0, 1)   # P2's piece
				game.builder.place("bumper_post", Vector2(0, -20), 0.0, 1)   # P2's other piece
				check("both pieces placed", game.builder.placed.size() == 2)
				start_roll()
				_hold = 0
				_step = 1
		1:
			# P1's marble sits on P2's piece; P2's marble sits on its own.
			hold_on(0, Vector2(0, -12))
			hold_on(1, Vector2(0, -20))
			_hold += 1
			if _hold >= 10:
				check("touching P2's piece is noticed", game._piece_owner_touching(game.marbles[0]) == 1)
				check("touching your own piece is ignored by traps",
						game._piece_owner_touching(game.marbles[1]) == 1)
				drop(0)
				drop(1)
				_wait = 4
				_step = 2
		2:
			var m0: Marble = game.marbles[0]
			var m1: Marble = game.marbles[1]
			check("P1's marble is out", m0.out)
			check("P1 was trapped by P2", m0.trapped_by == 1)
			check("P2's own piece didn't trap P2", m1.out and m1.trapped_by == -1)
			check("TRAPPER counted for P2", game.match_stats.trapped[1] == 1)
			# Let a third marble score something so the frame isn't "nobody made it".
			game.arrival_order.append(game.player_count - 1 if game.player_count > 2 else 1)
			game._finish_frame()
			check("P2 scored a trap", game.last_result.traps[1] == 1 and game.last_result.traps[0] == 0)
			check("the scoreboard line says trap", "trap +1" in game.hud._frame_summary(game))
			check("TRAPPER award at the end", "TRAPPER" in game.awards.map(func(a): return a.title))
			return _done()
	return false


func _done() -> bool:
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
