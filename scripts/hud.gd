class_name Hud
extends CanvasLayer
## Everything drawn on top of the game: scores, phase banners, the draft
## cards and pointers, the Customize screen, the scoreboard and key hints.
## Only reads game state, never changes it.
##
## Font: Chakra Petch, a free font (SIL Open Font License, see fonts/)
## with cut, faceted corners to suit the low-poly look. SemiBold for normal
## text (set for the whole project in ui/theme.tres), Bold for titles.

## Seconds the podium shows on its own before the coins screen comes up.
const PODIUM_TIME := 6.5
## Seconds between each match award popping in.
const AWARD_STEP := 0.9
const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const PANEL_BG := Color(0.07, 0.09, 0.16, 0.82)
const GOLD := Color(1.0, 0.82, 0.25)

## Draft card size and spacing, in pixels.
const CARD_W := 232.0
const CARD_H := 300.0
const CARD_GAP := 20.0

var thumbnails: Thumbnails

var _scores: HBoxContainer
var _badge: Label            # "FRAME 3/10" top centre
var _banner: Label           # "DRAFT 12" under the badge
var _center: Label           # countdown number
var _board: PanelContainer
var _board_grid: VBoxContainer
var _board_title: Label
var _board_lines: Label
var _board_frames := -1
var _board_key := ""
var _board_shown := {}   # total each player's row shows while counting up
var _coins_screen: Control   # COINS EARNED, after the podium
var _coins_grid: GridContainer
var _coins_key := ""
var _awards_screen: Control  # MATCH AWARDS, before the podium
var _awards_row: HBoxContainer
var _awards_key := ""
var _strike: Label
var _strike_burst: CPUParticles2D
## Seconds left of the STRIKE! banner (the scoreboard waits for it).
var _strike_left := 0.0
var _strike_player := -1
var _hints: HFlowContainer
var _hints_key := ""
var _chips: HBoxContainer    # build-phase status, bottom centre
var _ready_title: Label
var _ready_sub: Label
var _tables: HBoxContainer       # casino panels: derby, blackjack, bar (one per seated player)
var _hub_coins: HBoxContainer    # everyone's coins, top right on the island

var _draft_root: Control
var _draft_dim: ColorRect
var _card_layer: Control
var _cards: Array = []       # one Dictionary per crate slot
var _crate_shown: Array = []
var _pointers: Array = []    # one DraftPointer per player
var _last_countdown := -1
## Strike replay: black cinema bars top and bottom, a red REPLAY tag and a
## line along the bottom bar showing how far through it is.
const BAR_HEIGHT := 78.0
const REPLAY_RED := Color(0.95, 0.22, 0.2)
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _replay_line: ColorRect
var _replay_tag: Label
var _replay_skip: Label
var _bars := 0.0   # 0 = hidden, 1 = fully in


## A gold medal on a ribbon, drawn in code, for the match awards.
class AwardMedal extends Control:
	var ribbon := Color(0.85, 0.2, 0.25)

	func _init() -> void:
		custom_minimum_size = Vector2(72, 86)

	func _draw() -> void:
		var c := Vector2(size.x / 2.0, 54)
		# Ribbon: two tails in a V above the medal.
		for side in [-1.0, 1.0]:
			var top := c + Vector2(side * 16, -54)
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(side * 14, 0),
					c + Vector2(side * 6, -12), c + Vector2(-side * 8, -18)]), ribbon.darkened(0.15 if side > 0 else 0.0))
		draw_circle(c + Vector2(3, 4), 28, Color(0, 0, 0, 0.35))
		draw_circle(c, 28, Hud.GOLD.darkened(0.25))
		draw_circle(c, 23, Hud.GOLD)
		var star := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			star.append(c + Vector2(cos(a), sin(a)) * (15.0 if i % 2 == 0 else 6.5))
		draw_colored_polygon(star, Color(1, 0.95, 0.7))


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
	_build_replay_bars()

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

	_ready_title = _title_label(84, Control.PRESET_CENTER_TOP)
	_ready_title.offset_top = 70
	_ready_title.text = "READY?"
	_ready_sub = _title_label(24, Control.PRESET_CENTER_TOP)
	_ready_sub.offset_top = 175

	_tables = HBoxContainer.new()
	_tables.add_theme_constant_override("separation", 18)
	_tables.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tables.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tables.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tables.offset_bottom = -58
	add_child(_tables)

	_hub_coins = HBoxContainer.new()
	_hub_coins.add_theme_constant_override("separation", 8)
	_hub_coins.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hub_coins.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hub_coins.offset_right = -16
	_hub_coins.offset_top = 14
	add_child(_hub_coins)

	# Key hints along the bottom. They wrap onto a second line rather than
	# run off the screen (four players on controllers is a lot of hints).
	_hints = HFlowContainer.new()
	_hints.add_theme_constant_override("h_separation", 6)
	_hints.add_theme_constant_override("v_separation", 4)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.offset_left = 16
	_hints.offset_right = -16
	_hints.offset_top = 0
	_hints.offset_bottom = -12
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)


