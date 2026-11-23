class_name Closet
extends CanvasLayer
## The closet: a full-screen wardrobe for one player at a time, opened from
## the CUSTOMIZE plate on the practice island. Your marble spins on a
## pedestal on the left; the right side has five tabs (HATS, EYES, COLOR,
## STYLE, TRAIL) full of item cards with little pictures. Looks you haven't
## won yet are shown dark with a lock: they come from loot crates.
##
## Like everything else, the closet never reads the keyboard. main.gd calls
## request_move / request_confirm with each player's input.

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const MARBLE_SCENE := preload("res://scenes/marble.tscn")
const COLUMNS := 4
const CARD_SIZE := Vector2(150, 178)
const GOLD := Color(1.0, 0.82, 0.3)

## Who is in the closet (-1 = closed).
var player := -1
var profiles: Profiles
var player_color := Color.WHITE
var tab := 0
var index := 0
## True while the highlight is on the tab row instead of the cards.
var on_tabs := false

var _ui: Control
var _coins: Label
var _coin_shown := 0
var _who: Label
var _item_name: Label
var _item_rarity: Label
var _item_status: Label
var _tab_row: HBoxContainer
var _tabs: Array = []        # PanelContainer per tab
var _underline: ColorRect
var _count: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _cards: Array = []       # [{panel, icon, item, owned}] for the shown tab
var _hint: Label
var _vp: SubViewport
var _stand: Node3D
var _marble: Marble
var _time := 0.0
var _status_flash := 0.0


func _ready() -> void:
	layer = 10
	visible = false


func is_open() -> bool:
	return player >= 0


## Open the closet for a player. `color` is their marble colour.
func open(p: int, p_profiles: Profiles) -> void:
	player = p
	profiles = p_profiles
	player_color = Cosmetics.find("color", profiles.equipped(p, "color")).color
	_build()
	visible = true
	_show_tab(0, false)
	_ui.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	_ui.modulate.a = 0.0
	_ui.scale = Vector2(1.04, 1.04)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ui, "modulate:a", 1.0, 0.25)
	tw.tween_property(_ui, "scale", Vector2.ONE, 0.3)


func close() -> void:
	player = -1
	visible = false
	if _ui:
		_ui.queue_free()
		_ui = null
	_cards.clear()
	_tabs.clear()


func _process(delta: float) -> void:
	if not is_open():
		return
	_time += delta
	if _stand:
		# The ball turns on its pedestal; on the trail tab it does little
		# laps so you can see the trail.
		var r := 0.16 if Cosmetics.SLOTS[tab] == "trail" else 0.0
		_marble.position = _marble.position.lerp(Vector3(cos(_time * 2.2) * r, 0.45 + sin(_time * 2.0) * 0.02,
				sin(_time * 2.2) * r * 0.5), clampf(delta * 6.0, 0.0, 1.0))
	var want := profiles.coins(player)
	if _coin_shown != want:
		_coin_shown = want
		_coins.text = str(want)
		_pop(_coins.get_parent(), 1.15)
	if _status_flash > 0.0:
		_status_flash -= delta


# ------------------------------------------------------------ Requests

## Move the highlight. dir.x = left/right, dir.y = up (-1) / down (+1).
func request_move(dir: Vector2i) -> void:
	if not is_open() or dir == Vector2i.ZERO:
		return
	if on_tabs:
		if dir.x != 0:
			_show_tab(wrapi(tab + dir.x, 0, Cosmetics.SLOTS.size()), true)
		elif dir.y > 0:
			on_tabs = false
			_highlight()
		return
	var n := _cards.size()
	var next := index
	# Pushing past the left or right edge of the grid flips to the next tab.
	var col := index % COLUMNS
	if (dir.x < 0 and col == 0) or (dir.x > 0 and (col == COLUMNS - 1 or index == n - 1)):
		_show_tab(wrapi(tab + dir.x, 0, Cosmetics.SLOTS.size()), true)
		return
	if dir.x != 0:
		next = clampi(index + dir.x, 0, n - 1)
	elif dir.y < 0:
		if index < COLUMNS:
			on_tabs = true
			_highlight()
			return
		next = index - COLUMNS
	elif dir.y > 0:
		next = mini(index + COLUMNS, n - 1)
	_select(next)


