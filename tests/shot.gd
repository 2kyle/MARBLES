extends SceneTree
## Screenshot helper (not part of the game). Usage:
##   godot --script res://tests/shot.gd -- <out.png> <mode> [arg]
var game: Node
var _t := 0
var out := "user://shot.png"
var mode := "match"
var arg := ""
var arg2 := ""
## Frame to take the picture on (later for screens that animate in).
var shot_at := 90

func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: mode = a[1]
	if a.size() > 2: arg = a[2]
	if a.size() > 3: arg2 = a[3]
	if mode == "awards": shot_at = 360
	if mode == "wild": shot_at = 12
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.settings.graphics_auto = false   # software drawing is slow; keep the look fixed

func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		_setup()
	if _t > 3 and _t < shot_at:
		_tick()
	if _t == shot_at:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		return true
	return false

func _setup() -> void:
	# SYMBOLS=1 in front of the command turns PLAYER SYMBOLS on for the picture.
	if OS.get_environment("SYMBOLS") == "1":
		game.settings.player_symbols = true
		PlayerSymbols.enabled = true
	match mode:
		"title":
			if arg != "":
				game.force_theme = arg
				game._new_match()
				game.show_title()
		"match", "roll", "end", "draft", "return", "build", "podium", "awards", "wild":
			game.force_theme = arg
			game.settings.player_count = 2
			game.settings.bot_count = 2
			game._setup_local_seats()
			game._new_match()
			game.menu.close()
		"howto":
			# The HOW TO PLAY pop-up over a match; arg = step (0, 1 or 2).
			game.settings.player_count = 2
			game.settings.bot_count = 2
			game._setup_local_seats()
			game._new_match()
			game.menu.open_how_to_play()
			for i in int(arg):
				game.menu._howto_go(1)
		"hub", "casino", "crate", "bar":
			game.settings.player_count = 2 if mode == "casino" else 1
			game._enter_hub()

var _cam_done := false
func _tick() -> void:
	match mode:
		"roll":
			if _t == 4:
				game._start_countdown()
		"end":
			if _t == 4:
				game.state = game.State.ROLLING
				for m in game.marbles:
					m.arrived = true
					m.freeze = true
					m.global_position = game.deck.to_global(Vector3(0, -2.4, -14 - m.player_id))
			if _t == 5:
				game.camera.snap_to(game.camera.target)
		"draft":
			if _t == 4:
				game._start_draft()
		"wild":
			# A WILD FRAME's splash as its draft starts (arg2 = rule id).
			if _t == 4:
				game.frame = 3
				game._prepare_roll()
				if arg2 != "":
					game.wild = arg2
				game._start_draft()
		"podium":
			if _t == 4:
				game.frame = game.frames_per_match
				game.totals = [40, 12, 77, 3]
				game.match_pins = [30, 10, 60, 3]
				game.match_bonus = [10, 2, 17, 0]
				game.state = game.State.MATCH_OVER
				game.coin_breakdown = Scoring.match_coins(game.match_pins, game.match_bonus, game.totals)
				game._show_podium()
			if _t == 6:
				game.camera.snap_to(game.camera.target)
			# arg2: seconds into the podium to show ("" = everyone landed,
			# "coins" = the coins screen).
			if arg2 == "":
				game.podium.age = 4.0
			elif arg2 == "coins":
				game.podium.age = 10.0
		"awards":
			# The MATCH AWARDS screen at the end of a match.
			if _t == 4:
				game.frame = game.frames_per_match
				game.totals = [40, 12, 77, 3]
				var st: MatchAwards = game.match_stats
				st.record_frame([10, 3, 7, 1], 0, {0: 13.8, 2: 11.2})
				st.record_frame([10, 2, 9, 0], 0, {0: 12.9})
				st.record_frame([4, 1, 10, 0], 2, {2: 10.6})
				st.record_blast(1, 3)
				game.awards = st.results(game.player_count)
				game.state = game.State.MATCH_OVER
				game._start_awards()
				game.awards_left = 999.0   # hold it for the picture
		"build":
			if _t == 4:
				game._start_draft()
			if _t == 6:
				game._start_build()
		"return":
			# Look along the bowling end: lane, gutters, pit and ball return.
			if _t == 4:
				game.state = game.State.ROLLING
				for m in game.marbles:
					m.freeze = false
					m.visible = true
					m.global_position = game.deck.to_global(Vector3(m.player_id - 0.5, 0.5, -15))
			if _t >= 4:
				game.camera.set_process(false)
				game.camera.set_physics_process(false)
				game.camera.global_position = game.deck.to_global(Vector3(-3.5, 4.5, 6.0))
				game.camera.look_at(game.deck.to_global(Vector3(1.0, 0.0, -9.0)))
		"casino", "bar":
			var hub: Hub = game.hub
			if _t == 5:
				var at: Vector3 = hub.casino._seat(1) if mode == "casino" else CasinoIsland.BAR_PLATE
				hub.marbles[0].global_position = hub.casino.to_global(at + Vector3(0, 0.4, 0))
				hub.marbles[0].linear_velocity = Vector3.ZERO
				if mode == "casino":
					hub.marbles[1].global_position = hub.casino.to_global(hub.casino._seat(2) + Vector3(0, 0.4, 0))
			if _t == 30:
				game.profiles.add_coins(0, 100)
				if mode == "casino":
					hub.casino.blackjack.request_confirm(0)
				else:
					hub.casino.request_drink(0, hub.marbles[0])
			if _t >= 6:
				game.camera.set_process(false)
				game.camera.set_physics_process(false)
				var look: Vector3 = hub.casino.to_global(CasinoIsland.TABLE_POS if mode == "casino" else CasinoIsland.BAR_PLATE)
				var eye: Vector3 = look + hub.casino.global_basis * ((Vector3(0, 3.0, 3.2) if arg == "zoom" else Vector3(0, 5.5, 8.5)) if mode == "casino" else Vector3(-7, 4.5, 6))
				game.camera.global_position = eye
				game.camera.look_at(look + Vector3(0, 1, 0))
		"crate":
			var hub: Hub = game.hub
			if _t == 5:
				game.profiles.add_coins(0, 300)
				hub.marbles[0].global_position = hub.casino.to_global(CasinoIsland.CRATE_PLATE + Vector3(0, 0.4, 0))
				hub.marbles[0].linear_velocity = Vector3.ZERO
			if _t == 40 and game.crate_screen.is_open():
				game.crate_screen.request_confirm()
