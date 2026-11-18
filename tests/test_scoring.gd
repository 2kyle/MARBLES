extends SceneTree
## Run from the project folder with:
##   godot --headless --script res://tests/test_scoring.gd
## Prints PASS/FAIL for each case and exits with code 1 on any failure.

var _failures := 0


func _init() -> void:
	# Two players, P0 arrives first and P1 never arrives: P0 gets race bonus.
	var r := Scoring.score_frame(2, [0], [0, 0, 0, -1], -1)
	_check("solo arrival gets race bonus", r.points, [3 + 3, 0])

	# Both arrive: too-easy rule, no race bonus.
	r = Scoring.score_frame(2, [1, 0], [0, 1, 1, 1], -1)
	_check("everyone arrives, no race bonus", r.points, [1, 3])

	# Nobody arrives: too-hard rule, nothing at all.
	r = Scoring.score_frame(2, [], [0, 1], 0)
	_check("nobody arrives, no points", r.points, [0, 0])

	# Sweep bonus for the last pin.
	var credits := []
	for i in 21:
		credits.append(0 if i < 15 else 1)
	r = Scoring.score_frame(3, [0, 1], credits, 1)
	_check("sweep and race bonus", r.points, [15 + 3, 6 + 5 + 2, 0])

	# Uncredited pins score for nobody.
	r = Scoring.score_frame(2, [0], [-1, -1], -1)
	_check("uncredited pins", r.points, [3, 0])

	# Four players, three arrive: 3/2/1 bonus.
	r = Scoring.score_frame(4, [2, 0, 3], [], -1)
	_check("3/2/1 race bonus", r.points, [2, 0, 3, 1])

	if _failures > 0:
		print("%d test(s) failed" % _failures)
		quit(1)
	else:
		print("All scoring tests passed")
		quit(0)


func _check(name: String, got: Array, want: Array) -> void:
	if got == want:
		print("PASS  ", name)
	else:
		print("FAIL  ", name, "  got ", got, " want ", want)
		_failures += 1
