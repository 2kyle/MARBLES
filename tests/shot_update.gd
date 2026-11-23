extends SceneTree
## Screenshot helper for the Nov 23 content update (not part of the game):
##   godot --script res://tests/shot_update.gd -- <out.png> <mode>
## modes:
##   loop     the Loop-de-Loop and an aimed Bounce Pad on the lane, a marble going round
##   neon     the PLAY arch with the neon LANES sign and the shoe-rental counter
##   rings    the biplane flying toward its SKY RINGS
##   ghost    the TIME TRIAL ghost racing a marble down the practice run
##   tiny     a TINY BALLS frame, rolling
var game: Node
var _t := 0
var out := "user://shot_update.png"
var mode := "loop"
var shot_at := 90


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	TimeTrial.ghost_path = "user://test_ghost_shot.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	if mode in ["loop", "tiny"]: shot_at = 4000
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.settings.graphics_auto = false


func _fix_camera(eye: Vector3, look: Vector3) -> void:
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.global_position = eye
	game.camera.look_at(look)


func _process(_d: float) -> bool:
	_t += 1
	match mode:
		"loop", "tiny":
			if _t == 3:
				game.force_theme = "beach"
				game.settings.player_count = 1
				game.settings.bot_count = 1
				game._setup_local_seats()
				game._new_match()
				game.menu.close()
			var b: CourseBuilder = game.builder
			var tr: Track = game.track
			if _t == 4:
				if mode == "loop":
					b.place("loop_de_loop", Vector2(0.0, -12.0), 0.0, 0)
					b.place("bounce_pad", Vector2(1.3, -20.0), 90.0, 0)
				else:
					game._prepare_roll()
					game.wild = "tiny"
					for m in game.marbles:
						WildFrames.apply("tiny", m)
				game._start_countdown()
			if _t >= 5:
				game.hud.visible = mode == "tiny"
				if mode == "loop":
					var f := tr.world_frame_at(12.0)
					_fix_camera(f.origin + f.basis.x * 3.4 + f.basis.y * 1.5 + f.basis.z * 0.8, f.origin + f.basis.y * 0.9)
			if mode == "loop":
				# Snap the moment a marble is near the top of the loop.
				for m in game.marbles:
					var d: float = tr.distance_of(m.global_position)
					var f2 := tr.world_frame_at(d)
					if _t > 30 and f2.basis.y.dot(m.global_position - f2.origin) > 1.25 and absf(d - 12.0) < 1.5:
						shot_at = _t
				shot_at = mini(shot_at, 2000)
			elif game.state == game.State.ROLLING and game._roll_time > 8.0 and shot_at > _t:
				shot_at = _t
		"neon":
			if _t == 3:
				game.settings.player_count = 2
				game._enter_hub()
			if _t >= 5:
				var hub: Hub = game.hub
				_fix_camera(hub.to_global(Hub.PORTAL_POS + Vector3(-3.0, 3.2, -10.5)), hub.to_global(Hub.PORTAL_POS + Vector3(-2.2, 2.9, 0)))
		"rings":
			if _t < 3:
				return false
			if _t == 3:
				game.settings.player_count = 1
				game._enter_hub()
			var hub: Hub = game.hub
			if _t == 6:
				hub.marbles[0].global_position = hub.plane.global_transform * Vector3(0, 0.7, 0.4)
			if _t > 10 and hub.plane.pilot:
				hub.plane.steer = Vector2(0.25, 0.4)
				var pf := hub.plane.global_transform
				_fix_camera(pf.origin + pf.basis.z * 9.0 + Vector3.UP * 3.0, pf.origin - pf.basis.z * 30.0)
			shot_at = 420
		"ghost":
			if _t == 3:
				game.settings.player_count = 1
				game._enter_hub()
			if _t < 4:
				return false
			var hub: Hub = game.hub
			var c: Track = hub.trial.course
			if _t == 12:
				# A made-up best run straight down the middle, a bit ahead.
				var samples := PackedVector3Array()
				var d := TimeTrial.START_AT
				while d < c.length():
					var f := c.world_frame_at(d)
					samples.append(c.global_transform.affine_inverse() * (f.origin + f.basis.y * 0.3 + f.basis.x * 0.6))
					d += 0.25
				hub.trial.set_ghost(samples, samples.size() * TimeTrial.GHOST_STEP, "P1")
				var f0 := c.world_frame_at(TimeTrial.START_AT + 0.3)
				hub.marbles[0].global_position = f0.origin + f0.basis.y * 0.35 - f0.basis.x * 0.5
				hub.marbles[0].linear_velocity = -f0.basis.z * 2.0
			if _t > 12:
				var m: Marble = hub.marbles[0]
				var d2 := c.distance_of(m.global_position)
				var f3 := c.world_frame_at(d2)
				m.lane_basis = f3.basis
				m.lean = Vector2(clampf(-(m.global_position - f3.origin).dot(f3.basis.x) * 1.5, -1, 1), -0.6)
				_fix_camera(m.global_position + f3.basis.z * 3.6 + f3.basis.y * 1.8, m.global_position - f3.basis.z * 3.0)
			shot_at = 150
	if _t == shot_at:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false
