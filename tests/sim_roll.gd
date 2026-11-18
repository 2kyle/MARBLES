extends SceneTree
## Plays frames with no human input and prints what happened. Useful for
## checking physics changes quickly:
##   godot --headless --fixed-fps 120 --script res://tests/sim_roll.gd
## Optional: pass "-- lean" to have player 1 hold left the whole time.

var game: Node
var _frames_played := 0
var _was_rolling := false
var _ticks := 0
var _lean := false
var _pintest_x = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_lean = "lean" in args
	for a in args:
		if a.begins_with("pins="):
			_pintest_x = float(a.substr(5))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	_ticks += 1
	if game.state == game.State.WAITING and _ticks > 5:
		game._start_countdown()
		if _pintest_x != null:
			_launch_at_pins()
		if _lean:
			Input.action_press("p1_left")
	var rolling: bool = game.state == game.State.ROLLING
	if rolling and _ticks % 240 == 0:
		var parts := []
		for m in game.marbles:
			parts.append("P%d x=%.1f z=%.1f y=%.1f v=%.1f" % [m.player_id + 1,
					m.global_position.x, m.global_position.z, m.global_position.y, m.linear_velocity.length()])
		print("  t=%.1fs  %s  standing=%d" % [game._roll_time, "  ".join(parts),
				game.rack.standing_count()])
	if _was_rolling and not rolling:
		_frames_played += 1
		var r: Dictionary = game.last_result
		print("Frame %d: time %.1fs, arrivals %s, pins down %d, credits %s, sweep %d" % [
				game.frame, game._roll_time, game.arrival_order,
				game.rack.pin_count() - game.rack.standing_count(),
				game.rack.fallen_credits(), game.sweep_player])
		print("  points %s  note: %s" % [r.points, r.note])
		if _frames_played >= 3:
			return true
		game.frame += 1
		game._prepare_frame()
		game._start_countdown()
	_was_rolling = rolling
	return false


func _launch_at_pins() -> void:
	## "pins=X" option: skip the lane and fire player 1 straight at the rack
	## from x = X at 6 m/s, to tune the pin hit on its own.
	game._release_marbles()
	var m: Marble = game.marbles[0]
	m.global_position = Vector3(_pintest_x, 0.3, -35.0)
	m.linear_velocity = Vector3(0, 0, -6.0)
	m.angular_velocity = Vector3(-6.0 / 0.3, 0, 0)
	for i in range(1, game.marbles.size()):
		game.marbles[i].freeze = true
