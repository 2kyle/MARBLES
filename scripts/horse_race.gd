class_name HorseRace
extends Node3D
## MARBLE DERBY: a little betting game on the practice island. Four marble
## "horses" race down a straight four-lane track. Players roll onto the
## betting plate, pick a horse, wager some of their coins and watch.
##
## Each race the horses get a random form (how fast they tend to be), and
## the odds come from that: a favourite pays less, a long shot pays more.
## Winners get their wager times the odds back; losers lose their wager.
##
## Like the rest of the game, this never reads the keyboard. main.gd calls
## the request_* functions for each player.

enum Phase { OPEN, CALL, RACING, FINISHED }

const HORSES := [
	{"name": "Frank", "color": Color(0.35, 0.55, 1.0)},
	{"name": "Trunk", "color": Color(1.0, 0.55, 0.75)},
	{"name": "Fatty", "color": Color(1.0, 0.75, 0.3)},
	{"name": "Jakob", "color": Color(0.55, 0.9, 0.45)},
]
const LENGTH := 20.0
const LANE_W := 1.1
const HORSE_R := 0.32
## Seconds between the first bet and the start, so others can join in.
const CALL_TIME := 6.0
const RESULT_TIME := 5.0
const WAGER_STEP := 10
const MIN_WAGER := 10
## The house keeps a little: odds pay back 90% on average.
const PAYBACK := 0.9
const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")

var profiles: Profiles
var phase := Phase.OPEN
## How good each horse is this race (0..1) and what it pays if it wins.
var form: Array = [0.5, 0.5, 0.5, 0.5]
var odds: Array = [4.0, 4.0, 4.0, 4.0]
## What each player is looking at in the betting panel.
var pick: Array = [0, 0, 0, 0]
var wager: Array = [20, 20, 20, 20]
## Bets placed this race: player -> {horse, amount}.
var bets := {}
## A line of news for each player ("Bet placed!", "You won 60!").
var message: Array = ["", "", "", ""]
var winner := -1
var progress: Array = [0.0, 0.0, 0.0, 0.0]

var _speed: Array = [0.0, 0.0, 0.0, 0.0]
var _target: Array = [0.0, 0.0, 0.0, 0.0]
var _decide := 0.0
var _left := 0.0
var _rng := RandomNumberGenerator.new()
var _horses: Array = []   # [Node3D body, MeshInstance3D ball]
var _board: Label3D
var _gate: Node3D


func _ready() -> void:
	_rng.randomize()
	_build()
	_new_race()


# ------------------------------------------------------------ Requests

func request_pick(p: int, step: int) -> void:
	if bets.has(p):
		return
	pick[p] = wrapi(pick[p] + step, 0, HORSES.size())
	message[p] = ""


func request_wager(p: int, step: int) -> void:
	if bets.has(p) or profiles == null:
		return
	var most := maxi(profiles.coins(p), MIN_WAGER)
	wager[p] = clampi(wager[p] + step * WAGER_STEP, MIN_WAGER, most)
	message[p] = ""


func request_bet(p: int) -> void:
	if profiles == null:
		return
	if bets.has(p):
		message[p] = "You're on %s!" % HORSES[bets[p].horse].name
		return
	if phase == Phase.RACING or phase == Phase.FINISHED:
		message[p] = "Wait for the next race"
		return
	if profiles.coins(p) < wager[p]:
		message[p] = "Not enough coins"
		return
	profiles.add_coins(p, -wager[p])
	profiles.save_to_disk()
	bets[p] = {"horse": pick[p], "amount": wager[p]}
	message[p] = "Bet placed!"
	if phase == Phase.OPEN:
		phase = Phase.CALL
		_left = CALL_TIME


## What the race is doing, for the top of the screen ("" when idle).
func status() -> String:
	match phase:
		Phase.CALL:
			return "BOWLING BALL DERBY  ·  Starting in %d" % ceili(_left)
		Phase.RACING:
			return "BOWLING BALL DERBY  ·  And they're off!"
		Phase.FINISHED:
			return "BOWLING BALL DERBY  ·  %s wins!" % HORSES[winner].name
	return ""


