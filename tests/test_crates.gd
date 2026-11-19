extends SceneTree
## Opens lots of loot crates and checks the odds come out right:
## about 1% trophies, 15% coins, the rest looks in the right rarity mix,
## and that every look in the game can come out of a crate.
## Run: godot --headless --script res://tests/test_crates.gd

var failures := 0


func check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var n := 100000
	var kinds := {"trophy": 0, "coins": 0, "item": 0}
	var rarities := {}
	var seen := {}
	for i in n:
		var prize := LootCrates.roll(rng)
		kinds[prize.kind] += 1
		if prize.kind == "item":
			rarities[prize.rarity] = rarities.get(prize.rarity, 0) + 1
			seen[prize.slot + ":" + prize.item.id] = true
	var trophy: float = kinds.trophy * 100.0 / n
	var coins: float = kinds.coins * 100.0 / n
	check("trophy about 1%% (%.2f%%)" % trophy, absf(trophy - 1.0) < 0.2)
	check("coins about 15%% (%.1f%%)" % coins, absf(coins - 15.0) < 1.0)
	check("looks are the most common prize (%.1f%%)" % (kinds.item * 100.0 / n), kinds.item > kinds.coins * 4)
	var total := 0.0
	for w in LootCrates.RARITY_WEIGHTS.values():
		total += w
	for r in LootCrates.RARITY_WEIGHTS:
		var want: float = LootCrates.RARITY_WEIGHTS[r] / total * 100.0
		var got: float = rarities.get(r, 0) * 100.0 / kinds.item
		check("%s about %.0f%% of looks (%.1f%%)" % [r, want, got], absf(got - want) < 1.5)
	# Every non-starter look must be winnable.
	var missing := []
	for slot in Cosmetics.SLOTS:
		for it in Cosmetics.items(slot):
			if it.rarity != "starter" and not seen.has(slot + ":" + it.id):
				missing.append(slot + ":" + it.id)
	check("every look can come from a crate (missing: %s)" % [missing], missing.is_empty())

	# Opening crates on a profile: pays, grants, refunds duplicates.
	var prof := Profiles.new()
	prof.seats[0].coins = 100000
	var before: int = prof.seats[0].owned.size()
	var dupes := 0
	for i in 400:
		var prize := LootCrates.open(prof, 0, rng)
		if prize.duplicate:
			dupes += 1
	check("crates add looks (%d -> %d owned)" % [before, prof.seats[0].owned.size()], prof.seats[0].owned.size() > before + 20)
	check("duplicates happen and pay back (%d)" % dupes, dupes > 0)
	prof.seats[1].coins = LootCrates.PRICE - 1
	check("can't open a crate without enough coins", LootCrates.open(prof, 1, rng).is_empty())
	check("hats owned by default: just 'none'", prof.owns(1, "hat", "none") and not prof.owns(1, "hat", "crown"))
	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
