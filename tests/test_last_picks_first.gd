extends SceneTree
## Checks LAST PICKS FIRST: who counts as last (ties, everyone level), the
## head start (others can't grab a card, the first picker can, it ends
## early once they've picked, time running out picks them first), then in
## the game: frame 1 has no first picker, a later frame gives it to whoever
## is last, and the setting switches it off.
##   godot --headless --fixed-fps 120 --script res://tests/test_last_picks_first.gd

var game: Node
var _fails := 0
var _ticks := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	_rules()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _rules() -> void:
	check("everyone level: nobody", DraftBuild.trailing([3, 3, 3]).is_empty())
	check("one player: nobody", DraftBuild.trailing([0]).is_empty())
	check("the lowest score picks first", DraftBuild.trailing([5, 2, 7]) == [1])
	check("tied for last: both pick first", DraftBuild.trailing([1, 4, 1, 6]) == [0, 2])

	var db := DraftBuild.new()
	db.player_count = 3
	db.mirror_draft(["bumper_post", "spinner", "booster", "magnet"], [2])
	check("head start is on", db.head_start == DraftBuild.HEAD_START)
	check("P1 is held", db.is_held(0) and db.is_held(1) and not db.is_held(2))
	db.draft_pointer[0] = Vector2(0.5, 0.5)
	check("a held player can't grab a card", not db.request_pick(0) and db.picks[0] == "")
	check("and is told to wait", db.message[0] == "Wait!")
	db.tick(1.0)
	check("still held after a second", db.is_held(0))
	db.draft_pointer[2] = Vector2(1.5, 0.5)
	check("the first picker can grab a card", db.request_pick(2) and db.picks[2] == "spinner")
	db.tick(0.01)
	check("head start ends once they've picked", db.head_start == 0.0 and not db.is_held(0))
	check("now P1 can grab a card", db.request_pick(0) and db.picks[0] == "bumper_post")

	db.mirror_draft(["bumper_post", "spinner", "booster"], [2])
	db.tick(DraftBuild.HEAD_START + 0.1)
	check("head start runs out by itself", not db.is_held(0))

	# Time runs out with everyone on the same card: the first picker gets it.
	db.mirror_draft(["bumper_post", "spinner", "booster"], [2])
	for p in 3:
		db.draft_pointer[p] = Vector2(1.5, 1.3)
	db.auto_pick_remaining()
	check("time out: the first picker gets their card", db.picks[2] == "spinner")
	check("time out: everyone gets something", not db.picks.has(""))

	db.mirror_draft(["bumper_post", "spinner"], [])
	check("no first picker: nobody is held", db.head_start == 0.0 and not db.is_held(0))
	db.free()


func _process(_delta: float) -> bool:
	_ticks += 1
	if _ticks > 120 * 60:
		check("finished in time", false)
		return _done()
	if game.state == game.State.MENU:
		game._on_play_requested()
		return false
	if game.state != game.State.WAITING:
		return false
	game.auto_how_to_play = false
	check("at least two players", game.player_count >= 2)
	game.settings.last_picks_first = true
	game.frame = 1
	game._start_draft()
	check("frame 1: no first pick", game.draft_build.first_pick.is_empty())
	game.frame = 2
	game.totals.fill(4)
	game.totals[1] = 1
	game._start_draft()
	check("frame 2: the player in last picks first", game.draft_build.first_pick == [1])
	check("the others wait", game.draft_build.is_held(0))
	var hud_ok := true
	game.hud._update_top(game)
	hud_ok = game.hud._banner.text.begins_with("FIRST PICK")
	check("the banner says FIRST PICK", hud_ok)
	game.settings.last_picks_first = false
	game._start_draft()
	check("setting off: no first pick", game.draft_build.first_pick.is_empty())
	return _done()


func _done() -> bool:
	print("ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
