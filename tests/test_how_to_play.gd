extends SceneTree
## Checks the HOW TO PLAY guide: the title-screen button opens it, NEXT /
## BACK / left-right flip its steps, it pops up before the first match
## only, and GOT IT or SKIP gets you back to the game.
##   godot --headless --script res://tests/test_how_to_play.gd

var game: Node
var _t := 0
var _fails := 0
var _step := 0
## The real "seen it" setting, put back at the end so this test doesn't
## change what happens on this computer.
var _was_seen := false


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func press(text: String) -> void:
	var b := _find_button(game.menu._pages["howto"] if game.menu._pages.has("howto") else game.menu, text)
	if b == null:
		b = _find_button(game.menu, text)
	check("found a visible %s button" % text, b != null)
	if b:
		b.pressed.emit()


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
	var m: MainMenu = game.menu
	match _step:
		1:
			_was_seen = game.settings.seen_how_to_play
			check("title screen is open", menu_top() == "main")
			press("HOW TO PLAY")
		2:
			check("HOW TO PLAY button opens the guide", menu_top() == "howto")
			check("guide starts on the draft step", m._howto.step == 0 and m._howto_step.text == "1. DRAFT")
			check("no BACK on the first step", not m._howto_prev.visible)
			press("NEXT  >")
		3:
			check("NEXT goes to the build step", m._howto.step == 1 and m._howto_step.text == "2. BUILD")
			check("BACK shows on later steps", m._howto_prev.visible)
			m._howto_go(1, false)  # what pressing right does
		4:
			check("right goes to the roll step", m._howto.step == 2)
			check("last step says GOT IT!", m._howto_next.text == "GOT IT!")
			m._howto_go(1, false)
		5:
			check("right on the last step stays put", m._howto.step == 2 and menu_top() == "howto")
			press("<  BACK")
		6:
			check("BACK goes back a step", m._howto.step == 1)
			m._howto_go(1)
			m._howto_go(1)
		7:
			check("GOT IT! from the title goes back to the title", menu_top() == "main")
			# A first match: the guide pops up over the READY? screen.
			game.auto_how_to_play = true
			game.settings.seen_how_to_play = false
			game._on_play_requested()
		8:
			check("guide pops up before the first match", menu_top() == "howto" and m._stack.size() == 1)
			check("it starts on step 1 again", m._howto.step == 0)
			check("the match is waiting behind it", game.state == game.State.WAITING)
			check("it's remembered as seen", game.settings.seen_how_to_play)
			press("SKIP")
		9:
			check("SKIP closes it and shows the match", not m.is_open() and game.state == game.State.WAITING)
			game.show_title()
		10:
			game._on_play_requested()
		11:
			check("second match: no guide", not m.is_open())
			game.show_title()
			# Esc closes the pop-up too.
			game.settings.seen_how_to_play = false
			game._on_play_requested()
		12:
			m.back()
		13:
			check("Esc closes the pop-up", not m.is_open())
			game.settings.seen_how_to_play = _was_seen
			game.settings.save_to_disk()
			print("\n%s (%d failed)" % ["ALL PASSED" if _fails == 0 else "SOME FAILED", _fails])
			quit(1 if _fails > 0 else 0)
	return false
