extends SceneTree
## Checks PHOTO MODE: the pause menu button opens it, the game stays
## paused, the HUD hides, the camera flies, zooms and tilts, it can't fly
## off too far, and leaving puts the camera back and reopens the pause menu.
##   godot --headless --script res://tests/test_photo_mode.gd

var game: Node
var _t := 0
var _fails := 0
var _step := 0
var _start_xf: Transform3D
var _start_fov := 0.0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _find_button(node: Node, text: String) -> Button:
	for c in node.get_children():
		if c is Button and (c as Button).text == text and (c as Button).is_visible_in_tree():
			return c
		var inner := _find_button(c, text)
		if inner:
			return inner
	return null


func menu_top() -> String:
	return game.menu._stack[-1] if game.menu.is_open() else ""


func _process(_d: float) -> bool:
	_t += 1
	if _t % 3 != 0:
		return false
	_step += 1
	var p: PhotoMode = game.photo
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	match _step:
		1:
			game.auto_how_to_play = false
			game._on_play_requested()
		2:
			game._pause()
		3:
			check("pause menu is open", menu_top() == "pause")
			var b := _find_button(game.menu, "PHOTO MODE")
			check("pause menu has PHOTO MODE", b != null)
			_start_xf = cam.global_transform
			_start_fov = cam.fov
			if b:
				b.pressed.emit()
		4:
			check("photo mode is open", p.is_open())
			check("the menu is closed", not game.menu.is_open())
			check("the game stays paused", paused)
			check("the HUD is hidden", not game.hud.visible)
			check("the retro filter stays on", game.retro_filter.visible)
			check("nothing moved yet", cam.global_transform.origin.distance_to(_start_xf.origin) < 0.001)
			p.fly(1.0, Vector3(0, 0, 1), Vector2.ZERO, 0.0, 0.0)
		5:
			var moved := cam.global_position - _start_xf.origin
			check("forward flies the camera", moved.length() > 5.0)
			var fwd := -_start_xf.basis.z
			fwd.y = 0
			check("forward goes the way the camera faces", moved.normalized().dot(fwd.normalized()) > 0.95)
			var y := cam.global_position.y
			p.fly(1.0, Vector3(0, 1, 0), Vector2.ZERO, 0.0, 0.0)
			check("up goes up", cam.global_position.y > y + 5.0)
			p.fly(1.0, Vector3.ZERO, Vector2.ZERO, 1.0, 0.0)
			check("zoom in narrows the view", cam.fov < _start_fov - 10.0)
			p.fly(10.0, Vector3.ZERO, Vector2.ZERO, 1.0, 0.0)
			check("zoom stops at the limit", is_equal_approx(cam.fov, PhotoMode.FOV_MIN))
			p.fly(0.5, Vector3.ZERO, Vector2.ZERO, 0.0, 1.0)
			check("tilt leans the picture", absf(cam.global_basis.x.y) > 0.1)
			p.fly(1.0, Vector3.ZERO, Vector2(0.5, 0.2), 0.0, 0.0)
			p.fly(100.0, Vector3(0, 0, 1), Vector2.ZERO, 0.0, 0.0)
			check("can't fly further than the limit", cam.global_position.distance_to(_start_xf.origin) <= PhotoMode.MAX_RANGE + 0.01)
			p.reset_view()
			check("reset puts the view back", cam.global_position.distance_to(_start_xf.origin) < 0.001 and is_equal_approx(cam.fov, _start_fov))
			p.fly(1.0, Vector3(1, 0, 0), Vector2(0.3, 0), 1.0, 1.0)
			var esc := InputEventKey.new()
			esc.physical_keycode = KEY_ESCAPE
			esc.keycode = KEY_ESCAPE
			esc.pressed = true
			p._age = 1.0
			root.get_viewport().push_input(esc)
		6:
			check("Esc leaves photo mode", not p.is_open())
			check("camera is back where it was", cam.global_transform.is_equal_approx(_start_xf))
			check("zoom is back", is_equal_approx(cam.fov, _start_fov))
			check("the HUD is back", game.hud.visible)
			check("the pause menu is back", menu_top() == "pause")
			check("still paused", paused)
			game._resume()
		7:
			check("resume carries on", not paused and not game.menu.is_open())
			print("\n%s (%d failed)" % ["ALL PASSED" if _fails == 0 else "SOME FAILED", _fails])
			quit(1 if _fails > 0 else 0)
	return false
