extends SceneTree
## Rolls a marble at things on the islands that should be solid (benches,
## arches, the windmill, casino furniture) and checks it bounces off
## instead of rolling straight through.
##   godot --headless --fixed-fps 120 --script res://tests/sim_solid.gd

var game: Node
var hub: Hub
var _t := 0
var _fails := 0
var _case := -1
var _case_t := 0

## [name, start (hub space, or casino space if "casino"), direction, distance to the thing, space]
var cases := [
	["bench", Vector3(-5, 0.4, 20.2), Vector3.FORWARD, 1.4, "hub"],
	["customize arch post", Vector3(-6.2, 0.4, 3.5), Vector3.BACK, 4.2, "hub"],
	["windmill", Vector3(-17, 0.4, -19.0), Vector3.FORWARD, 4.0, "hub"],
	["slot machine", Vector3(-3.0, 0.4, CasinoIsland.HALF.y - 4.5), Vector3.BACK, 3.3, "casino"],
	["bar counter", Vector3(CasinoIsland.BAR_PLATE.x + 3.0, 0.4, CasinoIsland.BAR_PLATE.z), Vector3.FORWARD, 2.4, "casino"],
	["roulette table", Vector3(CasinoIsland.ROULETTE_POS.x, 0.4, CasinoIsland.ROULETTE_POS.z + 4.0), Vector3.FORWARD, 4.0, "casino"],
]


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 2:
		game.settings.player_count = 1
		game._enter_hub()
		hub = game.hub
	if _t < 10:
		return false
	var m: Marble = hub.marbles[0]
	if _case == -1 or _case_t > 240:
		if _case >= 0:
			_check(m)
		_case += 1
		_case_t = 0
		if _case >= cases.size():
			print("All solid tests passed" if _fails == 0 else "%d FAILED" % _fails)
			return true
		var c: Array = cases[_case]
		var space: Node3D = hub.casino if c[4] == "casino" else hub
		m.global_position = space.to_global(c[1])
		m.linear_velocity = space.global_basis * (c[2] * 6.0)
		m.angular_velocity = Vector3.ZERO
	_case_t += 1
	return false


func _check(m: Marble) -> void:
	var c: Array = cases[_case]
	var space: Node3D = hub.casino if c[4] == "casino" else hub
	var moved: float = (space.to_local(m.global_position) - c[1]).dot(c[2])
	var ok: bool = moved < c[3]
	print(("  ok    " if ok else "  FAIL  ") + "%s stops the marble (went %.1f m, it's %.1f m away)" % [c[0], moved, c[3]])
	if not ok:
		_fails += 1