func refresh(game) -> void:
	# The main menu draws its own screen; the game HUD stays out of the way.
	visible = game.state != game.State.MENU
	if not visible:
		return
	# The hub has no scores, and the FINAL STANDINGS stage is a screen of its own.
	var on_stage: bool = (game.state == game.State.MATCH_OVER and game.podium != null and game.podium.visible) \
			or game.state == game.State.AWARDS
	_scores.visible = game.state != game.State.HUB and not on_stage
	if _scores.visible:
		_update_scores(game)
	_update_top(game)
	_update_countdown(game)
	_update_draft(game)
	_update_chips(game)
	_update_ready(game)
	_update_hub(game)
	_update_replay(game)

	var show_board: bool = game.state in [game.State.RESULTS, game.State.MATCH_OVER] \
			or (Input.is_action_pressed("scoreboard") and not game.state in [game.State.WAITING, game.State.HUB])
	# Match over: let everyone enjoy the podium for a few seconds first.
	if game.state == game.State.MATCH_OVER and game.podium and game.podium.visible \
			and game.podium.age < PODIUM_TIME and not Input.is_action_pressed("scoreboard"):
		show_board = false
	# Let a STRIKE! play before the scores come in.
	_strike_left = maxf(_strike_left - get_process_delta_time(), 0.0)
	if _strike_left > 0.0 and not Input.is_action_pressed("scoreboard"):
		show_board = false
	# After the podium: the coins breakdown (the scores are on TAB).
	var show_coins := false
	if game.state == game.State.MATCH_OVER and not game.coin_breakdown.is_empty() \
			and not Input.is_action_pressed("scoreboard"):
		show_board = false
		show_coins = game.podium != null and game.podium.age >= PODIUM_TIME
	_board.visible = show_board
	if show_board:
		_fill_board(game)
	_update_coins_screen(game, show_coins)
	_update_awards_screen(game, game.state == game.State.AWARDS and not Input.is_action_pressed("scoreboard"))
	_update_hints(game)
	_tables.offset_bottom = -(_hints.size.y + 24.0)


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
		row.get_child(0).text = game.seat_name(i)
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
	_badge.visible = not game.state in [game.State.WAITING, game.State.HUB, game.State.MATCH_OVER, game.State.REPLAY, game.State.AWARDS]
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


## How much the card row is shrunk so every card fits on screen (six
## cards are wider than a 1280 px screen at full size).
func _card_scale(count: int) -> float:
	var screen := _draft_root.get_viewport_rect().size
	var width := count * (CARD_W + CARD_GAP)
	return minf(1.0, (screen.x - 48.0) / maxf(width, 1.0))


## Top-left corner of the card row on screen.
func _row_origin(count: int) -> Vector2:
	var screen := _draft_root.get_viewport_rect().size
	var k := _card_scale(count)
	var width := count * (CARD_W + CARD_GAP) * k
	return Vector2((screen.x - width) / 2.0, screen.y / 2.0 - CARD_H * k / 2.0 - 10.0)


## Card-space point (see DraftBuild.draft_pointer) to screen pixels.
func _card_to_screen(p: Vector2, count: int) -> Vector2:
	var k := _card_scale(count)
	return _row_origin(count) + Vector2(p.x * (CARD_W + CARD_GAP), p.y * CARD_H) * k


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
	var fit := _card_scale(n)
	for slot in _cards.size():
		var card: Dictionary = _cards[slot]
		var panel: PanelContainer = card.panel
		panel.position = origin + Vector2(slot * (CARD_W + CARD_GAP) + CARD_GAP / 2.0, 0) * fit
		# Scale about the card's top-left corner shifted to its middle, so a
		# shrunk card still sits in its slot.
		panel.position += panel.size * (fit - 1.0) / 2.0
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
			card.stamp.text = game.seat_name(owner)
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
		# Deal the cards in one after another: each flips up from small and
		# tilted with a springy overshoot.
		var k := clampf((Time.get_ticks_msec() / 1000.0 - card.born - 0.07 * slot) / 0.4, 0.0, 1.0)
		if k < 1.0:
			var e := 1.0 + 2.7 * pow(k - 1.0, 3) + 1.7 * pow(k - 1.0, 2)  # ease out, back
			panel.scale = Vector2.ONE * lerpf(0.2, 1.0, e) * fit
			panel.rotation = deg_to_rad(lerpf(-14.0, 0.0, e))
			panel.position.y += (1.0 - e) * 80.0
			panel.modulate.a = clampf(k * 4.0, 0.0, 1.0)
		else:
			panel.rotation = 0.0
			panel.modulate.a = 1.0
			panel.scale = panel.scale.lerp(Vector2.ONE * target_scale * fit, 0.3)

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
		ptr.tag = game.seat_name(p)
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
		box.add_child(RetroTitle.Trim.new())
		# Track altering cards (TAs) get a gold badge on top.
		var badge := Label.new()
		badge.text = PieceCatalog.tag(id) if PieceCatalog.is_track(id) else ""
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", TITLE_FONT)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		var badge_bg := _pill(GOLD, 10, 1)
		badge_bg.set_corner_radius_all(8)
		badge.add_theme_stylebox_override("normal", badge_bg if badge.text != "" else StyleBoxEmpty.new())
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(badge)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(176, 176)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if thumbnails:
			pic.texture = thumbnails.texture_for(id)
		box.add_child(pic)
		var name_label := Label.new()
		name_label.text = PieceCatalog.display_name(id).to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", TITLE_FONT)
		name_label.add_theme_font_size_override("font_size", 26)
		if PieceCatalog.is_track(id):
			name_label.add_theme_color_override("font_color", GOLD)
		box.add_child(name_label)
		var about := Label.new()
		about.text = PieceCatalog.info(id).about
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.add_theme_font_size_override("font_size", 17)
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(CARD_W - 24.0, 0)
		about.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		box.add_child(about)
		var stamp := Label.new()
		stamp.add_theme_font_override("font", TITLE_FONT)
		stamp.add_theme_font_size_override("font_size", 80)
		stamp.add_theme_color_override("font_outline_color", Color.BLACK)
		stamp.add_theme_constant_override("outline_size", 12)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stamp.visible = false
		panel.add_child(stamp)  # fills the card, on top of the picture
		if PieceCatalog.is_new(id):
			panel.add_child(_new_sticker())
		_card_layer.add_child(panel)
		panel.modulate.a = 0.0
		# "born": when it was dealt (see _update_draft for the deal-in).
		_cards.append({"panel": panel, "style": style, "pic": pic, "stamp": stamp,
				"born": Time.get_ticks_msec() / 1000.0})


