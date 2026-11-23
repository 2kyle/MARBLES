class_name UIFeel
extends Node
## The "pickaxe on rock" feel for the whole UI. Three jobs:
##
## 1. LOOK: every panel and button gets cut, faceted corners (like a chipped
##    stone or a gem) instead of soft round ones, a light rim on the top
##    edge and a dark one underneath (so it looks like a slab you can
##    press), jagged light and shadow facets, and a glint when it's lit up.
##    All drawn in code: no texture images.
## 2. TOUCH: moving onto a button gives a tiny tick and a glint; pressing it
##    squashes it, sprays rock chips and sparkles from where it was hit,
##    sweeps a shine across it, plays a "clink!" and gives the screen a
##    short jolt (Settings > UI SHAKE, can be turned off).
## 3. SOUND: through UISfx (see ui_sfx.gd for swapping in your own sounds).
##
## Every Button in the game is hooked up by itself (UIFeel watches for new
## ones), so new menus get the feel for free. Things that aren't real
## Buttons (draft cards, the closet, loot crates) call UIFeel.hover(),
## UIFeel.strike() or UIFeel.deny() themselves.
##
## main.gd calls UIFeel.install(self) once at startup.

const GOLD := Color(1.0, 0.82, 0.25)
const ROCK := Color(0.56, 0.53, 0.5)
## Stylebox names that get the faceted corners.
const BOX_NAMES := ["panel", "normal", "hover", "pressed", "focus", "disabled",
		"hover_pressed", "read_only", "background", "fill"]
## Words on buttons that take you back (they get a softer sound).
const BACK_WORDS := ["BACK", "QUIT", "LEAVE", "SKIP", "RESUME"]
## Controls smaller than this don't get facets drawn (too fiddly to see).
const FACET_MIN := Vector2(64, 28)

## How strong the screen jolt is: 0 off, 0.5 low, 1 normal, 1.6 high
## (Settings > UI SHAKE). Set by main.gd.
static var shake_amount := 1.0
static var _node: UIFeel

var _chips: ChipBurst
var _shake := 0.0
var _shake_t := 0.0
var _shake_dir := Vector2.DOWN
var _shake_layer: CanvasLayer
var _shake_base := Vector2.ZERO
var _shake_camera: Camera3D
## When the last press happened, so the page that opens after it doesn't
## also tick for the button it highlights.
var _last_strike := -10.0
var _quiet_until := 0.0
## True when the mouse was used last (chips fly from the click point).
var _mouse_last := false


# ------------------------------------------------------------ Public

## Hook the UI feel into the game. Safe to call more than once.
static func install(from: Node) -> void:
	var tree := from.get_tree()
	UISfx.ensure(tree)
	if _node and is_instance_valid(_node):
		return
	_node = UIFeel.new()
	_node.name = "UIFeel"
	tree.root.add_child.call_deferred(_node)


## Moving onto something: a tick, a glint and a quick shine.
static func hover(c: Control) -> void:
	if _node and is_instance_valid(c):
		_node._hover(c)


## Pressing / picking something: squash, chips, sparkles, shine, clink and
## a screen jolt. `power` ~1 for a button, more for big moments.
## `squash` false if the caller animates the control's scale itself.
static func strike(c: Control, color := GOLD, power := 1.0, squash := true,
		sound := "clink") -> void:
	if _node and is_instance_valid(c):
		_node._strike(c, color, power, squash, sound)


## "No": a dull thunk and a side-to-side wobble (locked, can't afford it).
static func deny(c: Control) -> void:
	if _node and is_instance_valid(c):
		_node._deny(c)


## Give a control the faceted look now (normally automatic).
static func carve(c: Control) -> void:
	if _node and is_instance_valid(c):
		_node._carve(c)