## Wear the highlighted look, if you own it.
func request_confirm() -> void:
	if not is_open():
		return
	if on_tabs:
		on_tabs = false
		_highlight()
		return
	var card: Dictionary = _cards[index]
	var slot: String = Cosmetics.SLOTS[tab]
	if card.owned:
		profiles.equip(player, slot, card.item.id)
		profiles.save_to_disk()
		if profiles.equipped(player, "hat") != "none" and profiles.equipped(player, "eyes") != "none":
			Achievements.unlock("DRESSED_UP")
		if slot == "color":
			player_color = card.item.color
		_refresh_cards()
		_pop(card.panel, 1.18)
		UIFeel.strike(card.panel, player_color, 1.1, false)
		_bounce_marble()
		_set_status("EQUIPPED!", Color(0.5, 1.0, 0.6))
	else:
		UIFeel.deny(card.panel)
		_set_status("LOCKED: WIN IT FROM A LOOT CRATE", Color(1.0, 0.55, 0.5))


# ------------------------------------------------------------ Tabs and cards

func _show_tab(t: int, animate: bool) -> void:
	tab = t
	var slot: String = Cosmetics.SLOTS[t]
	for c in _grid.get_children():
		_grid.remove_child(c)  # out of the layout now, not at the end of the frame
		c.queue_free()
	_cards.clear()
	var owned := 0
	var items := Cosmetics.items(slot)
	for item in items:
		var has := profiles.owns(player, slot, item.id)
		if has:
			owned += 1
		var card := _make_card(slot, item, has)
		_grid.add_child(card.panel)
		_cards.append(card)
	_count.text = "%d / %d OWNED" % [owned, items.size()]
	for i in _tabs.size():
		var label: Label = _tabs[i].get_child(0)
		label.add_theme_color_override("font_color", Color.WHITE if i == t else Color(1, 1, 1, 0.45))
	_select(Cosmetics.index_of(slot, profiles.equipped(player, slot)), false, false)
	if animate:
		UIFeel.hover(_tabs[t])
	_refresh_cards()
	# A new tab always starts scrolled to the top.
	_scroll.scroll_vertical = 0
	_scroll.set_deferred("scroll_vertical", 0)
	# Slide the underline under the new tab once the row has laid out.
	_move_underline.call_deferred(animate)
	if animate:
		for i in _cards.size():
			var p: Control = _cards[i].panel
			p.modulate.a = 0.0
			var tw := p.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.02 * i)
			tw.tween_property(p, "modulate:a", 1.0, 0.18)


func _move_underline(animate: bool) -> void:
	if _tabs.is_empty():
		return
	var target: Control = _tabs[tab]
	var to_pos := Vector2(target.position.x + 10, _underline.position.y)
	var to_size := Vector2(target.size.x - 20, _underline.size.y)
	if animate:
		var tw := _underline.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_underline, "position", to_pos, 0.22)
		tw.tween_property(_underline, "size", to_size, 0.22)
	else:
		_underline.position = to_pos
		_underline.size = to_size


func _select(i: int, animate := true, scroll := true) -> void:
	var old := index
	index = clampi(i, 0, _cards.size() - 1)
	_highlight()
	if animate and old != index:
		_bounce_marble()
		UIFeel.hover(_cards[index].panel)
	_try_on()
	if scroll:
		var card: Dictionary = _cards[index]
		_ensure_visible.call_deferred(card.panel)


func _ensure_visible(c: Control) -> void:
	if is_instance_valid(c) and _scroll:
		_scroll.ensure_control_visible(c)


