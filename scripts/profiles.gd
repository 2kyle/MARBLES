class_name Profiles
extends RefCounted
## Each player seat's coins, what they've won from loot crates, and what
## they're wearing.
## Saved on this computer (user://profiles.cfg) so it carries over between
## games. In online play each player would keep their own profile instead.

const PATH := "user://profiles.cfg"
const SEATS := 4
## Coins a brand-new seat starts with: enough for a first loot crate.
const STARTING_COINS := 150
const DEFAULT_COLORS := ["pink", "yellow", "violet", "lime"]

## Coins for playing: one per point scored in a frame, plus these.
const COINS_PER_MATCH := 20
const COINS_FOR_WIN := 50

var seats: Array = []


func _init() -> void:
	for i in SEATS:
		seats.append({
			"coins": STARTING_COINS,
			"owned": Cosmetics.free_items(),
			"equipped": {"hat": "none", "eyes": "classic", "color": DEFAULT_COLORS[i], "style": "gloss", "trail": "ribbon"},
		})


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for i in SEATS:
		var sec := "seat%d" % i
		if not cfg.has_section(sec):
			continue
		seats[i].coins = int(cfg.get_value(sec, "coins", STARTING_COINS))
		var owned: Array = cfg.get_value(sec, "owned", [])
		for item in Cosmetics.free_items():
			if not owned.has(item):
				owned.append(item)
		seats[i].owned = owned
		var eq: Dictionary = cfg.get_value(sec, "equipped", {})
		for slot in Cosmetics.SLOTS:
			if eq.has(slot) and owns(i, slot, eq[slot]):
				seats[i].equipped[slot] = eq[slot]


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for i in SEATS:
		var sec := "seat%d" % i
		cfg.set_value(sec, "coins", seats[i].coins)
		cfg.set_value(sec, "owned", seats[i].owned)
		cfg.set_value(sec, "equipped", seats[i].equipped)
	cfg.save(PATH)


func coins(seat: int) -> int:
	return seats[seat].coins


func owns(seat: int, slot: String, id: String) -> bool:
	return seats[seat].owned.has(slot + ":" + id)


func equipped(seat: int, slot: String) -> String:
	return seats[seat].equipped[slot]


func equip(seat: int, slot: String, id: String) -> bool:
	if not owns(seat, slot, id):
		return false
	seats[seat].equipped[slot] = id
	return true


## Give a seat a look (from a loot crate). Returns false if it already
## had it (the crate then pays coins back instead).
func grant(seat: int, slot: String, id: String) -> bool:
	if owns(seat, slot, id):
		return false
	seats[seat].owned.append(slot + ":" + id)
	return true


## Whether this seat has pulled the ultra-rare trophy.
func has_trophy(seat: int) -> bool:
	return owns(seat, "trophy", Cosmetics.TROPHY.id)


func add_coins(seat: int, amount: int) -> void:
	seats[seat].coins += amount


## Everything a marble needs to look right: hat, eyes, color, style and trail entries.
func look(seat: int) -> Dictionary:
	return {
		"hat": Cosmetics.find("hat", equipped(seat, "hat")),
		"eyes": Cosmetics.find("eyes", equipped(seat, "eyes")),
		"color": Cosmetics.find("color", equipped(seat, "color")),
		"style": Cosmetics.find("style", equipped(seat, "style")),
		"trail": Cosmetics.find("trail", equipped(seat, "trail")),
	}
