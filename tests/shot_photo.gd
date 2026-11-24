extends SceneTree
## Screenshot helper for PHOTO MODE (not part of the game). It starts a
## roll, pauses mid-roll, opens photo mode, swoops the camera low beside
## the marbles, then saves two pictures: <outdir>/photo_mode.png (with the
## help panel) and a real photo taken by PhotoMode.take_photo() into
## <outdir>/photos/ (without it, which also checks that saving works).
##   godot --fixed-fps 60 --resolution 1280x720 --script res://tests/shot_photo.gd -- <outdir> [pause_frame]
var game: Node
var _t := 0
var outdir := "user://photo_shots"
var pause_at := 330


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: outdir = a[0]
	if a.size() > 1: pause_at = int(a[1])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.settings.graphics_auto = false
	game.auto_how_to_play = false


func _process(_d: float) -> bool:
	_t += 1
	var p: PhotoMode = game.photo
	if _t == 3:
		game.settings.player_count = 2
		game.settings.bot_count = 2
		game._setup_local_seats()
		game._new_match()
		game.menu.close()
	elif _t == 4:
		game._start_countdown()
	elif _t == pause_at:
		game._pause()
		game._open_photo_mode()
		# Drop down, step back and look a bit to the side, zoom in, lean.
		p.fly(1.0, Vector3(0.6, -0.5, -0.4), Vector2(-0.35, -0.08), 0.6, 0.25)
	elif _t == pause_at + 30:
		root.get_viewport().get_texture().get_image().save_png(outdir + "/photo_mode.png")
		print("saved ", outdir, "/photo_mode.png")
		p.save_dir = outdir + "/photos"
		_snap(p)
	return false


func _snap(p: PhotoMode) -> void:
	var path: String = await p.take_photo()
	print("photo: ", path if path != "" else "(not saved)")
	quit(0 if path != "" and FileAccess.file_exists(path) else 1)