## Selected card grows; the rest settle back.
func _highlight() -> void:
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var p: Control = card.panel
		var on := i == index and not on_tabs
		p.pivot_offset = CARD_SIZE / 2.0
		var tw := p.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector2.ONE * (1.08 if on else 1.0), 0.16)
		var style: StyleBoxFlat = p.get_theme_stylebox("panel")
		style.border_color = Color.WHITE if on else Color(1, 1, 1, 0.0)
		style.bg_color = Color(1, 1, 1, 0.2) if on else Color(1, 1, 1, 0.08)
	for i in _tabs.size():
		var s: StyleBoxFlat = _tabs[i].get_theme_stylebox("panel")
		s.bg_color = Color(1, 1, 1, 0.22) if (on_tabs and i == tab) else Color(0, 0, 0, 0)
	_underline.color = Color.WHITE if on_tabs else player_color


## Show the highlighted look on the big marble, even if it's locked.
func _try_on() -> void:
	var slot: String = Cosmetics.SLOTS[tab]
	var card: Dictionary = _cards[index]
	var look := profiles.look(player)
	look[slot] = card.item
	_marble.look = look
	_item_name.text = card.item.name.to_upper()
	_item_rarity.text = Cosmetics.rarity_name(card.item.rarity).to_upper()
	_item_rarity.add_theme_color_override("font_color", Cosmetics.rarity_color(card.item.rarity))
	if _status_flash <= 0.0:
		if profiles.equipped(player, slot) == card.item.id:
			_item_status.text = "WEARING"
			_item_status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		elif card.owned:
			_item_status.text = "PRESS %s TO WEAR" % Hud._key_names(player).confirm
			_item_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		else:
			_item_status.text = "LOCKED: " + card.item.get("how", "find it in a loot crate").to_upper()
			_item_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))


## Update the WORN badges (after equipping something).
func _refresh_cards() -> void:
	var slot: String = Cosmetics.SLOTS[tab]
	for card in _cards:
		(card.badge as Control).visible = profiles.equipped(player, slot) == card.item.id


func _make_card(slot: String, item: Dictionary, owned: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.08)
	style.set_corner_radius_all(16)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0)
	style.content_margin_top = 8
	style.content_margin_bottom = 0
	style.content_margin_left = 6
	style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var icon := ItemIcons.make(slot, item, player_color, 100)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not owned:
		icon.modulate = Color(0.22, 0.24, 0.32)
	box.add_child(icon)
	var name := Label.new()
	name.text = item.name
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 17)
	name.add_theme_color_override("font_color", Color.WHITE if owned else Color(1, 1, 1, 0.5))
	name.clip_text = true
	box.add_child(name)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(0, 8)
	strip.color = Cosmetics.rarity_color(item.rarity)
	box.add_child(strip)
	# Badges on top: a lock for locked looks, WORN for the one you wear.
	var lock := LockIcon.new()
	lock.custom_minimum_size = Vector2(26, 30)
	lock.size_flags_horizontal = Control.SIZE_SHRINK_END
	lock.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lock.visible = not owned
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lock)
	var badge := Label.new()
	badge.text = "WORN"
	badge.add_theme_font_override("font", TITLE_FONT)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color(0.1, 0.25, 0.12))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.5, 1.0, 0.6)
	bs.set_corner_radius_all(8)
	bs.content_margin_left = 7
	bs.content_margin_right = 7
	badge.add_theme_stylebox_override("normal", bs)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_child(badge)
	return {"panel": panel, "icon": icon, "item": item, "owned": owned, "badge": badge}


# ------------------------------------------------------------ Juice

func _pop(c: Control, amount: float) -> void:
	if c == null:
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.08)
	tw.tween_property(c, "scale", Vector2.ONE * (1.08 if c is PanelContainer and _is_selected(c) else 1.0), 0.2)


func _is_selected(c: Control) -> bool:
	return not _cards.is_empty() and _cards[index].panel == c and not on_tabs


