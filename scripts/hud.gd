class_name Hud
extends CanvasLayer
## On-screen scoreboard and messages. Only reads game state, never changes it.

var _top: Label
var _scores: Label
var _center: Label
var _help: Label
var _side: Label


func _ready() -> void:
	_top = _make_label(28, Control.PRESET_CENTER_TOP, HORIZONTAL_ALIGNMENT_CENTER)
	_top.grow_vertical = Control.GROW_DIRECTION_END
	_top.position.y = 16
	_scores = _make_label(24, Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_scores.grow_horizontal = Control.GROW_DIRECTION_END
	_scores.grow_vertical = Control.GROW_DIRECTION_END
	_scores.position = Vector2(24, 16)
	_center = _make_label(36, Control.PRESET_CENTER_BOTTOM, HORIZONTAL_ALIGNMENT_CENTER)
	_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_center.offset_bottom = -110
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.55)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(20)
	_center.add_theme_stylebox_override("normal", panel)
	_side = _make_label(24, Control.PRESET_CENTER_RIGHT, HORIZONTAL_ALIGNMENT_LEFT)
	_side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_side.offset_right = -24
	var side_panel := StyleBoxFlat.new()
	side_panel.bg_color = Color(0, 0, 0, 0.55)
	side_panel.set_corner_radius_all(12)
	side_panel.set_content_margin_all(18)
	_side.add_theme_stylebox_override("normal", side_panel)
	_help = _make_label(18, Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT)
	_help.grow_horizontal = Control.GROW_DIRECTION_END
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_left = 24
	_help.offset_bottom = -24


func refresh(game) -> void:
	var standing: int = game.rack.standing_count()
	var total: int = game.rack.pin_count()
	_top.text = "Frame %d / %d     Pins standing: %d / %d" % [
			game.frame, game.frames_per_match, standing, total]
	if game.state == game.State.ROLLING:
		_top.text += "     Time: %d" % ceili(game.time_left())

	var lines := []
	for i in game.player_count:
		var tag := ""
		if game.state == game.State.ROLLING or game.state == game.State.RESULTS:
			var m: Marble = game.marbles[i]
			if m.out:
				tag = "  (out)"
			elif m.arrived:
				tag = "  (reached pins #%d)" % (game.arrival_order.find(i) + 1)
		lines.append("%s: %d%s" % [game.PLAYER_NAMES[i], game.totals[i], tag])
	_scores.text = "\n".join(lines)

	_side.text = ""
	match game.state:
		game.State.WAITING:
			_center.text = "Press Space to start the first frame"
		game.State.DRAFT:
			_center.text = ""
			_side.text = _draft_text(game)
		game.State.BUILD:
			_center.text = ""
			_side.text = _build_text(game)
		game.State.COUNTDOWN:
			_center.text = str(game.countdown_value())
		game.State.ROLLING:
			_center.text = ""
		game.State.RESULTS:
			_center.text = _results_text(game) + "\n\nPress Space for the next frame"
		game.State.MATCH_OVER:
			_center.text = _results_text(game) + "\n\n" + _winner_text(game) \
					+ "\nPress Space to play again"
	_center.visible = _center.text != ""
	_side.visible = _side.text != ""

	_help.text = ("Rolling: P1 leans with W A S D, P2 with the arrow keys\n"
			+ "Space: next    R: re-roll this frame    C: marble collision %s    V: camera    Esc: quit") \
			% ("ON" if game.marbles_collide else "OFF")


func _draft_text(game) -> String:
	var db: DraftBuild = game.draft_build
	var lines := ["DRAFT   %ds" % game.phase_time_left(), "Everyone grab one piece!", ""]
	for slot in db.crate.size():
		var line := "  " + PieceCatalog.display_name(db.crate[slot])
		if db.taken_by[slot] != -1:
			line += "   [taken by P%d]" % (db.taken_by[slot] + 1)
		for p in game.player_count:
			if db.picks[p] == "" and db.draft_cursor[p] == slot:
				line += "   < P%d" % (p + 1)
		lines.append(line)
	lines.append("")
	for p in game.player_count:
		var status: String = PieceCatalog.display_name(db.picks[p]) if db.picks[p] != "" else _draft_keys(p)
		if db.message[p] != "":
			status = db.message[p]
		lines.append("P%d: %s" % [p + 1, status])
	return "\n".join(lines)


func _build_text(game) -> String:
	var db: DraftBuild = game.draft_build
	var lines := ["BUILD   %ds" % game.phase_time_left(), "Place your piece on the lane", ""]
	for p in game.player_count:
		var piece := PieceCatalog.display_name(db.picks[p])
		var status := "placed" if db.has_placed[p] else Controls.describe(p)
		if db.message[p] != "" and not db.has_placed[p]:
			status = db.message[p]
		lines.append("P%d %s: %s" % [p + 1, piece, status])
	return "\n".join(lines)


func _draft_keys(p: int) -> String:
	match p:
		0: return "W / S choose, E grab"
		1: return "Up / Down choose, Enter grab"
		2: return "I / K choose, O grab"
		_: return "Num 8 / 5 choose, Num 9 grab"


func _results_text(game) -> String:
	var r: Dictionary = game.last_result
	if r.is_empty():
		return ""
	var lines := ["Frame %d results" % game.frame]
	for i in game.player_count:
		var parts := ["%d pin%s" % [r.pins[i], "" if r.pins[i] == 1 else "s"]]
		if r.race[i] > 0:
			parts.append("+%d race" % r.race[i])
		if r.sweep[i] > 0:
			parts.append("+%d sweep" % r.sweep[i])
		if r.knockouts[i] > 0:
			parts.append("+%d knockout" % r.knockouts[i])
		lines.append("%s: %d  (%s)" % [game.PLAYER_NAMES[i], r.points[i], ", ".join(parts)])
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


func _make_label(size: int, preset: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = align
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l
