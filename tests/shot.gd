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
		"match", "roll", "end", "draft":
			game.force_theme = arg
			game._new_match()
			game.menu.close()
		"hub":
			game.settings.player_count = 1
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
