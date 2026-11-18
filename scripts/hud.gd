class_name Hud
extends CanvasLayer
## On-screen scoreboard and messages. Only reads game state, never changes it.

var _top: Label
var _scores: Label
var _center: Label
var _help: Label


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

	match game.state:
		game.State.WAITING:
			_center.text = "Press Space to roll"
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

	_help.text = ("P1: W A S D    P2: arrow keys    lean your marble\n"
			+ "Space: roll    R: reset frame    C: marble collision %s    V: camera    Esc: quit") \
			% ("ON" if game.marbles_collide else "OFF")


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
