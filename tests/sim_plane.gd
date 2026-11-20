extends SceneTree
## Flies the lookout biplane: roll a ball into it, steer it about, check it
## stays in the sky and in range, then hop out back onto the lookout.
##   godot --headless --fixed-fps 120 --script res://tests/sim_plane.gd
var game: Node
var _t := 0
var _fails := 0
var _low := 1000.0
var _far := 0.0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(name: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + name)
	if not ok:
		_fails += 1


func _physics_process(_d: float) -> bool:
	_t += 1
	var hub: Hub = game.hub if game.hub else null
	if _t == 3:
		game.settings.player_count = 1
		game._enter_hub()
	elif _t == 10:
		var m := hub.marbles[0]
		m.global_position = hub.plane.global_transform * Vector3(0, 0.7, 0.4)
	elif _t == 60:
		check("rolling into the plane climbs in", hub.plane.pilot == hub.marbles[0])
	elif _t > 60 and _t < 60 + 120 * 40:
		# Weave about: dive, turn, climb, boost.
		var s := float(_t) / 120.0
		hub.plane.steer = Vector2(sin(s * 0.5), -1.0 if fmod(s, 10.0) < 5.0 else 0.6)
		if _t % 600 == 0:
			hub.plane.boost()
		var at := hub.to_local(hub.plane.global_position)
		if s > 4.0:
			_low = minf(_low, at.y)
		_far = maxf(_far, Vector2(at.x, at.z).length())
	elif _t == 60 + 120 * 40:
		print("  lowest %.1f m, furthest %.1f m" % [_low, _far])
		check("stays above the cliffs", _low > Biplane.MIN_HEIGHT - 6.0)
		check("stays near the island", _far < Biplane.MAX_RANGE + 40.0)
		check("the ball rides in the cockpit", hub.marbles[0].global_position.distance_to(hub.plane.global_position) < 2.0)
		hub.plane.bail()
	elif _t == 60 + 120 * 42:
		var at := hub.to_local(hub.marbles[0].global_position)
		check("hopping out lands you on the lookout (%.1f, %.1f, %.1f)" % [at.x, at.y, at.z],
				at.y > -1.0 and at.y < 2.0 and at.z < -Hub.ISLAND_RADIUS)
		check("the plane is back on its spot", hub.plane.pilot == null and hub.to_local(hub.plane.global_position).y < 1.0)
		print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
		quit(1 if _fails > 0 else 0)
	return false
