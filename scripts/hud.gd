class_name Hud
extends CanvasLayer
## Everything drawn on top of the game: scores, phase banners, the draft
## cards and pointers, the Customize screen, the scoreboard and key hints.
## Only reads game state, never changes it.
##
## Fonts: Fredoka for normal text (set for the whole project in
## ui/theme.tres) and Lilita One for titles and big numbers. Both are free
## fonts under the SIL Open Font License (see fonts/).

const TITLE_FONT := preload("res://fonts/LilitaOne-Regular.ttf")
const PANEL_BG := Color(0.07, 0.09, 0.16, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)

## Draft card size and spacing, in pixels.
const CARD_W := 176.0
const CARD_H := 224.0
const CARD_GAP := 18.0

var thumbnails: Thumbnails

var _scores: HBoxContainer
var _badge: Label            # "FRAME 3/10" top centre
var _banner: Label           # "DRAFT 12" under the badge
var _center: Label           # countdown number
var _board: PanelContainer
var _board_grid: GridContainer
var _board_title: Label
var _board_lines: Label
var _hints: HBoxContainer
var _hints_key := ""
var _chips: HBoxContainer    # build-phase status, bottom centre
var _customize: HBoxContainer
var _customize_title: Label
var _derby: HBoxContainer        # Marble Derby betting panels (practice island)
var _hub_coins: HBoxContainer    # everyone's coins, top right on the island

var _draft_root: Control
var _draft_dim: ColorRect
var _card_layer: Control
var _cards: Array = []       # one Dictionary per crate slot
var _crate_shown: Array = []
var _pointers: Array = []    # one DraftPointer per player
var _last_countdown := -1


## A player's draft pointer: a chunky arrow in their colour with a name tag.
class DraftPointer extends Control:
	var color := Color.WHITE
	var tag := "P1"
	const SHAPE := [Vector2(0, 0), Vector2(0, 38), Vector2(10, 29), Vector2(17, 44),
			Vector2(24, 41), Vector2(17, 26), Vector2(30, 26)]

	func _draw() -> void:
		var pts := PackedVector2Array(SHAPE)
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(3, 4))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
		draw_colored_polygon(pts, color)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color.WHITE, 3.0, true)
		var font: Font = Hud.TITLE_FONT
		var at := Vector2(30, 56)
		draw_string_outline(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.8))
		draw_string(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color.lightened(0.25))


func _ready() -> void:
	_build_draft_area()  # first, so its dimmer sits behind everything else

	_scores = HBoxContainer.new()
	_scores.add_theme_constant_override("separation", 8)
	_scores.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_scores.offset_left = 16
	_scores.offset_top = 14
	add_child(_scores)

	_badge = _title_label(24, Control.PRESET_CENTER_TOP)
	_badge.offset_top = 12
	_badge.add_theme_stylebox_override("normal", _pill(PANEL_BG, 16, 6))

	_banner = _title_label(46, Control.PRESET_CENTER_TOP)
	_banner.offset_top = 62

	_center = _title_label(150, Control.PRESET_CENTER)
	_center.pivot_offset = Vector2(60, 90)

	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 10)
	_chips.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_chips.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chips.offset_bottom = -56
	add_child(_chips)

	_build_board()

	_customize = HBoxContainer.new()
	_customize.add_theme_constant_override("separation", 18)
	_customize.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_customize.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_customize.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_customize.offset_bottom = -58
	add_child(_customize)
	_customize_title = _title_label(52, Control.PRESET_CENTER_TOP)
	_customize_title.offset_top = 62
	_customize_title.text = "CUSTOMIZE"

	_derby = HBoxContainer.new()
	_derby.add_theme_constant_override("separation", 18)
	_derby.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_derby.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_derby.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_derby.offset_bottom = -58
	add_child(_derby)

	_hub_coins = HBoxContainer.new()
	_hub_coins.add_theme_constant_override("separation", 8)
	_hub_coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hub_coins.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hub_coins.offset_right = -16
	_hub_coins.offset_top = 14
	add_child(_hub_coins)

	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 6)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.offset_left = 16
	_hints.offset_bottom = -12
	add_child(_hints)


