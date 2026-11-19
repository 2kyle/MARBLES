class_name MainMenu
extends CanvasLayer
## The title screen, its sub-pages (Play, Settings, Controls, Credits) and
## the pause menu. Everything is built in code, like the HUD.
##
## The menu never changes the game itself: it only emits signals, and
## main.gd decides what happens. That keeps it easy to add pages later.
## PRACTICE takes everyone to the practice island (main.gd opens the hub).
##
## Keyboard: arrows (or W/S) move between buttons, Enter (or E) picks,
## left/right change a setting, Esc goes back. The mouse works too.

signal play_requested
signal practice_requested
signal online_requested
signal resume_requested
signal restart_frame_requested
signal quit_to_menu_requested
signal quit_requested
signal settings_changed

const TITLE_FONT := preload("res://fonts/ChakraPetch-Bold.ttf")
const PANEL_BG := Color(0.07, 0.09, 0.16, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)
const TITLE := "MARBLES 4P"
const VERSION := "prototype"

var settings: GameSettings
## True while the pause menu is up (during a match).
var paused_menu := false

var _pages := {}
var _stack: Array = []
var _root: Control
var _title_box: Control
var _toast: Label
var _toast_time := 0.0
var _fps: Label
var _dim: ColorRect


## A button that cycles through values with left/right (or a click).
## Used for every setting so they all work the same way.
class Stepper:
	extends Button
	signal value_changed(index: int)
	var caption := ""
	var options: Array = []
	var index := 0:
		set(v):
			index = wrapi(v, 0, maxi(options.size(), 1))
			_refresh()

	func _ready() -> void:
		pressed.connect(func(): step(1))
		_refresh()

	func step(by: int) -> void:
		index += by
		value_changed.emit(index)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_left"):
			step(-1)
			accept_event()
		elif event.is_action_pressed("ui_right"):
			step(1)
			accept_event()

	func _refresh() -> void:
		if options.is_empty():
			return
		text = "%s      <  %s  >" % [caption, str(options[index])]


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_menu_keys()

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Title, top left.
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(72, 56)
	title_box.add_theme_constant_override("separation", -6)
	_root.add_child(title_box)
	_title_box = title_box
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title_box.add_child(title)
	var sub := Label.new()
	sub.text = "Build it. Wreck it. Roll it."
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", GOLD)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	sub.add_theme_constant_override("outline_size", 8)
	title_box.add_child(sub)

	_build_main_page()
	_build_play_page()
	_build_settings_page()
	_build_controls_page()
	_build_credits_page()
	_build_pause_page()

	var version := Label.new()
	version.text = "%s  ·  %s" % [TITLE, VERSION]
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_right = -20
	version.offset_bottom = -14
	_root.add_child(version)

	_toast = Label.new()
	_toast.add_theme_font_override("font", TITLE_FONT)
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -60
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_toast)

	_fps = Label.new()
	_fps.position = Vector2(12, 860)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_fps.offset_top = -64
	_fps.offset_left = 16
	_fps.add_theme_font_size_override("font_size", 14)
	add_child(_fps)


func _process(delta: float) -> void:
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	_fps.visible = settings != null and settings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("quit"):
		back()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ Showing pages

## Show the title screen.
func open_main() -> void:
	paused_menu = false
	_stack = ["main"]
	_show_top()


## Show the pause menu over a match.
func open_pause() -> void:
	paused_menu = true
	_stack = ["pause"]
	_show_top()


func close() -> void:
	_stack.clear()
	_show_top()


func is_open() -> bool:
	return not _stack.is_empty()


## Go back one page. Backing out of the pause menu resumes the match.
func back() -> void:
	if _stack.size() > 1:
		_stack.pop_back()
		_show_top()
	elif paused_menu:
		resume_requested.emit()


func _push(page: String) -> void:
	_stack.append(page)
	_show_top()


