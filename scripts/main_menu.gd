class_name MainMenu
extends CanvasLayer
## The title screen, its sub-pages (Play, Settings, Controls, Credits) and
## the pause menu. Everything is built in code, like the HUD.
##
## The menu never changes the game itself: it only emits signals, and
## main.gd decides what happens. That keeps it easy to add pages later.
## PRACTICE takes everyone to the practice island (main.gd opens the hub).
## ONLINE hosts or joins a game, over Steam or by address (main.gd and
## net.gd do the networking); the lobby page shows who's in, lets the host
## invite Steam friends, add bots and start.
## ACHIEVEMENTS lists every achievement and which ones you have.
## HOW TO PLAY is a short picture guide (draft, build, roll). main.gd also
## shows it over the first match anyone starts on this computer.
##
## Keyboard: arrows (or W/S) move between buttons, Enter (or E) picks,
## left/right change a setting, Esc goes back. The mouse works too.

signal play_requested
signal practice_requested
signal host_requested
signal steam_host_requested
signal invite_requested
signal join_requested(address: String)
signal lobby_leave_requested
signal lobby_start_requested
signal lobby_bots_changed(count: int)
signal resume_requested
signal restart_frame_requested
signal quit_to_menu_requested
signal quit_requested
signal settings_changed

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const PANEL_BG := Color(0.07, 0.09, 0.16, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)
## The game's name on the title screen (and on signs round the world).
const TITLE := "BOWLING WIP"
const VERSION := "prototype"

var _retry_button: Button
var settings: GameSettings
## Set by main.gd; the online page asks it whether Steam is running.
var steam: SteamService
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
var _address: LineEdit
var _lobby_list: Label
var _lobby_host_only: Array = []
var _lobby_wait: Label
var _lobby_invite: Button
var _lobby_steam := false
var _lobby_in_game := false
var _howto: HowToPlay
var _howto_step: Label
var _howto_text: Label
var _howto_dots: Label
var _howto_prev: Button
var _howto_next: Button


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

	_build_main_page()
	_build_play_page()
	_build_online_page()
	_build_lobby_page()
	_build_achievements_page()
	_build_settings_page()
	_build_controls_page()
	_build_credits_page()
	_build_how_to_play_page()
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
## `retry`: show RETRY FRAME (not at the hub, where there's no frame).
func open_pause(retry := true) -> void:
	_retry_button.visible = retry
	paused_menu = true
	_stack = ["pause"]
	_show_top()


## Show the HOW TO PLAY guide over a match that's about to start (the
## first time). GOT IT or SKIP closes it and the match carries on.
func open_how_to_play() -> void:
	paused_menu = true
	_stack = ["howto"]
	_show_top()


func close() -> void:
	_stack.clear()
	_lobby_in_game = false
	_show_top()


## Show the online lobby. Only the host gets the bots, frames and start
## controls; over Steam everyone can invite friends.
## `in_game`: opened with Esc on the online island (Esc again closes it;
## LEAVE leaves the game).
func open_lobby(is_host: bool, over_steam := false, in_game := false) -> void:
	paused_menu = in_game
	_lobby_steam = over_steam
	_lobby_in_game = in_game
	_stack = ["lobby"] if in_game else ["main", "online", "lobby"]
	set_lobby_text(_lobby_list.text, is_host)
	_show_top()


## Back to the HOST / JOIN page (after leaving or failing to connect).
func back_to_online() -> void:
	paused_menu = false
	_stack = ["main", "online"]
	_show_top()


func set_lobby_text(text: String, is_host: bool) -> void:
	_lobby_list.text = text
	for c in _lobby_host_only:
		c.visible = is_host
	_lobby_wait.visible = not is_host or _lobby_in_game
	_lobby_wait.text = ("Roll through the PLAY arch on the island to get ready. The match starts when everyone is." if _lobby_in_game
			else "Waiting for the host to start...")
	_lobby_invite.visible = _lobby_steam


func is_open() -> bool:
	return not _stack.is_empty()


## Go back one page. Backing out of the pause menu resumes the match;
## backing out of the lobby leaves the online game.
func back() -> void:
	if not _stack.is_empty() and _stack[-1] == "lobby" and _lobby_in_game:
		close()
	elif _stack == ["howto"]:
		close()
	elif not _stack.is_empty() and _stack[-1] == "lobby":
		lobby_leave_requested.emit()
	elif _stack.size() > 1:
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
		if c is Button and not (c as Button).disabled and (c as Button).visible:
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
	_button(page, "THE HUB", _on_practice)
	_button(page, "ONLINE", func(): _push("online"))
	_button(page, "SETTINGS", func(): _push("settings"))
	_button(page, "HOW TO PLAY", func(): _push("howto"))
	_button(page, "CONTROLS", func(): _push("controls"))
	_button(page, "ACHIEVEMENTS", func(): _push("achievements"))
	_button(page, "CREDITS", func(): _push("credits"))
	_button(page, "QUIT", func(): quit_requested.emit())