func refresh(game) -> void:
	# The main menu draws its own screen; the game HUD stays out of the way.
	visible = game.state != game.State.MENU
	if not visible:
		return
	_scores.visible = game.state != game.State.HUB
	if _scores.visible:
		_update_scores(game)
	_update_top(game)
	_update_countdown(game)
	_update_draft(game)
	_update_chips(game)
	_update_customize(game)
	_update_hub(game)

	var show_board: bool = game.state in [game.State.RESULTS, game.State.MATCH_OVER] \
			or (Input.is_action_pressed("scoreboard") and not game.state in [game.State.WAITING, game.State.HUB])
	_board.visible = show_board
	if show_board:
		_fill_board(game)
	_update_hints(game)


# ------------------------------------------------------------ Top of screen

func _update_scores(game) -> void:
	while _scores.get_child_count() < game.player_count:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _pill(PANEL_BG, 12, 4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		chip.add_child(row)
		var tag := Label.new()
		tag.add_theme_font_override("font", TITLE_FONT)
		tag.add_theme_font_size_override("font_size", 20)
		row.add_child(tag)
		var score := Label.new()
		score.add_theme_font_override("font", TITLE_FONT)
		score.add_theme_font_size_override("font_size", 26)
		row.add_child(score)
		var status := Label.new()
		status.add_theme_font_size_override("font_size", 14)
		status.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		row.add_child(status)
		_scores.add_child(chip)
	_show_first(_scores, game.player_count)
	for i in game.player_count:
		var chip: PanelContainer = _scores.get_child(i)
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel")
		style.border_color = game.player_colors[i]
		style.border_width_bottom = 4
		var row := chip.get_child(0)
		row.get_child(0).text = "P%d" % (i + 1)
		row.get_child(0).add_theme_color_override("font_color", game.player_colors[i].lightened(0.2))
		row.get_child(1).text = str(game.totals[i])
		var status := ""
		if game.state == game.State.ROLLING or game.state == game.State.RESULTS:
			var m: Marble = game.marbles[i]
			if m.out:
				status = "OUT"
			elif m.arrived:
				status = _ordinal(game.arrival_order.find(i) + 1)
		row.get_child(2).text = status
		row.get_child(2).visible = status != ""


func _update_top(game) -> void:
	var text := "FRAME %d/%d" % [game.frame, game.frames_per_match]
	if game.state in [game.State.COUNTDOWN, game.State.ROLLING, game.State.RESULTS, game.State.MATCH_OVER]:
		text += "      PINS %d" % game.rack.standing_count()
	if game.state == game.State.ROLLING:
		text += "      %ds" % ceili(game.time_left())
	_badge.text = text
	_badge.visible = not game.state in [game.State.WAITING, game.State.HUB]
	if game.state == game.State.HUB and game.hub.derby.status() != "":
		_badge.text = game.hub.derby.status()
		_badge.visible = true

	var banner := ""
	match game.state:
		game.State.DRAFT:
			banner = "DRAFT  %d" % game.phase_time_left()
		game.State.BUILD:
			banner = "BUILD  %d" % game.phase_time_left()
	_banner.text = banner
	_banner.visible = banner != ""
	_banner.add_theme_color_override("font_color", GOLD if game.phase_time_left() <= 5 else Color.WHITE)


func _update_countdown(game) -> void:
	if game.state != game.State.COUNTDOWN:
		_center.visible = false
		_last_countdown = -1
		return
	var n: int = game.countdown_value()
	_center.visible = true
	_center.text = str(n) if n > 0 else "GO!"
	if n != _last_countdown:
		_last_countdown = n
		_center.pivot_offset = _center.size / 2.0
		_center.scale = Vector2.ONE * 1.6
		var tw := _center.create_tween()
		tw.tween_property(_center, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------ Draft

func _build_draft_area() -> void:
	_draft_root = Control.new()
	_draft_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draft_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draft_root)
	_draft_dim = ColorRect.new()
	_draft_dim.color = Color(0.02, 0.03, 0.08, 0.45)
	_draft_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draft_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_root.add_child(_draft_dim)
	_card_layer = Control.new()
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_root.add_child(_card_layer)


## Top-left corner of the card row on screen.
func _row_origin(count: int) -> Vector2:
	var screen := _draft_root.get_viewport_rect().size
	var width := count * (CARD_W + CARD_GAP)
	return Vector2((screen.x - width) / 2.0, screen.y / 2.0 - CARD_H / 2.0 - 10.0)


## Card-space point (see DraftBuild.draft_pointer) to screen pixels.
func _card_to_screen(p: Vector2, count: int) -> Vector2:
	return _row_origin(count) + Vector2(p.x * (CARD_W + CARD_GAP), p.y * CARD_H)


func _update_draft(game) -> void:
	var db: DraftBuild = game.draft_build
	var show: bool = game.state == game.State.DRAFT
	_draft_root.visible = show
	if not show:
		return
	if _crate_shown != db.crate:
		_build_cards(db.crate)
	var n: int = db.crate.size()
	var origin := _row_origin(n)
	for slot in _cards.size():
		var card: Dictionary = _cards[slot]
		var panel: PanelContainer = card.panel
		panel.position = origin + Vector2(slot * (CARD_W + CARD_GAP) + CARD_GAP / 2.0, 0)
		var owner: int = db.taken_by[slot]
		var hover := -1
		for p in game.player_count:
			if db.picks[p] == "" and db.hovered_slot(p) == slot:
				hover = p
				break
		var style: StyleBoxFlat = card.style
		var target_scale := 1.0
		if owner != -1:
			style.border_color = game.player_colors[owner]
			card.pic.modulate = Color(1, 1, 1, 0.35)
			card.stamp.text = "P%d" % (owner + 1)
			card.stamp.add_theme_color_override("font_color", game.player_colors[owner].lightened(0.2))
			card.stamp.visible = true
		elif hover != -1:
			style.border_color = game.player_colors[hover]
			card.pic.modulate = Color.WHITE
			card.stamp.visible = false
			target_scale = 1.08
		else:
			style.border_color = Color(1, 1, 1, 0.12)
			card.pic.modulate = Color.WHITE
			card.stamp.visible = false
		card.stamp.pivot_offset = card.stamp.size / 2.0
		card.stamp.rotation = -0.2
		panel.pivot_offset = panel.size / 2.0
		panel.scale = panel.scale.lerp(Vector2.ONE * target_scale, 0.3)

	while _pointers.size() < game.player_count:
		var ptr := DraftPointer.new()
		ptr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draft_root.add_child(ptr)
		_pointers.append(ptr)
	for p in _pointers.size():
		var ptr: DraftPointer = _pointers[p]
		ptr.visible = p < game.player_count and db.picks[p] == ""
		if not ptr.visible:
			continue
		ptr.color = game.player_colors[p]
		ptr.tag = "P%d" % (p + 1)
		var target := _card_to_screen(db.draft_pointer[p], n)
		ptr.position = target if ptr.position == Vector2.ZERO else ptr.position.lerp(target, 0.5)
		ptr.queue_redraw()
		ptr.move_to_front()


func _build_cards(crate: Array) -> void:
	for c in _card_layer.get_children():
		c.queue_free()
	_cards.clear()
	_crate_shown = crate.duplicate()
	for id in crate:
		var panel := PanelContainer.new()
		var style := _pill(PANEL_BG, 10, 10)
		style.set_border_width_all(4)
		style.shadow_color = Color(0, 0, 0, 0.35)
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 5)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(CARD_W, CARD_H)
		panel.size = Vector2(CARD_W, CARD_H)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		# Track altering cards (TAs) get a gold badge on top.
		var badge := Label.new()
		badge.text = PieceCatalog.tag(id) if PieceCatalog.is_track(id) else ""
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", TITLE_FONT)
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		var badge_bg := _pill(GOLD, 10, 1)
		badge_bg.set_corner_radius_all(8)
		badge.add_theme_stylebox_override("normal", badge_bg if badge.text != "" else StyleBoxEmpty.new())
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(badge)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(124, 124)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if thumbnails:
			pic.texture = thumbnails.texture_for(id)
		box.add_child(pic)
		var name_label := Label.new()
		name_label.text = PieceCatalog.display_name(id).to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", TITLE_FONT)
		name_label.add_theme_font_size_override("font_size", 20)
		if PieceCatalog.is_track(id):
			name_label.add_theme_color_override("font_color", GOLD)
		box.add_child(name_label)
		var about := Label.new()
		about.text = PieceCatalog.info(id).about
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.add_theme_font_size_override("font_size", 14)
		about.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		box.add_child(about)
		var stamp := Label.new()
		stamp.add_theme_font_override("font", TITLE_FONT)
		stamp.add_theme_font_size_override("font_size", 64)
		stamp.add_theme_color_override("font_outline_color", Color.BLACK)
		stamp.add_theme_constant_override("outline_size", 12)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.visible = false
		panel.add_child(stamp)  # fills the card, on top of the picture
		_card_layer.add_child(panel)
		_cards.append({"panel": panel, "style": style, "pic": pic, "stamp": stamp})


