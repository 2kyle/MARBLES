extends SceneTree
## Screenshot helper for track-altering (TA) cards (not part of the game).
## Puts player 1 in the build phase holding a TA card, so you can see how
## its preview looks on the track. Usage:
##   godot --script res://tests/shot_ta.gd -- <out.png> <ta id> [metres down the track] [right]
## e.g. godot --script res://tests/shot_ta.gd -- /tmp/bend.png track_bend 20
## Add "place" as a 5th argument to drop it and photograph the result.
var game: Node
var _t := 0
var out := "user://shot_ta.png"
var id := "track_bend"
var at := 20.0
var right := false
var drop := false


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: id = a[1]
	if a.size() > 2: at = float(a[2])
	if a.size() > 3: right = a[3] == "right"
	if a.size() > 4: drop = a[4] == "place"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		game.force_theme = ""
		game.settings.player_count = 1
		game.settings.bot_count = 0
		game._setup_local_seats()
		game._new_match()
		game.menu.close()
	if _t == 4:
		game._start_draft()
		var db: DraftBuild = game.draft_build
		db.picks[0] = id
		db.taken_by[0] = 0
	if _t == 6:
		# Everyone has picked, so the game moves on to building by itself.
		var db: DraftBuild = game.draft_build
		db.cursor_pos[0] = game.builder.clamp_pos(Vector2(0, -at))
		db.cursor_angle[0] = 180.0 if right else 0.0
		db.refresh_visuals()
	if _t == 7 and drop:
		game.draft_build.request_place(0)
	if _t == 8 or _t == 30:
		game._update_camera()
		game.camera.snap_to(game.camera.target)
	if _t > 6 and _t < 70:
		game._phase_left = 99.0
	if _t == 70:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false
