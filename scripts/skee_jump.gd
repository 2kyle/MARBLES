class_name SkeeJump
extends Node3D
## SKEE-JUMP: a retro arcade game on the sports island, part skee-ball,
## part long jump. Roll down the lane, hit the kicker ramp and fly onto the
## scoring board. Where you FIRST land is your score: 10, 20, 30, 50 or the
## little 100 strip right before the back. Too slow and you fall SHORT, too
## fast and you sail OVER the 100 into the back net for nothing. Full speed
## reaches about the 50; the 100 needs a well-timed hop off the kicker.
##
## Three balls a game; after each one the machine puts you back at the
## start. At the end of a game you get a coin for every 10 points.
##
## Built in code like the rest of the island. Lane space: the lane runs
## along -X from the start pad (x = START_X) to the back net.

## A player finished a game of three balls with `score` points.
signal game_over(player: int, score: int)

const START_X := 4.2
## The kicker ramp runs from here...
const KICK_FROM := -4.0
## ...to here, where it's KICK_H high.
const KICK_TO := -5.2
const KICK_H := 0.44
## The scoring board runs from the kicker to here.
const BOARD_END := -9.8
const LANE_HALF := 0.75
const BOARD_HALF := 1.5
const BALLS := 3
## Scoring bands: [metres past the kicker it starts, points, colour].
## Anything closer than the first is SHORT, past the last is OVER.
const BANDS := [
	[0.6, 10, Color(0.25, 0.55, 0.95)],
	[1.3, 20, Color(0.3, 0.75, 0.5)],
	[2.0, 30, Color(1.0, 0.75, 0.25)],
	[2.7, 50, Color(1.0, 0.45, 0.25)],
	[3.4, 100, Color(1.0, 0.3, 0.55)],
	[3.9, 0, Color(0.2, 0.18, 0.25)],
]

const INK := Color(0.12, 0.08, 0.14)
const CREAM := Color(0.98, 0.94, 0.84)
const WOOD := Color(0.62, 0.45, 0.3)

var _zone: Area3D
## Per marble: {phase: "roll" / "fly" / "done", wait: seconds}.
var _state := {}
## Per player: {balls: thrown so far, score: points this game}.
var _games := {}
var best := 0
var _board: Label3D
var _last_player := -1


func build() -> void:
	_lane()
	_kicker()
	_scoring_board()
	_sign()
	_scoreboard()
	_zone = LowPoly.marble_zone(self, Vector3(START_X - BOARD_END + 1.0, 3.0, BOARD_HALF * 2.0 + 0.6),
			Vector3((START_X + BOARD_END) / 2.0, 1.5, 0), func(_m): pass)
	_refresh()


## Where a marble starts a ball, in world space.
func start_point() -> Vector3:
	return to_global(Vector3(START_X - 0.4, 0.4, 0))


func _physics_process(delta: float) -> void:
	if _zone == null:
		return
	var inside := {}
	for body in _zone.get_overlapping_bodies():
		if body is Marble and not (body as Marble).freeze:
			inside[body] = true
			_track(body as Marble, delta)
	for m in _state.keys():
		if not inside.has(m) and _state[m].phase != "done":
			_state.erase(m)


func _track(m: Marble, delta: float) -> void:
	var st: Dictionary = _state.get(m, {"phase": "roll", "wait": 0.0})
	_state[m] = st
	var local := to_local(m.global_position)
	match st.phase:
		"roll":
			if local.x < KICK_TO and absf(local.z) < BOARD_HALF:
				st.phase = "fly"
		"fly":
			if local.x > KICK_TO + 0.3:
				st.phase = "roll"  # rolled back down the kicker
			elif local.y < 0.45 and m.floor_normal() != Vector3.ZERO:
				# Down on the board (not still on the lip of the kicker).
				_score(m, KICK_TO - local.x)
				st.phase = "done"
				st.wait = 1.3
		"done":
			st.wait -= delta
			if st.wait <= 0.0:
				# Back to the start for the next ball.
				m.linear_velocity = Vector3.ZERO
				m.angular_velocity = Vector3.ZERO
				m.global_position = start_point()
				m.clear_trail()
				_state.erase(m)


