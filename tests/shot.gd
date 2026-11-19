extends SceneTree
## Screenshot helper (not part of the game). Usage:
##   godot --script res://tests/shot.gd -- <out.png> <mode> [arg]
var game: Node
var _t := 0
var out := "user://shot.png"
var mode := "match"
var arg := ""

func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	if a.size() > 2: arg = a[2]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		_setup()
	if _t > 3 and _t < 90:
		_tick()
	if _t == 90:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false

func _setup() -> void:
	match mode:
		"title":
			if arg != "":
				game.force_theme = arg
				game._new_match()
				game.show_title()
		"match", "roll", "end", "draft", "return":
			game.force_theme = arg
			game._new_match()
			game.menu.close()
		"hub", "casino", "crate", "bar":
			game.settings.player_count = 2 if mode == "casino" else 1
			game._enter_hub()

var _cam_done := false
func _tick() -> void:
	match mode:
		"roll":
			if _t == 4:
				game._start_countdown()
		"end":
			if _t == 4:
				game.state = game.State.ROLLING
				for m in game.marbles:
					m.arrived = true
					m.freeze = true
					m.global_position = game.deck.to_global(Vector3(0, -2.4, -14 - m.player_id))
			if _t == 5:
				game.camera.snap_to(game.camera.target)
		"draft":
			if _t == 4:
				game._start_draft()
		"return":
			# Look along the bowling end: lane, gutters, pit and ball return.
			if _t == 4:
				game.state = game.State.ROLLING
				for m in game.marbles:
					m.freeze = false
					m.visible = true
					m.global_position = game.deck.to_global(Vector3(m.player_id - 0.5, 0.5, -15))
			if _t >= 4:
				game.camera.set_process(false)
				game.camera.set_physics_process(false)
				game.camera.global_position = game.deck.to_global(Vector3(-3.5, 4.5, 6.0))
				game.camera.look_at(game.deck.to_global(Vector3(1.0, 0.0, -9.0)))
		"casino", "bar":
			var hub: Hub = game.hub
			if _t == 5:
				var at: Vector3 = hub.casino._seat(1) if mode == "casino" else CasinoIsland.BAR_PLATE
				hub.marbles[0].global_position = hub.to_global(CasinoIsland.OFFSET + at + Vector3(0, 0.4, 0))
				hub.marbles[0].linear_velocity = Vector3.ZERO
				if mode == "casino":
					hub.marbles[1].global_position = hub.to_global(CasinoIsland.OFFSET + hub.casino._seat(2) + Vector3(0, 0.4, 0))
			if _t == 30:
				game.profiles.add_coins(0, 100)
				if mode == "casino":
					hub.casino.blackjack.request_confirm(0)
				else:
					hub.casino.request_drink(0, hub.marbles[0])
			if _t >= 6:
				game.camera.set_process(false)
				game.camera.set_physics_process(false)
				var look: Vector3 = hub.to_global(CasinoIsland.OFFSET + (CasinoIsland.TABLE_POS if mode == "casino" else CasinoIsland.BAR_PLATE))
				var eye: Vector3 = look + ((Vector3(0, 3.0, 3.2) if arg == "zoom" else Vector3(0, 5.5, 8.5)) if mode == "casino" else Vector3(-7, 4.5, 6))
				game.camera.global_position = eye
				game.camera.look_at(look + Vector3(0, 1, 0))
		"crate":
			var hub: Hub = game.hub
			if _t == 5:
				game.profiles.add_coins(0, 300)
				hub.marbles[0].global_position = hub.to_global(CasinoIsland.OFFSET + CasinoIsland.CRATE_PLATE + Vector3(0, 0.4, 0))
				hub.marbles[0].linear_velocity = Vector3.ZERO
			if _t == 40 and game.crate_screen.is_open():
				game.crate_screen.request_confirm()
