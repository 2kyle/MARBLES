class_name LootCrates
extends RefCounted
## Loot crates: the only way to get new marble looks. A crate costs coins
## and gives one thing:
##   - 1% of the time: the Golden Marble Trophy (ultra rare)
##   - 15%: a pile of coins
##   - the rest: a look (hat, ball colour, style or trail), picked by rarity
## A look you already own pays out coins instead (more for rarer looks).
## Tune the numbers below to make crates kinder or meaner.

const PRICE := 100
const TROPHY_CHANCE := 0.01
const COIN_CHANCE := 0.15
## How likely each rarity is when a crate gives a look (out of 100).
const RARITY_WEIGHTS := {"common": 55.0, "rare": 28.0, "epic": 13.0, "legendary": 4.0}
## Coin prizes and how likely each is.
const COIN_PRIZES := [[50, 45.0], [80, 30.0], [120, 17.0], [200, 8.0]]
## Coins paid back for a look you already have.
const DUPLICATE_COINS := {"common": 25, "rare": 45, "epic": 80, "legendary": 150, "ultra": 500}


## Pick what's in a crate (doesn't touch any profile). Returns
## {kind: "trophy"} / {kind: "coins", amount} / {kind: "item", slot, item}.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var r := rng.randf()
	if r < TROPHY_CHANCE:
		return {"kind": "trophy", "slot": "trophy", "item": Cosmetics.TROPHY, "rarity": "ultra"}
	if r < TROPHY_CHANCE + COIN_CHANCE:
		var amount: int = _weighted(rng, COIN_PRIZES.map(func(c): return c[1]), COIN_PRIZES.map(func(c): return c[0]))
		return {"kind": "coins", "amount": amount, "rarity": "common"}
	var rarity: String = _weighted(rng, RARITY_WEIGHTS.values(), RARITY_WEIGHTS.keys())
	var pool := Cosmetics.crate_pool(rarity)
	var pick: Array = pool[rng.randi() % pool.size()]
	return {"kind": "item", "slot": pick[0], "item": pick[1], "rarity": rarity}


## Buy and open a crate for a seat. Returns the prize (as roll() does,
## plus "duplicate" and "coins_back"), or {} if the seat can't afford one.
## The caller saves the profiles.
static func open(profiles: Profiles, seat: int, rng: RandomNumberGenerator) -> Dictionary:
	if profiles.coins(seat) < PRICE:
		return {}
	profiles.add_coins(seat, -PRICE)
	var prize := roll(rng)
	prize.duplicate = false
	prize.coins_back = 0
	match prize.kind:
		"coins":
			profiles.add_coins(seat, prize.amount)
		_:
			if not profiles.grant(seat, prize.slot, prize.item.id):
				prize.duplicate = true
				prize.coins_back = DUPLICATE_COINS.get(prize.rarity, 25)
				profiles.add_coins(seat, prize.coins_back)
	return prize


static func _weighted(rng: RandomNumberGenerator, weights: Array, values: Array):
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0.0:
			return values[i]
	return values[values.size() - 1]
