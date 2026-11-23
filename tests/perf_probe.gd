extends SceneTree
## Rough timing of the game's own work per frame (not part of the game):
## script + physics time while drafting, building, rolling and in the hub.
## Run headless, so drawing isn't counted.
##   godot --headless --fixed-fps 120 --script res://tests/perf_probe.gd

var game: Node
var _t := 0
var _phase := ""
var _proc := 0.0
var _phys := 0.0
var _n := 0
var _age := 0
var _worst := 0.0
var _last_us := 0
var _plan := [
	[5, "draft"], [125, "build"], [245, "countdown"], [300, "roll"], [900, "hub"], [1300, "done"],
]


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	for p in _plan:
		if _t == p[0]:
			_report()
			_phase = p[1]
			match _phase:
				"draft":
					game.settings.player_count = 1
					game.settings.bot_count = 3
					game._setup_local_seats()
					game._new_match()
					game.menu.close()
					game._start_draft()
				"build":
					game._start_build()
				"countdown":
					game._start_countdown()
				"hub":
					game._enter_hub()
				"done":
					quit()
					return true
	# Skip the first half second of each phase (building things once).
	_age += 1
	if _age > 60:
		var now := Time.get_ticks_usec()
		var pr := (now - _last_us) / 1000000.0   # whole frame, wall clock
		_proc += pr
		_worst = maxf(_worst, pr)
		_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_n += 1
	_last_us = Time.get_ticks_usec()
	return false


func _report() -> void:
	if _phase == "" or _n == 0:
		_age = 0
		return
	print("%-10s frame %.2f ms (worst %.1f)   physics %.2f ms   nodes %d   objects %d" % [_phase,
			_proc / _n * 1000.0, _worst * 1000.0, _phys / _n * 1000.0,
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	_proc = 0.0
	_phys = 0.0
	_n = 0
	_age = 0
	_worst = 0.0
