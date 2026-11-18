class_name PieceCatalog
extends RefCounted
## Everything players can draft. To add a piece: make its scene in
## scenes/pieces/, then add an entry here.
##
## kind: "piece" stays on the lane; "bomb" is a one-shot item that blows up
##     placed pieces near where it lands.
## radius: rough footprint in metres. Pieces can't be placed with their
##     centres closer than about their two radii, and the bomb clears
##     anything within its radius.
## base_rotation: degrees the piece starts turned before the player rotates
##     it (the angled rail starts diagonal).

const PIECES := {
	"bumper_post": {
		"name": "Bumper post",
		"about": "Round post that kicks marbles sideways",
		"scene": "res://scenes/pieces/bumper_post.tscn",
		"kind": "piece", "radius": 0.45, "base_rotation": 0.0,
	},
	"angled_rail": {
		"name": "Angled rail",
		"about": "Short wall that turns a marble",
		"scene": "res://scenes/pieces/angled_rail.tscn",
		"kind": "piece", "radius": 1.0, "base_rotation": 45.0,
	},
	"ramp_jump": {
		"name": "Ramp jump",
		"about": "Launches a marble into the air",
		"scene": "res://scenes/pieces/ramp_jump.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
	},
	"carpet_strip": {
		"name": "Carpet strip",
		"about": "Thick rug that drains speed",
		"scene": "res://scenes/pieces/carpet_strip.tscn",
		"kind": "piece", "radius": 0.75, "base_rotation": 0.0,
	},
	"booster_pad": {
		"name": "Booster pad",
		"about": "Fires a marble the way the arrow points",
		"scene": "res://scenes/pieces/booster_pad.tscn",
		"kind": "piece", "radius": 0.7, "base_rotation": 0.0,
	},
	"spinner": {
		"name": "Spinner",
		"about": "Paddle that never stops turning and swats marbles",
		"scene": "res://scenes/pieces/spinner.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"gutter_cut": {
		"name": "Gutter cut",
		"about": "A hole: fall in and your frame is over",
		"scene": "res://scenes/pieces/gutter_cut.tscn",
		"kind": "piece", "radius": 0.6, "base_rotation": 0.0,
	},
	"curve": {
		"name": "Bend",
		"about": "Curved wall that swings marbles across the lane",
		"scene": "res://scenes/pieces/curve.tscn",
		"kind": "piece", "radius": 0.9, "base_rotation": 0.0,
	},
	"drop_step": {
		"name": "Drop step",
		"about": "Ramp up onto a ledge, then a sudden drop",
		"scene": "res://scenes/pieces/drop_step.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"hump": {
		"name": "Hump",
		"about": "Smooth hill across the lane that tosses marbles up",
		"scene": "res://scenes/pieces/hump.tscn",
		"kind": "piece", "radius": 1.0, "base_rotation": 0.0,
	},
	"washboard": {
		"name": "Washboard",
		"about": "Row of little bumps that make marbles hop and skid",
		"scene": "res://scenes/pieces/washboard.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
	},
	"tilt_table": {
		"name": "Tilt table",
		"about": "A square of lane that rocks side to side",
		"scene": "res://scenes/pieces/tilt_table.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"bomb": {
		"name": "Bomb",
		"about": "Blows up every piece near where you drop it",
		"scene": "res://scenes/pieces/bomb.tscn",
		"kind": "bomb", "radius": 1.6, "base_rotation": 0.0,
	},
}


static func ids() -> Array:
	return PIECES.keys()


static func info(id: String) -> Dictionary:
	return PIECES[id]


static func display_name(id: String) -> String:
	return PIECES[id].name if PIECES.has(id) else ""


static func is_bomb(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].kind == "bomb"


## A crate of `count` random picks (repeats allowed).
static func random_crate(count: int, rng: RandomNumberGenerator) -> Array:
	var all := ids()
	var crate := []
	for i in count:
		crate.append(all[rng.randi_range(0, all.size() - 1)])
	return crate