func _show_top() -> void:
	var top: String = _stack[-1] if not _stack.is_empty() else ""
	_root.visible = top != ""
	_dim.visible = top != ""
	# Over a match, dim the whole screen; on the title screen only shade
	# the left side so the island stays in view.
	_dim.color = Color(0.02, 0.03, 0.08, 0.6) if paused_menu else Color(0, 0, 0, 0)
	_title_box.visible = not paused_menu or top == "pause"
	for name in _pages:
		_pages[name].visible = name == top
	if top != "":
		var first := _first_focus(_pages[top])
		if first:
			first.grab_focus.call_deferred()


func _first_focus(node: Node) -> Control:
	for c in node.get_children():
		if c is Button and not (c as Button).disabled:
			return c
		var inner := _first_focus(c)
		if inner:
			return inner
	return null


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5


# ------------------------------------------------------------ Pages

func _build_main_page() -> void:
	var page := _page("main", "")
	_button(page, "PLAY", func(): _push("play"), true)
	_button(page, "PRACTICE ISLAND", _on_practice)
	_button(page, "ONLINE", _on_online, false, "SOON")
	_button(page, "SETTINGS", func(): _push("settings"))
	_button(page, "CONTROLS", func(): _push("controls"))
	_button(page, "CREDITS", func(): _push("credits"))
	_button(page, "QUIT", func(): quit_requested.emit())


func _on_practice() -> void:
	practice_requested.emit()


func _on_online() -> void:
	online_requested.emit()
	toast("Online play is coming soon!")


func _build_play_page() -> void:
	var page := _page("play", "LOCAL MATCH")
	var players := _stepper(page, "PLAYERS", [1, 2, 3, 4])
	players.value_changed.connect(func(i):
		settings.player_count = i + 1
		_save())
	var frames := _stepper(page, "FRAMES", [3, 5, 10])
	frames.value_changed.connect(func(i):
		settings.frames_per_match = [3, 5, 10][i]
		_save())
	var bump := _stepper(page, "BUMPING", ["ON", "OFF"])
	bump.value_changed.connect(func(i):
		settings.marbles_collide = i == 0
		_save())
	page.set_meta("sync", func():
		players.index = settings.player_count - 1
		frames.index = maxi([3, 5, 10].find(settings.frames_per_match), 0)
		bump.index = 0 if settings.marbles_collide else 1)
	_note(page, "Everyone shares this keyboard. Players 3 and 4 use I J K L and the number pad.")
	_button(page, "START", func(): play_requested.emit(), true)
	_button(page, "BACK", back)


func _build_settings_page() -> void:
	var page := _page("settings", "SETTINGS")
	var full := _stepper(page, "FULLSCREEN", ["OFF", "ON"])
	full.value_changed.connect(func(i):
		settings.fullscreen = i == 1
		_save())
	var vsync := _stepper(page, "VSYNC", ["OFF", "ON"])
	vsync.value_changed.connect(func(i):
		settings.vsync = i == 1
		_save())
	var volumes := []
	for v in range(0, 101, 10):
		volumes.append("%d%%" % v)
	var volume := _stepper(page, "VOLUME", volumes)
	volume.value_changed.connect(func(i):
		settings.master_volume = i / 10.0
		_save())
	var shake := _stepper(page, "CAMERA SHAKE", ["OFF", "LOW", "NORMAL", "HIGH"])
	shake.value_changed.connect(func(i):
		settings.camera_shake = [0.0, 0.5, 1.0, 1.6][i]
		_save())
	var fps := _stepper(page, "SHOW FPS", ["OFF", "ON"])
	fps.value_changed.connect(func(i):
		settings.show_fps = i == 1
		_save())
	page.set_meta("sync", func():
		full.index = 1 if settings.fullscreen else 0
		vsync.index = 1 if settings.vsync else 0
		volume.index = roundi(settings.master_volume * 10.0)
		shake.index = maxi([0.0, 0.5, 1.0, 1.6].find(settings.camera_shake), 0)
		fps.index = 1 if settings.show_fps else 0)
	_button(page, "BACK", back)


