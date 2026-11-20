extends SceneTree
## Checks the jungle on the practice island (scripts/jungle.gd):
##   - the bouncy mushrooms throw a marble up onto the tallest cap, where
##     it picks up the gem (and gets coins the first time)
##   - a marble can roll right through the hollow log
##   - every step of the cliff climb can be hopped onto from the one before
##   - falling off near the casino puts you back on the casino island
##   - rolling off a casino plate sends you away from the table
##   godot --headless --fixed-fps 120 --script res://tests/sim_jungle.gd

var game: Node
var hub: Hub
var _t := 0
var _fails := 0
var _coins := 0
var _step := 0
var _step_t := 0
var _climb_done := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _gem(id: int) -> Dictionary:
	for g in hub.jungle._gems:
		if g.id == id:
			return g
	return {}


func _put(m: Marble, at: Vector3, vel := Vector3.ZERO) -> void:
	m.global_position = hub.to_global(at)
	m.linear_velocity = hub.global_basis * vel
	m.angular_velocity = Vector3.ZERO


func _process(_d: float) -> bool:
	_t += 1
	if _t == 2:
		game.settings.player_count = 3
		game._enter_hub()
		hub = game.hub
		# Forget P1's gems so the coins can be checked.
		game.profiles.seats[0].secrets = []
		_coins = game.profiles.coins(0)
		return false
	if _t < 10:
		return false
	var m0: Marble = hub.marbles[0]
	var m1: Marble = hub.marbles[1]
	var m2: Marble = hub.marbles[2]
	if _t == 10:
		_put(m0, Jungle.MUSHROOM_PAD + Vector3(-1.5, 0.4, 0), Vector3(3, 0, 0))
		_put(m1, Jungle.LOG + Vector3(-Jungle.LOG_LENGTH / 2.0 - 2.0, 0.4, 0), Vector3(5, 0, 0))
		var first := hub.jungle._on_ring(Jungle.CLIMB_FROM - 3.5, Jungle.CLIMB_R)
		_put(m2, first + Vector3.UP * 0.4)
	# The climb: from each step, roll at the next one and hop.
	if _t >= 10 and _step < Jungle.CLIMB_COUNT:
		_step_t += 1
		var next := hub.jungle._on_ring(Jungle.CLIMB_FROM + _step * Jungle.CLIMB_STEP, Jungle.CLIMB_R)
		var here := hub.to_local(m2.global_position)
		var to := (next - here) * Vector3(1, 0, 1)
		# Roll at the next step, hop on the way, then brake once landed
		# (like a player letting go of the keys).
		if _step_t == 1:
			m2.linear_velocity = hub.global_basis * (to.normalized() * clampf(to.length() * 1.15, 0.5, 2.6))
		if _step_t == 5:
			m2.request_hop()
		if _step_t == 85:
			m2.linear_velocity = Vector3.ZERO
			m2.angular_velocity = Vector3.ZERO
		if _step_t == 110:
			var top := Jungle.STEP_H * (_step + 1)
			var on := absf(here.y - (top + 0.3)) < 0.2 and to.length() < 1.45
			if not on or _step == Jungle.CLIMB_COUNT - 1:
				check("climb step %d of %d (marble at height %.2f, step top %.2f)" % [_step + 1, Jungle.CLIMB_COUNT, here.y - 0.3, top], on)
			if not on:
				_step = Jungle.CLIMB_COUNT
			_step += 1
			_step_t = 0
			if on and _step == Jungle.CLIMB_COUNT:
				# Roll from the top step onto the ledge, to the gem.
				var gem: Vector3 = _gem(0).at
				m2.linear_velocity = hub.global_basis * ((gem - here) * Vector3(1, 0, 1)).normalized() * 2.5
	if _step == Jungle.CLIMB_COUNT and _step_t == 0:
		_step_t = -1
		_climb_done = _t
	if _climb_done > 0 and _t == _climb_done + 480:
		check("rolled along the sky ledge and picked up its gem", _gem(0).taken)
	if _t == 10 + 120 * 4:
		var cap: Vector3 = Jungle.CAPS[Jungle.CAPS.size() - 1][0]
		var at := hub.to_local(m0.global_position)
		check("mushrooms throw you up to the top cap (at %s)" % at.snapped(Vector3.ONE * 0.1), at.y > cap.y - 0.2 and Vector2(at.x - cap.x, at.z - cap.z).length() < 2.0)
		check("the mushroom-top gem was picked up", _gem(1).taken)
		check("first find pays %d coins (%d -> %d)" % [Hub.SECRET_COINS, _coins, game.profiles.coins(0)], game.profiles.coins(0) == _coins + Hub.SECRET_COINS)
		var at1 := hub.to_local(m1.global_position)
		check("rolled through the hollow log (at %s)" % at1.snapped(Vector3.ONE * 0.1), at1.x > Jungle.LOG.x + Jungle.LOG_LENGTH / 2.0)
		check("the gem inside the log was picked up", _gem(3).taken)
		# Fall off by the casino.
		_put(m1, hub.casino.position + hub.casino.basis * Vector3(CasinoIsland.RADIUS + 2.0, -10.0, 0))
	if _t == 10 + 120 * 5:
		var d := hub.to_local(m1.global_position).distance_to(hub.casino.position)
		check("falling off by the casino puts you back there (%.0f m from its middle)" % d, d < CasinoIsland.RADIUS)
		# Onto the bar plate, then roll off.
		_put(m1, hub.casino.transform * CasinoIsland.BAR_PLATE + Vector3.UP * 0.4)
	if _t == 10 + 120 * 6:
		check("bar plate opens the bar", game.table_open[1] == "bar")
		game.table_open[1] = ""
		hub.release_from_plate(1)
	if _t == 10 + 120 * 7:
		var local := hub.casino.to_local(m1.global_position)
		check("leaving the bar rolls you away from the counter (%s)" % local.snapped(Vector3.ONE * 0.1), local.z > CasinoIsland.BAR_PLATE.z + 1.0)
	if _t > 10 + 120 * 7 and _step >= Jungle.CLIMB_COUNT and (_climb_done == 0 or _t > _climb_done + 480):
		print("FAILED: %d" % _fails if _fails else "ALL PASSED")
		quit(1 if _fails else 0)
		return true
	return false
