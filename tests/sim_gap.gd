extends SceneTree
## Checks the hop and gap jumps. Builds a track with a gap in it, rolls the
## marbles with nobody playing, and reports who fell in (a marble that misses is out for the frame).
##   godot --headless --fixed-fps 120 --script res://tests/sim_gap.gd -- [hop] [gap_at=N]
## "hop": every marble hops 1.2 m before each gap (a well-timed jump).

var game: Node
var _ticks := 0
var _hop := false
var _rolled := false
var _misses := {}
var _hops := 0
var _gap_at := 14.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_hop = "hop" in args
	for a in args:
		if a.begins_with("gap_at="):
			_gap_at = float(a.substr(7))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 5:
		var layout := TrackGen.insert(game.track.layout, _gap_at, TrackGen.gap())
		game.track.apply_layout(layout, game.track.start_xz)
		game._on_track_reshaped()
		print("gaps (m along track): ", game.track.gaps)
		game._start_countdown()
	if game.state == game.State.ROLLING:
		_rolled = true
		for m in game.marbles:
			if m.out and not _misses.has(str(m)):
				_misses[str(m)] = true
				print("  P%d fell off near %.1f m at t=%.1fs" % [m.player_id + 1,
						game.track.distance_of(m.global_position), game._roll_time])
			if _hop:
				var d: float = game.track.distance_of(m.global_position)
				for g in game.track.gaps:
					if d > g[0] - 1.4 and d < g[0] - 0.4:
						if m.request_hop():
							_hops += 1
							print("  P%d hopped at %.1f m, speed %.1f" % [m.player_id + 1, d, m.linear_velocity.length()])
	elif _rolled:
		print("Done: time %.1fs, arrivals %s, hops %d" % [
				game._roll_time, game.arrival_order, _hops])
		return true
	return _ticks > 120 * 70
