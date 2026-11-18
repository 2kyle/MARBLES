class_name Hud
extends CanvasLayer
## On-screen scoreboard and messages. Only reads game state, never changes it.
## Kept small and pushed to the screen edges so the lane stays visible.

const PANEL_BG := Color(0, 0, 0, 0.5)

var thumbnails: Thumbnails

var _top: Label
var _scores: VBoxContainer
var _center: Label
var _help: Label
var _phase: Label          # "DRAFT 12s" / "BUILD 24s" box, top right
var _cards_box: VBoxContainer
var _cards: Array = []     # one Dictionary per crate slot
var _crate_shown: Array = []


func _ready() -> void:
	_top = _make_label(20, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_top.grow_vertical = Control.GROW_DIRECTION_END
	_top.offset_top = 10

	_scores = VBoxContainer.new()
	_scores.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_scores.offset_left = 14
	_scores.offset_top = 10
	add_child(_scores)

	_center = _make_label(28, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_center.offset_bottom = -70
	_center.add_theme_stylebox_override("normal", _panel_style(16))

	_phase = _make_label(18, Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_LEFT)
	_phase.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_phase.grow_vertical = Control.GROW_DIRECTION_END
	_phase.offset_right = -14
	_phase.offset_top = 10
	_phase.add_theme_stylebox_override("normal", _panel_style(10))

	_help = _make_label(14, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_help.grow_horizontal = Control.GROW_DIRECTION_END
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_left = 14
	_help.offset_bottom = -10
	_help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 6)
	_cards_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_cards_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cards_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cards_box.offset_right = -14
	add_child(_cards_box)


func refresh(game) -> void:
	var rolling_ish: bool = game.state in [game.State.COUNTDOWN, game.State.ROLLING,
			game.State.RESULTS, game.State.MATCH_OVER]
	_top.text = "Frame %d / %d" % [game.frame, game.frames_per_match]
	if rolling_ish:
		_top.text += "    Pins standing %d / %d" % [game.rack.standing_count(), game.rack.pin_count()]
	if game.state == game.State.ROLLING:
		_top.text += "    %ds" % ceili(game.time_left())

	var lines := []
	for i in game.player_count:
		var tag := ""
		if game.state == game.State.ROLLING or game.state == game.State.RESULTS:
			var m: Marble = game.marbles[i]
			if m.out:
				tag = "  out"
			elif m.arrived:
				tag = "  #%d at pins" % (game.arrival_order.find(i) + 1)
		lines.append("P%d  %d%s" % [i + 1, game.totals[i], tag])
	while _scores.get_child_count() < lines.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		_scores.add_child(l)
	for i in lines.size():
		var l: Label = _scores.get_child(i)
		l.text = lines[i]
		l.add_theme_color_override("font_color", game.PLAYER_COLORS[i].lightened(0.3))

	_phase.text = ""
	_center.text = ""
	match game.state:
		game.State.WAITING:
			_center.text = "Press Space to start"
		game.State.DRAFT:
			_phase.text = _draft_status(game)
		game.State.BUILD:
			_phase.text = _build_status(game)
		game.State.COUNTDOWN:
			_center.text = str(game.countdown_value())
		game.State.RESULTS:
			_center.text = _results_text(game) + "\nSpace: next frame"
		game.State.MATCH_OVER:
			_center.text = _results_text(game) + "\n" + _winner_text(game) \
					+ "\nSpace: play again"
	_center.visible = _center.text != ""
	_phase.visible = _phase.text != ""

	_update_cards(game)
	_help.text = _help_text(game)


# ------------------------------------------------------------ Draft cards

func _update_cards(game) -> void:
	var db: DraftBuild = game.draft_build
	var show: bool = game.state == game.State.DRAFT
	_cards_box.visible = show
	if not show:
		return
	if _crate_shown != db.crate:
		_build_cards(db.crate)
	for slot in _cards.size():
		var card: Dictionary = _cards[slot]
		var owner: int = db.taken_by[slot]
		var hovering := []
		for p in game.player_count:
			if db.picks[p] == "" and db.draft_cursor[p] == slot:
				hovering.append(p)
		var style: StyleBoxFlat = card.style
		if owner != -1:
			style.border_color = game.PLAYER_COLORS[owner]
			card.panel.modulate = Color(1, 1, 1, 0.45)
			card.tag.text = "P%d" % (owner + 1)
		elif hovering.size() > 0:
			style.border_color = game.PLAYER_COLORS[hovering[0]]
			card.panel.modulate = Color.WHITE
			var tags := []
			for p in hovering:
				tags.append("P%d" % (p + 1))
			card.tag.text = " ".join(tags)
		else:
			style.border_color = Color(1, 1, 1, 0.15)
			card.panel.modulate = Color(1, 1, 1, 0.85)
			card.tag.text = ""


func _build_cards(crate: Array) -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	_cards.clear()
	_crate_shown = crate.duplicate()
	var size := 92 if crate.size() <= 4 else 72
	for id in crate:
		var panel := PanelContainer.new()
		var style := _panel_style(4)
		style.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var pic := TextureRect.new()
		pic.custom_minimum_size = Vector2(size, size)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if thumbnails:
			pic.texture = thumbnails.texture_for(id)
		row.add_child(pic)
		var words := VBoxContainer.new()
		words.alignment = BoxContainer.ALIGNMENT_CENTER
		words.custom_minimum_size = Vector2(130, 0)
		row.add_child(words)
		var name_label := Label.new()
		name_label.text = PieceCatalog.display_name(id)
		name_label.add_theme_font_size_override("font_size", 16)
		words.add_child(name_label)
		var about := Label.new()
		about.text = PieceCatalog.info(id).about
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(130, 0)
		about.add_theme_font_size_override("font_size", 11)
		about.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		words.add_child(about)
		var tag := Label.new()
		tag.add_theme_font_size_override("font_size", 14)
		words.add_child(tag)
		_cards_box.add_child(panel)
		_cards.append({"panel": panel, "style": style, "tag": tag})


# ------------------------------------------------------------ Status text

func _draft_status(game) -> String:
	var db: DraftBuild = game.draft_build
	var lines := ["DRAFT  %ds" % game.phase_time_left()]
	for p in game.player_count:
		var s: String = PieceCatalog.display_name(db.picks[p]) if db.picks[p] != "" else "choosing..."
		if db.message[p] != "":
			s = db.message[p]
		lines.append("P%d  %s" % [p + 1, s])
	return "\n".join(lines)


func _build_status(game) -> String:
	var db: DraftBuild = game.draft_build
	var lines := ["BUILD  %ds" % game.phase_time_left()]
	for p in game.player_count:
		var piece := PieceCatalog.display_name(db.picks[p])
		var s := "done" if db.has_placed[p] else ("can't go here" if db.cursor_blocked(p) else "placing")
		lines.append("P%d  %s  %s" % [p + 1, piece, s])
	return "\n".join(lines)


func _help_text(game) -> String:
	match game.state:
		game.State.DRAFT:
			return "P1: W/S choose, E grab      P2: Up/Down choose, Enter grab"
		game.State.BUILD:
			return "P1: WASD move, Q turn, E drop      P2: arrows move, Right Shift turn, Enter drop"
		game.State.COUNTDOWN, game.State.ROLLING:
			return "Lean: P1 WASD, P2 arrows      R re-roll   C collision %s   V camera" \
					% ("on" if game.marbles_collide else "off")
	return "Space next   R re-roll   C collision %s   V camera   Esc quit" \
			% ("on" if game.marbles_collide else "off")


func _results_text(game) -> String:
	var r: Dictionary = game.last_result
	if r.is_empty():
		return ""
	var lines := ["Frame %d" % game.frame]
	for i in game.player_count:
		var parts := ["%d pin%s" % [r.pins[i], "" if r.pins[i] == 1 else "s"]]
		if r.race[i] > 0:
			parts.append("+%d race" % r.race[i])
		if r.sweep[i] > 0:
			parts.append("+%d sweep" % r.sweep[i])
		if r.knockouts[i] > 0:
			parts.append("+%d knockout" % r.knockouts[i])
		lines.append("P%d  +%d  (%s)" % [i + 1, r.points[i], ", ".join(parts)])
	if r.note != "":
		lines.append(r.note)
	return "\n".join(lines)


func _winner_text(game) -> String:
	var best := -1
	var winners := []
	for i in game.player_count:
		if game.totals[i] > best:
			best = game.totals[i]
			winners = [game.PLAYER_NAMES[i]]
		elif game.totals[i] == best:
			winners.append(game.PLAYER_NAMES[i])
	if winners.size() > 1:
		return "Tie between %s with %d!" % [" and ".join(winners), best]
	return "%s wins with %d!" % [winners[0], best]


# ------------------------------------------------------------ Helpers

func _panel_style(margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.set_corner_radius_all(8)
	s.set_content_margin_all(margin)
	return s


func _make_label(size: int, preset: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l
