extends SceneTree
## Checks the hub's TIME TRIAL (scripts/time_trial.gd):
##   - the clock starts as a marble rolls away from the top pad
##   - jumping straight to the bottom doesn't count (no shortcuts)
##   - falling off cancels the run
##   - a real run (a marble let go at the top and steered down the middle,
##     hopping the gap) finishes with a sensible time, it's saved as a best,
##     and the RUN RECORDS board shows it
##   godot --headless --fixed-fps 120 --script res://tests/sim_time_trial.gd

var game: Node
var hub: Hub
var _t := 0
var _fails := 0
var _finished := []
var _step_t := 0
var _phase := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _put_on_run(m: Marble, d: float, speed := 0.0) -> void:
	var c: Track = hub.trial.course
	var f := c.world_frame_at(d)
	m.global_position = f.origin + f.basis.y * 0.35
	m.linear_velocity = -f.basis.z * speed
	m.angular_velocity = Vector3.ZERO


func _physics_process(_d: float) -> bool:
	_t += 1
	if _t == 2:
		game.settings.player_count = 1
		game._enter_hub()
		hub = game.hub
		hub.trial.finished.connect(func(p, s): _finished.append([p, s]))
		game.profiles.seats[game.profile_of(0)].best_run = 0.0   # start fresh
		return false
	if _t < 5:
		return false
	var m: Marble = hub.marbles[0]
	var c: Track = hub.trial.course
	_step_t += 1
	match _phase:
		0:
			_put_on_run(m, TimeTrial.START_AT + 0.5, 2.0)
			_phase = 1
			_step_t = 0
		1:
			if _step_t == 30:
				check("the clock starts rolling away from the top pad (%.2fs)" % hub.trial.time_of(0), hub.trial.time_of(0) > 0.0)
				_put_on_run(m, c.length() - 0.2, 2.0)
			if _step_t == 34:
				check("jumping straight to the bottom doesn't count", _finished.is_empty() and hub.trial.time_of(0) < 0.0)
				_put_on_run(m, TimeTrial.START_AT + 0.5, 2.0)
				_phase = 2
				_step_t = 0
		2:
			if _step_t == 20:
				check("a second run starts", hub.trial.time_of(0) > 0.0)
				m.global_position = hub.spawn_point(0) + Vector3.UP * 0.5
			if _step_t == 24:
				check("falling off (or leaving the run) cancels it", hub.trial.time_of(0) < 0.0 and _finished.is_empty())
				# A real run: let go just past the top pad, rolling.
				_put_on_run(m, TimeTrial.START_AT + 0.2, 3.0)
				_phase = 3
				_step_t = 0
		3:
			# Steer down the middle like a player would, and hop the gap.
			var d := c.distance_of(m.global_position)
			var f := c.world_frame_at(d)
			var side := (m.global_position - f.origin).dot(f.basis.x)
			m.lane_basis = f.basis
			m.lean = Vector2(clampf(-side * 1.5, -1.0, 1.0), -1.0)
			for g in c.gaps:
				if d > g[0] - 1.6 and d < g[0] - 0.4:
					m.request_hop()
			if _finished.size() >= 1:
				var s: float = _finished[0][1]
				check("a real run down the practice run finishes (%.2fs)" % s, s > 2.0 and s < 30.0)
				var best: float = game.profiles.best_run(game.profile_of(0))
				check("it's saved as a best (%.2fs)" % best, best > 0.0 and best <= s + 0.001)
				check("the RUN RECORDS board shows it", hub.trial._board.text.contains("P1"))
				_done()
				return true
			if _step_t > 120 * 40:
				check("a real run down the practice run finishes (never got there, at %.1f m of %.1f)" % [d, c.length()], false)
				_done()
				return true
	return false


func _done() -> void:
	print("ALL PASSED" if _fails == 0 else "%d time trial checks FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