# ------------------------------------------------------------ Build chips

func _update_chips(game) -> void:
	var show: bool = game.state == game.State.BUILD
	_chips.visible = show
	if not show:
		return
	var db: DraftBuild = game.draft_build
	while _chips.get_child_count() < game.player_count:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _pill(PANEL_BG, 14, 6))
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 17)
		chip.add_child(l)
		_chips.add_child(chip)
	_show_first(_chips, game.player_count)
	for p in game.player_count:
		var chip: PanelContainer = _chips.get_child(p)
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel")
		style.border_color = game.player_colors[p]
		style.border_width_bottom = 4
		var piece := PieceCatalog.display_name(db.current_id(p)) if db.picks[p] != "" else ""
		if PieceCatalog.is_track(db.picks[p]):
			piece = "Track Altering: " + piece
		if PieceCatalog.parts(db.picks[p]) > 1 and not db.has_placed[p]:
			piece += "  %d/%d" % [db.part[p] + 1, PieceCatalog.parts(db.picks[p])]
		if PieceCatalog.turns(db.picks[p]):
			piece += "  < LEFT" if PieceCatalog.turns_left(db.cursor_angle[p]) else "  RIGHT >"
		var state := ""
		if db.has_placed[p]:
			state = "DONE"
		elif db.cursor_blocked(p):
			state = "BLOCKED"
		var text := "P%d  %s" % [p + 1, piece]
		if state != "":
			text += "  ·  " + state
		var l: Label = chip.get_child(0)
		l.text = text
		l.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if state == "BLOCKED" else Color.WHITE)


