extends SceneTree
## Checks the practice island's people-only rule, name tags, and the
## sports island: the trampoline throws a marble through the hoop, and a
## ball in a goal scores.
##   godot --headless --fixed-fps 120 --script res://tests/sim_sports.gd

var game: Node
var _fails := 0
var _t := 0
var _tries := 0


func _initialize() -> void:
	# Keep test achievements out of the real save file.
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_t += 1
	var hub: Hub = game.hub
	var sports: SportsIsland = hub.sports if hub else null
	match _t:
		3:
			game.settings.player_count = 2
			game.settings.bot_count = 2
			game._enter_hub()
		10:
			check("only people on the island (2 marbles, no bots)", hub.marbles.size() == 2)
			check("a name tag over each marble", hub._tags.size() == 2)
			var tag: Node3D = hub._tags[0]
			check("tag floats above its marble", tag.global_position.y > hub.marbles[0].global_position.y + 0.5)
	# Drop marble 1 onto the trampoline every 3 seconds, up to 5 times.
	if _t >= 20 and _t % 360 == 20 and _tries < 5 and sports.baskets == 0:
		_tries += 1
		var m: Marble = hub.marbles[0]
		m.linear_velocity = Vector3.ZERO
		m.global_position = sports.to_global(SportsIsland.TRAMPOLINE + Vector3(0, 1.0, 0))
	if _t == 2000:
		check("trampoline throws marbles through the hoop (%d basket(s) in %d tries)" % [sports.baskets, _tries], sports.baskets >= 1)
		# Roll the ball into the right-hand (orange) goal: blue scores.
		var ball: RigidBody3D = sports._ball
		ball.global_position = sports.to_global(SportsIsland.PITCH + Vector3(SportsIsland.PITCH_HALF.x - 2.0, 0.6, 0))
		ball.linear_velocity = sports.global_basis.x * 6.0
	if _t == 2300:
		check("ball in the orange goal scores for blue (%s)" % str(sports.score), sports.score.blue == 1 and sports.score.orange == 0)
	if _t == 2700:
		var ball: RigidBody3D = sports._ball
		var local := sports.to_local(ball.global_position) - SportsIsland.PITCH
		check("ball goes back to the middle after a goal", Vector2(local.x, local.z).length() < 1.0)
		# Fall off the sports island: come back on the sports island.
		var m: Marble = hub.marbles[1]
		m.global_position = sports.to_global(Vector3(0, -12, 0))
	if _t == 2710:
		var m: Marble = hub.marbles[1]
		check("falling off the sports island puts you back there", sports.to_local(m.global_position).length() < SportsIsland.RADIUS)
		print("All sports tests passed" if _fails == 0 else "%d sports test(s) FAILED" % _fails)
		quit(1 if _fails > 0 else 0)
		return true
	return false
