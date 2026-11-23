extends SceneTree
## Finds on-screen text that overlaps other text (not part of the game).
## Steps through the screens of a match and the hub, and at each one lists
## any two visible bits of text whose letters overlap, and any text that
## runs off the screen. Also saves a picture of each screen.
##   godot --resolution 1280x720 --script res://tests/find_ui_overlap.gd -- <out dir> [people] [bots]
## (Needs a real window, so run it with a screen, or xvfb-run on Linux.)

var game: Node
var _t := 0
var _step := 0
var _wait := 0
var _out := "user://ui/"
var _problems := 0
var people := 2
var bots := 2

## [name, frames to wait, what to do].
var steps: Array = []


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: _out = a[0]
	if a.size() > 1: people = int(a[1])
	if a.size() > 2: bots = int(a[2])
	DirAccess.make_dir_recursive_absolute(_out)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.settings.graphics_auto = false   # software drawing is slow; keep the look fixed
	game.settings.show_fps = true   # check the FPS counter too
	steps = [
		["title", 20, func(): pass],
		["settings", 20, func(): game.menu._push("settings")],
		["draft", 30, func():
			game.menu.close()
			game.settings.player_count = people
			game.settings.bot_count = bots
			game._setup_local_seats()
			game._new_match()
			game.menu.close()
			game._start_draft()],
		["wild_draft", 90, func():
			game.frame = 3
			game._prepare_roll()
			game.wild = "low_gravity"
			game._start_draft()],
		["build", 40, func(): game._start_build()],
		["countdown", 30, func(): game._start_countdown()],
		["roll", 120, func(): pass],
		["results", 60, func():
			game.state = game.State.ROLLING
			for m in game.marbles:
				m.arrived = true
			game.arrival_order = range(game.player_count)
			game._finish_frame()
			if game.state == game.State.REPLAY:
				game._end_replay()],
		["strike", 10, func(): game.hud.show_strike(0, game.player_colors[0])],
		["scoreboard", 240, func(): pass],
		["hub", 60, func():
			game.settings.player_count = people
			game._enter_hub()],
		["hub_trial", 8, func():
			var t: TimeTrial = game.hub.trial
			var m: Marble = game.hub.marbles[0]
			var f := t.course.world_frame_at(TimeTrial.START_AT + 0.4)
			m.global_position = f.origin + f.basis.y * 0.35
			m.linear_velocity = -f.basis.z * 2.0],
	]


func _process(_d: float) -> bool:
	_t += 1
	if _t < 5:
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_check(steps[_step - 1][0])
		return false
	if _step >= steps.size():
		print("UI OVERLAP: %d problem(s)" % _problems)
		quit(1 if _problems > 0 else 0)
		return true
	var s: Array = steps[_step]
	(s[2] as Callable).call()
	_wait = s[1]
	_step += 1
	return false


## Where the letters of a piece of text actually are on screen.
func _text_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var xf := c.get_global_transform_with_canvas()
	r = Rect2(xf.origin, c.size * xf.get_scale())
	if c is Label:
		var l := c as Label
		if l.text.strip_edges() == "":
			return Rect2()
		# A label with its own background pill covers the whole pill.
		if l.has_theme_stylebox_override("normal") and not l.get_theme_stylebox("normal") is StyleBoxEmpty:
			return r.grow(-2.0)
		var font := l.get_theme_font("font")
		var size := l.get_theme_font_size("font_size")
		var width := -1.0 if l.autowrap_mode == TextServer.AUTOWRAP_OFF else l.size.x
		var ts := font.get_multiline_string_size(l.text, l.horizontal_alignment, width, size) * xf.get_scale()
		ts.x = minf(ts.x, r.size.x) if l.autowrap_mode != TextServer.AUTOWRAP_OFF else ts.x
		var x := r.position.x
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER: x += (r.size.x - ts.x) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT: x += r.size.x - ts.x
		var y := r.position.y
		match l.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER: y += (r.size.y - ts.y) / 2.0
			VERTICAL_ALIGNMENT_BOTTOM: y += r.size.y - ts.y
		return Rect2(x, y, ts.x, ts.y).grow(-2.0)
	if c is Button:
		if (c as Button).text == "":
			return Rect2()
		return r.grow(-2.0)
	return Rect2()


func _shown(c: CanvasItem) -> bool:
	var n: Node = c
	while n:
		if n is CanvasItem:
			if not (n as CanvasItem).visible or (n as CanvasItem).modulate.a < 0.15 or (n as CanvasItem).self_modulate.a < 0.15:
				return false
		elif n is CanvasLayer and not (n as CanvasLayer).visible:
			return false
		n = n.get_parent()
	return true


func _check(name: String) -> void:
	var texts: Array = []
	for c in root.find_children("*", "Control", true, false):
		if (c is Label or c is Button) and _shown(c):
			var r := _text_rect(c)
			if r.has_area():
				texts.append([c, r])
	var screen := root.get_visible_rect()
	var found := []
	for i in texts.size():
		var a: Control = texts[i][0]
		var ra: Rect2 = texts[i][1]
		if not screen.encloses(ra.grow(-1.0)) and ra.intersects(screen):
			found.append("  off screen: %s '%s' %s" % [a.get_path(), _short(a), ra])
		for j in range(i + 1, texts.size()):
			var b: Control = texts[j][0]
			var rb: Rect2 = texts[j][1]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var o := ra.intersection(rb)
			if o.size.x > 3.0 and o.size.y > 3.0:
				found.append("  overlap: '%s' (%s) x '%s' (%s) by %dx%d" % [_short(a), a.name, _short(b), b.name, o.size.x, o.size.y])
	print("[%s] %d texts, %d problem(s)" % [name, texts.size(), found.size()])
	for f in found:
		print(f)
	_problems += found.size()
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))


func _short(c: Control) -> String:
	var t: String = c.text if "text" in c else ""
	return t.replace("\n", " / ").left(32)
