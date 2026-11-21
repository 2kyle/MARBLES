extends SceneTree
## Screenshot helper for the newest pieces (not part of the game). Usage:
##   godot --script res://tests/shot_pieces.gd -- <out.png> pieces
##       the Pop Bumper, Bounce Pad, Magnet and Pendulum placed on the lane
##   godot --script res://tests/shot_pieces.gd -- <out.png> draft
##       a draft with the newest cards on offer (they wear NEW! stickers)
##   godot --script res://tests/shot_pieces.gd -- <out.png> skee
##       the SKEE-JUMP arcade lane on the sports island
var game: Node
var _t := 0
var out := "user://shot_pieces.png"
var mode := "pieces"


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if mode == "skee":
		if _t == 3:
			game.settings.player_count = 1
			game._enter_hub()
		if _t >= 6:
			var skee: SkeeJump = game.hub.sports.skee
			var m: Marble = game.hub.marbles[0]
			if _t == 6:
				m.global_position = skee.to_global(Vector3(-5.9, 1.1, 0.2))
				m.linear_velocity = -skee.global_basis.x * 2.0
			game.camera.set_process(false)
			game.camera.set_physics_process(false)
			game.camera.global_position = skee.to_global(Vector3(5.5, 3.4, 4.2))
			game.camera.look_at(skee.to_global(Vector3(-4.0, 0.3, 0)))
	elif _t == 3:
		game.force_theme = "beach"
		game.settings.player_count = 1
		game.settings.bot_count = 1
		game._setup_local_seats()
		game._new_match()
		game.menu.close()
	if mode == "draft":
		if _t == 4:
			game._start_draft()
			var db: DraftBuild = game.draft_build
			var ids := ["pop_bumper", "track_oil", "pendulum", "magnet", "track_zigzag", "bounce_pad", "track_hill"]
			for k in db.crate.size():
				db.crate[k] = ids[k % ids.size()]
		if _t > 4:
			game._phase_left = 99.0
	elif mode == "pieces":
		var b: CourseBuilder = game.builder
		if _t == 4:
			b.place("pop_bumper", Vector2(-1.0, -9.0), 0.0, 0)
			b.place("pop_bumper", Vector2(1.2, -10.0), 0.0, 0)
			b.place("bounce_pad", Vector2(0.0, -13.5), 0.0, 0)
			b.place("magnet", Vector2(-0.6, -18.0), 0.0, 0)
			b.place("pendulum", Vector2(0.0, -23.0), 0.0, 0)
		if _t == 5:
			game.hud.visible = false
		if _t >= 5:
			game.camera.set_process(false)
			game.camera.set_physics_process(false)
			var tr: Track = game.track
			var f := tr.world_frame_at(4.0)
			game.camera.global_position = f.origin + f.basis.y * 4.2 + f.basis.z * 1.5
			game.camera.look_at(tr.world_frame_at(17.0).origin)
	if _t == (30 if mode == "skee" else 80):
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false