# ------------------------------------------------------------ Customize

func _update_customize(game) -> void:
	# Before a match everyone customizes; on the practice island only the
	# players parked on the Customize plate do.
	var in_hub: bool = game.state == game.State.HUB
	var show: bool = game.state == game.State.WAITING or (in_hub and game.customize_open.has(true))
	_customize.visible = show
	_customize_title.visible = show
	if not show:
		return
	while _customize.get_child_count() < game.player_count:
		_customize.add_child(_make_customize_panel())
	_show_first(_customize, game.player_count)
	if in_hub:
		for p in game.player_count:
			_customize.get_child(p).visible = game.customize_open[p]
	for p in game.player_count:
		var panel: PanelContainer = _customize.get_child(p)
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		style.border_color = game.player_colors[p]
		var box := panel.get_child(0)
		var head: HBoxContainer = box.get_child(0)
		head.get_child(0).text = "P%d" % (p + 1)
		head.get_child(0).add_theme_color_override("font_color", game.player_colors[p].lightened(0.2))
		head.get_child(2).text = "%d COINS" % game.profiles.coins(p)
		for r in Cosmetics.SLOTS.size():
			var slot: String = Cosmetics.SLOTS[r]
			var id: String = game.customize_browse[p].get(slot, game.profiles.equipped(p, slot))
			var item := Cosmetics.find(slot, id)
			var row: PanelContainer = box.get_child(1 + r)
			var selected: bool = game.customize_row[p] == r
			var row_style: StyleBoxFlat = row.get_theme_stylebox("panel")
			row_style.bg_color = Color(1, 1, 1, 0.12) if selected else Color(0, 0, 0, 0)
			var cols: HBoxContainer = row.get_child(0)
			cols.get_child(0).text = slot.to_upper()
			cols.get_child(1).text = ("<  %s  >" if selected else "%s") % item.name
			var owned: bool = game.profiles.owns(p, slot, id)
			cols.get_child(2).text = "" if owned else str(item.price)
			cols.get_child(2).visible = not owned
		var foot: Label = box.get_child(1 + Cosmetics.SLOTS.size())
		var slot_now: String = Cosmetics.SLOTS[game.customize_row[p]]
		var id_now: String = game.customize_browse[p].get(slot_now, "")
		if game.customize_message[p] != "":
			foot.text = game.customize_message[p]
		elif id_now != "" and not game.profiles.owns(p, slot_now, id_now):
			foot.text = "%s  Buy" % _key_names(p).confirm
		else:
			foot.text = ""


