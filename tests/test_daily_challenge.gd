extends SceneTree
## Checks the DAILY CHALLENGE: a day always makes the same track, world,
## starting pieces and crates (and different days make different ones),
## best scores and streaks are kept and saved, and in the game: the title
## screen has the button and page, the match has no bots, 5 frames and the
## pieces already down, there's no RETRY FRAME, and the end of the match
## saves your best for the day.
##   godot --headless --fixed-fps 120 --script res://tests/test_daily_challenge.gd

var game: Node
var _fails := 0
var _step := 0
var _t := 0
var _first_crate: Array = []
const DAY := "2026-11-25"


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	DailyChallenge.save_path = "user://test_daily.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DailyChallenge.save_path))
	_rules()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _find_button(node: Node, text: String) -> Button:
	for c in node.get_children():
		if c is Button and (c as Button).text == text and (c as Button).is_visible_in_tree():
			return c
		var inner := _find_button(c, text)
		if inner:
			return inner
	return null


## The rules on their own, no game needed.
func _rules() -> void:
	var a := DailyChallenge.plan(DAY)
	var b := DailyChallenge.plan(DAY)
	check("the same day makes the same track", a.layout == b.layout and a.theme == b.theme and a.width == b.width)
	check("the same day places the same pieces", a.pieces == b.pieces and a.pieces.size() == DailyChallenge.PIECES_PLACED)
	check("the same day has the same crates", a.crate_seed == b.crate_seed)
	var differ := 0
	for d in ["2026-11-26", "2026-11-27", "2026-11-28", "2026-12-01"]:
		var other := DailyChallenge.plan(d)
		if other.layout != a.layout:
			differ += 1
	check("other days make other tracks", differ == 4)
	for p in a.pieces:
		check("starting piece %s is a simple piece" % p.id, DailyChallenge.STARTER_PIECES.has(p.id) and PieceCatalog.PIECES.has(p.id))
	check("dates read nicely", DailyChallenge.pretty(DAY) == "NOV 25")
	check("the day before 1 March is 28 February", DailyChallenge._day_before("2026-03-01") == "2026-02-28")
	check("the day before 1 January is New Year's Eve", DailyChallenge._day_before("2027-01-01") == "2026-12-31")

	var dc := DailyChallenge.new()
	check("no best before playing", dc.best_on(DAY, 0) == -1)
	check("first go is a new best", dc.record(DAY, 0, 20))
	check("a lower score isn't", not dc.record(DAY, 0, 12) and dc.best_on(DAY, 0) == 20)
	check("a higher score is", dc.record(DAY, 0, 31) and dc.best_on(DAY, 0) == 31)
	check("other seats have their own best", dc.best_on(DAY, 1) == -1)
	check("one day played is a streak of 1", dc.streak(0, DAY) == 1)
	dc.record("2026-11-26", 0, 5)
	check("the next day makes it 2", dc.streak(0, "2026-11-26") == 2)
	check("the streak still shows the day after", dc.streak(0, "2026-11-27") == 2)
	check("missing a day ends it", dc.streak(0, "2026-11-28") == 0)
	dc.record("2026-11-29", 0, 5)
	check("playing again starts over at 1", dc.streak(0, "2026-11-29") == 1)
	dc.save_to_disk()
	var back := DailyChallenge.new()
	back.load_from_disk()
	check("best scores are saved", back.best_on(DAY, 0) == 31 and back.best_on("2026-11-26", 0) == 5)
	check("streaks are saved", back.streak(0, "2026-11-29") == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DailyChallenge.save_path))


func _process(_d: float) -> bool:
	_t += 1
	if _t % 3 != 0:
		return false
	_step += 1
	match _step:
		1:
			game.auto_how_to_play = false
			game.daily = DailyChallenge.new()   # fresh scores for the test
			game.menu.daily = game.daily
			check("title screen has DAILY CHALLENGE", _find_button(game.menu, "DAILY CHALLENGE") != null)
			game.menu._push("daily")
		2:
			check("the DAILY CHALLENGE page opens", game.menu._stack[-1] == "daily")
			check("the page has a START button", _find_button(game.menu, "START") != null)
			game.settings.player_count = 1
			game.settings.bot_count = 2
			game._on_daily_requested()
		3:
			var plan := DailyChallenge.plan(game.daily_key)
			check("daily challenge is on", game.daily_on)
			check("no bots in the daily challenge", game.player_count == 1)
			check("5 frames", game.frames_per_match == DailyChallenge.FRAMES)
			check("today's world", game.arena.id == plan.theme)
			check("today's track", game.track.layout == plan.layout)
			check("pieces already on the lane", game.builder.placed.size() == DailyChallenge.PIECES_PLACED)
			for e in game.builder.placed:
				check("starting %s belongs to nobody" % e.id, e.by == -1)
			check("waiting on the ready screen", game.state == game.State.WAITING)
			# Every day gets all its starting pieces down, whatever the track.
			var short := []
			for d in 20:
				var key := DailyChallenge._day_before("2026-12-%02d" % (d + 2))
				game.builder.clear()
				game.daily_key = key
				game._daily_track()
				if game.builder.placed.size() != DailyChallenge.PIECES_PLACED:
					short.append(key)
			check("20 days in a row all get their starting pieces " + str(short), short.is_empty())
			game.daily_key = DailyChallenge.today()
			game._new_match()
			game._start_draft()
			_first_crate = game.draft_build.crate.duplicate()
		4:
			# Play it again: the same crate comes up.
			game._new_match()
			game._start_draft()
			check("the same crate on a second go", game.draft_build.crate == _first_crate)
			check("the same pieces on a second go", game.builder.placed.size() == DailyChallenge.PIECES_PLACED)
			game._pause()
		5:
			check("no RETRY FRAME in the daily challenge", not game.menu._retry_button.visible)
			game._resume()
			# Jump to the last frame and knock some pins over.
			game.frame = DailyChallenge.FRAMES
			game._prepare_roll()
			game._release_marbles()
			game.arrival_order.append(0)
			game._finish_times[0] = 9.5
			for i in 6:
				var pin = game.rack.pins[i]
				pin.credited_to = 0
				var xf: Transform3D = pin.global_transform
				pin.global_transform = Transform3D(xf.basis.rotated(Vector3.RIGHT, PI / 2), xf.origin + Vector3(0, -0.3, 0))
		6, 7, 8:
			pass   # let the pins settle
		9:
			game._finish_frame()
			var score: int = game.totals[0]
			check("the match ends after the last frame", game.state in [game.State.MATCH_OVER, game.State.AWARDS, game.State.REPLAY])
			check("scored some points", score > 0)
			check("today's best is saved", game.daily.best_on(game.daily_key, 0) == score)
			check("NEW BEST! for a first go", game.daily_new_best[0] and game.daily_summary().contains("NEW BEST!"))
			var saved := DailyChallenge.new()
			saved.load_from_disk()
			check("today's best is on disk", saved.best_on(game.daily_key, 0) == score)
			check("streak of one day", saved.streak(0, game.daily_key) == 1)
		10:
			game._on_quit_to_menu()
			check("quitting ends the daily challenge", not game.daily_on)
			game._on_play_requested()
			check("a normal match is not a daily", not game.daily_on and game.frames_per_match == game.settings.frames_per_match)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DailyChallenge.save_path))
			print("All daily challenge tests passed" if _fails == 0 else "%d daily challenge tests FAILED" % _fails)
			quit(1 if _fails > 0 else 0)
			return true
	return false
