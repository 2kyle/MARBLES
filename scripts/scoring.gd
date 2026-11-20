class_name Scoring
extends RefCounted
## Pure scoring rules for one frame. No nodes, no physics: give it what
## happened and it returns the points. Keeping this separate means the host
## can run it later in online play, and it is easy to test on its own.
##
## Rules (from the design doc):
##   +1  each pin your marble knocked down (chain hits count for whoever
##       touched the first pin in the chain)
##   +5  clean sweep: you knocked down the last pin standing
##   +3 / +2 / +1  race bonus for 1st / 2nd / 3rd marble to reach the pins
##   +2  your piece knocked another player's marble out (e.g. a gutter cut)
## Balance rules:
##   Too easy: if every marble reaches the pins, nobody gets the race bonus.
##   Too hard: if no marble reaches the pins, the frame scores nothing.

const RACE_BONUS := [3, 2, 1]
const SWEEP_BONUS := 5
const KNOCKOUT_BONUS := 2


## player_count: number of marbles in the frame.
## arrival_order: player ids in the order they reached the pins.
## fallen_pin_credits: one entry per fallen pin, the player id credited
##     with it, or -1 if no marble is credited.
## sweep_player: player id that knocked down the last pin, or -1.
## knockouts: one entry per marble knocked out by someone else's piece,
##     the player id who placed that piece.
##
## Returns a Dictionary:
##   "points": Array[int], total frame points per player
##   "pins": Array[int], pin points per player
##   "race": Array[int], race bonus per player
##   "sweep": Array[int], sweep bonus per player
##   "knockouts": Array[int], knockout bonus per player
##   "note": String, a short explanation for the scoreboard
static func score_frame(player_count: int, arrival_order: Array,
		fallen_pin_credits: Array, sweep_player: int, knockouts: Array = []) -> Dictionary:
	var pins := _zeros(player_count)
	var race := _zeros(player_count)
	var sweep := _zeros(player_count)
	var ko := _zeros(player_count)
	var note := ""

	if arrival_order.is_empty():
		note = "Nobody made it!"
		return _result(player_count, pins, race, sweep, ko, note)

	for id in knockouts:
		if id >= 0 and id < player_count:
			ko[id] += KNOCKOUT_BONUS

	for credit in fallen_pin_credits:
		if credit >= 0 and credit < player_count:
			pins[credit] += 1

	if sweep_player >= 0 and sweep_player < player_count:
		sweep[sweep_player] = SWEEP_BONUS

	if arrival_order.size() >= player_count:
		note = "Everyone made it. No race bonus."
	else:
		for i in mini(arrival_order.size(), RACE_BONUS.size()):
			var id: int = arrival_order[i]
			if id >= 0 and id < player_count:
				race[id] = RACE_BONUS[i]

	return _result(player_count, pins, race, sweep, ko, note)


## Each player's finishing place (0 = 1st) from match totals. Ties share
## the better place, so two players on top are both 1st.
static func places(totals: Array) -> Array:
	var out := []
	for t in totals:
		var better := 0
		for o in totals:
			if o > t:
				better += 1
		out.append(better)
	return out


## The coins each player earns over a whole match, broken down for the
## coins screen. `pins` and `bonus` are match totals per player (bonus is
## race, sweep and knockout points). Returns one Dictionary per player:
##   pins, pin_coins, bonus, place (0 = 1st), place_coins, finish, total
static func match_coins(pins: Array, bonus: Array, totals: Array) -> Array:
	var place := places(totals)
	var out := []
	for i in totals.size():
		var row := {
			"pins": pins[i], "pin_coins": pins[i] * Profiles.COINS_PER_PIN,
			"bonus": bonus[i],
			"place": place[i], "place_coins": Profiles.COINS_FOR_PLACE[mini(place[i], 3)],
			"finish": Profiles.COINS_FOR_FINISHING,
		}
		row.total = row.pin_coins + row.bonus + row.place_coins + row.finish
		out.append(row)
	return out


static func _result(player_count: int, pins: Array, race: Array,
		sweep: Array, ko: Array, note: String) -> Dictionary:
	var points := _zeros(player_count)
	for i in player_count:
		points[i] = pins[i] + race[i] + sweep[i] + ko[i]
	return {"points": points, "pins": pins, "race": race, "sweep": sweep,
			"knockouts": ko, "note": note}


static func _zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a
