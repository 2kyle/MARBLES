extends SceneTree
## Checks the MATCH AWARDS shown at the end of a match, before the podium:
## the award rules on their own (most strikes, most pins in one roll,
## fastest marble, most pieces blown up, ties, nobody earning one), then in
## the game: the awards screen comes up after the last frame, moves on to
## the podium by itself, any key skips it, and a match where nobody earned
## anything goes straight to the podium.
##   godot --headless --fixed-fps 120 --script res://tests/test_match_awards.gd

var game: Node
var _fails := 0
var _step := 0
var _wait := 0
var _ticks := 0
var _award_ticks := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	_rules()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _titles(list: Array) -> Array:
	return list.map(func(a): return a.title)


## The rules on their own, no game needed.
func _rules() -> void:
	var m := MatchAwards.new()
	check("no awards before anything happens", m.results(2).is_empty())
	m.record_frame([3, 6], -1, {1: 14.25})
	m.record_frame([10, 2], 0, {0: 11.5, 1: 16.0})
	m.record_frame([4, 10], 1, {})
	m.record_frame([10, 0], 0, {0: 12.0})
	m.record_blast(1, 2)
	m.record_blast(1, 1)
	m.record_blast(0, 0)
	var r := m.results(2)
	check("all four awards", _titles(r) == ["STRIKE KING", "PIN CRUSHER", "SPEED DEMON", "DEMOLITION"])
	check("STRIKE KING goes to the most strikes", r[0].players == [0] and r[0].detail == "2 STRIKES")
	check("PIN CRUSHER is shared on a tie", r[1].players == [0, 1] and r[1].detail == "10 PINS")
	check("SPEED DEMON is the fastest single roll", r[2].players == [0] and r[2].detail == "11.5 SECONDS")
	check("DEMOLITION adds up every bomb", r[3].players == [1] and r[3].detail == "3 PIECES")

	m.reset()
	m.record_frame([2, 1, 0], -1, {})
	r = m.results(3)
	check("only earned awards show", _titles(r) == ["PIN CRUSHER"])
	check("one pin says PIN, not PINS", MatchAwards._detail("best_roll", 1) == "1 PIN")
	m.record_frame([0, 0, 0, 0], 3, {3: 9.0})
	check("players past player_count are left out", m.results(3).size() == 1)


## Start a roll straight away (no draft or build) on a fresh rack.
func start_roll() -> void:
	game._prepare_roll()
	game._release_marbles()


## Knock `count` pins flat, credited to player 1, as if their marble got
## to the pins in 9.5 seconds (pins only score for marbles that get there).
func knock_pins(count: int) -> void:
	game.arrival_order.append(0)
	game._finish_times[0] = 9.5
	for i in count:
		var pin = game.rack.pins[i]
		pin.credited_to = 0
		var t: Transform3D = pin.global_transform
		pin.global_transform = Transform3D(t.basis.rotated(Vector3.RIGHT, PI / 2), t.origin + Vector3(0, -0.3, 0))


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks > 120 * 120:
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
				# A bomb blows up a piece: that counts for DEMOLITION.
				game.builder.place("bumper_post", Vector2(0, -12), 0.0, 1)
				game.builder.place("bomb", Vector2(0, -12), 0.0, 0)
				check("a bomb counts the pieces it blows up", game.match_stats.blown_up[0] == 1)
				start_roll()
				_wait = 120
				_step = 1
		1:
			knock_pins(4)
			_wait = 120 * 2
			_step = 2
		2:
			game._finish_frame()
			check("last frame goes to the awards", game.state == game.State.AWARDS)
			check("awards worked out", _titles(game.awards) == ["PIN CRUSHER", "SPEED DEMON", "DEMOLITION"])
			check("podium waits for the awards", game.podium == null or not game.podium.visible)
			_wait = 60
			_step = 3
		3:
			check("awards screen is showing", game.hud._awards_screen.visible)
			check("one tile per award", game.hud._awards_row.get_child_count() == game.awards.size())
			check("scores hidden behind the awards", not game.hud._scores.visible)
			_award_ticks = 0
			_step = 4
		4:
			_award_ticks += 1
			if game.state == game.State.AWARDS:
				return false
			var seconds := 0.5 + _award_ticks / 120.0
			print("  awards showed for %.2fs" % seconds)
			check("awards move on by themselves", seconds > 2.0 and seconds < 12.0)
			check("then the podium", game.state == game.State.MATCH_OVER and game.podium.visible)
			check("awards screen gone", not game.hud._awards_screen.visible)
			# Second match: skip the awards with a key.
			game._new_match()
			check("a new match clears the awards", game.awards.is_empty() and game.match_stats.blown_up[0] == 0)
			start_roll()
			_wait = 120
			_step = 5
		5:
			knock_pins(2)
			_wait = 120 * 2
			_step = 6
		6:
			game._finish_frame()
			check("awards again", game.state == game.State.AWARDS)
			_wait = 120   # past the moment where a late hop is ignored
			_step = 7
		7:
			var key := InputEventKey.new()
			key.keycode = KEY_X
			key.pressed = true
			game._unhandled_input(key)
			check("any key skips to the podium", game.state == game.State.MATCH_OVER and game.podium.visible)
			# Third match: nobody does anything, so no awards at all.
			game._new_match()
			start_roll()
			_wait = 60
			_step = 8
		8:
			game._finish_frame()
			check("nothing earned: straight to the podium", game.state == game.State.MATCH_OVER and game.podium.visible)
			return _done()
	return false


func _done() -> bool:
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
