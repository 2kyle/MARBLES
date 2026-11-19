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
		"about": "Kicks marbles sideways",
		"scene": "res://scenes/pieces/bumper_post.tscn",
		"kind": "piece", "radius": 0.45, "base_rotation": 0.0,
	},
	"angled_rail": {
		"name": "Angled rail",
		"about": "Turns marbles",
		"scene": "res://scenes/pieces/angled_rail.tscn",
		"kind": "piece", "radius": 1.0, "base_rotation": 45.0,
	},
	"ramp_jump": {
		"name": "Ramp jump",
		"about": "Launches marbles",
		"scene": "res://scenes/pieces/ramp_jump.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
	},
	"carpet_strip": {
		"name": "Carpet strip",
		"about": "Slows marbles down",
		"scene": "res://scenes/pieces/carpet_strip.tscn",
		"kind": "piece", "radius": 0.75, "base_rotation": 0.0,
	},
	"booster_pad": {
		"name": "Booster pad",
		"about": "Speed boost",
		"scene": "res://scenes/pieces/booster_pad.tscn",
		"kind": "piece", "radius": 0.7, "base_rotation": 0.0,
	},
	"spinner": {
		"name": "Spinner",
		"about": "Swats marbles",
		"scene": "res://scenes/pieces/spinner.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"gutter_cut": {
		"name": "Gutter cut",
		"about": "Fall in, you're out",
		"scene": "res://scenes/pieces/gutter_cut.tscn",
		"kind": "piece", "radius": 0.6, "base_rotation": 0.0,
	},
	"curve": {
		"name": "Curve Wall",
		"about": "Swings marbles across",
		"scene": "res://scenes/pieces/curve.tscn",
		"kind": "piece", "radius": 0.9, "base_rotation": 0.0,
	},
	"drop_step": {
		"name": "Ledge",
		"about": "Ledge with a drop",
		"scene": "res://scenes/pieces/drop_step.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"hump": {
		"name": "Hump",
		"about": "Tosses marbles up",
		"scene": "res://scenes/pieces/hump.tscn",
		"kind": "piece", "radius": 1.0, "base_rotation": 0.0,
	},
	"washboard": {
		"name": "Washboard",
		"about": "Bumpy and skiddy",
		"scene": "res://scenes/pieces/washboard.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
	},
	"tilt_table": {
		"name": "Tilt table",
		"about": "Rocks side to side",
		"scene": "res://scenes/pieces/tilt_table.tscn",
		"kind": "piece", "radius": 1.2, "base_rotation": 0.0,
	},
	"track_bend": {
		"name": "Track Bend",
		"about": "Bends the track",
		"turns": true,
		"scene": "res://scenes/pieces/track_bend.tscn",
		"kind": "track", "segment": "bend", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_drop": {
		"name": "Cliff Drop",
		"about": "Adds a steep drop",
		"scene": "res://scenes/pieces/track_drop.tscn",
		"kind": "track", "segment": "drop", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_hairpin": {
		"name": "Hairpin",
		"about": "Adds a U-turn",
		"turns": true,
		"scene": "res://scenes/pieces/track_hairpin.tscn",
		"kind": "track", "segment": "hairpin", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_gap": {
		"name": "Gap Jump",
		"about": "A gap to hop over",
		"scene": "res://scenes/pieces/track_gap.tscn",
		"kind": "track", "segment": "gap", "radius": 1.6, "base_rotation": 0.0,
	},
	"bomb": {
		"name": "Bomb",
		"about": "Blows up pieces",
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


## Track cards that bend left or right (the rotate key flips them).
static func turns(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].get("turns", false)


## Which way a turning track card goes for a cursor angle (0 = left,
## 180 = right).
static func turns_left(angle: float) -> bool:
	return fposmod(angle, 360.0) < 90.0 or fposmod(angle, 360.0) >= 270.0


static func is_track(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].kind == "track"


## The new stretch of track a track card adds, turning left or right.
static func track_segment(id: String, turn_left: bool) -> Dictionary:
	var sign := 1.0 if turn_left else -1.0
	match PIECES[id].segment:
		"drop":
			return TrackGen.drop()
		"gap":
			return TrackGen.gap()
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
