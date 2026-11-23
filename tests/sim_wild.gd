extends SceneTree
## Rolls one frame on the bare lane under a WILD FRAMES rule and checks the
## marbles still get to the pins (or splash out) instead of getting stuck.
##   godot --headless --fixed-fps 120 --script res://tests/sim_wild.gd -- tiny
## Rules: any id from WildFrames.LIST (default: every rule, one after another).

var game: Node
var _ticks := 0
var _rules := []
var _rule := ""
var _rolled := false
var _fails := 0
var _start_ticks := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		for w in WildFrames.LIST:
			_rules.append(w.id)
	else:
		_rules = args.duplicate()
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _next() -> void:
	_rule = _rules.pop_front()
	game._prepare_roll()
	game.wild = _rule
	for m in game.marbles:
		WildFrames.apply(_rule, m)
	game._start_countdown()
	_rolled = false
	_start_ticks = _ticks


func _process(_d: float) -> bool:
	_ticks += 1
	if game.state == game.State.MENU:
		game._on_play_requested()
	if _ticks == 5:
		_next()
		return false
	if _rule == "":
		return false
	if game.state == game.State.ROLLING:
		_rolled = true
	elif _rolled or _ticks - _start_ticks > 120 * 60:
		var done := 0
		for m in game.marbles:
			if m.arrived or m.out:
				done += 1
		var ok: bool = done == game.marbles.size() and game._roll_time < 44.0
		print("%s  %-13s time %.1fs, arrivals %s, out %s, pins down %d" % ["PASS" if ok else "FAIL", _rule,
				game._roll_time, game.arrival_order, game.marbles.filter(func(m): return m.out).map(func(m): return m.player_id),
				game.rack.pin_count() - game.rack.standing_count()])
		if not ok:
			_fails += 1
		if _rules.is_empty():
			print("ALL PASSED" if _fails == 0 else "%d wild rules FAILED" % _fails)
			quit(1 if _fails > 0 else 0)
			return true
		_next()
	return false
