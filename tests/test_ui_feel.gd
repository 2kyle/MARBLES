extends SceneTree
## The "pickaxe on rock" UI feel (scripts/ui_feel.gd, scripts/ui_sfx.gd):
## buttons and panels get faceted corners, every sound is made, pressing a
## button squashes it, throws chips and jolts the screen, UI SHAKE OFF
## really turns the jolt off, and the jolt always puts the screen back.
##   godot --headless --fixed-fps 120 --script res://tests/test_ui_feel.gd

var game: Node
var _t := 0
var _fails := 0
var _button: Button
var _panel: PanelContainer
var _layer: CanvasLayer
var _max_offset := 0.0


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
	if _t == 3:
		_layer = CanvasLayer.new()
		root.add_child(_layer)
		_panel = PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.1, 0.1, 0.2, 0.8)
		ps.set_corner_radius_all(18)
		_panel.add_theme_stylebox_override("panel", ps)
		_panel.size = Vector2(300, 200)
		_layer.add_child(_panel)
		_button = Button.new()
		_button.text = "PLAY"
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(1, 1, 1, 0.06)
		bs.set_corner_radius_all(12)
		bs.content_margin_top = 5
		_button.add_theme_stylebox_override("normal", bs)
		_button.position = Vector2(100, 100)
		_button.size = Vector2(240, 44)
		_layer.add_child(_button)
	if _t == 6:
		var sb: StyleBoxFlat = _button.get_theme_stylebox("normal")
		_check(sb.corner_detail <= 2, "button corners are cut straight (faceted), not rounded")
		var corners := [sb.corner_radius_top_left, sb.corner_radius_top_right,
				sb.corner_radius_bottom_right, sb.corner_radius_bottom_left]
		_check(corners.min() != corners.max(), "each corner is chipped a different amount: %s" % [corners])
		_check(sb.content_margin_top == 5, "carving doesn't change the button's layout")
		_check(_button.has_meta("rock_facets"), "the button draws facets")
		var pst: StyleBoxFlat = _panel.get_theme_stylebox("panel")
		_check(pst.corner_detail <= 2 and _panel.has_meta("rock_facets"), "panels are carved too")
		var menu_button := _find_button(game.menu, "PLAY")
		_check(menu_button != null and (menu_button.get_theme_stylebox("normal") as StyleBoxFlat).corner_detail <= 2,
				"the title menu's buttons are carved")
		var sfx := root.get_node_or_null("UISfx")
		_check(sfx != null, "the UI sound player exists")
		if sfx:
			for s in UISfx.NAMES:
				var takes: Array = sfx._streams.get(s, [])
				var ok := not takes.is_empty() and takes[0] != null
				if ok and takes[0] is AudioStreamWAV:
					ok = takes[0].get_length() > 0.03 and takes[0].data.size() > 1000
				_check(ok, "sound '%s' is ready" % s)
		UIFeel.shake_amount = 1.0
		_button.pressed.emit()
	if _t > 6 and _t < 60 and _layer:
		_max_offset = maxf(_max_offset, _layer.offset.length())
	if _t == 9:
		_check(not _button.scale.is_equal_approx(Vector2.ONE), "pressing squashes the button")
		var chips = root.get_node("UIFeel")._chips
		_check(chips._bits.size() > 5, "pressing throws rock chips and sparkles (%d)" % chips._bits.size())
	if _t == 60:
		_check(_max_offset > 0.5, "pressing jolts the screen (%.1f px)" % _max_offset)
		_check(_layer.offset == Vector2.ZERO, "the screen goes back where it was after the jolt")
		_check(_button.scale.is_equal_approx(Vector2.ONE), "the button springs back to normal size")
		UIFeel.shake_amount = 0.0
		_max_offset = 0.0
		_button.pressed.emit()
	if _t > 60 and _t < 100:
		_max_offset = maxf(_max_offset, _layer.offset.length())
	if _t == 100:
		_check(_max_offset == 0.0, "UI SHAKE OFF: no jolt")
		UIFeel.shake_amount = 1.0
		# Nothing breaks if a pressed button is freed straight away.
		var gone := Button.new()
		_layer.add_child(gone)
		gone.size = Vector2(120, 40)
		gone.pressed.emit()
		gone.free()
		UIFeel.deny(_button)
	if _t == 130:
		print("All UI feel tests passed" if _fails == 0 else "%d UI feel test(s) FAILED" % _fails)
		quit(1 if _fails else 0)
	return false


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text.begins_with(text):
		return n
	for c in n.get_children():
		var f := _find_button(c, text)
		if f:
			return f
	return null