func _score(m: Marble, past: float) -> void:
	var points := 0
	var word := "SHORT!"
	var color := Color(0.8, 0.8, 0.85)
	for b in BANDS:
		if past >= b[0]:
			points = b[1]
			color = b[2]
			word = "OVER!" if points == 0 else "%d!" % points
	if points == 100:
		word = "100!!"
		LowPoly.confetti(self, m.global_position + Vector3.UP * 0.5)
	PopText.spawn(self, m.global_position + Vector3.UP * 0.9, word, color.lightened(0.3), 1.3)
	print_verbose("SKEE-JUMP: P%d landed %.2f m past the kicker: %s" % [m.player_id + 1, past, word])
	var p := m.player_id
	var g: Dictionary = _games.get(p, {"balls": 0, "score": 0})
	g.balls += 1
	g.score += points
	_games[p] = g
	_last_player = p
	if g.balls >= BALLS:
		best = maxi(best, g.score)
		game_over.emit(p, g.score)
		PopText.spawn(self, to_global(Vector3(BOARD_END + 1.0, 2.6, 0)), "GAME! %d\n+%d COINS" % [g.score, g.score / 10], Color(1.0, 0.85, 0.35), 1.6)
		_games.erase(p)
		_refresh(g.score, BALLS)
	else:
		_refresh(g.score, g.balls)


func _refresh(score := 0, balls := 0) -> void:
	var who := "P%d  " % (_last_player + 1) if _last_player >= 0 else ""
	_board.text = "%sBALL %d/%d   SCORE %d\nBEST %d" % [who, mini(balls + (0 if balls >= BALLS else 1), BALLS), BALLS, score, best]


# ------------------------------------------------------------ Building

func _lane() -> void:
	# A strip of maple lane with a start pad, rails either side.
	var length := START_X - KICK_FROM
	LowPoly.box(self, Vector3(length, 0.03, LANE_HALF * 2.0), Vector3((START_X + KICK_FROM) / 2.0, 0.015, 0), Color(0.86, 0.68, 0.45))
	for k in 3:
		# Little guide marks down the lane.
		LowPoly.box(self, Vector3(0.35, 0.035, 0.12), Vector3(1.6 - k * 1.8, 0.02, 0), Color(0.55, 0.1, 0.08))
	LowPoly.cyl(self, 0.6, 0.6, 0.04, Vector3(START_X - 0.4, 0.02, 0), Color(1.0, 0.82, 0.3), 18)
	var go := LowPoly.label(self, Vector3(START_X - 0.4, 0.06, 0), "START", 44, INK)
	go.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	for side in [-1.0, 1.0]:
		var z: float = side * (LANE_HALF + 0.08)
		LowPoly.box(self, Vector3(length, 0.28, 0.14), Vector3((START_X + KICK_FROM) / 2.0, 0.14, z), Color(0.93, 0.27, 0.32))
		LowPoly.solid_box(self, Vector3(length, 0.28, 0.14), Vector3((START_X + KICK_FROM) / 2.0, 0.14, z))
		# Rails carry on along the kicker so marbles can't slip off it.
		LowPoly.box(self, Vector3(KICK_FROM - KICK_TO, 0.28 + KICK_H, 0.14), Vector3((KICK_FROM + KICK_TO) / 2.0, (0.28 + KICK_H) / 2.0, z), Color(0.93, 0.27, 0.32))
		LowPoly.solid_box(self, Vector3(KICK_FROM - KICK_TO, 0.28 + KICK_H, 0.14), Vector3((KICK_FROM + KICK_TO) / 2.0, (0.28 + KICK_H) / 2.0, z))


func _kicker() -> void:
	var run := KICK_FROM - KICK_TO
	var a := atan2(KICK_H, run)
	var length := sqrt(run * run + KICK_H * KICK_H)
	var n := Vector3(sin(a), cos(a), 0)
	var mid := Vector3((KICK_FROM + KICK_TO) / 2.0, KICK_H / 2.0, 0) - n * 0.05
	var body := StaticBody3D.new()
	var phys := PhysicsMaterial.new()
	phys.friction = 0.4
	body.physics_material_override = phys
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length + 0.1, 0.1, LANE_HALF * 2.0)
	col.shape = box
	body.add_child(col)
	body.position = mid
	body.rotation.z = -a
	add_child(body)
	var mesh := LowPoly.box(body, Vector3(length + 0.1, 0.1, LANE_HALF * 2.0), Vector3.ZERO, Color(1.0, 0.75, 0.25))
	mesh.name = "Kicker"
	# A solid block under the ramp so you can't roll in under it from the side.
	LowPoly.box(self, Vector3(0.12, KICK_H, LANE_HALF * 2.0), Vector3(KICK_TO + 0.06, KICK_H / 2.0, 0), INK)
	LowPoly.solid_box(self, Vector3(0.12, KICK_H - 0.04, LANE_HALF * 2.0), Vector3(KICK_TO + 0.06, (KICK_H - 0.04) / 2.0, 0))