# ------------------------------------------------------------ Setup

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quiet_until = _now() + 0.8
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_chips = ChipBurst.new()
	layer.add_child(_chips)
	_style_theme()
	get_tree().node_added.connect(_on_node_added)
	# Anything built before we arrived (the title menu).
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			_on_node_added(n)
		stack.append_array(n.get_children())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_mouse_last = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_mouse_last = false


func _on_node_added(n: Node) -> void:
	if not n is Control or n.has_meta("rock_seen"):
		return
	var c: Control = n
	c.set_meta("rock_seen", true)
	# Styles are usually set just after add_child, so wait a moment; and
	# re-carve whenever a style is swapped (theme_changed).
	_carve_soon(c)
	c.theme_changed.connect(_carve_soon.bind(c))
	if c is BaseButton:
		_hook_button(c)


## The project theme's default boxes (text boxes, scroll bars) get carved too.
func _style_theme() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0.03, 0.04, 0.09, 0.85)
	edit.border_color = Color(1, 1, 1, 0.25)
	edit.set_border_width_all(2)
	edit.border_width_bottom = 3
	edit.set_corner_radius_all(9)
	edit.set_content_margin_all(10)
	var edit_hot := edit.duplicate()
	edit_hot.border_color = GOLD
	for s in [edit, edit_hot]:
		_rock_box(s, 7)
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit_hot)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD, 0.75)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 5
	grab.content_margin_right = 5
	_rock_box(grab, 3)
	var grab_hot := grab.duplicate()
	grab_hot.bg_color = GOLD
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.3)
	track.set_corner_radius_all(4)
	track.content_margin_left = 5
	track.content_margin_right = 5
	_rock_box(track, 5)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grab_hot)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grab_hot)
	theme.set_stylebox("scroll", "VScrollBar", track)


# ------------------------------------------------------------ The look

## Carve at the end of this frame (by id, in case it's freed by then).
func _carve_soon(c: Control) -> void:
	var id := c.get_instance_id()
	(func(): _carve(instance_from_id(id))).call_deferred()


## Swap a control's soft round boxes for chipped, faceted ones, and draw
## facets over its panels and buttons.
func _carve(target: Object) -> void:
	if not is_instance_valid(target):
		return
	var c := target as Control
	var seed_n: int = c.get_meta("rock_seed", -1)
	if seed_n == -1:
		seed_n = hash(c.get_instance_id()) & 0xffff
		c.set_meta("rock_seed", seed_n)
	var corners := PackedFloat32Array()
	for box_name in BOX_NAMES:
		if not c.has_theme_stylebox_override(box_name):
			continue
		var sb := c.get_theme_stylebox(box_name)
		if sb is StyleBoxFlat:
			_rock_box(sb, seed_n)
			if corners.is_empty() and (box_name == "panel" or box_name == "normal"):
				corners = PackedFloat32Array([sb.corner_radius_top_left,
						sb.corner_radius_top_right, sb.corner_radius_bottom_right,
						sb.corner_radius_bottom_left])
	if corners.is_empty():
		return
	c.set_meta("rock_corners", corners)
	var wants_facets := c is BaseButton or c is PanelContainer or c is Panel
	if wants_facets and not c.has_meta("rock_facets"):
		c.set_meta("rock_facets", true)
		c.draw.connect(_draw_facets.bind(c))
		c.queue_redraw()