func _on_practice() -> void:
	practice_requested.emit()


func _build_play_page() -> void:
	var page := _page("play", "LOCAL MATCH")
	var players := _stepper(page, "PLAYERS", [1, 2, 3, 4])
	var bots := _stepper(page, "BOTS", [0, 1, 2, 3])
	# People and bots share the four seats.
	players.value_changed.connect(func(i):
		settings.player_count = i + 1
		settings.bot_count = mini(settings.bot_count, 3 - i)
		bots.index = settings.bot_count
		_save())
	bots.value_changed.connect(func(i):
		settings.bot_count = mini(i, 4 - settings.player_count)
		bots.index = settings.bot_count
		_save())
	var skill := _stepper(page, "BOT SKILL", MarbleBot.SKILLS.map(func(k): return k.name))
	skill.value_changed.connect(func(i):
		settings.bot_level = i
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
		bots.index = settings.bot_count
		skill.index = settings.bot_level
		frames.index = maxi([3, 5, 10].find(settings.frames_per_match), 0)
		bump.index = 0 if settings.marbles_collide else 1)
	_note(page, "Everyone shares this keyboard. Players 3 and 4 use I J K L and the number pad.")
	_button(page, "START", func(): play_requested.emit(), true)
	_button(page, "BACK", back)


func _build_online_page() -> void:
	var page := _page("online", "ONLINE")
	var steam_host := _button(page, "HOST ON STEAM", func(): steam_host_requested.emit(), true)
	var steam_note := _note(page, "")
	_note(page, "Or play by address. HOST BY ADDRESS, or type a friend's address (like 192.168.1.20) and JOIN:")
	_button(page, "HOST BY ADDRESS", func(): host_requested.emit())
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "address"
	_address.add_theme_font_size_override("font_size", 24)
	_address.custom_minimum_size = Vector2(440, 48)
	_address.text_submitted.connect(func(t): join_requested.emit(t))
	page.add_child(_address)
	_button(page, "JOIN", func(): join_requested.emit(_address.text))
	_note(page, "By address, the host uses port %d (UDP). Over the internet they need it forwarded on their router; on the same Wi-Fi it just works." % NetSession.DEFAULT_PORT)
	_button(page, "BACK", back)
	page.set_meta("sync", func():
		var on := steam != null and steam.available
		steam_host.disabled = not on
		steam_note.text = ("Play with your Steam friends: host, then invite them from the lobby. They can also pick \"Join Game\" on you in their Steam friends list. No setup needed." if on
				else "Steam play is off: %s. You can still play by address." % (steam.problem if steam else "Steam isn't set up")))


