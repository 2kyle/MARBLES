class_name PieceCatalog
extends RefCounted
## Everything players can draft. To add a piece: make its scene in
## scenes/pieces/, then add an entry here.
##
## kind: "piece" stays on the lane; "bomb" is a one-shot item that blows up
##     placed pieces near where it lands; "track" is a TA (track-altering
##     card): it reshapes the track itself where it's dropped (the scene is
##     only its picture). TAs and pieces share the same draft pool.
## spins: true if the whole piece turns round (its footprint is a circle).
## sweep: how far a moving part reaches from the centre (before scaling).
## radius: rough size in metres (bots and the bomb's blast use it). The
##     real footprint that stops pieces overlapping each other or the walls
##     is measured from the scene itself (CourseBuilder.footprint()).
## base_rotation: degrees the piece starts turned before the player rotates
##     it (the angled rail starts diagonal).

const PIECES := {
	"bumper_post": {
		"name": "Bumper post",
		"about": "Kicks balls sideways",
		"scene": "res://scenes/pieces/bumper_post.tscn",
		"kind": "piece", "radius": 0.63, "base_rotation": 0.0,
	},
	"angled_rail": {
		"name": "Angled rail",
		"about": "Turns balls",
		"scene": "res://scenes/pieces/angled_rail.tscn",
		"kind": "piece", "radius": 1.4, "base_rotation": 45.0,
	},
	"ramp_jump": {
		"name": "Ramp jump",
		"about": "Launches balls",
		"scene": "res://scenes/pieces/ramp_jump.tscn",
		"kind": "piece", "radius": 1.54, "base_rotation": 0.0,
	},
	"carpet_strip": {
		"name": "Carpet strip",
		"about": "Slows balls down",
		"scene": "res://scenes/pieces/carpet_strip.tscn",
		"kind": "piece", "radius": 1.05, "base_rotation": 0.0,
	},
	"booster_pad": {
		"name": "Booster pad",
		"about": "Speed boost",
		"scene": "res://scenes/pieces/booster_pad.tscn",
		"kind": "piece", "radius": 0.98, "base_rotation": 0.0,
		"aimed": true,
	},
	"spinner": {
		"name": "Spinner",
		"about": "Swats balls",
		"scene": "res://scenes/pieces/spinner.tscn",
		"kind": "piece", "radius": 1.68, "base_rotation": 0.0,
		"spins": true,
	},
	"gutter_cut": {
		"name": "Gutter cut",
		"about": "Fall in, you're out",
		"scene": "res://scenes/pieces/gutter_cut.tscn",
		"kind": "piece", "radius": 0.84, "base_rotation": 0.0,
	},
	"curve": {
		"name": "Curve Wall",
		"about": "Swings balls across",
		"scene": "res://scenes/pieces/curve.tscn",
		"kind": "piece", "radius": 1.26, "base_rotation": 0.0,
	},
	"drop_step": {
		"name": "Ledge",
		"about": "Ledge with a drop",
		"scene": "res://scenes/pieces/drop_step.tscn",
		"kind": "piece", "radius": 1.68, "base_rotation": 0.0,
	},
	"hump": {
		"name": "Hump",
		"about": "Tosses balls up",
		"scene": "res://scenes/pieces/hump.tscn",
		"kind": "piece", "radius": 1.4, "base_rotation": 0.0,
	},
	"washboard": {
		"name": "Washboard",
		"about": "Bumpy and skiddy",
		"scene": "res://scenes/pieces/washboard.tscn",
		"kind": "piece", "radius": 1.54, "base_rotation": 0.0,
	},
	"tilt_table": {
		"name": "Tilt table",
		"about": "Rocks side to side",
		"scene": "res://scenes/pieces/tilt_table.tscn",
		"kind": "piece", "radius": 1.68, "base_rotation": 0.0,
	},
	"pop_bumper": {
		"name": "Pop Bumper",
		"about": "Pinball kick, any way",
		"scene": "res://scenes/pieces/pop_bumper.tscn",
		"kind": "piece", "radius": 0.75, "base_rotation": 0.0,
	},
	"pendulum": {
		"name": "Pendulum",
		"about": "Swings across the lane",
		"scene": "res://scenes/pieces/pendulum.tscn",
		"kind": "piece", "radius": 1.6, "base_rotation": 0.0,
		# The ball swings (rod + ball) * sin(58 degrees) either side.
		"sweep": Vector2(1.63, 0.0),
	},
	"magnet": {
		"name": "Magnet",
		"about": "Drags balls in",
		"scene": "res://scenes/pieces/magnet.tscn",
		"kind": "piece", "radius": 1.5, "base_rotation": 0.0,
	},
	"bounce_pad": {
		"name": "Bounce Pad",
		"about": "Springs balls high",
		"scene": "res://scenes/pieces/bounce_pad.tscn",
		"kind": "piece", "radius": 0.95, "base_rotation": 0.0,
	},
	"loop_de_loop": {
		"name": "Loop-de-Loop",
		"about": "Round and upside down",
		"scene": "res://scenes/pieces/loop_de_loop.tscn",
		"kind": "piece", "radius": 1.5, "base_rotation": 0.0,
		"new": true,
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
	"teleporter": {
		"name": "Teleporter",
		"about": "Warps balls to its exit",
		"scene": "res://scenes/pieces/teleporter.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
		"parts": 2,
	},
	"teleporter_exit": {
		"name": "Teleporter exit",
		"about": "Where warped balls come out",
		"scene": "res://scenes/pieces/teleporter.tscn",
		"kind": "piece", "radius": 1.1, "base_rotation": 0.0,
		"hidden": true,
		"aimed": true,
	},
	"wind_fan": {
		"name": "Wind Fan",
		"about": "Blows balls along",
		"scene": "res://scenes/pieces/wind_fan.tscn",
		"kind": "piece", "radius": 1.7, "base_rotation": 90.0,
		"aimed": true,
	},
	"track_open": {
		"name": "Wall Breaker",
		"about": "Knocks the walls off",
		"scene": "res://scenes/pieces/track_open.tscn",
		"kind": "track", "segment": "open", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_sbend": {
		"name": "S-Bend",
		"about": "Wiggles left, then right",
		"turns": true,
		"scene": "res://scenes/pieces/track_sbend.tscn",
		"kind": "track", "segment": "sbend", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_narrow": {
		"name": "Narrow Bridge",
		"about": "A thin plank, no walls",
		"scene": "res://scenes/pieces/track_narrow.tscn",
		"kind": "track", "segment": "narrow", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_oil": {
		"name": "Oil Slick",
		"about": "Fresh lane oil, no grip",
		"scene": "res://scenes/pieces/track_oil.tscn",
		"kind": "track", "segment": "oil", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_zigzag": {
		"name": "Zig-Zag",
		"about": "Left, right, left!",
		"turns": true,
		"scene": "res://scenes/pieces/track_zigzag.tscn",
		"kind": "track", "segment": "zigzag", "radius": 1.6, "base_rotation": 0.0,
	},
	"track_hill": {
		"name": "Rollercoaster Hill",
		"about": "Up and over, keep speed",
		"scene": "res://scenes/pieces/track_hill.tscn",
		"kind": "track", "segment": "hill", "radius": 1.6, "base_rotation": 0.0,
	},
	"bomb": {
		"name": "Bomb",
		"about": "Blows up pieces",
		"scene": "res://scenes/pieces/bomb.tscn",
		"kind": "bomb", "radius": 1.6, "base_rotation": 0.0,
	},
}


## How much bigger pieces are built than their scenes (scenes were made
## small; 1.4 makes them matter more on the track). Footprint radii above
## already include it.
const PIECE_SCALE := 1.4
## How far a Wall Breaker takes the walls off, in metres of track.
const OPEN_LENGTH := 10.0


## Every piece that can turn up in a crate.
static func ids() -> Array:
	var out := []
	for id in PIECES:
		if not PIECES[id].get("hidden", false):
			out.append(id)
	return out


## How much to scale a piece's scene when it's placed.
static func scale_of(id: String) -> float:
	return PIECE_SCALE if PIECES.has(id) and PIECES[id].kind == "piece" else 1.0


## Pieces that push or send balls a set way (booster, fan, teleporter
## exit). Their floor arrows point the way they push, not down the track.
static func aimed(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].get("aimed", false)


## Pieces placed in two parts (teleporter: entry, then exit).
static func parts(id: String) -> int:
	return PIECES[id].get("parts", 1) if PIECES.has(id) else 1


## Short tag for cards and labels. Track-altering cards (we call them TAs
## for short) say "TRACK ALTERING" in the game.
static func tag(id: String) -> String:
	if is_track(id):
		return "TRACK ALTERING"
	if is_bomb(id):
		return "ITEM"
	return ""


## Pieces added in the latest update: their draft cards get a NEW! sticker.
## (Delete "new": true from an entry once everyone's used to it.)
static func is_new(id: String) -> bool:
	return PIECES.has(id) and PIECES[id].get("new", false)


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


## The new stretch of track a track card adds, turning left or right: one
## TrackGen segment, or an Array of them (the S-Bend is two bends).
static func track_segment(id: String, turn_left: bool) -> Variant:
	var sign := 1.0 if turn_left else -1.0
	match PIECES[id].segment:
		"sbend":
			return TrackGen.s_bend(sign)
		"zigzag":
			return TrackGen.zigzag(sign)
		"hill":
			return TrackGen.hill()
		"oil":
			return TrackGen.oil()
		"narrow":
			return TrackGen.narrow()
		"drop":
			return TrackGen.drop()
		"gap":
			return TrackGen.gap()
		"open":
			return {"len": OPEN_LENGTH, "open": true}
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