## Cut the corners of one box: straight bevels instead of curves, each
## corner a different size so it looks hand-chipped, and a darker lip
## along the bottom so it reads as a slab of stone.
func _rock_box(sb: StyleBoxFlat, seed_n: int) -> void:
	if sb.has_meta("rock"):
		return
	sb.set_meta("rock", true)
	# Someone chose the corner detail on purpose: leave it alone.
	if sb.corner_detail != 8:
		return
	var r := maxf(maxf(sb.corner_radius_top_left, sb.corner_radius_top_right),
			maxf(sb.corner_radius_bottom_right, sb.corner_radius_bottom_left))
	if r < 1.0:
		return
	r = maxf(r, 6.0)
	# Big tilted cut on two opposite corners, small nicks on the other two.
	# (Small boxes like key caps get a gentler version so they stay boxy.)
	var cuts := [1.4, 0.45, 1.15, 0.6] if r > 9.0 else [1.0, 0.55, 0.9, 0.55]
	var turn := seed_n % 4
	sb.corner_radius_top_left = int(r * cuts[turn])
	sb.corner_radius_top_right = int(r * cuts[(turn + 1) % 4])
	sb.corner_radius_bottom_right = int(r * cuts[(turn + 2) % 4])
	sb.corner_radius_bottom_left = int(r * cuts[(turn + 3) % 4])
	sb.corner_detail = 1 if r < 22.0 else 2
	sb.anti_aliasing = true
	if sb.border_width_bottom == 0 and sb.bg_color.a > 0.03:
		# The lip: borders don't change the layout because these boxes set
		# their own content margins (or have none to change).
		sb.border_width_bottom = 3
		sb.border_color = Color(sb.bg_color.darkened(0.55), minf(sb.bg_color.a + 0.25, 1.0)) \
				if sb.bg_color.a > 0.5 else Color(0, 0, 0, 0.35)


## The cut-stone polygon for a control's size and corners.
static func shape(size: Vector2, corners: PackedFloat32Array) -> PackedVector2Array:
	var m := minf(size.x, size.y) / 2.0
	var tl := minf(corners[0], m)
	var tr := minf(corners[1], m)
	var br := minf(corners[2], m)
	var bl := minf(corners[3], m)
	var w := size.x
	var h := size.y
	return PackedVector2Array([Vector2(tl, 0), Vector2(w - tr, 0), Vector2(w, tr),
			Vector2(w, h - br), Vector2(w - br, h), Vector2(bl, h), Vector2(0, h - bl),
			Vector2(0, tl)])