## A tilted red NEW! sticker for the top corner of a draft card.
func _new_sticker() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "NEW!"
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	var bg := _pill(RetroTitle.STRIPES[1], 12, 2)
	bg.set_corner_radius_all(14)
	bg.border_color = Color(0.05, 0.05, 0.12)
	bg.set_border_width_all(3)
	l.add_theme_stylebox_override("normal", bg)
	l.position = Vector2(CARD_W - 92, -16)
	l.rotation = deg_to_rad(12.0)
	holder.add_child(l)
	return holder


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
			piece = "TA · " + piece
		if PieceCatalog.parts(db.picks[p]) > 1 and not db.has_placed[p]:
			piece += "  %d/%d" % [db.part[p] + 1, PieceCatalog.parts(db.picks[p])]
		if PieceCatalog.turns(db.picks[p]):
			piece += "  < LEFT" if PieceCatalog.turns_left(db.cursor_angle[p]) else "  RIGHT >"
		var state := ""
		if db.has_placed[p]:
			state = "DONE"
		elif db.cursor_blocked(p):
			state = DraftBuild._reason_text(db.blocked_reason(p)) if not PieceCatalog.is_track(db.picks[p]) else "WON'T FIT"
		var text := "%s  %s" % [game.seat_name(p), piece]
		if state != "":
			text += "  ·  " + state
		var l: Label = chip.get_child(0)
		l.text = text
		l.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if state != "" and state != "DONE" else Color.WHITE)
	# Sit just above the key hints, however many lines they take.
	_chips.offset_bottom = -(_hints.size.y + 22.0)


# ------------------------------------------------------------ Ready screen

func _update_ready(game) -> void:
	var show: bool = game.state == game.State.WAITING
	_ready_title.visible = show
	_ready_sub.visible = show
	if not show:
		return
	_ready_sub.text = "PRESS %s TO START  ·  CHANGE LOOKS IN THE CLOSET AT THE HUB" % _gk("SPACE")
	var pulse := 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 3.0) * 0.04
	_ready_title.pivot_offset = _ready_title.size / 2.0
	_ready_title.scale = Vector2(pulse, pulse)


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
	# The closet and crate screens draw their own coins and hints.
	var screen: bool = in_hub and (game.closet.is_open() or game.crate_screen.is_open())
	_hub_coins.visible = in_hub and not screen
	_hints.visible = not screen
	_tables.visible = in_hub and game.table_open.any(func(t): return t != "")
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
		var gems := Label.new()
		gems.add_theme_font_override("font", TITLE_FONT)
		gems.add_theme_font_size_override("font_size", 20)
		gems.add_theme_color_override("font_color", Cosmetics.rarity_color("secret"))
		row.add_child(gems)
		_hub_coins.add_child(chip)
	_show_first(_hub_coins, game.player_count)
	for p in game.player_count:
		var chip: PanelContainer = _hub_coins.get_child(p)
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel")
		style.border_color = game.player_colors[p]
		style.border_width_bottom = 4
		var row := chip.get_child(0)
		row.get_child(0).text = game.seat_name(p)
		row.get_child(0).add_theme_color_override("font_color", game.player_colors[p].lightened(0.2))
		var prof: int = game.profile_of(p)
		row.get_child(1).text = "%d COINS" % game.profiles.coins(prof) if prof >= 0 else ""
		# Secret gems found so far (saved between visits).
		row.get_child(2).text = "◆ %d/%d" % [game.profiles.secrets_found(prof), Jungle.GEM_COUNT] if prof >= 0 else ""
	if not _tables.visible:
		return
	while _tables.get_child_count() < game.player_count:
		_tables.add_child(_make_table_panel())
	_show_first(_tables, game.player_count)
	for p in game.player_count:
		var panel: PanelContainer = _tables.get_child(p)
		var kind: String = game.table_open[p]
		panel.visible = kind != ""
		if kind == "":
			continue
		var box := panel.get_child(0)
		var head: HBoxContainer = box.get_child(0)
		(head.get_child(0) as Label).text = game.seat_name(p)
		(head.get_child(0) as Label).add_theme_color_override("font_color", (game.player_colors[p] as Color).darkened(0.35))
		(head.get_child(1) as Label).text = {"derby": "THE DERBY", "blackjack": "BLACKJACK", "bar": "THE BAR"}.get(kind, kind.to_upper())
		var prof: int = game.profile_of(p)
		(head.get_child(3) as Label).text = "%d COINS" % game.profiles.coins(prof) if prof >= 0 else ""
		var rows: Array = []   # [key, value (String, or Array of cards), right, value colour] per row
		var foot := ""
		var keys := _key_names(game.seat_keys[p])
		match kind:
			"derby":
				var derby: HorseRace = game.hub.casino.derby
				var placed: bool = derby.bets.has(p)
				var h: int = derby.bets[p].horse if placed else derby.pick[p]
				var amount: int = derby.bets[p].amount if placed else derby.wager[p]
				rows.append(["HORSE", ("No.%d %s" if placed else "◂ No.%d %s ▸") % [h + 1, HorseRace.HORSES[h].name],
						"pays %.1fx" % derby.odds[h], (HorseRace.HORSES[h].color as Color).darkened(0.35)])
				rows.append(["WAGER", ("%d" if placed else "− %d +") % amount, "win %d" % roundi(amount * derby.odds[h]), INK])
				if derby.message[p] != "":
					foot = derby.message[p]
				elif not placed:
					foot = "%s  place bet" % keys.confirm
			"blackjack":
				var bj: Blackjack = game.hub.casino.blackjack
				var st: Dictionary = bj.seats[p]
				if not st.cards.is_empty():
					var shown: Array = st.dealer.slice(0, 1) if st.hidden else st.dealer
					rows.append(["DEALER", shown + ([null] if st.hidden else []), str(Blackjack.value(shown)), INK])
					rows.append(["YOU", st.cards, str(Blackjack.value(st.cards)), INK])
				var betting: bool = st.phase == Blackjack.Phase.BETTING or st.phase == Blackjack.Phase.DONE
				rows.append(["WAGER", ("− %d +" if betting else "%d") % st.wager, "", INK])
				if st.message != "":
					foot = st.message
				elif st.phase == Blackjack.Phase.PLAYING:
					foot = "%s  hit      %s  stand" % [keys.confirm, keys.rotate]
				elif st.phase == Blackjack.Phase.DEALER:
					foot = "Dealer's turn..."
				else:
					foot = "%s  deal" % keys.confirm
			"bar":
				var casino: CasinoIsland = game.hub.casino
				var d: Dictionary = CasinoIsland.DRINKS[casino.drink_pick[p]]
				rows.append(["DRINK", "◂ %s ▸" % d.name, "%d coins" % d.price, (d.color as Color).darkened(0.4)])
				foot = casino.bar_message[p] if casino.bar_message[p] != "" else "%s  order" % keys.confirm
		for r in 3:
			var row: HBoxContainer = box.get_child(2 + r)
			row.visible = r < rows.size()
			if not row.visible:
				continue
			(row.get_child(0) as Label).text = rows[r][0]
			var value: Label = row.get_child(1)
			var cards: HBoxContainer = row.get_child(2)
			value.visible = rows[r][1] is String
			cards.visible = not value.visible
			if value.visible:
				value.text = rows[r][1]
				value.add_theme_color_override("font_color", rows[r][3])
			else:
				_show_cards(cards, rows[r][1])
			(row.get_child(3) as Label).text = rows[r][2]
		(box.get_child(5) as Label).text = foot.to_upper()


