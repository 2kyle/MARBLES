extends SceneTree
## Checks keyboard and controller bindings and the settings menu by sending
## fake key presses and controller events.
##   godot --headless --script res://tests/test_controls.gd

var game: Node
var _t := 0
var _fails := 0
var _step := 0


func _initialize() -> void:
	# Keep test achievements out of the real save file.
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func key(code: int, down := true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func pad_button(device: int, button: int, down := true) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)


func pad_axis(device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func focused() -> String:
	var f := root.gui_get_focus_owner()
	return (f as Button).text if f is Button else str(f)


func _process(_d: float) -> bool:
	_t += 1
	if _t % 3 != 0:
		return false
	_step += 1
	match _step:
		1:
			# Every player's actions exist with keys and a controller.
			for p in 4:
				for d in Controls.DIRECTIONS:
					var a := Controls.action_name(p, d)
					var has_key := false
					var has_pad := false
					for ev in InputMap.action_get_events(a):
						has_key = has_key or ev is InputEventKey
						has_pad = has_pad or ev is InputEventJoypadButton or ev is InputEventJoypadMotion
					check("%s has a key and a controller binding" % a, has_key and has_pad)
			check("menu is open on the title screen", game.menu.is_open())
			check("first button focused: " + focused(), focused().begins_with("PLAY"))
			pad_button(0, JOY_BUTTON_DPAD_DOWN)
		2:
			pad_button(0, JOY_BUTTON_DPAD_DOWN, false)
			check("D-pad down moves to: " + focused(), focused().begins_with("THE HUB"))
			key(KEY_S)
		3:
			key(KEY_S, false)
			check("S moves to: " + focused(), focused().begins_with("ONLINE"))
			pad_axis(0, JOY_AXIS_LEFT_Y, 1.0)
		4:
			pad_axis(0, JOY_AXIS_LEFT_Y, 0.0)
			check("left stick down moves to: " + focused(), focused().begins_with("SETTINGS"))
			pad_button(0, JOY_BUTTON_A)
		5:
			pad_button(0, JOY_BUTTON_A, false)
		6:
			check("A opens Settings", game.menu._stack[-1] == "settings")
			# Focus is on FULLSCREEN; go down to VOLUME and turn it down.
			key(KEY_DOWN)
		7:
			key(KEY_DOWN, false)
			key(KEY_DOWN)
		8:
			key(KEY_DOWN, false)
			# RETRO LOOK sits between VSYNC and VOLUME: step past it.
			if focused().begins_with("RETRO"):
				root.gui_get_focus_owner().find_valid_focus_neighbor(SIDE_BOTTOM).grab_focus()
			var before: float = game.settings.master_volume
			set_meta("vol", before)
			pad_button(0, JOY_BUTTON_DPAD_LEFT)
		9:
			pad_button(0, JOY_BUTTON_DPAD_LEFT, false)
			check("focus on: " + focused(), true)
			check("D-pad left on VOLUME lowers it (%.1f -> %.1f)" % [get_meta("vol"), game.settings.master_volume],
					game.settings.master_volume < get_meta("vol"))
			key(KEY_D)
		10:
			key(KEY_D, false)
			check("D raises it back (%.1f)" % game.settings.master_volume, is_equal_approx(game.settings.master_volume, get_meta("vol")))
			var cfg := ConfigFile.new()
			check("settings saved to disk", cfg.load(GameSettings.PATH) == OK)
			pad_button(0, JOY_BUTTON_B)
		11:
			pad_button(0, JOY_BUTTON_B, false)
			check("B goes back to the title", game.menu._stack == ["main"])
			game._on_play_requested()
		12:
			check("match waiting on the ready screen", game.state == game.State.WAITING)
			pad_button(1, JOY_BUTTON_DPAD_RIGHT)
		13:
			pad_button(1, JOY_BUTTON_DPAD_RIGHT, false)
			check("P2 now shown as using a controller", Controls.using_pad[1])
			pad_button(0, JOY_BUTTON_Y)
		14:
			pad_button(0, JOY_BUTTON_Y, false)
			check("Y starts the draft", game.state == game.State.DRAFT)
			pad_axis(0, JOY_AXIS_LEFT_X, 0.6)
		15:
			var lean := Controls.read_lean(0)
			check("P1 left stick gives analog lean (%.2f)" % lean.x, lean.x > 0.3 and lean.x < 0.9)
			check("P2 lean unaffected by P1's stick", Controls.read_lean(1) == Vector2.ZERO)
			pad_axis(0, JOY_AXIS_LEFT_X, 0.0)
			pad_button(0, JOY_BUTTON_START)
		16:
			pad_button(0, JOY_BUTTON_START, false)
			check("Start pauses", paused and game.menu._stack == ["pause"])
			pad_button(0, JOY_BUTTON_START)
		17:
			pad_button(0, JOY_BUTTON_START, false)
			check("Start again resumes", not paused and not game.menu.is_open())
			key(KEY_ESCAPE)
		18:
			key(KEY_ESCAPE, false)
			check("Esc pauses", paused)
			key(KEY_ESCAPE)
		19:
			key(KEY_ESCAPE, false)
			check("Esc resumes", not paused)
			print("%s" % ("All control tests passed" if _fails == 0 else "%d control tests FAILED" % _fails))
			return true
	return false