func _draw_facets(c: Control) -> void:
	if not is_instance_valid(c) or not c.has_meta("rock_corners"):
		return
	var size := c.size
	if size.x < FACET_MIN.x or size.y < FACET_MIN.y:
		return
	var box := _current_box(c)
	if not box is StyleBoxFlat or (box.bg_color.a < 0.03 and box.border_width_top == 0):
		return
	var poly := shape(size, c.get_meta("rock_corners"))
	var hot: bool = c is BaseButton and (c.has_focus() or c.is_hovered())
	var rng := RandomNumberGenerator.new()
	rng.seed = c.get_meta("rock_seed", 1)
	var strength := clampf(box.bg_color.a * 1.4, 0.35, 1.0)
	var w := size.x
	var h := size.y

	# Light facet along the top with a jagged lower edge (light catching
	# the cut face), and a shadow facet along the bottom.
	var band := minf(h * 0.24, 14.0)
	var top := PackedVector2Array([Vector2(-2, -2), Vector2(w + 2, -2)])
	var steps := clampi(int(w / 38.0), 3, 14)
	for i in range(steps, -1, -1):
		var x := w * i / steps
		top.append(Vector2(x, band * rng.randf_range(0.35, 1.0)))
	_fill_clipped(c, top, poly, Color(1, 1, 1, (0.2 if hot else 0.1) * strength))
	# The cut line where the light facet meets the face.
	c.draw_polyline(top.slice(2), Color(1, 1, 1, (0.3 if hot else 0.14) * strength), 1.0, true)
	var low := minf(h * 0.2, 11.0)
	var bottom := PackedVector2Array([Vector2(w + 2, h + 2), Vector2(-2, h + 2)])
	for i in steps + 1:
		var x := w * i / steps
		bottom.append(Vector2(x, h - low * rng.randf_range(0.3, 1.0)))
	_fill_clipped(c, bottom, poly, Color(0, 0, 0, 0.22 * strength))
	c.draw_polyline(bottom.slice(2), Color(0, 0, 0, 0.25 * strength), 1.0, true)
	# One big slanted facet across a corner, like a chunk split off.
	var fx := rng.randf_range(0.55, 0.8) * w
	var facet := PackedVector2Array([Vector2(fx, -2), Vector2(w + 2, -2),
			Vector2(w + 2, h * rng.randf_range(0.5, 0.9))])
	_fill_clipped(c, facet, poly, Color(1, 1, 1, (0.07 if hot else 0.035) * strength))

	# Chips knocked out of the edge: little dark nicks along the rim.
	for k in clampi(int(w / 120.0), 1, 4):
		var e := rng.randi() % 8
		var a: Vector2 = poly[e]
		var b: Vector2 = poly[(e + 1) % 8]
		if a.distance_to(b) < 24.0:
			continue
		var at := a.lerp(b, rng.randf_range(0.2, 0.8))
		var along := (b - a).normalized()
		var inward := along.orthogonal() * -1.0
		var nick := rng.randf_range(3.0, 6.0)
		c.draw_colored_polygon(PackedVector2Array([at - along * nick * 1.3, at + along * nick,
				at + inward * nick + along * rng.randf_range(-2.0, 2.0)]), Color(0, 0, 0, 0.35 * strength))
	# Rim: bright on the top and left edges, dark on the bottom and right,
	# so it looks raised and sharp.
	var rim_light := Color(1, 1, 1, (0.55 if hot else 0.28) * strength)
	var rim_dark := Color(0, 0, 0, 0.3 * strength)
	c.draw_polyline(PackedVector2Array([poly[6] + Vector2(1, 0), poly[7] + Vector2(1, 0),
			poly[0] + Vector2(0, 1), poly[1] + Vector2(0, 1)]), rim_light, 1.5, true)
	c.draw_polyline(PackedVector2Array([poly[2] - Vector2(1, 0), poly[3] - Vector2(1, 0),
			poly[4] - Vector2(0, 1), poly[5] - Vector2(0, 1)]), rim_dark, 1.5, true)
	# Two hairline cracks running in from the cut corners.
	for k in 2:
		var at: Vector2 = poly[0].lerp(poly[7], 0.5) if k == 0 else poly[3].lerp(poly[4], 0.5)
		var dir := (Vector2(1, 0.55) if k == 0 else Vector2(-1, -0.5)).normalized()
		var a := at
		var crack := PackedVector2Array([a])
		for j in 3:
			a += dir.rotated(rng.randf_range(-0.6, 0.6)) * rng.randf_range(5.0, 10.0)
			crack.append(a)
		c.draw_polyline(crack, Color(1, 1, 1, 0.12 * strength) if k == 0 else Color(0, 0, 0, 0.2 * strength), 1.0, true)
	# A glint on the top-left cut when it's lit up.
	if hot:
		_star(c, poly[0].lerp(poly[7], 0.5) + Vector2(3, 3), 7.0, Color(1, 1, 1, 0.9))
	# The shine sweeping across after a hover or press.
	var shine: float = c.get_meta("rock_shine", -1.0)
	if shine >= 0.0 and shine <= 1.0:
		var x := lerpf(-0.35 * w - h, 1.1 * w, shine)
		var wide := 18.0 + w * 0.06
		var streak := PackedVector2Array([Vector2(x + h * 0.6, -2), Vector2(x + h * 0.6 + wide, -2),
				Vector2(x + wide, h + 2), Vector2(x, h + 2)])
		_fill_clipped(c, streak, poly, Color(1, 1, 1, 0.42 * (1.0 - shine * 0.6)))
		var thin := PackedVector2Array([Vector2(x + h * 0.6 + wide + 8, -2), Vector2(x + h * 0.6 + wide + 13, -2),
				Vector2(x + wide + 13, h + 2), Vector2(x + wide + 8, h + 2)])
		_fill_clipped(c, thin, poly, Color(1, 1, 1, 0.3 * (1.0 - shine)))


