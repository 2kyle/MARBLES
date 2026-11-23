extends SceneTree
## WILD FRAMES: every third frame bends a rule, the same one on every
## computer, the marbles really change, a banner announces it, and the
## setting turns it off.
##   godot --headless --script res://tests/test_wild_frames.gd

var game: Node
var _t := 0
var _fails := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_t += 1
	if game.state == game.State.MENU:
		game._on_play_requested()
	if _t == 5:
		var wild := []
		for f in range(1, 11):
			wild.append(WildFrames.pick(f, 42))
		_check(wild[0] == "" and wild[1] == "" and wild[3] == "", "frames 1, 2 and 4 are normal")
		_check(wild[2] != "" and wild[5] != "" and wild[8] != "", "frames 3, 6 and 9 are wild: %s" % [[wild[2], wild[5], wild[8]]])
		_check(WildFrames.pick(3, 42) == wild[2], "the same match seed picks the same rule (online games agree)")
		_check(WildFrames.pick(3, 42, false) == "", "WILD FRAMES off: no wild frames")
		for w in WildFrames.LIST:
			var plain: Marble = load("res://scenes/marble.tscn").instantiate()
			var m: Marble = load("res://scenes/marble.tscn").instantiate()
			WildFrames.apply(w.id, m)
			var changed: bool = m.gravity_scale != plain.gravity_scale or m.mass != plain.mass \
					or m.hop_speed != plain.hop_speed or m.max_speed != plain.max_speed \
					or (m.physics_material_override as PhysicsMaterial).bounce != (plain.physics_material_override as PhysicsMaterial).bounce \
					or (m.physics_material_override as PhysicsMaterial).friction != (plain.physics_material_override as PhysicsMaterial).friction \
					or m.ball_size != plain.ball_size or m.steer_flip != plain.steer_flip \
					or m.magnet_pull != plain.magnet_pull or m.wind != plain.wind
			_check(changed, "%s changes the marbles" % w.name)
			# Bouncy and ice must not change every marble's shared material.
			_check((plain.physics_material_override as PhysicsMaterial).bounce < 0.5 and (plain.physics_material_override as PhysicsMaterial).friction > 0.1, "%s leaves other marbles alone" % w.name)
			if w.id == "tiny":
				_check(is_equal_approx(((m.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius, 0.3 * m.ball_size)
						and is_equal_approx(((plain.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius, 0.3),
						"TINY BALLS shrinks the ball's collision, not every marble's")
			_check(WildIcon.has_picture(w.id), "%s has its own badge picture" % w.name)
			plain.free()
			m.free()
		# In a match: frame 3 is wild and its marbles really are changed.
		game.settings.wild_frames = true
		game.frame = 3
		game._prepare_roll()
		_check(game.wild != "", "frame 3 of a match is wild (%s)" % game.wild)
		game._start_draft()
	if _t == 20:
		var hud = game.hud
		_check(hud._wild_chip.visible and hud._wild_tag.text.contains(WildFrames.info(game.wild).name), "the wild frame tag shows: " + hud._wild_tag.text)
		_check(hud._wild_splash != null and is_instance_valid(hud._wild_splash), "a WILD FRAME! splash plays when the draft starts")
		game.settings.wild_frames = false
		game.frame = 4
		game._prepare_roll()
		_check(game.wild == "", "frame 4 is normal")
		print("ALL PASSED" if _fails == 0 else "%d wild frame checks FAILED" % _fails)
		quit(1 if _fails > 0 else 0)
		return true
	return false
