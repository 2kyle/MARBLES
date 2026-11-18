class_name PieceCatalog
extends RefCounted
## Every piece players can draft. To add a piece: make its scene in
## scenes/pieces/, then add a line here.
##
## base_rotation: degrees the piece is turned before the player rotates it
## (the angled rail sits at 45 degrees so its two orientations are / and \).

const PIECES := {
	"bumper_post": {
		"name": "Bumper post",
		"about": "Round post that bounces marbles sideways",
		"scene": "res://scenes/pieces/bumper_post.tscn",
		"base_rotation": 0.0,
	},
	"angled_rail": {
		"name": "Angled rail",
		"about": "Short wall that turns a marble 45 degrees",
		"scene": "res://scenes/pieces/angled_rail.tscn",
		"base_rotation": 45.0,
	},
	"ramp_jump": {
		"name": "Ramp jump",
		"about": "Launches a marble over what's in front of it",
		"scene": "res://scenes/pieces/ramp_jump.tscn",
		"base_rotation": 0.0,
	},
	"carpet_strip": {
		"name": "Carpet strip",
		"about": "Thick rug that drains speed",
		"scene": "res://scenes/pieces/carpet_strip.tscn",
		"base_rotation": 0.0,
	},
	"booster_pad": {
		"name": "Booster pad",
		"about": "Fires a marble the way the arrow points",
		"scene": "res://scenes/pieces/booster_pad.tscn",
		"base_rotation": 0.0,
	},
	"spinner": {
		"name": "Spinner",
		"about": "Paddle that never stops turning and swats marbles",
		"scene": "res://scenes/pieces/spinner.tscn",
		"base_rotation": 0.0,
	},
	"gutter_cut": {
		"name": "Gutter cut",
		"about": "A hole: fall in and your frame is over",
		"scene": "res://scenes/pieces/gutter_cut.tscn",
		"base_rotation": 0.0,
	},
}


static func ids() -> Array:
	return PIECES.keys()


static func info(id: String) -> Dictionary:
	return PIECES[id]


static func display_name(id: String) -> String:
	return PIECES[id].name if PIECES.has(id) else ""


## A crate of `count` random pieces (repeats allowed).
static func random_crate(count: int, rng: RandomNumberGenerator) -> Array:
	var all := ids()
	var crate := []
	for i in count:
		crate.append(all[rng.randi_range(0, all.size() - 1)])
	return crate