func _current_box(c: Control) -> StyleBox:
	if c is BaseButton:
		var b: BaseButton = c
		if b.disabled and c.has_theme_stylebox("disabled"):
			return c.get_theme_stylebox("disabled")
		if b.button_pressed or b.get_draw_mode() == BaseButton.DRAW_PRESSED:
			return c.get_theme_stylebox("pressed")
		if c.has_focus():
			return c.get_theme_stylebox("focus")
		if b.is_hovered():
			return c.get_theme_stylebox("hover")
		return c.get_theme_stylebox("normal")
	if c is Label:
		return c.get_theme_stylebox("normal")
	return c.get_theme_stylebox("panel")


static func _fill_clipped(c: CanvasItem, piece: PackedVector2Array, clip: PackedVector2Array, color: Color) -> void:
	for part in Geometry2D.intersect_polygons(piece, clip):
		if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
			c.draw_colored_polygon(part, color)


## A four-pointed sparkle star.
static func _star(c: CanvasItem, at: Vector2, r: float, color: Color) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0 - PI / 2.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.22))
	c.draw_colored_polygon(pts, color)


# ------------------------------------------------------------ Touch

func _hook_button(b: BaseButton) -> void:
	var on_hover := func(): _hover(b)
	b.focus_entered.connect(on_hover)
	b.mouse_entered.connect(on_hover)
	b.focus_exited.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.button_down.connect(func(): _press_in(b))
	# Settings steppers change with left/right as well as clicks, so they
	# clink when their value changes rather than when pressed.
	if b.has_signal("value_changed"):
		b.connect("value_changed", func(_i): _strike(b, GOLD, 0.6, true, "clink"))
	else:
		b.pressed.connect(func():
			var back := false
			for word in BACK_WORDS:
				if b is Button and (b as Button).text.begins_with(word):
					back = true
			_strike(b, GOLD, 0.7 if back else 1.0, true, "back" if back else "clink"))


func _hover(c: Control) -> void:
	var now := _now()
	if now - float(c.get_meta("rock_hover_t", -1.0)) < 0.12:
		return
	c.set_meta("rock_hover_t", now)
	c.queue_redraw()
	if not c.is_visible_in_tree():
		return
	_sweep(c, 0.3)
	if now > _quiet_until and now - _last_strike > 0.3:
		UISfx.play("hover", randf_range(0.97, 1.1))