func horse_positions() -> Array:
	var out := []
	for h in _horses:
		out.append((h[0] as Node3D).global_position)
	return out


# ------------------------------------------------------------ Race

func update(delta: float) -> void:
	match phase:
		Phase.CALL:
			_left -= delta
			_gate.position.y = 0.0
			if _left <= 0.0:
				phase = Phase.RACING
				_decide = 0.0
		Phase.RACING:
			_gate.position.y = lerpf(_gate.position.y, 1.6, 1.0 - exp(-6.0 * delta))
			_run(delta)
		Phase.FINISHED:
			_left -= delta
			if _left <= 0.0:
				_new_race()
	for i in _horses.size():
		var body: Node3D = _horses[i][0]
		var ball: Node3D = _horses[i][1]
		var z: float = -progress[i]
		var bounce: float = absf(sin(progress[i] * 3.0)) * 0.12 if phase == Phase.RACING else 0.0
		body.position = Vector3(_lane_x(i), HORSE_R + bounce, z)
		ball.rotation.x = -progress[i] / HORSE_R


func _run(delta: float) -> void:
	_decide -= delta
	if _decide <= 0.0:
		_decide = 0.4
		for i in 4:
			_target[i] = _pick_speed(form[i], _rng)
	for i in 4:
		_speed[i] = lerpf(_speed[i], _target[i], 1.0 - exp(-3.0 * delta))
		progress[i] = minf(progress[i] + _speed[i] * delta, LENGTH)
	if winner < 0:
		var best := -1
		for i in 4:
			if progress[i] >= LENGTH and (best < 0 or _speed[i] > _speed[best]):
				best = i
		if best >= 0:
			winner = best
			_pay_out()
	if winner >= 0 and progress.min() >= LENGTH - 0.01:
		phase = Phase.FINISHED
		_left = RESULT_TIME
	# Let the others finish quickly once someone has won.
	if winner >= 0:
		for i in 4:
			progress[i] = minf(progress[i] + delta * 1.5, LENGTH)


## A horse's speed for the next moment: its form, plus luck, and now and
## then a stumble.
static func _pick_speed(f: float, rng: RandomNumberGenerator) -> float:
	if rng.randf() < 0.08:
		return 0.9
	return 2.3 + f * 0.25 + rng.randf_range(-1.1, 1.1)


func _pay_out() -> void:
	for p in bets:
		var bet: Dictionary = bets[p]
		if bet.horse == winner:
			var win := roundi(bet.amount * odds[winner])
			profiles.add_coins(p, win)
			message[p] = "%s won! +%d coins" % [HORSES[winner].name, win]
			Achievements.unlock("DERBY_WIN")
			if odds[winner] >= 5.0:
				Achievements.unlock("LONG_SHOT")
			if profiles.coins(p) >= 1000:
				Achievements.unlock("PIGGY_BANK")
		else:
			message[p] = "%s lost. -%d coins" % [HORSES[bet.horse].name, bet.amount]
	profiles.save_to_disk()


func _new_race() -> void:
	phase = Phase.OPEN
	bets.clear()
	winner = -1
	for i in 4:
		progress[i] = 0.0
		_speed[i] = 0.0
		form[i] = _rng.randf()
	_work_out_odds()
	for p in 4:
		if message[p].contains("won") or message[p].contains("lost"):
			continue  # keep last race's result on screen until they browse
		message[p] = ""
	_update_board()


## Run the race 400 times in our head to see how often each horse wins,
## then set fair-ish odds from that.
func _work_out_odds() -> void:
	var sim := RandomNumberGenerator.new()
	sim.seed = _rng.randi()
	var wins := [0, 0, 0, 0]
	var runs := 400
	var dt := 0.1
	for r in runs:
		var pos := [0.0, 0.0, 0.0, 0.0]
		var spd := [0.0, 0.0, 0.0, 0.0]
		var tgt := [0.0, 0.0, 0.0, 0.0]
		var t := 0.0
		var step := 0
		var done := -1
		while done < 0 and t < 30.0:
			if step % 4 == 0:
				for i in 4:
					tgt[i] = _pick_speed(form[i], sim)
			for i in 4:
				spd[i] = lerpf(spd[i], tgt[i], 1.0 - exp(-3.0 * dt))
				pos[i] += spd[i] * dt
				if pos[i] >= LENGTH and done < 0:
					done = i
			t += dt
			step += 1
		wins[maxi(done, 0)] += 1
	for i in 4:
		var chance := maxf(wins[i], 4.0) / runs
		odds[i] = clampf(snappedf(PAYBACK / chance, 0.5), 1.5, 12.0)


