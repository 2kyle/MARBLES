class_name DailyChallenge
extends RefCounted
## DAILY CHALLENGE: one track a day, the same for everyone.
##
## The day's date ("2026-11-25") is turned into a number (the "seed"), and
## that number picks everything: the track's shape, the world, the lane
## width, the scenery, a few pieces already sitting on the lane, and even
## which pieces turn up in each frame's crate. So everyone who plays on the
## same day gets the same challenge, and tomorrow brings a new one.
##
## You can roll it as often as you like that day: your best score is kept
## (per player seat) and shown as the score to beat. Playing on days in a
## row builds up a STREAK.
##
## main.gd asks plan() for the day's track and pieces; the menu shows what
## best_today() and streak() say.

## Where the best scores and streaks are saved. (Tests point this at a
## file of their own.)
static var save_path := "user://daily.cfg"

## Frames in a daily challenge (short, so it's a quick daily go).
const FRAMES := 5
## How many pieces are already on the lane when it starts.
const PIECES_PLACED := 3
## Pieces that can be on the lane from the start. Simple ones only: no
## track cards, bombs, teleporters or gutter cuts.
const STARTER_PIECES := [
	"bumper_post", "angled_rail", "ramp_jump", "booster_pad", "spinner",
	"hump", "washboard", "pop_bumper", "pendulum", "magnet", "bounce_pad",
	"curve", "drop_step", "tilt_table",
]
## Lane widths the day can pick from (the same range as a normal match).
const WIDTHS := Vector2(4.2, 6.6)
## Players with a saved best (one per seat at this computer).
const SEATS := 4

## best[date][seat] = best total score that day.
var best := {}
## Per seat: the last date they played, and how many days in a row.
var last_day: Array = ["", "", "", ""]
var streak_days: Array = [0, 0, 0, 0]


## Today's date on this computer, like "2026-11-25".
static func today() -> String:
	return Time.get_date_string_from_system()


## A short, friendly version of a date for the screen: "NOV 25".
static func pretty(key: String) -> String:
	var parts := key.split("-")
	if parts.size() != 3:
		return key
	const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	var m := clampi(int(parts[1]), 1, 12)
	return "%s %d" % [MONTHS[m - 1], int(parts[2])]


## The number that picks everything for a day.
static func seed_for(key: String) -> int:
	return ("marbles-daily-" + key).hash()


## Everything about a day's challenge, worked out from its date alone:
##   layout, decor_seed, theme, width: the track and world
##   pieces: [{id, along (0 top of the lane .. 1 bottom), x (-1 .. 1), angle}]
##   crate_seed: seeds the crates, so they're the same for everyone too
static func plan(key: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(key)
	var layout := TrackGen.random_layout(rng)
	var decor_seed := rng.randi()
	var theme := Arena.random_theme(rng)
	var width := snappedf(rng.randf_range(WIDTHS.x, WIDTHS.y), 0.1)
	var pieces := []
	for i in PIECES_PLACED:
		pieces.append({
			"id": STARTER_PIECES[rng.randi_range(0, STARTER_PIECES.size() - 1)],
			# Spread down the lane: one in each third, somewhere in it.
			"along": (i + rng.randf_range(0.25, 0.75)) / PIECES_PLACED,
			"x": rng.randf_range(-0.8, 0.8),
			"angle": rng.randi_range(-3, 3) * 15.0,
		})
	return {
		"layout": layout, "decor_seed": decor_seed, "theme": theme, "width": width,
		"pieces": pieces, "crate_seed": rng.randi(),
	}


## Put a plan's pieces on the lane. Each one goes to the closest free spot
## to where the plan wants it. Returns how many went down.
static func place_pieces(builder: CourseBuilder, pieces: Array) -> int:
	var top := builder.top_z
	var bottom := builder.bottom_z()
	var count := 0
	for p in pieces:
		var z := lerpf(top, bottom, p.along)
		# Big pieces (a magnet) may not fit off to the side or turned, so
		# try nearer the middle, then straight on, before giving up.
		for tries in [[p.x, p.angle], [p.x * 0.4, p.angle], [0.0, 0.0]]:
			var want := builder.clamp_pos(Vector2(tries[0] * builder.half_width, z))
			var spot = builder.nearest_free(p.id, want, tries[1])
			if spot != null and builder.place(p.id, spot, tries[1], -1):
				count += 1
				break
	return count


# ------------------------------------------------------------ Scores

func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	best = cfg.get_value("scores", "best", {})
	last_day = cfg.get_value("streak", "last_day", ["", "", "", ""])
	streak_days = cfg.get_value("streak", "days", [0, 0, 0, 0])
	while last_day.size() < SEATS:
		last_day.append("")
	while streak_days.size() < SEATS:
		streak_days.append(0)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best)
	cfg.set_value("streak", "last_day", last_day)
	cfg.set_value("streak", "days", streak_days)
	cfg.save(save_path)


## A seat's best score on day `key`, or -1 if they haven't played it.
func best_on(key: String, seat: int) -> int:
	var day: Dictionary = best.get(key, {})
	return int(day.get(seat, -1))


## Days in a row a seat has played (0 if their streak has run out).
func streak(seat: int, key := today()) -> int:
	var last: String = last_day[seat]
	if last == key or last == _day_before(key):
		return streak_days[seat]
	return 0


## A seat finished the day's challenge with `score`. Updates their streak
## and returns true if it's their new best for that day.
func record(key: String, seat: int, score: int) -> bool:
	if last_day[seat] != key:
		streak_days[seat] = streak_days[seat] + 1 if last_day[seat] == _day_before(key) else 1
		last_day[seat] = key
	var old := best_on(key, seat)
	if score <= old:
		return false
	var day: Dictionary = best.get(key, {})
	day[seat] = score
	best[key] = day
	# Only keep the last couple of months of days.
	var keys := best.keys()
	keys.sort()
	while keys.size() > 60:
		best.erase(keys.pop_front())
	return true


## The date before `key` ("2026-03-01" -> "2026-02-28").
static func _day_before(key: String) -> String:
	var t := Time.get_unix_time_from_datetime_string(key + "T12:00:00")
	return Time.get_date_string_from_unix_time(t - 86400)