## Ink and paper for the casino tickets.
const INK := Color(0.2, 0.1, 0.08)
const PAPER := Color(0.97, 0.92, 0.8)
const TICKET_RED := Color(0.66, 0.12, 0.13)


## Little playing cards in a row (null = a face-down card).
func _show_cards(row: HBoxContainer, cards: Array) -> void:
	while row.get_child_count() < cards.size():
		var l := Label.new()
		l.add_theme_font_override("font", TITLE_FONT)
		l.add_theme_font_size_override("font_size", 18)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(36, 0)
		row.add_child(l)
	for i in row.get_child_count():
		var l: Label = row.get_child(i)
		l.visible = i < cards.size()
		if not l.visible:
			continue
		var c = cards[i]
		var face := StyleBoxFlat.new()
		face.set_corner_radius_all(3)
		face.set_border_width_all(1)
		face.content_margin_left = 3
		face.content_margin_right = 3
		if c == null:
			face.bg_color = TICKET_RED
			face.border_color = PAPER
			l.text = "✦"
			l.add_theme_color_override("font_color", PAPER)
		else:
			face.bg_color = Color.WHITE
			face.border_color = INK.lightened(0.4)
			l.text = Blackjack.card_name(c) + Blackjack.SUITS[c[1]]
			l.add_theme_color_override("font_color", Blackjack.RED if c[1] in [1, 2] else Blackjack.BLACK)
		l.add_theme_stylebox_override("normal", face)


## A casino panel, printed like an old casino ticket: cream card, red
## border with a thin inner rule, a red name ribbon, dark ink.
func _make_table_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(4)
	style.set_border_width_all(4)
	style.border_color = TICKET_RED
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_offset = Vector2(5, 6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var tag := Label.new()
	tag.add_theme_font_override("font", TITLE_FONT)
	tag.add_theme_font_size_override("font_size", 22)
	head.add_child(tag)
	var title := Label.new()
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", PAPER)
	var ribbon := StyleBoxFlat.new()
	ribbon.bg_color = TICKET_RED
	ribbon.content_margin_left = 10
	ribbon.content_margin_right = 10
	ribbon.set_corner_radius_all(2)
	title.add_theme_stylebox_override("normal", ribbon)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var coins := Label.new()
	coins.add_theme_font_override("font", TITLE_FONT)
	coins.add_theme_font_size_override("font_size", 18)
	coins.add_theme_color_override("font_color", Color(0.6, 0.42, 0.05))
	head.add_child(coins)
	box.add_child(head)
	# A thin double rule under the heading.
	var rule := ColorRect.new()
	rule.color = TICKET_RED
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	for r in 3:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		var key := Label.new()
		key.custom_minimum_size = Vector2(70, 0)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", INK.lightened(0.35))
		cols.add_child(key)
		var value := Label.new()
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.add_theme_font_override("font", TITLE_FONT)
		value.add_theme_font_size_override("font_size", 19)
		cols.add_child(value)
		var cards := HBoxContainer.new()
		cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_theme_constant_override("separation", 4)
		cols.add_child(cards)
		var right := Label.new()
		right.add_theme_font_override("font", TITLE_FONT)
		right.add_theme_font_size_override("font_size", 16)
		right.add_theme_color_override("font_color", Color(0.6, 0.42, 0.05))
		cols.add_child(right)
		box.add_child(cols)
	var foot := Label.new()
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_override("font", TITLE_FONT)
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", TICKET_RED)
	foot.custom_minimum_size = Vector2(0, 22)
	box.add_child(foot)
	return panel


# ------------------------------------------------------------ Scoreboard

func _build_board() -> void:
	_board = PanelContainer.new()
	var style := _pill(Color(0.06, 0.08, 0.15, 0.94), 28, 20)
	style.border_width_top = 6
	style.border_color = GOLD
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 18
	_board.add_theme_stylebox_override("panel", style)
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_board.add_child(box)
	_board_title = Label.new()
	_board_title.add_theme_font_override("font", TITLE_FONT)
	_board_title.add_theme_font_size_override("font_size", 46)
	_board_title.add_theme_color_override("font_color", GOLD)
	_board_title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	_board_title.add_theme_constant_override("outline_size", 10)
	_board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_board_title)
	_board_grid = VBoxContainer.new()
	_board_grid.add_theme_constant_override("separation", 8)
	box.add_child(_board_grid)
	_board_lines = Label.new()
	_board_lines.add_theme_font_size_override("font_size", 16)
	_board_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_lines.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	box.add_child(_board_lines)
	add_child(_board)


## One row per player (a coloured card), one cell per frame, then the total.
func _make_board_row(frames: int, header: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var st := _pill(Color(1, 1, 1, 0.0 if header else 0.06), 14, 6 if header else 8)
	st.border_width_bottom = 0 if header else 4
	card.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var name := Label.new()
	name.custom_minimum_size = Vector2(70, 0)
	name.add_theme_font_override("font", TITLE_FONT)
	name.add_theme_font_size_override("font_size", 28)
	_shadow(name)
	row.add_child(name)
	for f in frames:
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(34, 0)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", 14 if header else 20)
		_shadow(cell)
		row.add_child(cell)
	var total := Label.new()
	total.custom_minimum_size = Vector2(90, 0)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total.add_theme_font_override("font", TITLE_FONT)
	total.add_theme_font_size_override("font_size", 14 if header else 38)
	_shadow(total)
	row.add_child(total)
	var plus := Label.new()
	plus.custom_minimum_size = Vector2(70, 0)
	plus.add_theme_font_override("font", TITLE_FONT)
	plus.add_theme_font_size_override("font_size", 26)
	plus.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	plus.add_theme_constant_override("outline_size", 6)
	row.add_child(plus)
	return card


## A dark edge round white text, so it reads on any player colour.
func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 5)


