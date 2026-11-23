extends SceneTree
## Screenshots of the pickaxe-on-rock UI feel (not part of the game):
##   godot --resolution 1280x720 --script res://tests/shot_ui_feel.gd -- <out.png> <mode>
## Modes: title (PLAY lit up), press (just after pressing PLAY: chips and
## shine in flight), settings (the SETTINGS page, on UI SHAKE).
var game: Node
var _t := 0
var out := "user://shot.png"
var mode := "title"
var _shot_at := 40


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.settings.graphics_auto = false


func _process(_d: float) -> bool:
	_t += 1
	if _t == 30:
		var play := _find(game.menu, "PLAY")
		match mode:
			"title":
				play.grab_focus()
			"press":
				play.grab_focus()
				UIFeel._node._mouse_last = false
				play.pressed.emit()
				_shot_at = 33
			"settings":
				game.menu._push("settings")
		if mode == "settings":
			_shot_at = 60
	if _t == 50 and mode == "settings":
		var row := _find(game.menu, "UI SHAKE")
		if row:
			row.grab_focus()
	if _t == maxi(_shot_at, 31):
		root.get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		return true
	return false


func _find(n: Node, text: String) -> Button:
	if n is Button and n.is_visible_in_tree() and (n as Button).text.begins_with(text):
		return n
	for c in n.get_children():
		var f := _find(c, text)
		if f:
			return f
	return null
