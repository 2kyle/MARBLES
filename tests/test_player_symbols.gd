extends SceneTree
## PLAYER SYMBOLS (colour-blind friendly): every seat has its own shape,
## the shapes really look different, they show on the marbles and the
## score chips during a match, and switching the setting off hides them.
##   godot --headless --script res://tests/test_player_symbols.gd

var game: Node
var _t := 0
var _fails := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


## The shape's picture as a grid of on/off (for comparing shapes).
func _mask(seat: int) -> PackedByteArray:
	var img := PlayerSymbols.texture(seat).get_image()
	var out := PackedByteArray()
	for y in img.get_height():
		for x in img.get_width():
			out.append(1 if img.get_pixel(x, y).a > 0.5 else 0)
	return out


func _process(_d: float) -> bool:
	_t += 1
	if game.state == game.State.MENU:
		game.settings.player_count = 2
		game.settings.bot_count = 2
		game._on_play_requested()
	if _t == 5:
		var shapes := {}
		for p in 4:
			shapes[PlayerSymbols.shape_for(p)] = true
		_check(shapes.size() == 4, "four players get four different shapes")
		var masks := []
		for p in 4:
			masks.append(_mask(p))
		var all_differ := true
		for a in 4:
			for b in range(a + 1, 4):
				var diff := 0
				for i in masks[a].size():
					if masks[a][i] != masks[b][i]:
						diff += 1
				if diff < 150:
					all_differ = false
					print("  %s vs %s: only %d pixels differ" % [PlayerSymbols.name_for(a), PlayerSymbols.name_for(b), diff])
		_check(all_differ, "every shape's picture is clearly different from the others")
		var img := PlayerSymbols.texture(0).get_image()
		var mid := img.get_pixel(32, 32)
		var corner := img.get_pixel(1, 1)
		_check(mid.a > 0.9 and mid.v > 0.9 and corner.a < 0.05, "shapes are white in the middle and see-through round the edge")
		_check(PlayerSymbols.texture(2) == PlayerSymbols.texture(2), "pictures are made once and reused")
		var l := Label.new()
		l.text = "P1"
		root.add_child(l)
		PlayerSymbols.mark(l, 0, true)
		var icon := l.get_node_or_null("Symbol") as TextureRect
		_check(icon != null and icon.visible, "a label gets the shape in front of its words")
		PlayerSymbols.mark(l, 0, false)
		_check(icon != null and not icon.visible, "and loses it when symbols are off")
		l.queue_free()
		_check(not game.settings.player_symbols, "PLAYER SYMBOLS starts off")
		# Switch it on the way the Settings page does.
		game.settings.player_symbols = true
		game.menu.settings_changed.emit()
		_check(PlayerSymbols.enabled, "turning the setting on turns the symbols on")
	if _t == 30:
		# Fresh marbles at the gate, as at the start of a roll.
		game.state = game.State.ROLLING
		game._prepare_roll()
	if _t == 60:
		var badges := 0
		for m in game.marbles:
			var b := (m as Marble).get_node_or_null("SymbolBadge") as Sprite3D
			if b and b.visible and b.texture == PlayerSymbols.texture(m.player_id):
				badges += 1
		_check(game.marbles.size() > 0 and badges == game.marbles.size(),
				"every marble (people and bots) has its own shape floating over it: %d of %d" % [badges, game.marbles.size()])
		var chips: Node = game.hud._scores
		var marked := 0
		for i in game.player_count:
			var name: Label = chips.get_child(i).get_child(0).get_child(0)
			var icon := name.get_node_or_null("Symbol") as TextureRect
			if icon and icon.visible and icon.texture == PlayerSymbols.texture(i):
				marked += 1
		_check(marked == game.player_count, "every score chip shows its player's shape: %d of %d" % [marked, game.player_count])
		game.settings.player_symbols = false
		game.menu.settings_changed.emit()
	if _t == 70:
		var hidden := true
		for m in game.marbles:
			var b := (m as Marble).get_node_or_null("SymbolBadge") as Sprite3D
			if b and b.visible:
				hidden = false
		var name: Label = game.hud._scores.get_child(0).get_child(0).get_child(0)
		var icon := name.get_node_or_null("Symbol") as TextureRect
		_check(hidden and (icon == null or not icon.visible), "turning the setting off hides them all again")
		print("ALL PASSED" if _fails == 0 else "%d player symbol checks FAILED" % _fails)
		quit(1 if _fails > 0 else 0)
	return false