func _fill_board(game) -> void:
	var frames: int = game.frames_per_match
	var rows: int = game.player_count + 1
	if _board_grid.get_child_count() != rows or _board_frames != frames:
		for c in _board_grid.get_children():
			_board_grid.remove_child(c)
			c.queue_free()
		_board_frames = frames
		for r in rows:
			_board_grid.add_child(_make_board_row(frames, r == 0))
		_board_key = ""
	# Header row: frame numbers.
	var head: HBoxContainer = _board_grid.get_child(0).get_child(0)
	for f in frames:
		var l: Label = head.get_child(1 + f)
		l.text = str(f + 1)
		l.add_theme_color_override("font_color", GOLD if f == game.frame - 1 else Color(1, 1, 1, 0.4))
	(head.get_child(1 + frames) as Label).text = "TOTAL"
	(head.get_child(1 + frames) as Label).add_theme_color_override("font_color", Color(1, 1, 1, 0.4))

	var leader := 0
	for p in game.player_count:
		if game.totals[p] > game.totals[leader]:
			leader = p
	for p in game.player_count:
		var card: PanelContainer = _board_grid.get_child(p + 1)
		# The whole row is the player's colour, with white writing on it.
		var st: StyleBoxFlat = card.get_theme_stylebox("panel")
		st.bg_color = (game.player_colors[p] as Color).darkened(0.25)
		st.border_color = (game.player_colors[p] as Color).lightened(0.2)
		var row: HBoxContainer = card.get_child(0)
		var color := Color.WHITE
		var name: Label = row.get_child(0)
		name.text = ("★ " if p == leader and game.totals[p] > 0 else "") + game.seat_name(p)
		name.add_theme_color_override("font_color", color)
		for f in frames:
			var cell: Label = row.get_child(1 + f)
			var played: bool = f < game.frame_points.size()
			cell.text = str(game.frame_points[f][p]) if played else "·"
			cell.add_theme_color_override("font_color", Color(1, 1, 1, 1.0 if played else 0.35))
		var total: Label = row.get_child(1 + frames)
		var shown: int = _board_shown.get(p, game.totals[p])
		total.text = str(shown)
		total.add_theme_color_override("font_color", color)

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

	# A new result: play the scores in.
	var key := "%d-%d-%d" % [game.frame, game.state, game.frame_points.size()]
	if game.state in [game.State.RESULTS, game.State.MATCH_OVER] and key != _board_key:
		_board_key = key
		_animate_board(game, frames, leader)