func _build_lobby_page() -> void:
	var page := _page("lobby", "LOBBY")
	_lobby_list = Label.new()
	_lobby_list.add_theme_font_override("font", TITLE_FONT)
	_lobby_list.add_theme_font_size_override("font_size", 26)
	_lobby_list.custom_minimum_size = Vector2(440, 150)
	page.add_child(_lobby_list)
	var bots := _stepper(page, "BOTS", [0, 1, 2, 3])
	bots.value_changed.connect(func(i):
		settings.bot_count = i
		_save()
		lobby_bots_changed.emit(i))
	var skill := _stepper(page, "BOT SKILL", MarbleBot.SKILLS.map(func(k): return k.name))
	skill.value_changed.connect(func(i):
		settings.bot_level = i
		_save())
	var frames := _stepper(page, "FRAMES", [3, 5, 10])
	frames.value_changed.connect(func(i):
		settings.frames_per_match = [3, 5, 10][i]
		_save())
	_lobby_invite = _button(page, "INVITE STEAM FRIENDS", func(): invite_requested.emit())
	var start := _button(page, "START NOW", func(): lobby_start_requested.emit(), true)
	_lobby_host_only = [bots, skill, frames, start]
	_lobby_wait = Label.new()
	_lobby_wait.text = "Waiting for the host to start..."
	_lobby_wait.add_theme_font_size_override("font_size", 20)
	_lobby_wait.add_theme_color_override("font_color", GOLD)
	_lobby_wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_wait.custom_minimum_size = Vector2(440, 0)
	page.add_child(_lobby_wait)
	page.set_meta("sync", func():
		bots.index = settings.bot_count
		skill.index = settings.bot_level
		frames.index = maxi([3, 5, 10].find(settings.frames_per_match), 0))
	_button(page, "LEAVE GAME", func(): lobby_leave_requested.emit())


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
	var replay := _stepper(page, "STRIKE REPLAY", ["OFF", "ON"])
	replay.value_changed.connect(func(i):
		settings.strike_replay = i == 1
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
		replay.index = 1 if settings.strike_replay else 0
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
	_note(page, "Move = lean while rolling, steer the pointer in the draft and slide your piece in the build. At the hub, the turn key (or B) leaves a plate.")
	_button(page, "BACK", back)


## Every achievement: its badge, name and how to get it. Locked ones are
## grey. Rebuilt each time it's shown so it's always up to date.
func _build_achievements_page() -> void:
	var page := _page("achievements", "ACHIEVEMENTS")
	var count := Label.new()
	count.add_theme_font_size_override("font_size", 18)
	count.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	page.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var back_button := _button(page, "BACK", back)
	# Up/down on the keyboard or a controller scrolls the list.
	back_button.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down"):
			scroll.scroll_vertical += 120 if e.is_action_pressed("ui_down") else -120
			back_button.accept_event())
	page.set_meta("sync", func():
		for c in grid.get_children():
			c.free()
		count.text = "%d of %d unlocked" % [Achievements.unlocked_count(), Achievements.LIST.size()]
		for a in Achievements.LIST:
			var got := Achievements.has(a.id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.custom_minimum_size = Vector2(365, 64)
			row.add_child(AchievementIcon.make(a, not got, 60))
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", 0)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var title := Label.new()
			title.text = a.name
			title.add_theme_font_override("font", TITLE_FONT)
			title.add_theme_font_size_override("font_size", 20)
			title.add_theme_color_override("font_color", GOLD if got else Color(1, 1, 1, 0.55))
			words.add_child(title)
			var how := Label.new()
			var goal: int = a.get("goal", 0)
			how.text = a.text + ("  (%d / %d)" % [Achievements.count(a.id), goal] if goal > 0 and not got else "")
			how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			how.add_theme_font_size_override("font_size", 14)
			how.add_theme_color_override("font_color", Color(1, 1, 1, 0.8 if got else 0.5))
			words.add_child(how)
			row.add_child(words)
			grid.add_child(row))


func _build_credits_page() -> void:
	var page := _page("credits", "CREDITS")
	_note(page, "Made with Godot 4 (godotengine.org).\n\nFonts: Righteous by Astigmatic, and Chakra Petch by the\nChakra Petch Project Authors, both under the SIL Open Font License.\n\nSteam support: GodotSteam (MIT License) and the Steamworks SDK.\n\nEverything else is built in code for this prototype.")
	_button(page, "BACK", back)


## The picture guide: one step at a time, with NEXT (GOT IT on the last
## step), BACK and SKIP. Left and right on the picture flip steps too.
func _build_how_to_play_page() -> void:
	var page := _page("howto", "HOW TO PLAY")
	_howto_step = Label.new()
	_howto_step.add_theme_font_override("font", TITLE_FONT)
	_howto_step.add_theme_font_size_override("font_size", 24)
	page.add_child(_howto_step)
	_howto = HowToPlay.new()
	page.add_child(_howto)
	_howto_text = _note(page, "")
	_howto_text.custom_minimum_size = Vector2(HowToPlay.SIZE.x, 44)
	_howto_text.add_theme_font_size_override("font_size", 18)
	_howto_text.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_howto_dots = Label.new()
	_howto_dots.add_theme_font_size_override("font_size", 18)
	_howto_dots.add_theme_color_override("font_color", GOLD)
	page.add_child(_howto_dots)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	_howto_next = _button(row, "NEXT  >", func(): _howto_go(1), true)
	_howto_prev = _button(row, "<  BACK", func(): _howto_go(-1))
	_button(row, "SKIP", _howto_done)
	# Left/right on any of the buttons flips the page, like a picture book.
	for b in row.get_children():
		(b as Button).gui_input.connect(func(e: InputEvent):
			if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
				_howto_go(1 if e.is_action_pressed("ui_right") else -1, false)
				b.accept_event())
	_note(page, "Everyone's keys are on the CONTROLS page.")
	page.set_meta("sync", func():
		_howto.step = 0
		_howto_refresh())


## Move `by` steps through the guide. Past the last step, the guide closes
## (only for NEXT: left/right just stop at the ends).
func _howto_go(by: int, can_finish := true) -> void:
	var to := _howto.step + by
	if to >= HowToPlay.STEPS.size():
		if can_finish:
			_howto_done()
		return
	if to < 0:
		return
	_howto.step = to
	_howto_refresh()
	if not _howto_prev.visible:
		_howto_next.grab_focus()


func _howto_refresh() -> void:
	var s: Dictionary = HowToPlay.STEPS[_howto.step]
	_howto_step.text = s.name
	_howto_text.text = s.text
	var last := _howto.step == HowToPlay.STEPS.size() - 1
	_howto_next.text = "GOT IT!" if last else "NEXT  >"
	_howto_prev.visible = _howto.step > 0
	var dots := []
	for i in HowToPlay.STEPS.size():
		dots.append("●" if i == _howto.step else "○")
	_howto_dots.text = "  ".join(dots)


## GOT IT / SKIP: back to the title, or on with the match.
func _howto_done() -> void:
	if _stack.size() > 1:
		back()
	else:
		close()


func _build_pause_page() -> void:
	var page := _page("pause", "PAUSED")
	_button(page, "RESUME", func(): resume_requested.emit(), true)
	_retry_button = _button(page, "RETRY FRAME", func(): restart_frame_requested.emit())
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


func _note(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	parent.add_child(l)
	return l


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
