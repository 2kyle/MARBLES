extends SceneTree
## Screenshot helper for the STRIKE REPLAY (not part of the game). Fires
## player 1 straight into the pins, makes sure it's a strike, then takes a
## picture part way through the slow-motion replay. Usage:
##   godot --script res://tests/shot_replay.gd -- <out.png> [how far through, 0 to 1]
var game: Node
var _t := 0
var out := "user://shot_replay.png"
var at := 0.5


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: at = float(a[1])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		game.auto_how_to_play = false
		game.settings.player_count = 2
		game.settings.bot_count = 0
		game._setup_local_seats()
		game._new_match()
		game.menu.close()
	if _t == 10:
		game._prepare_roll()
		game._release_marbles()
		# Player 1 rolls in from just up the lane; player 2 waits at the gate.
		var m: Marble = game.marbles[0]
		var spot: Transform3D = game.track.world_frame_at(game.track.length() - 3.0)
		var aim: Vector3 = (game.rack.global_position - spot.origin).normalized()
		m.global_position = spot.origin + spot.basis.y * 0.4
		m.linear_velocity = aim * 9.0
		game.marbles[1].freeze = true
	if _t == 260:
		# Whatever's still standing gets a shove too, so it's a strike.
		for pin in game.rack.pins:
			if pin.credited_to == -1:
				pin.credited_to = 0
			if not pin.fallen:
				var axis := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				pin.global_transform = Transform3D(pin.global_basis.rotated(axis, 1.2), pin.global_position)
	if _t == 420:
		game._finish_frame()
	if _t > 420 and game.state == game.State.REPLAY and game.replay.progress() >= at:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	if _t > 2000:
		print("no replay to photograph")
		return true
	return false