func _build_controls_page() -> void:
	var page := _page("controls", "CONTROLS")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	page.add_child(tabs)
	var diagram := ControlsDiagram.new()
	var keys := _button(tabs, "KEYBOARD", func(): diagram.kind = ControlsDiagram.Kind.KEYBOARD)
	var pad := _button(tabs, "CONTROLLER", func(): diagram.kind = ControlsDiagram.Kind.CONTROLLER)
	# Moving onto a tab shows it straight away.
	keys.focus_entered.connect(func(): diagram.kind = ControlsDiagram.Kind.KEYBOARD)
	pad.focus_entered.connect(func(): diagram.kind = ControlsDiagram.Kind.CONTROLLER)
	page.add_child(diagram)
	_note(page, "Move = lean while rolling, steer the pointer in the draft and slide your piece in the build. On the practice island, the turn key (or B) leaves a plate.")
	_button(page, "BACK", back)


func _build_credits_page() -> void:
	var page := _page("credits", "CREDITS")
	_note(page, "Made with Godot 4 (godotengine.org).\n\nFont: Chakra Petch by the Chakra Petch Project Authors,\nunder the SIL Open Font License.\n\nEverything else is built in code for this prototype.")
	_button(page, "BACK", back)


func _build_pause_page() -> void:
	var page := _page("pause", "PAUSED")
	_button(page, "RESUME", func(): resume_requested.emit(), true)
	_button(page, "RETRY FRAME", func(): restart_frame_requested.emit())
	_button(page, "SETTINGS", func(): _push("settings"))
	_button(page, "CONTROLS", func(): _push("controls"))
	_button(page, "QUIT TO MENU", func(): quit_to_menu_requested.emit())


# ------------------------------------------------------------ Widgets

func _page(name: String, heading: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(18)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(72, 230)
	panel.custom_minimum_size = Vector2(440, 0)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	if heading != "":
		var h := Label.new()
		h.text = heading
		h.add_theme_font_override("font", TITLE_FONT)
		h.add_theme_font_size_override("font_size", 34)
		h.add_theme_color_override("font_color", GOLD)
		box.add_child(h)
	panel.visibility_changed.connect(func():
		if panel.visible and box.has_meta("sync") and settings:
			box.get_meta("sync").call())
	_pages[name] = panel
	return box


func _button(parent: Control, text: String, action: Callable, big := false, tag := "") -> Button:
	var b := Button.new()
	b.text = text if tag == "" else "%s   ·  %s" % [text, tag]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", 34 if big else 26)
	_style_button(b, big)
	if tag != "":
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		b.add_theme_color_override("font_focus_color", Color(1, 1, 1, 0.7))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.7))
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _stepper(parent: Control, caption: String, options: Array) -> Stepper:
	var s := Stepper.new()
	s.caption = caption
	s.options = options
	s.alignment = HORIZONTAL_ALIGNMENT_LEFT
	s.add_theme_font_size_override("font_size", 22)
	_style_button(s, false)
	parent.add_child(s)
	return s


func _note(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	parent.add_child(l)


func _style_button(b: Button, big: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8 if big else 5
	normal.content_margin_bottom = 8 if big else 5
	var hot := normal.duplicate()
	hot.bg_color = GOLD
	var pressed := hot.duplicate()
	pressed.bg_color = GOLD.darkened(0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04))
	b.add_theme_color_override("font_focus_color", Color(0.08, 0.06, 0.04))
	b.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.04))
	b.focus_entered.connect(func(): b.add_theme_stylebox_override("normal", hot))
	b.focus_exited.connect(func(): b.add_theme_stylebox_override("normal", normal))
	b.mouse_entered.connect(b.grab_focus)


func _save() -> void:
	settings.save_to_disk()
	settings.apply()
	settings_changed.emit()


## W/S and E work in menus too, alongside the arrows and Enter.
func _add_menu_keys() -> void:
	for pair in [["ui_up", KEY_W], ["ui_down", KEY_S], ["ui_left", KEY_A],
			["ui_right", KEY_D], ["ui_accept", KEY_E]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)
