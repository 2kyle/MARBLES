extends SceneTree
## Checks SKEE-JUMP on the sports island: rolls a marble off the kicker at
## a few speeds and prints where it lands and what it scores.
##   godot --headless --fixed-fps 120 --script res://tests/sim_skee.gd
var game: Node
var _t := 0
var _speeds := [3.0, 5.0, 6.5, 8.0, 9.5, 11.0]
var _i := -1
var _wait := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		game.settings.player_count = 1
		game._enter_hub()
	if _t < 10:
		return false
	var skee: SkeeJump = game.hub.sports.skee
	var m: Marble = game.hub.marbles[0]
	if not skee.game_over.is_connected(_over):
		skee.game_over.connect(_over)
	_wait -= 1
	if _wait <= 0:
		_i += 1
		if _i >= _speeds.size():
			print("best ", skee.best)
			return true
		m.global_position = skee.start_point() + skee.global_basis.x * -3.0
		m.linear_velocity = -skee.global_basis.x * _speeds[_i]
		m.angular_velocity = Vector3.ZERO
		_wait = 120 * 4
		print("roll at %.1f m/s" % _speeds[_i])
	return _t > 120 * 40


func _over(p: int, score: int) -> void:
	print("  game over: P%d %d points" % [p + 1, score])