func _make_customize_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _pill(PANEL_BG, 14, 12)
	style.border_width_top = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var tag := Label.new()
	tag.add_theme_font_override("font", TITLE_FONT)
	tag.add_theme_font_size_override("font_size", 26)
	head.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_coin_label(22))
	box.add_child(head)
	for r in Cosmetics.SLOTS.size():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _pill(Color(0, 0, 0, 0), 8, 3))
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		row.add_child(cols)
		var key := Label.new()
		key.custom_minimum_size = Vector2(62, 0)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		cols.add_child(key)
		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_theme_font_size_override("font_size", 19)
		cols.add_child(value)
		cols.add_child(_coin_label(16))
		box.add_child(row)
	var foot := Label.new()
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", GOLD)
	foot.custom_minimum_size = Vector2(0, 22)
	box.add_child(foot)
	return panel


## A gold number, for coins and prices.
func _coin_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


# ------------------------------------------------------------ Practice island

func _update_hub(game) -> void:
	var in_hub: bool = game.state == game.State.HUB
	_hub_coins.visible = in_hub
	_derby.visible = in_hub and game.derby_open.has(true)
	if not in_hub:
		return
	# Coins, top right.
	while _hub_coins.get_child_count() < game.player_count:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _pill(PANEL_BG, 12, 4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		chip.add_child(row)
		var tag := Label.new()
		tag.add_theme_font_override("font", TITLE_FONT)
		tag.add_theme_font_size_override("font_size", 20)
		row.add_child(tag)
		row.add_child(_coin_label(24))
		_hub_coins.add_child(chip)
	_show_first(_hub_coins, game.player_count)
	for p in game.player_count:
		var chip: PanelContainer = _hub_coins.get_child(p)
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel")
		style.border_color = game.player_colors[p]
		style.border_width_bottom = 4
		var row := chip.get_child(0)
		row.get_child(0).text = "P%d" % (p + 1)
		row.get_child(0).add_theme_color_override("font_color", game.player_colors[p].lightened(0.2))
		row.get_child(1).text = "%d COINS" % game.profiles.coins(p)
	if not _derby.visible:
		return
	# Sit above the Customize panels if both are open.
	_derby.offset_bottom = -300 if _customize.visible else -58
	var derby: HorseRace = game.hub.derby
	while _derby.get_child_count() < game.player_count:
		_derby.add_child(_make_derby_panel())
	_show_first(_derby, game.player_count)
	for p in game.player_count:
		var panel: PanelContainer = _derby.get_child(p)
		panel.visible = game.derby_open[p]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		style.border_color = game.player_colors[p]
		var box := panel.get_child(0)
		var head: HBoxContainer = box.get_child(0)
		head.get_child(0).text = "P%d  DERBY" % (p + 1)
		head.get_child(0).add_theme_color_override("font_color", game.player_colors[p].lightened(0.2))
		head.get_child(2).text = "%d COINS" % game.profiles.coins(p)
		var placed: bool = derby.bets.has(p)
		var h: int = derby.bets[p].horse if placed else derby.pick[p]
		var amount: int = derby.bets[p].amount if placed else derby.wager[p]
		var horse_row: HBoxContainer = box.get_child(1)
		horse_row.get_child(0).text = "HORSE"
		horse_row.get_child(1).text = ("%d %s" if placed else "<  %d %s  >") % [h + 1, HorseRace.HORSES[h].name]
		horse_row.get_child(1).add_theme_color_override("font_color", HorseRace.HORSES[h].color.lightened(0.3))
		horse_row.get_child(2).text = "pays %.1fx" % derby.odds[h]
		var wager_row: HBoxContainer = box.get_child(2)
		wager_row.get_child(0).text = "WAGER"
		wager_row.get_child(1).text = ("%d" if placed else "-  %d  +") % amount
		wager_row.get_child(2).text = "win %d" % roundi(amount * derby.odds[h])
		var foot: Label = box.get_child(3)
		if derby.message[p] != "":
			foot.text = derby.message[p]
		elif not placed:
			foot.text = "%s  Place bet" % _key_names(p).confirm
		else:
			foot.text = ""


func _make_derby_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _pill(PANEL_BG, 14, 12)
	style.border_width_top = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var tag := Label.new()
	tag.add_theme_font_override("font", TITLE_FONT)
	tag.add_theme_font_size_override("font_size", 24)
	head.add_child(tag)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_coin_label(20))
	box.add_child(head)
	for r in 2:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		var key := Label.new()
		key.custom_minimum_size = Vector2(62, 0)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		cols.add_child(key)
		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_theme_font_size_override("font_size", 19)
		cols.add_child(value)
		cols.add_child(_coin_label(16))
		box.add_child(cols)
	var foot := Label.new()
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", GOLD)
	foot.custom_minimum_size = Vector2(0, 22)
	box.add_child(foot)
	return panel


