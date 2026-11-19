extends SceneTree
## Checks the practice island: the practice run sends you back to the top,
## the plaza lift takes you up, the Customize plate opens Customize, and the
## PLAY arch starts a match.
##   godot --headless --fixed-fps 120 --script res://tests/sim_hub.gd

var game: Node
var _ticks := 0
var _last_y := {}
var _lowest_d := {}
var _done := false
var _coins_crate := 0
var _coins_before := 0


func _initialize() -> void:
	# Keep test achievements out of the real save file.
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 2:
		game.settings.player_count = 4
		game._enter_hub()
		var hub: Hub = game.hub
		var run: Track = hub._course
		print("hub state: ", game.state == game.State.HUB, "  marbles: ", hub.marbles.size())
		print("run length %.1f m, top y %.1f, end y %.1f" % [run.length(),
				run.frame_at(0.0).origin.y, run.end_transform().origin.y])
	if _ticks < 30:
		return false
	var hub: Hub = game.hub
	if _ticks == 30:
		# P1 starts at the top of the run, P2 drives onto the lift,
		# P3 onto the Customize plate.
		var m0: Marble = hub.marbles[0]
		m0.global_position = hub._top.global_position + Vector3.UP * 0.4
		m0.linear_velocity = -hub._top.global_basis.z * 1.0
		hub.marbles[1].global_position = hub.to_global(Hub.LIFT_POS + Vector3(0, 0.4, 2.0))
		hub.marbles[1].linear_velocity = hub.global_basis.z * -3.0
		hub.marbles[2].global_position = hub.to_global(Hub.PLATE_POS + Vector3(0, 0.4, 2.0))
		hub.marbles[2].linear_velocity = hub.global_basis.z * -3.0
		# P4 onto the Marble Derby betting plate.
		hub.marbles[3].global_position = hub.to_global(Hub.BET_PLATE_POS + Vector3(0, 0.4, 2.0))
		hub.marbles[3].linear_velocity = hub.global_basis.z * -3.0
		print("derby odds: ", hub.derby.odds)
	if _ticks > 30 and game.state == game.State.HUB:
		var run: Track = hub._course
		for m in hub.marbles:
			var p: int = m.player_id
			var y: float = m.global_position.y
			if _last_y.has(p) and y - _last_y[p] > 3.0:
				print("  P%d jumped up %.1f m at %.1fs (teleport)" % [p + 1, y - _last_y[p], _ticks / 120.0])
			_last_y[p] = y
			if p == 0:
				var d: float = run.distance_of(m.global_position)
				if _ticks % 120 == 0:
					print("  P1 t=%.0fs d=%.1f pos=%s" % [_ticks / 120.0, d, hub.to_local(m.global_position).snapped(Vector3.ONE * 0.1)])
				# Hop the gap like a player would.
				if run.in_gap(d + 1.2, 0.0):
					m.request_hop()
		if _ticks == 240:
			print("closet open for P%d, plate: %s" % [game.closet.player + 1, hub.on_plate])
			var closet: Closet = game.closet
			closet.request_move(Vector2i(0, -1))   # up to the tabs
			closet.request_move(Vector2i(1, 0))    # BALL COLOR tab
			closet.request_move(Vector2i(0, 1))    # back into the cards
			closet.request_move(Vector2i(1, 0))    # next colour (a starter, owned)
			closet.request_confirm()
			print("closet tab %d card %d -> P3 colour now %s" % [closet.tab, closet.index, game.profiles.equipped(2, "color")])
			closet.request_move(Vector2i(0, 1))
			closet.request_move(Vector2i(0, 1))
			closet.request_confirm()   # a locked one: shouldn't equip
			print("locked try: still %s" % game.profiles.equipped(2, "color"))
			game._close_closet()
			print("after close: open=%s P3 frozen: %s" % [game.closet.is_open(), hub.marbles[2].freeze])
			# Then P3 heads for the loot crates.
			game.profiles.add_coins(2, 300)
			hub.marbles[2].global_position = hub.to_global(Hub.CRATE_POS + Vector3(0, 0.4, 2.0))
			hub.marbles[2].linear_velocity = hub.global_basis.z * -3.0
		if _ticks == 420:
			print("crates open for P%d" % (game.crate_screen.player + 1))
			_coins_crate = game.profiles.coins(2)
			game.crate_screen.request_confirm()
			print("  shaking: ", game.crate_screen.busy(), "  coins %d -> %d" % [_coins_crate, game.profiles.coins(2)])
		if _ticks == 420 + 240:
			var prize: Dictionary = game.crate_screen.prize
			print("  prize: ", prize.get("kind"), " ", prize.get("item", {}).get("name", prize.get("amount", "")),
					" (%s) duplicate=%s" % [prize.get("rarity"), prize.get("duplicate")])
			game._close_crates()
			print("  crate closed: ", not game.crate_screen.is_open())
		if _ticks == 200:
			print("derby open: ", game.derby_open)
			_coins_before = game.profiles.coins(3)
			hub.derby.request_pick(3, 2)
			hub.derby.request_wager(3, 2)
			hub.derby.request_bet(3)
			print("bet: ", hub.derby.bets, "  ", hub.derby.message[3], "  coins %d -> %d" % [_coins_before, game.profiles.coins(3)])
		if _ticks % 240 == 0 and _ticks < 120 * 28:
			print("  derby: ", hub.derby.status(), "  progress ", hub.derby.progress.map(func(x): return snappedf(x, 0.1)))
		if _ticks == 120 * 28:
			print("derby result: winner %d, P4 says '%s', coins %d -> %d" % [hub.derby.winner + 1, hub.derby.message[3], _coins_before, game.profiles.coins(3)])
			game.derby_open[3] = false
			hub.release_from_plate(3)
		if _ticks == 120 * 30:
			var m3: Marble = hub.marbles[3]
			m3.global_position = hub.to_global(Hub.PORTAL_POS + Vector3(0, 0.4, -1.5))
			m3.linear_velocity = hub.global_basis.z * 4.0
	if _ticks > 120 * 31 and not _done:
		_done = true
		print("after PLAY arch: state WAITING = ", game.state == game.State.WAITING, ", hub visible = ", hub.visible)
		return true
	return false
