extends SceneTree
## Checks achievements (unlocking, counting, saving, sending to Steam) and
## the Steam helper on its own, with and without Steam.
##   godot --headless --script res://tests/test_achievements.gd

var _fails := 0


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


var off: SteamService
var steam: SteamService
var fake: Object


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements_unit.cfg"
	Achievements.reset()
	off = SteamService.new()
	root.add_child(off)
	fake = load("res://tests/fake_steam.gd").new()
	steam = SteamService.new(fake)
	root.add_child(steam)


## Runs on the first frame, once both Steam helpers have started.
func _process(_delta: float) -> bool:
	# Without the plugin: Steam is off and says why, nothing breaks.
	check("no Steam plugin: Steam is off (%s)" % off.problem, not off.available and off.problem != "")
	off.unlock("STRIKE")
	off.presence("hi")
	off.queue_free()

	var ids := {}
	for a in Achievements.LIST:
		ids[a.id] = true
		check("%s has a name, how-to, emblem and colour" % a.id, a.name != "" and a.text != "" and a.emblem != "" and a.color is Color)
		check("%s is a valid Steam API name" % a.id, a.id == a.id.to_upper() and not a.id.contains(" "))
	check("no two achievements share an id", ids.size() == Achievements.LIST.size())

	# With a stand-in for Steam.
	check("Steam starts with the stand-in", steam.available)

	var popped := []
	Achievements.on_unlocked = func(a): popped.append(a.id)
	Achievements.unlock("STRIKE")
	Achievements.unlock("STRIKE")
	check("unlocking pops up once", popped == ["STRIKE"])
	check("unlocking is sent to Steam", fake.achievements.has("STRIKE"))
	Achievements.unlock("NOT_A_REAL_ONE")
	check("unknown ids are ignored", not Achievements.has("NOT_A_REAL_ONE"))

	Achievements.add("PINS_500", 120)
	Achievements.add("PINS_500", 300)
	check("counting: 420 of 500 isn't unlocked yet", Achievements.count("PINS_500") == 420 and not Achievements.has("PINS_500"))
	Achievements.add("PINS_500", 90)
	check("counting: unlocks at 500", Achievements.has("PINS_500") and fake.achievements.has("PINS_500"))

	# Saved and loaded again.
	Achievements._loaded = false
	Achievements._got.clear()
	Achievements._counts.clear()
	check("saved to disk and loaded back", Achievements.has("STRIKE") and Achievements.has("PINS_500"))

	check("+connect_lobby is read from the command line",
			SteamService._lobby_from_text("--foo +connect_lobby 109775240000024691 --bar") == 109775240000024691)
	check("no +connect_lobby means no lobby", SteamService._lobby_from_text("--foo") == 0)

	# Icons draw without errors at both sizes.
	for a in Achievements.LIST:
		var icon := AchievementIcon.make(a, false, 64)
		root.add_child(icon)
		icon.queue_free()

	Achievements.on_unlocked = Callable()
	Achievements.reset()
	steam.queue_free()
	fake.free()
	print("All achievement tests passed" if _fails == 0 else "%d achievement test(s) FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