# ------------------------------------------------------------ Scoreboard

func _build_board() -> void:
	_board = PanelContainer.new()
	var style := _pill(PANEL_BG, 22, 16)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	_board.add_theme_stylebox_override("panel", style)
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_board.add_child(box)
	_board_title = Label.new()
	_board_title.add_theme_font_override("font", TITLE_FONT)
	_board_title.add_theme_font_size_override("font_size", 34)
	_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_board_title)
	_board_grid = GridContainer.new()
	_board_grid.add_theme_constant_override("h_separation", 16)
	_board_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_board_grid)
	_board_lines = Label.new()
	_board_lines.add_theme_font_size_override("font_size", 16)
	_board_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_lines.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	box.add_child(_board_lines)
	add_child(_board)


## One row per player, one column per frame, then the total.
func _fill_board(game) -> void:
	var frames: int = game.frames_per_match
	var cols: int = frames + 2
	if _board_grid.columns != cols or _board_grid.get_child_count() != cols * (game.player_count + 1):
		for c in _board_grid.get_children():
			c.queue_free()
		_board_grid.columns = cols
		for i in cols * (game.player_count + 1):
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(26, 0)
			l.add_theme_font_size_override("font_size", 18)
			_board_grid.add_child(l)
	var cells := _board_grid.get_children()
	cells[0].text = ""
	for f in frames:
		var head: Label = cells[1 + f]
		head.text = str(f + 1)
		head.add_theme_font_size_override("font_size", 14)
		var current: bool = f == game.frame - 1
		head.add_theme_color_override("font_color", GOLD if current else Color(1, 1, 1, 0.45))
	cells[cols - 1].text = "TOTAL"
	cells[cols - 1].add_theme_font_size_override("font_size", 14)
	cells[cols - 1].add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	var leader := 0
	for p in game.player_count:
		if game.totals[p] > game.totals[leader]:
			leader = p
	for p in game.player_count:
		var row: int = (p + 1) * cols
		var color: Color = game.player_colors[p].lightened(0.25)
		cells[row].text = "P%d" % (p + 1)
		cells[row].add_theme_font_override("font", TITLE_FONT)
		cells[row].add_theme_color_override("font_color", color)
		for f in frames:
			var cell: Label = cells[row + 1 + f]
			var played: bool = f < game.frame_points.size()
			cell.text = str(game.frame_points[f][p]) if played else "·"
			cell.add_theme_color_override("font_color", Color(1, 1, 1, 1.0 if played else 0.3))
		var total: Label = cells[row + cols - 1]
		total.text = str(game.totals[p])
		total.add_theme_font_override("font", TITLE_FONT)
		total.add_theme_color_override("font_color", color)
		total.add_theme_font_size_override("font_size", 28 if p == leader else 22)

	var lines := []
	match game.state:
		game.State.RESULTS:
			_board_title.text = "FRAME %d" % game.frame
			lines.append(_frame_summary(game))
			lines.append(_coins_text(game, false))
		game.State.MATCH_OVER:
			_board_title.text = _winner_text(game)
			lines.append(_coins_text(game, true))
		_:
			_board_title.text = "SCORES"
	_board_lines.text = "\n".join(lines.filter(func(s): return s != ""))
	_board_lines.visible = _board_lines.text != ""