## Juice: the board pops in, then each player's points count up into their
## total one after another, with a flying "+N", a pop on the new frame
## cell and a flash of their card. The leader's total gets a bounce.
func _animate_board(game, frames: int, leader: int) -> void:
	_board.pivot_offset = _board.size / 2.0
	_board.scale = Vector2.ONE * 0.8
	_board.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_board, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_board, "modulate:a", 1.0, 0.2)
	var f: int = game.frame_points.size() - 1
	for p in game.player_count:
		var gained: int = game.frame_points[f][p] if f >= 0 else 0
		var to: int = game.totals[p]
		_board_shown[p] = to - gained
		var card: PanelContainer = _board_grid.get_child(p + 1)
		var row: HBoxContainer = card.get_child(0)
		var total: Label = row.get_child(1 + frames)
		var cell: Label = row.get_child(1 + f) if f >= 0 else null
		var plus: Label = row.get_child(2 + frames)
		plus.text = "+%d" % gained if gained > 0 else ""
		plus.add_theme_color_override("font_color", GOLD)
		plus.modulate.a = 0.0
		if cell:
			cell.modulate.a = 0.0
		var delay: float = 0.45 + p * 0.35
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_callback(func():
			if cell:
				cell.pivot_offset = cell.size / 2.0
				cell.modulate.a = 1.0
				cell.scale = Vector2.ONE * 1.8
				create_tween().tween_property(cell, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			card.modulate = Color(1.6, 1.6, 1.6)
			create_tween().tween_property(card, "modulate", Color.WHITE, 0.4)
			plus.modulate.a = 1.0
			plus.position.y = 0.0
			var pt := create_tween().set_parallel(true)
			pt.tween_property(plus, "position:y", -18.0, 0.9).set_ease(Tween.EASE_OUT)
			pt.tween_property(plus, "modulate:a", 0.0, 0.5).set_delay(0.6))
		var count_time: float = clampf(gained * 0.06, 0.25, 0.9)
		t.tween_method(func(v: float):
			_board_shown[p] = roundi(v)
			total.text = str(roundi(v))
			total.pivot_offset = total.size / 2.0
			total.scale = Vector2.ONE * (1.0 + 0.25 * absf(sin(v * 1.7)) * (1.0 if gained > 0 else 0.0)),
			float(to - gained), float(to), count_time)
		t.tween_callback(func():
			_board_shown[p] = to
			total.scale = Vector2.ONE * 1.35
			create_tween().tween_property(total, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	if game.state == game.State.MATCH_OVER:
		_board_title.pivot_offset = _board_title.size / 2.0
		var wt := create_tween().set_loops(4)
		wt.tween_property(_board_title, "scale", Vector2.ONE * 1.12, 0.25)
		wt.tween_property(_board_title, "scale", Vector2.ONE, 0.25)


# ------------------------------------------------------------ Coins earned

## Rows of the COINS EARNED screen: label, then how to show a player's
## entry from their Scoring.match_coins breakdown.
const COIN_ROWS := ["PINS KNOCKED DOWN", "BONUS POINTS", "FINAL PLACE", "FINISHED THE MATCH", "TOTAL"]


## The coins screen: a dark backdrop and a card with one column per player,
## the rows filling in one at a time and the totals counting up.
func _update_coins_screen(game, show: bool) -> void:
	if _coins_screen == null:
		_build_coins_screen()
	_coins_screen.visible = show
	if not show:
		_coins_key = ""
		return
	var key := "%d-%d" % [game.player_count, game.frame_points.size()]
	if key == _coins_key:
		_update_wallets(game)
		return
	_coins_key = key
	for c in _coins_grid.get_children():
		_coins_grid.remove_child(c)
		c.queue_free()
	var n: int = game.player_count
	_coins_grid.columns = n + 1
	_coins_grid.add_child(Control.new())
	for p in n:
		var name := _coin_cell(game.seat_name(p), 30, (game.player_colors[p] as Color).lightened(0.25), TITLE_FONT)
		_coins_grid.add_child(name)
	var cells := []   # [row, player, Label, final value]
	for r in COIN_ROWS.size():
		var total_row: bool = r == COIN_ROWS.size() - 1
		_coins_grid.add_child(_coin_cell(COIN_ROWS[r], 18 if not total_row else 26,
				GOLD if total_row else Color(1, 1, 1, 0.7), TITLE_FONT if total_row else null, HORIZONTAL_ALIGNMENT_LEFT))
		for p in n:
			var b: Dictionary = game.coin_breakdown[p]
			var text := ""
			var value := 0
			match r:
				0: text = "%d pins  +%d" % [b.pins, b.pin_coins]
				1: text = "+%d" % b.bonus
				2: text = "%s  +%d" % [_ordinal(b.place + 1), b.place_coins]
				3: text = "+%d" % b.finish
				4: value = b.total
			var cell := _coin_cell(text, 22 if not total_row else 40, GOLD if total_row else Color.WHITE,
					TITLE_FONT if total_row else null)
			cell.modulate.a = 0.0
			_coins_grid.add_child(cell)
			cells.append([r, p, cell, value])
	# A wallet line under each player: their coins now (people only).
	_coins_grid.add_child(_coin_cell("WALLET", 16, Color(1, 1, 1, 0.5), null, HORIZONTAL_ALIGNMENT_LEFT))
	for p in n:
		var w := _coin_cell("", 16, Color(1, 1, 1, 0.6))
		w.name = "Wallet%d" % p
		_coins_grid.add_child(w)
	_update_wallets(game)
	# Play it in: the card pops up, then each row fills in, then the totals count up.
	_coins_screen.modulate.a = 0.0
	create_tween().tween_property(_coins_screen, "modulate:a", 1.0, 0.3)
	for c in cells:
		var cell: Label = c[2]
		var delay: float = 0.4 + c[0] * 0.4 + c[1] * 0.06
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_callback(func():
			cell.modulate.a = 1.0
			cell.pivot_offset = cell.size / 2.0
			cell.scale = Vector2.ONE * 1.4
			create_tween().tween_property(cell, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		if c[0] == COIN_ROWS.size() - 1:
			var to: int = c[3]
			t.tween_method(func(v: float): cell.text = "+%d" % roundi(v), 0.0, float(to), clampf(to * 0.01, 0.4, 1.2))


func _update_wallets(game) -> void:
	for p in game.player_count:
		var w := _coins_grid.get_node_or_null("Wallet%d" % p) as Label
		if w:
			var prof: int = game.profile_of(p)
			w.text = "%d coins" % game.profiles.coins(prof) if prof >= 0 else ""


func _build_coins_screen() -> void:
	_coins_screen = Control.new()
	_coins_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coins_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coins_screen)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins_screen.add_child(dim)
	var card := PanelContainer.new()
	var style := _pill(Color(0.1, 0.06, 0.07, 0.96), 34, 22)
	style.border_width_top = 6
	style.border_width_bottom = 6
	style.border_color = Color(0.6, 0.1, 0.14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_coins_screen.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)
	var title := _coin_cell("COINS EARNED", 50, GOLD, TITLE_FONT)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	_coins_grid = GridContainer.new()
	_coins_grid.add_theme_constant_override("h_separation", 34)
	_coins_grid.add_theme_constant_override("v_separation", 10)
	box.add_child(_coins_grid)


func _coin_cell(text: String, size: int, color: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	_shadow(l)
	return l


# ------------------------------------------------------------ Match awards

## The MATCH AWARDS screen at the end of a match: a dark backdrop and a
## row of medals (STRIKE KING, SPEED DEMON...) popping in one at a time,
## each with the winner's name in their colour. The awards come from
## MatchAwards (main.gd keeps them in `awards`).
func _update_awards_screen(game, show: bool) -> void:
	if _awards_screen == null:
		_build_awards_screen()
	# Wait for a last-frame STRIKE! to finish first.
	show = show and _strike_left <= 0.0
	_awards_screen.visible = show
	if not show:
		if game.state != game.State.AWARDS:
			_awards_key = ""
		return
	var key := str(game.awards)
	if key == _awards_key:
		return
	_awards_key = key
	for c in _awards_row.get_children():
		_awards_row.remove_child(c)
		c.queue_free()
	var tiles := []
	for a in game.awards:
		var tile := _award_tile(game, a)
		tile.modulate.a = 0.0
		_awards_row.add_child(tile)
		tiles.append(tile)
	_awards_screen.modulate.a = 0.0
	create_tween().tween_property(_awards_screen, "modulate:a", 1.0, 0.3)
	for i in tiles.size():
		var tile: Control = tiles[i]
		var t := create_tween()
		t.tween_interval(0.5 + i * AWARD_STEP)
		t.tween_callback(func():
			tile.modulate.a = 1.0
			tile.pivot_offset = tile.size / 2.0
			tile.scale = Vector2.ONE * 0.4
			tile.rotation = -0.12
			var pop := create_tween().set_parallel(true)
			pop.tween_property(tile, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_property(tile, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## True while the STRIKE! banner is still playing.
func strike_showing() -> bool:
	return _strike_left > 0.0


## One award: medal, award name, what it's for, who won and their number.
func _award_tile(game, a: Dictionary) -> PanelContainer:
	var tile := PanelContainer.new()
	var style := _pill(Color(0.16, 0.1, 0.12, 0.95), 18, 16)
	style.border_width_bottom = 4
	style.border_color = Color(0.6, 0.1, 0.14)
	tile.add_theme_stylebox_override("panel", style)
	tile.custom_minimum_size = Vector2(230, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(box)
	var medal := AwardMedal.new()
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var first: int = a.players[0]
	medal.ribbon = (game.player_colors[first] as Color).darkened(0.1)
	box.add_child(medal)
	box.add_child(_coin_cell(a.title, 28, GOLD, TITLE_FONT))
	box.add_child(_coin_cell(a.about, 15, Color(1, 1, 1, 0.65)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)
	for p in a.players:
		box.add_child(_coin_cell(game.seat_name(p), 30 if a.players.size() < 3 else 24,
				(game.player_colors[p] as Color).lightened(0.25), TITLE_FONT))
	box.add_child(_coin_cell(a.detail, 18, Color.WHITE))
	return tile


func _build_awards_screen() -> void:
	_awards_screen = Control.new()
	_awards_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_awards_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awards_screen.visible = false
	add_child(_awards_screen)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_awards_screen.add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_awards_screen.add_child(box)
	var title := _coin_cell("MATCH AWARDS", 64, GOLD, TITLE_FONT)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	_awards_row = HBoxContainer.new()
	_awards_row.add_theme_constant_override("separation", 18)
	_awards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_awards_row)


# ------------------------------------------------------------ Strike!

## Big STRIKE! in the middle of the screen, in the player's colour.
func show_strike(player: int, color: Color) -> void:
	if _strike == null:
		_strike = Label.new()
		_strike.add_theme_font_override("font", TITLE_FONT)
		_strike.add_theme_font_size_override("font_size", 170)
		_strike.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
		_strike.add_theme_constant_override("outline_size", 28)
		_strike.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
		_strike.add_theme_constant_override("shadow_offset_y", 12)
		_strike.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_strike.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_strike.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_strike)
		_strike_burst = CPUParticles2D.new()
		_strike_burst.emitting = false
		_strike_burst.one_shot = true
		_strike_burst.amount = 90
		_strike_burst.lifetime = 1.4
		_strike_burst.explosiveness = 1.0
		_strike_burst.spread = 180.0
		_strike_burst.initial_velocity_min = 300.0
		_strike_burst.initial_velocity_max = 750.0
		_strike_burst.gravity = Vector2(0, 600)
		_strike_burst.scale_amount_min = 6.0
		_strike_burst.scale_amount_max = 14.0
		add_child(_strike_burst)
	_strike.text = "STRIKE!"
	_strike.add_theme_color_override("font_color", color.lightened(0.35))
	_strike.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	_strike.visible = true
	_strike.modulate.a = 1.0
	_strike.scale = Vector2.ZERO
	_strike.rotation = -0.25
	_strike_burst.position = get_viewport().get_visible_rect().size / 2.0
	_strike_burst.color = color.lightened(0.3)
	_strike_burst.restart()
	_strike_burst.emitting = true
	_strike_left = 2.2
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_strike, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_strike, "rotation", -0.06, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_property(_strike, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func(): _strike.visible = false)
	_strike_player = player


## "ACHIEVEMENT UNLOCKED" card that slides up in the corner for a few
## seconds. Several in a row wait their turn. It sits on its own layer so it
## shows over the closet, the crate screen and menus too.
func show_achievement(entry: Dictionary) -> void:
	_award_queue.append(entry)
	if _award_queue.size() == 1:
		_next_award()


var _award_queue: Array = []
var _award_layer: CanvasLayer


func _next_award() -> void:
	if _award_queue.is_empty():
		return
	var entry: Dictionary = _award_queue[0]
	if _award_layer == null:
		_award_layer = CanvasLayer.new()
		_award_layer.layer = 100
		_award_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_award_layer)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.16, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 14
	style.content_margin_right = 22
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(AchievementIcon.make(entry, false, 72))
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var top := Label.new()
	top.text = "ACHIEVEMENT UNLOCKED"
	top.add_theme_font_size_override("font_size", 15)
	top.add_theme_color_override("font_color", GOLD)
	words.add_child(top)
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_override("font", TITLE_FONT)
	name_label.add_theme_font_size_override("font_size", 28)
	words.add_child(name_label)
	var how := Label.new()
	how.text = entry.text
	how.add_theme_font_size_override("font_size", 15)
	how.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	words.add_child(how)
	_award_layer.add_child(card)
	card.reset_size()
	# Slides up into the bottom right corner, like Steam's own pop-ups.
	var screen := get_viewport().get_visible_rect().size
	card.position = Vector2(screen.x - card.size.x - 24, screen.y + 10)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", screen.y - card.size.y - 24, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(card, "position:y", screen.y + 10, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		card.queue_free()
		_award_queue.pop_front()
		_next_award())


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
		parts.append("%s +%d  (%s)" % [game.seat_name(i), r.points[i], ", ".join(bits)])
	var text := "      ".join(parts)
	if r.note != "":
		text += "\n" + r.note
	return text


func _coins_text(game, whole_match: bool) -> String:
	var parts := []
	for i in game.player_count:
		var got: int = game.match_coins[i] if whole_match else game.coins_earned[i]
		parts.append("%s +%d" % [game.seat_name(i), got])
	return "COINS   " + "      ".join(parts)


func _winner_text(game) -> String:
	var best := -1
	var winners := []
	for i in game.player_count:
		if game.totals[i] > best:
			best = game.totals[i]
			winners = [game.seat_name(i)]
		elif game.totals[i] == best:
			winners.append(game.seat_name(i))
	if winners.size() > 1:
		return "TIE!  %s" % " & ".join(winners)
	return "%s WINS!" % winners[0]


# ------------------------------------------------------------ Strike replay

func _build_replay_bars() -> void:
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bottom)
	_replay_line = ColorRect.new()
	_replay_line.color = REPLAY_RED
	_replay_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bottom.add_child(_replay_line)
	_replay_tag = Label.new()
	_replay_tag.text = "●  REPLAY"
	_replay_tag.add_theme_font_override("font", TITLE_FONT)
	_replay_tag.add_theme_font_size_override("font_size", 34)
	_replay_tag.add_theme_color_override("font_color", REPLAY_RED)
	_replay_tag.position = Vector2(28, 18)
	_bar_top.add_child(_replay_tag)
	_replay_skip = Label.new()
	_replay_skip.text = "Press any key to skip"
	_replay_skip.add_theme_font_size_override("font_size", 16)
	_replay_skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_replay_skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_replay_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_replay_skip.offset_right = -28
	_bar_bottom.add_child(_replay_skip)
	_set_bars(0.0)


## Slide the cinema bars in for the replay and out again afterwards.
func _update_replay(game) -> void:
	var on: bool = game.state == game.State.REPLAY
	var delta := get_process_delta_time()
	_bars = move_toward(_bars, 1.0 if on else 0.0, delta * 4.0)
	_set_bars(_bars)
	if on:
		# The tag blinks like a camera's record light.
		_replay_tag.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6 else 0.35
		_replay_line.size = Vector2(_bar_bottom.size.x * game.replay.progress(), 4)
	# The score chips sit where the top bar goes, so they make way.
	_scores.modulate.a = 1.0 - _bars


func _set_bars(amount: float) -> void:
	var h := BAR_HEIGHT * ease(amount, 0.5)
	_bar_top.visible = amount > 0.0
	_bar_bottom.visible = amount > 0.0
	_bar_top.offset_bottom = h
	_bar_bottom.offset_top = -h
	_replay_tag.visible = amount >= 1.0
	_replay_skip.visible = amount >= 1.0
	_replay_line.visible = amount >= 1.0


# ------------------------------------------------------------ Key hints

func _update_hints(game) -> void:
	var items := []   # [key, action] pairs; "|" separates groups
	match game.state:
		game.State.WAITING:
			items += [[_gk("SPACE"), "Start"], [_gk("V"), "Track"], [_gk("ESC"), "Pause"]]
		game.State.HUB:
			for p in game.local_seats():
				var k := _key_names(game.seat_keys[p])
				var kind: String = game.table_open[p]
				if p < game.hub.marbles.size() and game.hub.plane.pilot == game.hub.marbles[p]:
					items += [[k.move, game.seat_name(p) + " Fly"], [k.confirm, "Boost"], [k.rotate, "Hop out"], "|"]
				elif kind == "derby":
					items += [[k.move, game.seat_name(p) + " Horse/Wager"], [k.confirm, "Bet"], [k.rotate, "Leave"], "|"]
				elif kind == "blackjack":
					items += [[k.move, game.seat_name(p) + " Wager"], [k.confirm, "Deal/Hit"], [k.rotate, "Stand/Leave"], "|"]
				elif kind == "bar":
					items += [[k.move, game.seat_name(p) + " Drink"], [k.confirm, "Order"], [k.rotate, "Leave"], "|"]
				else:
					items += [[k.move, game.seat_name(p) + " Roll"], [k.confirm, "Hop"], "|"]
			items += [[_gk("Z X"), "Camera"], [_gk("ESC"), "Pause"]]
		game.State.DRAFT:
			for p in game.local_seats():
				var k := _key_names(game.seat_keys[p])
				items += [[k.move, game.seat_name(p)], [k.confirm, "Grab"], "|"]
		game.State.BUILD:
			for p in game.local_seats():
				var k := _key_names(game.seat_keys[p])
				var turn := "Turn"
				if PieceCatalog.is_track(game.draft_build.picks[p]):
					turn = "Flip" if PieceCatalog.turns(game.draft_build.picks[p]) else ""
				items += [[k.move, game.seat_name(p)]]
				if turn != "":
					items += [[k.rotate, turn]]
				items += [[k.confirm, "Drop"], "|"]
		game.State.REPLAY:
			pass   # "Press any key to skip" is on the replay bar instead
		game.State.AWARDS:
			items += [[_gk("SPACE"), "Skip"], [_gk("TAB"), "Scores"]]
		game.State.COUNTDOWN, game.State.ROLLING:
			for p in game.local_seats():
				var k := _key_names(game.seat_keys[p])
				items += [[k.move, game.seat_name(p) + " Lean"], [k.confirm, "Hop"], "|"]
			items += [[_gk("ESC"), "Pause"], [_gk("TAB"), "Scores"], [_gk("V"), "Camera"]]
			if not Controls.any_pad():
				items += [["R", "Retry"], ["C", "Bumping " + ("on" if game.marbles_collide else "off")]]
		_:
			var next := "New match" if game.state == game.State.MATCH_OVER else "Next"
			items += [[_gk("SPACE"), next], [_gk("TAB"), "Scores"]]
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
		# Key and word stay together when the row wraps.
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		_hints.add_child(pair)
		var cap := Label.new()
		cap.text = it[0]
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
		cap.add_theme_stylebox_override("normal", _pill(Color(1, 1, 1, 0.88), 7, 1))
		pair.add_child(cap)
		var word := Label.new()
		word.text = it[1]
		word.add_theme_font_size_override("font_size", 14)
		word.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		word.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		word.add_theme_constant_override("outline_size", 4)
		pair.add_child(word)


## Short key names for a player, for the hints.
## A game-wide key, or its controller button if anyone is on a controller.
func _gk(key: String) -> String:
	if not Controls.any_pad():
		return key
	return {"SPACE": "SPACE / Y", "ESC": "ESC / START", "TAB": "TAB / BACK", "V": "V / LB", "Z X": "Z X / R-STICK"}.get(key, key)


static func _key_names(p: int) -> Dictionary:
	if Controls.using_pad[p]:
		return {"move": "L-STICK", "rotate": "X", "confirm": "A"}
	match p:
		0: return {"move": "WASD", "rotate": "Q", "confirm": "SPACE"}
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
	# A chunky retro drop shadow in sign orange.
	l.add_theme_color_override("font_shadow_color", Color(0.93, 0.4, 0.2, 0.9))
	l.add_theme_constant_override("shadow_offset_x", maxi(2, size / 14))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 11))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_END if preset == Control.PRESET_CENTER_TOP else Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l