# ------------------------------------------------------------ Building

func _lane_x(i: int) -> float:
	return (i - 1.5) * LANE_W


func _build() -> void:
	var dirt := Color(0.72, 0.56, 0.38)
	var white := Color(0.97, 0.96, 0.92)
	# Track floor, lanes and rails.
	LowPoly.box(self, Vector3(LANE_W * 4 + 0.6, 0.1, LENGTH + 3.0), Vector3(0, 0.05, -LENGTH / 2.0), dirt)
	for k in 5:
		var x := (k - 2) * LANE_W
		LowPoly.box(self, Vector3(0.05, 0.02, LENGTH + 1.0), Vector3(x, 0.11, -LENGTH / 2.0), white)
	for side in [-1, 1]:
		var x: float = side * (LANE_W * 2 + 0.35)
		LowPoly.box(self, Vector3(0.1, 0.1, LENGTH + 3.0), Vector3(x, 0.75, -LENGTH / 2.0), white)
		for k in 9:
			LowPoly.box(self, Vector3(0.12, 0.8, 0.12), Vector3(x, 0.4, 1.4 - k * (LENGTH + 2.8) / 8.0), white)
		# The rail is solid, so marbles can't roll onto the race track.
		LowPoly.solid_box(self, Vector3(0.14, 0.85, LENGTH + 3.0), Vector3(x, 0.425, -LENGTH / 2.0))
	# Finish line (checkered) and a banner over it.
	for k in 16:
		for row in 2:
			LowPoly.box(self, Vector3(LANE_W * 4 / 16.0, 0.02, 0.25),
					Vector3(-LANE_W * 2 + (k + 0.5) * LANE_W * 4 / 16.0, 0.115, -LENGTH - 0.125 + row * 0.25),
					Color.BLACK if (k + row) % 2 == 0 else Color.WHITE)
	for side in [-1, 1]:
		LowPoly.box(self, Vector3(0.18, 3.0, 0.18), Vector3(side * (LANE_W * 2 + 0.6), 1.5, -LENGTH), white)
		LowPoly.solid_box(self, Vector3(0.18, 3.0, 0.18), Vector3(side * (LANE_W * 2 + 0.6), 1.5, -LENGTH))
	LowPoly.box(self, Vector3(LANE_W * 4 + 1.4, 0.6, 0.12), Vector3(0, 3.0, -LENGTH), Color(0.85, 0.2, 0.25))
	LowPoly.label(self, Vector3(0, 3.0, -LENGTH + 0.08), "FINISH", 70, Color(0.4, 0.05, 0.1))

	# Starting gate: a bar that lifts when the race starts.
	_gate = Node3D.new()
	add_child(_gate)
	LowPoly.box(_gate, Vector3(LANE_W * 4, 0.12, 0.12), Vector3(0, 0.5, -0.6), Color(1.0, 0.8, 0.25))
	for side in [-1, 1]:
		LowPoly.box(self, Vector3(0.2, 2.2, 0.2), Vector3(side * (LANE_W * 2 + 0.6), 1.1, -0.6), white)
		LowPoly.solid_box(self, Vector3(0.2, 2.2, 0.2), Vector3(side * (LANE_W * 2 + 0.6), 1.1, -0.6))

	# The horses: marbles with ears, a mane and a number.
	for i in 4:
		var h: Dictionary = HORSES[i]
		var body := Node3D.new()
		add_child(body)
		var ball := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = HORSE_R
		s.height = HORSE_R * 2.0
		ball.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = h.color
		m.roughness = 0.25
		m.metallic = 0.1
		ball.material_override = m
		body.add_child(ball)
		# A white stripe so you can see it roll.
		var stripe := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = HORSE_R - 0.02
		t.outer_radius = HORSE_R + 0.015
		stripe.mesh = t
		stripe.material_override = LowPoly.mat(Color.WHITE)
		stripe.rotation.z = PI / 2
		ball.add_child(stripe)
		for side in [-1, 1]:
			var ear := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.12, 0.18, 0.06)
			ear.mesh = pm
			ear.material_override = LowPoly.mat(h.color.darkened(0.3))
			ear.position = Vector3(side * 0.12, HORSE_R + 0.06, -0.08)
			body.add_child(ear)
		# Each name floats at its own height, so side by side they never overlap.
		var tag := LowPoly.label(self, Vector3(0, HORSE_R + 0.45 + i * 0.27, 0), "%d %s" % [i + 1, h.name], 26, h.color.darkened(0.5))
		tag.reparent(body, false)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_horses.append([body, ball])

	# Odds board beside the start, facing the plaza.
	var bx := LANE_W * 2 + 3.5
	LowPoly.box(self, Vector3(0.2, 4.6, 0.2), Vector3(bx - 1.6, 2.3, -1.5), Color(0.45, 0.3, 0.2))
	LowPoly.box(self, Vector3(0.2, 4.6, 0.2), Vector3(bx + 1.6, 2.3, -1.5), Color(0.45, 0.3, 0.2))
	LowPoly.box(self, Vector3(3.6, 2.2, 0.15), Vector3(bx, 3.5, -1.5), Color(0.12, 0.3, 0.2))
	for x in [bx - 1.6, bx + 1.6]:
		LowPoly.solid_box(self, Vector3(0.2, 4.6, 0.2), Vector3(x, 2.3, -1.5))
	_board = LowPoly.label(self, Vector3(bx, 3.5, -1.4), "", 30, Color(0.05, 0.15, 0.1))
	_board.pixel_size = 0.007
	LowPoly.label(self, Vector3(bx, 5.05, -1.4), "BALL DERBY", 64, Color(0.5, 0.25, 0.05))

	# A little stand of cheering spectators on the far side.
	var crowd := Node3D.new()
	add_child(crowd)
	for row in 3:
		LowPoly.box(self, Vector3(0.9, 0.3 + row * 0.35, LENGTH * 0.7),
				Vector3(-LANE_W * 2 - 1.3 - row * 0.9, (0.3 + row * 0.35) / 2.0, -LENGTH / 2.0), Color(0.6, 0.45, 0.3).lightened(row * 0.08))
		LowPoly.solid_box(self, Vector3(0.9, 0.3 + row * 0.35, LENGTH * 0.7),
				Vector3(-LANE_W * 2 - 1.3 - row * 0.9, (0.3 + row * 0.35) / 2.0, -LENGTH / 2.0))
		for k in 10:
			var fan := MeshInstance3D.new()
			var fs := SphereMesh.new()
			fs.radius = 0.2
			fs.height = 0.4
			fan.mesh = fs
			fan.material_override = LowPoly.mat(Color.from_hsv(_rng.randf(), 0.6, 0.95))
			fan.position = Vector3(-LANE_W * 2 - 1.3 - row * 0.9, 0.5 + row * 0.35 + 0.2, -LENGTH * 0.15 - k * LENGTH * 0.07 + _rng.randf_range(-0.2, 0.2))
			crowd.add_child(fan)
	set_meta("crowd", crowd)


func _process(delta: float) -> void:
	# The crowd bounces when a race is on.
	var crowd: Node3D = get_meta("crowd", null)
	if crowd == null:
		return
	var excited := phase == Phase.RACING or phase == Phase.FINISHED
	var t := Time.get_ticks_msec() / 1000.0
	var i := 0
	for fan in crowd.get_children():
		var base: float = fan.get_meta("y", fan.position.y)
		fan.set_meta("y", base)
		var amount := 0.18 if excited else 0.03
		fan.position.y = base + absf(sin(t * (6.0 if excited else 1.5) + i * 1.7)) * amount
		i += 1


func _update_board() -> void:
	var lines := []
	for i in 4:
		lines.append("%d  %-8s  %4.1fx" % [i + 1, HORSES[i].name, odds[i]])
	_board.text = "\n".join(lines)


