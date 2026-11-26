class_name MatchAwards
extends RefCounted
## Fun awards at the end of a match, shown just before the podium:
##   STRIKE KING   most strikes
##   PIN CRUSHER   most pins knocked down in one roll
##   SPEED DEMON   fastest marble to reach the pins
##   DEMOLITION    most placed pieces blown up with bombs
##   TRAPPER       most rival marbles trapped off the track (see Traps)
##
## Like Scoring, this is plain rules with no nodes: main.gd tells it what
## happened each frame and asks for the awards at the end. That keeps it
## easy to test on its own (tests/test_match_awards.gd).
##
## An award only shows if someone actually earned it (no strikes this
## match, no STRIKE KING). Players who tie share it.

## The awards, in the order they're shown.
const AWARDS := [
	{"id": "strikes", "title": "STRIKE KING", "about": "Most strikes"},
	{"id": "best_roll", "title": "PIN CRUSHER", "about": "Most pins in one roll"},
	{"id": "fastest", "title": "SPEED DEMON", "about": "Fastest to the pins"},
	{"id": "blown_up", "title": "DEMOLITION", "about": "Most pieces blown up"},
	{"id": "trapped", "title": "TRAPPER", "about": "Most rivals trapped"},
]

var strikes: Array = [0, 0, 0, 0]
var best_roll: Array = [0, 0, 0, 0]
## Seconds from the start gate to the pins, best roll (INF = never got there).
var fastest: Array = [INF, INF, INF, INF]
var blown_up: Array = [0, 0, 0, 0]
var trapped: Array = [0, 0, 0, 0]


## A new match: everything back to zero.
func reset() -> void:
	strikes = [0, 0, 0, 0]
	best_roll = [0, 0, 0, 0]
	fastest = [INF, INF, INF, INF]
	blown_up = [0, 0, 0, 0]
	trapped = [0, 0, 0, 0]


## One frame is over. `pins`: pins each player knocked down this roll.
## `striker`: who got a strike (-1 = nobody). `finish_times`: player id ->
## seconds it took their marble to reach the pins (only those who made it).
func record_frame(pins: Array, striker: int, finish_times: Dictionary) -> void:
	for p in mini(pins.size(), 4):
		best_roll[p] = maxi(best_roll[p], pins[p])
	if striker >= 0 and striker < 4:
		strikes[striker] += 1
	for p in finish_times:
		if p >= 0 and p < 4:
			fastest[p] = minf(fastest[p], finish_times[p])


## `player`'s bomb blew up `count` pieces.
func record_blast(player: int, count: int) -> void:
	if player >= 0 and player < 4:
		blown_up[player] += count


## `player` trapped a rival's marble off the track.
func record_trap(player: int) -> void:
	if player >= 0 and player < 4:
		trapped[player] += 1


## The awards earned this match, in show order. Each is a Dictionary:
##   title, about: the award's name and what it's for
##   players: who won it (more than one on a tie)
##   detail: the winning number in words, e.g. "3 STRIKES" or "12.4 SECONDS"
## Online, the host works these out and sends them to everyone.
func results(player_count: int) -> Array:
	var out := []
	for a in AWARDS:
		var values: Array = get(a.id).slice(0, player_count)
		var lowest_wins: bool = a.id == "fastest"
		var best = values.min() if lowest_wins else values.max()
		if values.is_empty() or (lowest_wins and best == INF) or (not lowest_wins and best <= 0):
			continue
		var winners := []
		for p in values.size():
			if values[p] == best:
				winners.append(p)
		out.append({"title": a.title, "about": a.about, "players": winners,
				"detail": _detail(a.id, best)})
	return out


static func _detail(id: String, value) -> String:
	match id:
		"strikes":
			return "%d STRIKE%s" % [value, "" if value == 1 else "S"]
		"best_roll":
			return "%d PIN%s" % [value, "" if value == 1 else "S"]
		"fastest":
			return "%.1f SECONDS" % value
		"blown_up":
			return "%d PIECE%s" % [value, "" if value == 1 else "S"]
		"trapped":
			return "%d TRAP%s" % [value, "" if value == 1 else "S"]
	return str(value)
