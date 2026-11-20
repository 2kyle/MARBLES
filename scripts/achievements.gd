class_name Achievements
extends RefCounted
## The achievement list, and unlocking them.
##
## Achievements belong to this computer (one Steam account), so any person
## playing here can unlock them; bots and online players on other computers
## can't. They're saved in user://achievements.cfg, so they work without
## Steam too, and copied to Steam when it's running (steam_service.gd).
##
## To add one: add an entry to LIST, call Achievements.unlock("ITS_ID") (or
## Achievements.add("ITS_ID", n) for a counting one) where it happens, and
## add it on the Steamworks site with the same ID (see docs/STEAM.md).
##   id       the "API name" on Steam (capital letters and _ only)
##   name     shown in game and on Steam
##   text     how to get it
##   emblem   the picture on its icon (see achievement_icon.gd)
##   color    the icon's colour
##   goal     for counting achievements: how many it takes

const LIST := [
	{"id": "FIRST_FRAME", "name": "Rolling Start", "text": "Finish your first frame.", "emblem": "marble", "color": Color(0.3, 0.6, 1.0)},
	{"id": "FIRST_MATCH", "name": "Full Rack", "text": "Play a whole match to the end.", "emblem": "pin", "color": Color(0.95, 0.35, 0.4)},
	{"id": "FIRST_WIN", "name": "Top of the Table", "text": "Win a match against at least one other marble.", "emblem": "crown", "color": Color(1.0, 0.72, 0.2)},
	{"id": "STRIKE", "name": "STRIKE!", "text": "Knock down every pin on your own in one frame.", "emblem": "star", "color": Color(0.95, 0.45, 0.15)},
	{"id": "TURKEY", "name": "Turkey", "text": "Get three strikes in one match.", "emblem": "stars", "color": Color(0.75, 0.3, 0.2)},
	{"id": "PINS_500", "name": "Pin Pal", "text": "Knock down 500 pins.", "emblem": "pins", "color": Color(0.55, 0.4, 0.9), "goal": 500},
	{"id": "PHOTO_FINISH", "name": "Photo Finish", "text": "Be the first marble to reach the pins.", "emblem": "flag", "color": Color(0.25, 0.7, 0.45)},
	{"id": "BUMPER_CARS", "name": "Bumper Cars", "text": "Knock another marble off the track.", "emblem": "bump", "color": Color(0.9, 0.3, 0.55)},
	{"id": "SPLASHDOWN", "name": "Splashdown", "text": "Fall off the track into the water.", "emblem": "wave", "color": Color(0.2, 0.65, 0.8)},
	{"id": "ONLINE_MATCH", "name": "Long Distance", "text": "Finish a match online.", "emblem": "globe", "color": Color(0.2, 0.5, 0.75)},
	{"id": "FIRST_CRATE", "name": "Unboxed", "text": "Open a loot crate.", "emblem": "crate", "color": Color(0.7, 0.48, 0.28)},
	{"id": "LEGENDARY", "name": "Legendary Pull", "text": "Win a Legendary look from a loot crate.", "emblem": "gem", "color": Color(0.95, 0.7, 0.15)},
	{"id": "GOLDEN_MARBLE", "name": "Golden Marble", "text": "Pull the ultra-rare Golden Marble Trophy.", "emblem": "trophy", "color": Color(0.85, 0.62, 0.1)},
	{"id": "DRESSED_UP", "name": "Dressed to Roll", "text": "Wear a hat and a pair of eyes from the closet.", "emblem": "hat", "color": Color(0.45, 0.3, 0.7)},
	{"id": "DERBY_WIN", "name": "Picked a Winner", "text": "Win a bet in the Marble Derby.", "emblem": "horseshoe", "color": Color(0.5, 0.65, 0.25)},
	{"id": "LONG_SHOT", "name": "Long Shot", "text": "Win a Derby bet at 5x odds or more.", "emblem": "longshot", "color": Color(0.3, 0.45, 0.2)},
	{"id": "NOTHING_BUT_NET", "name": "Nothing but Net", "text": "Sink a basket off the trampoline.", "emblem": "hoop", "color": Color(1.0, 0.5, 0.2)},
	{"id": "BACK_OF_THE_NET", "name": "Back of the Net", "text": "Score a goal on the sports island.", "emblem": "ball", "color": Color(0.3, 0.75, 0.35)},
	{"id": "PIGGY_BANK", "name": "Piggy Bank", "text": "Save up 1,000 coins.", "emblem": "coin", "color": Color(0.95, 0.75, 0.25)},
	{"id": "GEM_HUNTER", "name": "Treasure Hunter", "text": "Find all 6 secret gems in the jungle.", "emblem": "gem", "color": Color(0.2, 0.7, 0.45)},
]

## Where they're saved (tests use their own file).
static var save_path := "user://achievements.cfg"

## Called with the achievement's entry when one unlocks (main.gd shows a
## pop-up).
static var on_unlocked: Callable
## Unlocked ids -> true, and counts for counting achievements.
static var _got := {}
static var _counts := {}
static var _loaded := false


static func info(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


static func has(id: String) -> bool:
	_load()
	return _got.has(id)


static func count(id: String) -> int:
	_load()
	return _counts.get(id, 0)


static func unlocked_ids() -> Array:
	_load()
	return _got.keys()


static func unlocked_count() -> int:
	_load()
	return _got.size()


## Unlock `id` (does nothing if it's already unlocked).
static func unlock(id: String) -> void:
	_load()
	if _got.has(id) or info(id).is_empty():
		return
	_got[id] = true
	_save()
	if SteamService.instance:
		SteamService.instance.unlock(id)
	if on_unlocked.is_valid():
		on_unlocked.call(info(id))


## Add `n` to a counting achievement; it unlocks when it reaches its goal.
static func add(id: String, n: int) -> void:
	_load()
	if n <= 0 or _got.has(id):
		return
	var goal: int = info(id).get("goal", 1)
	var before: int = _counts.get(id, 0)
	_counts[id] = mini(before + n, goal)
	_save()
	if _counts[id] >= goal:
		unlock(id)
	elif SteamService.instance and _counts[id] / 100 > before / 100:
		# Steam's "12 / 50" pop-up, every hundred.
		SteamService.instance.progress(id, _counts[id], goal)


## Forget everything (for tests).
static func reset() -> void:
	_got.clear()
	_counts.clear()
	_loaded = true
	_save()
	if SteamService.instance:
		SteamService.instance.reset_all(LIST.map(func(a): return a.id))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for id in cfg.get_value("got", "ids", []):
		_got[id] = true
	_counts = cfg.get_value("counts", "all", {})


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("got", "ids", _got.keys())
	cfg.set_value("counts", "all", _counts)
	cfg.save(save_path)