## The moment the button goes down: it sinks in a little.
func _press_in(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	var tw := _fresh_tween(b)
	tw.tween_property(b, "scale", Vector2(1.03, 0.9), 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _strike(c: Control, color: Color, power: float, squash: bool, sound: String) -> void:
	var now := _now()
	_last_strike = now
	UISfx.play(sound, randf_range(0.97, 1.04) / sqrt(maxf(power, 0.3)) if sound != "big" else 1.0)
	# The shine rings in just after the hit.
	if sound != "back":
		get_tree().create_timer(0.05, true, false, true).timeout.connect(
				func(): UISfx.play("shine", randf_range(0.95, 1.1)))
	if not c.is_visible_in_tree():
		# Usually the button opened a new page and its own one hid: the
		# chips still fly from where it was.
		_burst(c, color, power)
		_jolt(c, power)
		return
	var base := c.scale
	if squash:
		# Squash on impact, spring past normal, settle.
		c.pivot_offset = c.size / 2.0
		var tw := _fresh_tween(c)
		tw.tween_property(c, "scale", Vector2(1.1, 0.86), 0.05)
		tw.tween_property(c, "scale", Vector2(0.97, 1.05), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# The caller eases the scale back itself: just give it a punch.
		c.pivot_offset = c.size / 2.0
		c.scale = base * (1.0 + 0.1 * clampf(power, 0.5, 1.6))
	_sweep(c, 0.32)
	_burst(c, color, power)
	# Next frame, so a UI SHAKE change previews at its new strength.
	var id := c.get_instance_id()
	(func():
		var still := instance_from_id(id) as Control
		if still:
			_jolt(still, power)).call_deferred()


func _deny(c: Control) -> void:
	_last_strike = _now()
	UISfx.play("deny")
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	for a in [4.0, -3.5, 2.5, -1.5, 0.0]:
		tw.tween_property(c, "rotation", deg_to_rad(a), 0.045)
	_burst(c, ROCK, 0.45)
	_jolt(c, 0.5)


## A new tween for a control's squash, stopping the last one so two don't
## fight over its size.
func _fresh_tween(c: Control) -> Tween:
	if c.has_meta("rock_tween"):
		var old: Tween = c.get_meta("rock_tween")
		if old and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	c.set_meta("rock_tween", tw)
	return tw


## Run the shine streak across a control.
func _sweep(c: Control, time: float) -> void:
	if not c.has_meta("rock_facets"):
		return
	var tw := c.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(c):
			c.set_meta("rock_shine", v)
			c.queue_redraw(), 0.0, 1.0001, time)


## Rock chips and sparkles from where it was hit.
func _burst(c: Control, color: Color, power: float) -> void:
	if c.get_viewport() != get_tree().root:
		return
	# Hit where the mouse clicked, or the middle for keys and pads.
	var at := c.size / 2.0
	var mouse := c.get_local_mouse_position()
	if _mouse_last and Rect2(Vector2.ZERO, c.size).has_point(mouse):
		at = mouse
	var xf := c.get_global_transform_with_canvas()
	var screen_at := xf * at
	_chips.burst(screen_at, color, power, xf.get_scale().x)


## A short sharp jolt of the screen: a kick downward (the swing landing)
## that rattles out quickly.
func _jolt(c: Control, power: float) -> void:
	if shake_amount <= 0.0:
		return
	var layer := c.get_canvas_layer_node() if is_instance_valid(c) and c.is_inside_tree() else null
	if layer != _shake_layer:
		_end_shake()
		_shake_layer = layer
		if layer:
			_shake_base = layer.offset
	_shake_camera = get_viewport().get_camera_3d()
	_shake = clampf(maxf(_shake, power), 0.0, 1.6)
	_shake_t = 0.0
	_shake_dir = Vector2(randf_range(-0.6, 0.6), 1.0).normalized()


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake_t += delta
	var life := 0.2
	if _shake_t >= life:
		_end_shake()
		return
	var px := 6.0 * shake_amount * _shake
	var fade := exp(-_shake_t * 22.0)
	var wobble := cos(_shake_t * 95.0)
	var off := _shake_dir * px * fade * wobble \
			+ Vector2(randf_range(-1, 1), randf_range(-1, 1)) * px * 0.25 * fade
	if _shake_layer and is_instance_valid(_shake_layer):
		_shake_layer.offset = _shake_base + off.round()
	if _shake_camera and is_instance_valid(_shake_camera):
		_shake_camera.h_offset = off.x * 0.006
		_shake_camera.v_offset = -off.y * 0.006


func _end_shake() -> void:
	if _shake_layer and is_instance_valid(_shake_layer):
		_shake_layer.offset = _shake_base
	if _shake_camera and is_instance_valid(_shake_camera):
		_shake_camera.h_offset = 0.0
		_shake_camera.v_offset = 0.0
	_shake = 0.0
	_shake_layer = null
	_shake_camera = null


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------ Chips

## Little flying bits drawn on top of everything: grey rock shards that
## tumble and fall, gold and white sparkles that drift and wink out, and
## a jagged flash ring at the point of impact.
class ChipBurst:
	extends Node2D

	const MAX := 160
	var _bits: Array = []
	var _flashes: Array = []

	func _ready() -> void:
		set_process(false)

	func burst(at: Vector2, color: Color, power: float, scale_by: float) -> void:
		var s := clampf(scale_by, 0.5, 2.0)
		var count := int(14 * clampf(power, 0.4, 2.0))
		for i in count:
			var a := randf_range(-PI * 0.95, -PI * 0.05) if randf() < 0.8 else randf_range(0, TAU)
			var speed := randf_range(160.0, 420.0) * s * sqrt(power)
			var shade := randf()
			var col := ROCK.lightened(0.25).lerp(color, 0.3) if shade < 0.6 else ROCK.darkened(0.2)
			_bits.append({"p": at, "v": Vector2(cos(a), sin(a)) * speed, "r": randf() * TAU,
					"spin": randf_range(-18, 18), "size": randf_range(4.0, 9.0) * s,
					"life": randf_range(0.35, 0.6), "age": 0.0, "kind": 0, "col": col,
					"k": randf_range(0.5, 1.0)})
		for i in int(9 * clampf(power, 0.4, 2.0)):
			var a := randf() * TAU
			_bits.append({"p": at + Vector2(cos(a), sin(a)) * randf_range(4, 16) * s,
					"v": Vector2(cos(a), sin(a)) * randf_range(40.0, 200.0) * s, "r": 0.0, "spin": 0.0,
					"size": randf_range(5.0, 10.0) * s, "life": randf_range(0.3, 0.55), "age": 0.0,
					"kind": 1, "col": Color.WHITE if randf() < 0.5 else color.lightened(0.4), "k": 1.0})
		_flashes.append({"p": at, "age": 0.0, "size": 26.0 * s * clampf(power, 0.6, 1.6), "col": color.lightened(0.5)})
		while _bits.size() > MAX:
			_bits.pop_front()
		set_process(true)

	func _process(delta: float) -> void:
		for b in _bits:
			b.age += delta
			b.p += b.v * delta
			if b.kind == 0:
				b.v.y += 1500.0 * delta
				b.v.x *= 0.985
				b.r += b.spin * delta
			else:
				b.v *= 0.9
		_bits = _bits.filter(func(b): return b.age < b.life)
		for f in _flashes:
			f.age += delta
		_flashes = _flashes.filter(func(f): return f.age < 0.14)
		queue_redraw()
		if _bits.is_empty() and _flashes.is_empty():
			set_process(false)

	func _draw() -> void:
		for f in _flashes:
			var k: float = f.age / 0.14
			var r: float = f.size * (0.4 + k)
			var pts := PackedVector2Array()
			for i in 11:
				var a := i * TAU / 10.0
				pts.append(f.p + Vector2(cos(a), sin(a)) * r * (1.0 if i % 2 == 0 else 0.55))
			draw_polyline(pts, Color(f.col, 0.9 * (1.0 - k)), 3.0 * (1.0 - k) + 1.0, true)
		for b in _bits:
			var fade := 1.0 - pow(b.age / b.life, 2.0)
			if b.kind == 0:
				# A jagged shard: a squashed, uneven triangle.
				var sz: float = b.size
				var rot := Transform2D(b.r, b.p)
				draw_colored_polygon(PackedVector2Array([rot * Vector2(-sz, -sz * 0.4 * b.k),
						rot * Vector2(sz * 0.9, -sz * 0.7), rot * Vector2(sz * 0.2, sz * 0.8)]),
						Color(b.col, fade))
				var tri := PackedVector2Array([rot * Vector2(-sz, -sz * 0.4 * b.k),
						rot * Vector2(sz * 0.9, -sz * 0.7), rot * Vector2(sz * 0.2, sz * 0.8),
						rot * Vector2(-sz, -sz * 0.4 * b.k)])
				draw_polyline(tri, Color(0.08, 0.07, 0.1, 0.8 * fade), 1.5, true)
				draw_line(tri[0], tri[1], Color(1, 1, 1, 0.7 * fade), 1.5, true)
			else:
				var twinkle: float = b.size * (0.5 + 0.5 * absf(sin(b.age * 30.0))) * fade
				UIFeel._star(self, b.p, twinkle, Color(b.col, fade))