func _scoring_board() -> void:
	var length := KICK_TO - BOARD_END
	var mid_x := (KICK_TO + BOARD_END) / 2.0
	LowPoly.box(self, Vector3(length, 0.05, BOARD_HALF * 2.0), Vector3(mid_x, 0.025, 0), INK)
	# The coloured bands, nearest first, each with its points painted on.
	for i in BANDS.size():
		var from: float = BANDS[i][0]
		var to: float = BANDS[i + 1][0] if i + 1 < BANDS.size() else length
		var x0 := KICK_TO - from
		var x1 := KICK_TO - to
		LowPoly.box(self, Vector3(x0 - x1 - 0.06, 0.012, BOARD_HALF * 2.0 - 0.1), Vector3((x0 + x1) / 2.0, 0.056, 0), BANDS[i][2])
		var text: String = "OVER" if BANDS[i][1] == 0 else str(BANDS[i][1])
		var l := LowPoly.label(self, Vector3((x0 + x1) / 2.0, 0.07, 0), text, 56 if BANDS[i][1] < 100 else 44, INK)
		l.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	var short := LowPoly.label(self, Vector3(KICK_TO - 0.3, 0.07, 0), "SHORT", 30, INK)
	short.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	short.modulate = Color(1, 1, 1, 0.6)
	# Low side walls and a tall back net so balls stay on the board.
	for side in [-1.0, 1.0]:
		var z: float = side * (BOARD_HALF + 0.07)
		LowPoly.box(self, Vector3(length, 0.4, 0.14), Vector3(mid_x, 0.2, z), CREAM)
		LowPoly.solid_box(self, Vector3(length, 0.4, 0.14), Vector3(mid_x, 0.2, z))
	LowPoly.box(self, Vector3(0.14, 1.6, BOARD_HALF * 2.0 + 0.28), Vector3(BOARD_END - 0.07, 0.8, 0), Color(0.93, 0.27, 0.32))
	LowPoly.solid_box(self, Vector3(0.14, 1.6, BOARD_HALF * 2.0 + 0.28), Vector3(BOARD_END - 0.07, 0.8, 0), 0.05)


## A marquee sign over the start: SKEE-JUMP in lights.
func _sign() -> void:
	var at := Vector3(START_X - 1.6, 0, 0)
	for side in [-1.0, 1.0]:
		var post := at + Vector3(0, 1.4, side * (LANE_HALF + 0.35))
		LowPoly.box(self, Vector3(0.16, 2.8, 0.16), post, INK)
		LowPoly.solid_box(self, Vector3(0.16, 2.8, 0.16), post)
	var board := at + Vector3(0, 2.75, 0)
	LowPoly.box(self, Vector3(0.18, 0.9, 3.4), board, Color(0.45, 0.22, 0.6))
	for face in [1.0, -1.0]:
		var l := LowPoly.label(self, board + Vector3(face * 0.1, 0, 0), "SKEE-JUMP", 50, INK, face * PI / 2.0)
		l.modulate = Color(1.0, 0.85, 0.35)
		l.double_sided = false
	# Chase lights round the edge of the sign.
	for y in [-0.5, 0.5]:
		for face in [1.0, -1.0]:
			LowPoly.marquee_strip(self, 3.4, board + Vector3(face * 0.1, y * 0.9, 0), face * PI / 2.0)


func _scoreboard() -> void:
	var at := Vector3(BOARD_END - 0.2, 2.4, 0)
	LowPoly.box(self, Vector3(0.2, 1.2, 3.4), at, INK)
	_board = LowPoly.label(self, at + Vector3(0.12, 0, 0), "", 40, Color(0.05, 0.02, 0.08), PI / 2.0)
	_board.double_sided = false
	_board.modulate = Color(1.0, 0.85, 0.35)
