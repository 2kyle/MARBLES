class_name Cosmetics
extends RefCounted
## Every marble look in the game and what it costs in the store.
## To add one: add an entry here. Styles with a "pattern" use
## shaders/marble.gdshader; trails are made in scripts/marble_trail.gd.

const COLORS := [
	{"id": "pink", "name": "Pink", "color": Color(0.95, 0.3, 0.55), "price": 0},
	{"id": "yellow", "name": "Yellow", "color": Color(1.0, 0.8, 0.15), "price": 0},
	{"id": "violet", "name": "Violet", "color": Color(0.7, 0.45, 0.95), "price": 0},
	{"id": "lime", "name": "Lime", "color": Color(0.6, 0.95, 0.3), "price": 0},
	{"id": "sky", "name": "Sky blue", "color": Color(0.3, 0.7, 1.0), "price": 0},
	{"id": "orange", "name": "Orange", "color": Color(1.0, 0.5, 0.15), "price": 0},
	{"id": "white", "name": "Snow", "color": Color(0.95, 0.95, 0.97), "price": 40},
	{"id": "black", "name": "Midnight", "color": Color(0.12, 0.12, 0.16), "price": 40},
	{"id": "red", "name": "Cherry", "color": Color(0.85, 0.08, 0.12), "price": 40},
	{"id": "gold", "name": "Gold", "color": Color(1.0, 0.76, 0.25), "price": 120},
]

## pattern: 0 plain, 1 stripes, 2 swirl, 3 galaxy, 4 lava, 5 checker
const STYLES := [
	{"id": "gloss", "name": "Gloss", "pattern": 0, "metallic": 0.1, "roughness": 0.15, "glow": 0.0, "price": 0},
	{"id": "stripes", "name": "Stripes", "pattern": 1, "metallic": 0.1, "roughness": 0.2, "glow": 0.0, "price": 0},
	{"id": "metal", "name": "Chrome", "pattern": 0, "metallic": 0.95, "roughness": 0.12, "glow": 0.0, "price": 60},
	{"id": "checker", "name": "Checkers", "pattern": 5, "metallic": 0.1, "roughness": 0.25, "glow": 0.0, "price": 80},
	{"id": "swirl", "name": "Swirl", "pattern": 2, "metallic": 0.1, "roughness": 0.1, "glow": 0.0, "price": 120},
	{"id": "neon", "name": "Neon", "pattern": 0, "metallic": 0.0, "roughness": 0.4, "glow": 2.5, "price": 150},
	{"id": "glass", "name": "Glass", "pattern": -1, "metallic": 0.0, "roughness": 0.05, "glow": 0.0, "price": 200},
	{"id": "lava", "name": "Lava", "pattern": 4, "metallic": 0.0, "roughness": 0.7, "glow": 3.0, "price": 250},
	{"id": "galaxy", "name": "Galaxy", "pattern": 3, "metallic": 0.2, "roughness": 0.1, "glow": 1.5, "price": 300},
]

const TRAILS := [
	{"id": "none", "name": "No trail", "price": 0},
	{"id": "ribbon", "name": "Ribbon", "price": 0},
	{"id": "sparkles", "name": "Sparkles", "price": 100},
	{"id": "bubbles", "name": "Bubbles", "price": 120},
	{"id": "flame", "name": "Flame", "price": 200},
	{"id": "rainbow", "name": "Rainbow", "price": 350},
]

## The rows on the locker screen, in order.
const SLOTS := ["color", "style", "trail"]


static func items(slot: String) -> Array:
	match slot:
		"color": return COLORS
		"style": return STYLES
		_: return TRAILS


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


## Everything that's free, so every profile owns it from the start.
static func free_items() -> Array:
	var out := []
	for slot in SLOTS:
		for it in items(slot):
			if it.price == 0:
				out.append(slot + ":" + it.id)
	return out
