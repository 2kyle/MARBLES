class_name Cosmetics
extends RefCounted
## Every marble look in the game. Looks come from loot crates (see
## loot_crates.gd), and each has a rarity. "starter" looks are owned from
## the start. To add one: add an entry here. Styles with a "pattern" use
## shaders/marble.gdshader, trails are made in scripts/marble_trail.gd,
## hats in scripts/hats.gd and eyes in scripts/eyes.gd.

## Rarities, from most to least common, with their colour.
const RARITIES := {
	"starter": {"name": "Starter", "color": Color(0.7, 0.72, 0.78)},
	"common": {"name": "Common", "color": Color(0.82, 0.85, 0.9)},
	"rare": {"name": "Rare", "color": Color(0.35, 0.65, 1.0)},
	"epic": {"name": "Epic", "color": Color(0.72, 0.42, 1.0)},
	"legendary": {"name": "Legendary", "color": Color(1.0, 0.72, 0.2)},
	"ultra": {"name": "Ultra Rare", "color": Color(1.0, 0.35, 0.55)},
	# Never in a crate: earned by doing something (see "how" on the item).
	"secret": {"name": "Secret", "color": Color(0.3, 0.95, 0.6)},
}

const HATS := [
	{"id": "none", "name": "No hat", "rarity": "starter"},
	{"id": "party", "name": "Party Hat", "rarity": "common"},
	{"id": "beanie", "name": "Beanie", "rarity": "common"},
	{"id": "cap", "name": "Ball Cap", "rarity": "common"},
	{"id": "cone", "name": "Traffic Cone", "rarity": "common"},
	{"id": "tophat", "name": "Top Hat", "rarity": "rare"},
	{"id": "cowboy", "name": "Cowboy Hat", "rarity": "rare"},
	{"id": "chef", "name": "Chef Hat", "rarity": "rare"},
	{"id": "bunny", "name": "Bunny Ears", "rarity": "rare"},
	{"id": "flowers", "name": "Flower Crown", "rarity": "rare"},
	{"id": "propeller", "name": "Propeller Cap", "rarity": "epic"},
	{"id": "pirate", "name": "Pirate Hat", "rarity": "epic"},
	{"id": "viking", "name": "Viking Helmet", "rarity": "epic"},
	{"id": "duck", "name": "Rubber Duck", "rarity": "epic"},
	{"id": "wizard", "name": "Wizard Hat", "rarity": "legendary"},
	{"id": "crown", "name": "Crown", "rarity": "legendary"},
	{"id": "halo", "name": "Halo", "rarity": "legendary"},
	{"id": "gem_crown", "name": "Jungle Gem Crown", "rarity": "secret", "how": "Find all 6 secret gems in the jungle"},
]

const EYES := [
	{"id": "classic", "name": "Classic", "rarity": "starter"},
	{"id": "dots", "name": "Button Dots", "rarity": "starter"},
	{"id": "none", "name": "No Eyes", "rarity": "starter"},
	{"id": "googly", "name": "Googly", "rarity": "common"},
	{"id": "sleepy", "name": "Sleepy", "rarity": "common"},
	{"id": "happy", "name": "Happy", "rarity": "common"},
	{"id": "angry", "name": "Grumpy", "rarity": "rare"},
	{"id": "cute", "name": "Sparkly", "rarity": "rare"},
	{"id": "cyclops", "name": "Cyclops", "rarity": "rare"},
	{"id": "shades", "name": "Cool Shades", "rarity": "epic"},
	{"id": "robot", "name": "Robot Visor", "rarity": "epic"},
	{"id": "hearts", "name": "Heart Eyes", "rarity": "legendary"},
	{"id": "stars", "name": "Star Eyes", "rarity": "legendary"},
]

const COLORS := [
	{"id": "pink", "name": "Pink", "color": Color(0.95, 0.3, 0.55), "rarity": "starter"},
	{"id": "yellow", "name": "Yellow", "color": Color(1.0, 0.8, 0.15), "rarity": "starter"},
	{"id": "violet", "name": "Violet", "color": Color(0.7, 0.45, 0.95), "rarity": "starter"},
	{"id": "lime", "name": "Lime", "color": Color(0.6, 0.95, 0.3), "rarity": "starter"},
	{"id": "sky", "name": "Sky Blue", "color": Color(0.3, 0.7, 1.0), "rarity": "common"},
	{"id": "orange", "name": "Orange", "color": Color(1.0, 0.5, 0.15), "rarity": "common"},
	{"id": "mint", "name": "Mint", "color": Color(0.45, 0.92, 0.75), "rarity": "common"},
	{"id": "peach", "name": "Peach", "color": Color(1.0, 0.7, 0.55), "rarity": "common"},
	{"id": "white", "name": "Snow", "color": Color(0.95, 0.95, 0.97), "rarity": "rare"},
	{"id": "black", "name": "Midnight", "color": Color(0.12, 0.12, 0.16), "rarity": "rare"},
	{"id": "red", "name": "Cherry", "color": Color(0.85, 0.08, 0.12), "rarity": "rare"},
	{"id": "teal", "name": "Deep Teal", "color": Color(0.05, 0.5, 0.55), "rarity": "epic"},
	{"id": "gold", "name": "Gold", "color": Color(1.0, 0.76, 0.25), "rarity": "legendary"},
]

