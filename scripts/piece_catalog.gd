class_name PieceCatalog
extends RefCounted
## Everything players can draft. To add a piece: make its scene in
## scenes/pieces/, then add an entry here.
##
## kind: "piece" stays on the lane; "bomb" is a one-shot item that blows up
##     placed pieces near where it lands; "track" reshapes the track itself
##     where it's dropped (the scene is only its picture). Which way a track
##     card turns depends on which side of the track you drop it.
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
	"track_bend": {
		"name": "Track: bend",
		"about": "Bends the track itself. Drop it on the side you want it to turn",
		"scene": "res://scenes/pieces/track_bend.tscn",
		"kind": "track", "segment": "bend", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_drop": {
		"name": "Track: cliff drop",
		"about": "Adds a steep drop to the track itself",
		"scene": "res://scenes/pieces/track_drop.tscn",
		"kind": "track", "segment": "drop", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_hairpin": {
		"name": "Track: hairpin",
		"about": "Adds a tight U-turn. Drop it on the side you want it to turn",
		"scene": "res://scenes/pieces/track_hairpin.tscn",
		"kind": "track", "segment": "hairpin", "radius": 1.6, "base_rotation": 0.0,
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


static func is_track(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].kind == "track"


## The new stretch of track a track card adds. `side` < 0 = left of the
## centre line (turn left), > 0 = right.
static func track_segment(id: String, side: float) -> Dictionary:
	var sign := 1.0 if side < 0.0 else -1.0
	match PIECES[id].segment:
		"drop":
			return TrackGen.drop()
		"hairpin":
			return TrackGen.hairpin(sign)
		_:
			return TrackGen.bend(75.0 * sign)


## A crate of `count` random picks (repeats allowed). With `track_cards`
## on, there's always at least one card that reshapes the track.
static func random_crate(count: int, rng: RandomNumberGenerator, track_cards := true) -> Array:
	var all := []
	var tracks := []
	for id in ids():
		if is_track(id):
			tracks.append(id)
			if not track_cards:
				continue
		all.append(id)
	var crate := []
	for i in count:
		crate.append(all[rng.randi_range(0, all.size() - 1)])
	if track_cards:
		var has_track := false
		for id in crate:
			has_track = has_track or is_track(id)
		if not has_track:
			crate[rng.randi_range(0, count - 1)] = tracks[rng.randi_range(0, tracks.size() - 1)]
	return crate
