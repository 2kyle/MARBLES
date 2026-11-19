extends SceneTree
## Checks the new pieces on a fixed spot of track: a teleporter pair, a wind
## fan blowing across the track, and a Wall Breaker TA.
##   godot --headless --fixed-fps 120 --script res://tests/sim_items.gd -- [tele|fan|open]

var game: Node
var _ticks := 0
var _mode := "tele"
var _rolled := false
var _teleported := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_mode = args[0]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 5:
		var b: CourseBuilder = game.builder
		match _mode:
			"tele":
				b.place("teleporter", Vector2(-1.0, -8.0), 0.0, 0)
				var entry: Node3D = b.last_placed
				b.place("teleporter", Vector2(1.0, -8.0), 0.0, 0)
				var entry2: Node3D = b.last_placed
				b.place("teleporter_exit", Vector2(0.0, -30.0), 0.0, 0)
				entry.partner = b.last_placed
				entry2.partner = b.last_placed
				b.last_placed.partner = entry
			"fan":
				b.place("wind_fan", Vector2(0.0, -10.0), 0.0, 0)  # default: blows across
			"open":
				b.place("track_open", Vector2(0.0, -8.0), 0.0, 0)
				print("open stretches: ", game.track.open_edges)
		print("placed: ", b.placed.map(func(p): return p.id), " gaps: ", game.track.gaps)
		game._start_countdown()
	if game.state == game.State.ROLLING:
		_rolled = true
		for m in game.marbles:
			var d: float = game.track.distance_of(m.global_position)
			if _mode == "tele" and d > 25.0 and d < 33.0 and not _teleported.has(m.player_id) and game._roll_time < 3.0:
				_teleported[m.player_id] = true
				print("  P%d at %.1f m after %.2fs (teleported)" % [m.player_id + 1, d, game._roll_time])
			if _mode == "fan" and d > 7.0 and d < 14.0 and _ticks % 12 == 0:
				var f: Transform3D = game.track.world_frame_at(d)
				print("  P%d at %.1f m: %.2f m from centre, sideways speed %.2f" % [m.player_id + 1, d,
						f.basis.x.dot(m.global_position - f.origin), f.basis.x.dot(m.linear_velocity)])
			if m.out and not _teleported.has(-1 - m.player_id):
				_teleported[-1 - m.player_id] = true
				print("  P%d fell off near %.1f m" % [m.player_id + 1, d])
	elif _rolled:
		print("Done: time %.1fs, arrivals %s" % [game._roll_time, game.arrival_order])
		return true
	return _ticks > 120 * 70