## e.g. "P1 +9  7 pins, race +2      P2 +4  4 pins"
func _frame_summary(game) -> String:
	var r: Dictionary = game.last_result
	if r.is_empty():
		return ""
	var parts := []
	for i in game.player_count:
		var bits := ["%d pins" % r.pins[i]]
		if r.race[i] > 0:
			bits.append("race +%d" % r.race[i])
		if r.sweep[i] > 0:
			bits.append("sweep +%d" % r.sweep[i])
		if r.knockouts[i] > 0:
			bits.append("KO +%d" % r.knockouts[i])
		parts.append("P%d +%d  (%s)" % [i + 1, r.points[i], ", ".join(bits)])
	var text := "      ".join(parts)
	if r.note != "":
		text += "\n" + r.note
	return text


func _coins_text(game, whole_match: bool) -> String:
	var parts := []
	for i in game.player_count:
		var got: int = game.match_coins[i] if whole_match else game.coins_earned[i]
		parts.append("P%d +%d" % [i + 1, got])
	return "COINS   " + "      ".join(parts)


func _winner_text(game) -> String:
	var best := -1
	var winners := []
	for i in game.player_count:
		if game.totals[i] > best:
			best = game.totals[i]
			winners = ["P%d" % (i + 1)]
		elif game.totals[i] == best:
			winners.append("P%d" % (i + 1))
	if winners.size() > 1:
		return "TIE!  %s" % " & ".join(winners)
	return "%s WINS!" % winners[0]


# ------------------------------------------------------------ Key hints