## pattern: 0 plain, 1 stripes, 2 swirl, 3 galaxy, 4 lava, 5 checker
const STYLES := [
	{"id": "gloss", "name": "Gloss", "pattern": 0, "metallic": 0.1, "roughness": 0.15, "glow": 0.0, "rarity": "starter"},
	{"id": "stripes", "name": "Stripes", "pattern": 1, "metallic": 0.1, "roughness": 0.2, "glow": 0.0, "rarity": "common"},
	{"id": "checker", "name": "Checkers", "pattern": 5, "metallic": 0.1, "roughness": 0.25, "glow": 0.0, "rarity": "common"},
	{"id": "metal", "name": "Chrome", "pattern": 0, "metallic": 0.95, "roughness": 0.12, "glow": 0.0, "rarity": "rare"},
	{"id": "swirl", "name": "Swirl", "pattern": 2, "metallic": 0.1, "roughness": 0.1, "glow": 0.0, "rarity": "rare"},
	{"id": "neon", "name": "Neon", "pattern": 0, "metallic": 0.0, "roughness": 0.4, "glow": 2.5, "rarity": "epic"},
	{"id": "glass", "name": "Glass", "pattern": -1, "metallic": 0.0, "roughness": 0.05, "glow": 0.0, "rarity": "epic"},
	{"id": "lava", "name": "Lava", "pattern": 4, "metallic": 0.0, "roughness": 0.7, "glow": 3.0, "rarity": "legendary"},
	{"id": "galaxy", "name": "Galaxy", "pattern": 3, "metallic": 0.2, "roughness": 0.1, "glow": 1.5, "rarity": "legendary"},
]

const TRAILS := [
	{"id": "none", "name": "No Trail", "rarity": "starter"},
	{"id": "ribbon", "name": "Ribbon", "rarity": "starter"},
	{"id": "sparkles", "name": "Sparkles", "rarity": "rare"},
	{"id": "bubbles", "name": "Bubbles", "rarity": "rare"},
	{"id": "flame", "name": "Flame", "rarity": "epic"},
	{"id": "rainbow", "name": "Rainbow", "rarity": "legendary"},
]

## The ultra-rare trophy. It isn't worn: it stands on your practice island.
const TROPHY := {"id": "golden_marble", "name": "Golden Marble Trophy", "rarity": "ultra"}

## The closet's sections, in order.
const SLOTS := ["hat", "eyes", "color", "style", "trail"]
const SLOT_NAMES := {"hat": "HATS", "eyes": "EYES", "color": "COLOR", "style": "STYLE", "trail": "TRAIL"}


static func items(slot: String) -> Array:
	match slot:
		"hat": return HATS
		"eyes": return EYES
		"color": return COLORS
		"style": return STYLES
		"trail": return TRAILS
		"trophy": return [TROPHY]
	return []


static func find(slot: String, id: String) -> Dictionary:
	for it in items(slot):
		if it.id == id:
			return it
	return items(slot)[0]


static func index_of(slot: String, id: String) -> int:
	var list := items(slot)
	for i in list.size():
		if list[i].id == id:
			return i
	return 0


static func rarity_color(rarity: String) -> Color:
	return RARITIES.get(rarity, RARITIES.common).color


static func rarity_name(rarity: String) -> String:
	return RARITIES.get(rarity, RARITIES.common).name


## Everything a brand-new profile owns.
static func free_items() -> Array:
	var out := []
	for slot in SLOTS:
		for it in items(slot):
			if it.rarity == "starter":
				out.append(slot + ":" + it.id)
	return out


## Every look a crate can give, as [slot, item] pairs, for one rarity.
static func crate_pool(rarity: String) -> Array:
	var out := []
	for slot in SLOTS:
		for it in items(slot):
			if it.rarity == rarity:
				out.append([slot, it])
	return out