func _shake(c: Control) -> void:
	var tw := c.create_tween()
	for k in 4:
		tw.tween_property(c, "rotation", 0.06 * (1 if k % 2 == 0 else -1), 0.04)
	tw.tween_property(c, "rotation", 0.0, 0.04)


func _bounce_marble() -> void:
	if _stand == null:
		return
	_stand.scale = Vector3.ONE * 0.86
	var tw := _stand.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stand, "scale", Vector3.ONE, 0.5)


func _set_status(text: String, color: Color) -> void:
	_status_flash = 1.4
	_item_status.text = text
	_item_status.add_theme_color_override("font_color", color)
	_pop(_item_status, 1.12)


# ------------------------------------------------------------ Building

func _build() -> void:
	if _ui:
		_ui.queue_free()
	_tabs.clear()
	_cards.clear()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)

	# Background: a deep evening-blue wash. The left 45% is the marble's
	# stage (its own little 3D world, drawn edge to edge).
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = _gradient([Color(0.16, 0.19, 0.36), Color(0.08, 0.09, 0.19)], false)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_ui.add_child(bg)
	var stage := SubViewportContainer.new()
	stage.stretch = true
	stage.anchor_right = 0.45
	stage.anchor_bottom = 1.0
	_ui.add_child(stage)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	stage.add_child(_vp)
	_build_stage(_vp)
	var edge := ColorRect.new()
	edge.anchor_left = 0.45
	edge.anchor_right = 0.45
	edge.anchor_bottom = 1.0
	edge.offset_right = 6
	edge.color = player_color
	_ui.add_child(edge)
	# Darken the bottom of the stage so the item's name reads clearly.
	var shade := TextureRect.new()
	shade.texture = _gradient([Color(0.05, 0.06, 0.14, 0.0), Color(0.05, 0.06, 0.14, 0.85)], false)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_right = 0.45
	shade.anchor_top = 0.68
	shade.anchor_bottom = 1.0
	_ui.add_child(shade)

	# Header: title and whose closet it is on the left, coins on the right.
	var title := _label("CLOSET", 64, Color.WHITE)
	title.position = Vector2(48, 22)
	_ui.add_child(title)
	_who = _label("PLAYER %d" % (player + 1), 26, player_color)
	_who.position = Vector2(54, 100)
	_ui.add_child(_who)
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0, 0, 0, 0.35)
	cs.set_corner_radius_all(26)
	cs.content_margin_left = 10
	cs.content_margin_right = 22
	cs.border_color = GOLD
	cs.set_border_width_all(3)
	chip.add_theme_stylebox_override("panel", cs)
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -260
	chip.offset_right = -40
	chip.offset_top = 30
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	chip.add_child(row)
	var coin := ItemIcons.CoinIcon.new()
	coin.custom_minimum_size = Vector2(56, 56)
	row.add_child(coin)
	_coins = _label(str(profiles.coins(player)), 40, GOLD)
	_coin_shown = profiles.coins(player)
	row.add_child(_coins)
	_ui.add_child(chip)

	# Left: the item's name under the marble.
	var left := VBoxContainer.new()
	left.anchor_right = 0.45
	left.anchor_top = 0.78
	left.anchor_bottom = 0.97
	left.alignment = BoxContainer.ALIGNMENT_END
	_ui.add_child(left)
	_item_name = _label("", 44, Color.WHITE)
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_item_name)
	_item_rarity = _label("", 24, Color.WHITE)
	_item_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_item_rarity)
	_item_status = _label("", 20, Color.WHITE)
	_item_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_status.custom_minimum_size = Vector2(0, 34)
	left.add_child(_item_status)

	# Right: tabs, then the grid of cards.
	var right := VBoxContainer.new()
	right.anchor_left = 0.48
	right.anchor_right = 0.975
	right.anchor_top = 0.15
	right.anchor_bottom = 0.96
	right.add_theme_constant_override("separation", 10)
	_ui.add_child(right)
	var tab_area := Control.new()
	tab_area.custom_minimum_size = Vector2(0, 58)
	right.add_child(tab_area)
	_tab_row = HBoxContainer.new()
	_tab_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_row.add_theme_constant_override("separation", 6)
	tab_area.add_child(_tab_row)
	for slot in Cosmetics.SLOTS:
		var t := PanelContainer.new()
		var ts := StyleBoxFlat.new()
		ts.bg_color = Color(0, 0, 0, 0)
		ts.set_corner_radius_all(12)
		ts.content_margin_left = 14
		ts.content_margin_right = 14
		t.add_theme_stylebox_override("panel", ts)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := _label(Cosmetics.SLOT_NAMES[slot], 26, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_child(l)
		_tab_row.add_child(t)
		_tabs.append(t)
	_underline = ColorRect.new()
	_underline.color = player_color
	_underline.position = Vector2(0, 52)
	_underline.size = Vector2(100, 6)
	tab_area.add_child(_underline)
	_count = _label("", 16, Color(1, 1, 1, 0.55))
	right.add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	right.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pad.add_child(_grid)
	var k := Hud._key_names(player)
	_hint = _label("%s  Browse (past the edge = next tab)      %s  Wear      %s  Close" % [k.move, k.confirm, k.rotate], 20, Color(1, 1, 1, 0.7))
	right.add_child(_hint)


## The little stage for the big marble: a pedestal, light and camera.
func _build_stage(vp: SubViewport) -> void:
	var world := Node3D.new()
	vp.add_child(world)
	ItemIcons._studio(world)
	# A soft sky-blue backdrop that fades darker toward the floor.
	var env: Environment = (world.get_child(0) as WorldEnvironment).environment
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.5, 0.6, 0.85)
	sky_mat.ground_horizon_color = Color(0.5, 0.6, 0.85)
	sky_mat.ground_bottom_color = Color(0.2, 0.24, 0.45)
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var glow := OmniLight3D.new()
	glow.light_color = player_color
	glow.light_energy = 1.5
	glow.omni_range = 2.5
	glow.position = Vector3(0, 0.25, 0.9)
	world.add_child(glow)
	var cam := Camera3D.new()
	cam.fov = 32.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.95, 3.1), Vector3(0, 0.47, 0))
	_stand = Node3D.new()
	world.add_child(_stand)
	for s in [[0.48, 0.08, 0.0, Color(0.95, 0.93, 0.88)], [0.38, 0.06, 0.08, player_color.lerp(Color.WHITE, 0.4)]]:
		var c := CylinderMesh.new()
		c.top_radius = s[0]
		c.bottom_radius = s[0] + 0.04
		c.height = s[1]
		c.radial_segments = 10
		var mi := MeshInstance3D.new()
		mi.mesh = c
		var m := StandardMaterial3D.new()
		m.albedo_color = s[3]
		m.roughness = 0.9
		mi.material_override = m
		mi.position.y = s[2] + s[1] / 2.0
		_stand.add_child(mi)
	_marble = MARBLE_SCENE.instantiate()
	_marble.freeze = true
	_marble.position = Vector3(0, 0.45, 0)
	_stand.add_child(_marble)
	_marble.preview = true
	_marble.look = profiles.look(player)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12, 0.8))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	return l


static func _gradient(colors: Array, radial: bool) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[1])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	if radial:
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.45)
		t.fill_to = Vector2(0.5, 0.0)
	else:
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
	return t


## A little padlock for locked cards.
class LockIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_arc(Vector2(w / 2, h * 0.42), w * 0.28, PI, TAU, 12, Color(0.85, 0.87, 0.95), 3.5)
		var body := Rect2(Vector2(w * 0.12, h * 0.42), Vector2(w * 0.76, h * 0.52))
		draw_rect(body, Color(0.85, 0.87, 0.95))
		draw_circle(body.get_center(), w * 0.09, Color(0.2, 0.22, 0.3))