func _update_hints(game) -> void:
	var items := []   # [key, action] pairs; "|" separates groups
	var n: int = game.player_count
	match game.state:
		game.State.WAITING:
			for p in n:
				var k := _key_names(p)
				items += [[k.move, "P%d" % (p + 1)], [k.confirm, "Buy"], "|"]
			items += [[_gk("SPACE"), "Start"], [_gk("V"), "Track"], [_gk("ESC"), "Pause"]]
		game.State.HUB:
			for p in n:
				var k := _key_names(p)
				if game.customize_open[p]:
					items += [[k.move, "P%d Browse" % (p + 1)], [k.confirm, "Buy"], [k.rotate, "Done"], "|"]
				elif game.derby_open[p]:
					items += [[k.move, "P%d Horse/Wager" % (p + 1)], [k.confirm, "Bet"], [k.rotate, "Leave"], "|"]
				else:
					items += [[k.move, "P%d Roll" % (p + 1)], [k.confirm, "Hop"], "|"]
			items += [[_gk("ESC"), "Pause"]]
		game.State.DRAFT:
			for p in n:
				var k := _key_names(p)
				items += [[k.move, "P%d" % (p + 1)], [k.confirm, "Grab"], "|"]
		game.State.BUILD:
			for p in n:
				var k := _key_names(p)
				var turn := "Turn"
				if PieceCatalog.is_track(game.draft_build.picks[p]):
					turn = "Flip" if PieceCatalog.turns(game.draft_build.picks[p]) else ""
				items += [[k.move, "P%d" % (p + 1)]]
				if turn != "":
					items += [[k.rotate, turn]]
				items += [[k.confirm, "Drop"], "|"]
		game.State.COUNTDOWN, game.State.ROLLING:
			for p in n:
				var k := _key_names(p)
				items += [[k.move, "P%d Lean" % (p + 1)], [k.confirm, "Hop"], "|"]
			items += [[_gk("ESC"), "Pause"], [_gk("TAB"), "Scores"], [_gk("V"), "Camera"]]
			if not Controls.any_pad():
				items += [["R", "Retry"], ["C", "Bumping " + ("on" if game.marbles_collide else "off")]]
		_:
			items += [[_gk("SPACE"), "Next"], [_gk("TAB"), "Scores"]]
	if not items.is_empty() and items[-1] is String:
		items.pop_back()
	var key := str(items)
	if key == _hints_key:
		return
	_hints_key = key
	for c in _hints.get_children():
		c.queue_free()
	for it in items:
		if it is String:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(14, 0)
			_hints.add_child(gap)
			continue
		var cap := Label.new()
		cap.text = it[0]
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		cap.add_theme_stylebox_override("normal", _pill(Color(1, 1, 1, 0.88), 7, 1))
		_hints.add_child(cap)
		var word := Label.new()
		word.text = it[1]
		word.add_theme_font_size_override("font_size", 14)
		word.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		word.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		word.add_theme_constant_override("outline_size", 4)
		_hints.add_child(word)


## Short key names for a player, for the hints.
## A game-wide key, or its controller button if anyone is on a controller.
func _gk(key: String) -> String:
	if not Controls.any_pad():
		return key
	return {"SPACE": "SPACE / Y", "ESC": "ESC / START", "TAB": "TAB / BACK", "V": "V / LB"}.get(key, key)


func _key_names(p: int) -> Dictionary:
	if Controls.using_pad[p]:
		return {"move": "L-STICK", "rotate": "X", "confirm": "A"}
	match p:
		0: return {"move": "WASD", "rotate": "Q", "confirm": "E"}
		1: return {"move": "ARROWS", "rotate": "R-SHIFT", "confirm": "ENTER"}
		2: return {"move": "IJKL", "rotate": "U", "confirm": "O"}
		_: return {"move": "NUM 8456", "rotate": "NUM 7", "confirm": "NUM 9"}


# ------------------------------------------------------------ Helpers

## Show the first `count` children (one per player) and hide the rest, so
## a match with fewer players than the last one doesn't show old panels.
func _show_first(parent: Node, count: int) -> void:
	for i in parent.get_child_count():
		(parent.get_child(i) as CanvasItem).visible = i < count

func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
	return "%dTH" % n


func _pill(bg: Color, h_margin: int, v_margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.content_margin_left = h_margin
	s.content_margin_right = h_margin
	s.content_margin_top = v_margin
	s.content_margin_bottom = v_margin
	return s


func _title_label(size: int, preset: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_END if preset == Control.PRESET_CENTER_TOP else Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l
