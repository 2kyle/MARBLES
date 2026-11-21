class_name HowToPlay
extends Control
## The pictures for the HOW TO PLAY guide: one little animated drawing for
## each step of a frame (draft, build, roll). Drawn in code like the
## controls diagram, so there are no image files to keep up to date.
##
## main_menu.gd puts this on its "howto" page with the words and the
## NEXT / SKIP buttons; this only draws the picture for `step`.

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const PLAYER_COLORS := [Color(1.0, 0.45, 0.65), Color(1.0, 0.8, 0.25), Color(0.7, 0.5, 1.0), Color(0.5, 0.9, 0.45)]
const GOLD := Color(1.0, 0.82, 0.25)
const INK := Color(0.08, 0.08, 0.14)
const LANE := Color(0.42, 0.62, 0.86)
const WALL := Color(0.9, 0.93, 1.0)
const SIZE := Vector2(640, 300)
## The strip along the bottom with the key and button prompts.
const PROMPT_Y := 262.0
const PROMPT_H := 34.0

## One entry per step: the heading, what to do, and the button prompts
## shown under the picture as [what it does, keyboard key, controller
## button]. The keys are Player 1's; the CONTROLS page has everyone's.
const STEPS := [
	{"name": "1. DRAFT",
	"text": "A crate opens with picture cards. Steer your pointer onto a piece and grab it. First to grab a piece gets it!",
	"prompts": [["MOVE", "WASD", "LS"], ["GRAB", "SPACE", "A"]]},
	{"name": "2. BUILD",
	"text": "Slide your piece anywhere on the winding lane, turn it, and drop it. The ring turns red where it won't fit. Pieces stay all match.",
	"prompts": [["SLIDE", "WASD", "LS"], ["TURN", "Q", "X"], ["DROP", "SPACE", "A"]]},
	{"name": "3. ROLL",
	"text": "Everyone's bowling ball races down the twisty lane to one shared rack of pins. Lean, hop over gaps, and smash as many pins as you can!",
	"prompts": [["LEAN", "WASD", "LS"], ["HOP", "SPACE", "A"]]},
]

var step := 0:
	set(v):
		step = clampi(v, 0, STEPS.size() - 1)
		_t = 0.0
		queue_redraw()

## Seconds since this step was shown; drives the little animations.
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	# A solid backing so the world behind the menu doesn't show through.
	draw_style_box(_box(Color(0.06, 0.07, 0.12, 0.92), 12), Rect2(Vector2.ZERO, SIZE))
	match step:
		0: _draw_draft()
		1: _draw_build()
		2: _draw_roll()
	_draw_prompts()


# ------------------------------------------------------------ 1. Draft

func _draw_draft() -> void:
	# Four piece cards in a row, like the real draft.
	var card := Vector2(118, 150)
	var gap := 22.0
	var left := (SIZE.x - 4 * card.x - 3 * gap) / 2.0
	var top := 46.0
	# Player 1's pointer glides onto the second card and grabs it.
	var grab_at := 1.6
	var grabbed := fmod(_t, 4.0) > grab_at
	for i in 4:
		var r := Rect2(Vector2(left + i * (card.x + gap), top), card)
		if i == 1 and grabbed:
			r = r.grow(6)
			draw_style_box(_box(PLAYER_COLORS[0], 14), r.grow(5))
		draw_style_box(_box(Color(0.96, 0.95, 0.9), 12), r)
		_draw_piece_icon(i, r.get_center() + Vector2(0, -14))
		var names := ["BUMPER", "RAMP", "BOOSTER", "SPINNER"]
		_centered(Vector2(r.get_center().x, r.end.y - 16), names[i], 15, INK)
	var card_center := func(i: int) -> Vector2:
		return Vector2(left + i * (card.x + gap) + card.x / 2.0, top + card.y * 0.7)
	var k := clampf(fmod(_t, 4.0) / grab_at, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var p1: Vector2 = Vector2(80, 235).lerp(card_center.call(1), k)
	_pointer(p1, PLAYER_COLORS[0], "P1")
	# A friend's pointer heads for another card.
	var bob := sin(_t * 3.0) * 4.0
	_pointer(card_center.call(3) + Vector2(10, 18 + bob), PLAYER_COLORS[1], "P2")
	if grabbed:
		_centered(Vector2(SIZE.x / 2.0, 30), "GRABBED!", 22, PLAYER_COLORS[0])
	else:
		_centered(Vector2(SIZE.x / 2.0, 30), "PICK A PIECE", 22, GOLD)


## A tiny drawing of a track piece, for the draft cards.
func _draw_piece_icon(kind: int, c: Vector2) -> void:
	match kind:
		0:  # bumper: a round post with a ring
			draw_circle(c, 26, Color(0.95, 0.35, 0.35))
			draw_circle(c, 15, Color(1.0, 0.75, 0.7))
		1:  # ramp: a wedge
			draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 20), c + Vector2(34, 20), c + Vector2(34, -18)]), Color(0.95, 0.65, 0.2))
		2:  # booster: two chevrons
			for dx in [-14.0, 10.0]:
				draw_polyline(PackedVector2Array([c + Vector2(dx - 10, -20), c + Vector2(dx + 10, 0), c + Vector2(dx - 10, 20)]), Color(0.2, 0.75, 1.0), 8.0)
		3:  # spinner: a turning cross
			var a := _t * 2.0
			for j in 2:
				var d := Vector2.from_angle(a + j * PI / 2.0) * 30.0
				draw_line(c - d, c + d, Color(0.6, 0.4, 0.95), 9.0)
			draw_circle(c, 7, INK)


# ------------------------------------------------------------ 2. Build

## A point on the winding lane seen from above, `u` from 0 (START) to 1
## (the pins). It snakes left and right like a real random track.
func _lane_point(u: float) -> Vector2:
	return Vector2(lerpf(70, 520, u), 150 + 48 * sin(u * TAU * 1.15 + 0.4))


func _draw_build() -> void:
	var lane_w := 50.0
	var pts := PackedVector2Array()
	for i in 49:
		pts.append(_lane_point(i / 48.0))
	# Walls, then the lane floor on top.
	draw_polyline(pts, WALL, lane_w + 12, true)
	for p in [pts[0], pts[-1]]:
		draw_circle(p, (lane_w + 12) / 2.0, WALL)
	draw_polyline(pts, LANE, lane_w, true)
	for p in [pts[0], pts[-1]]:
		draw_circle(p, lane_w / 2.0, LANE)
	_text(pts[0] + Vector2(-30, -40), "START", 14, WALL)
	# The rack of pins at the end.
	var end := pts[-1]
	draw_circle(end + Vector2(36, 0), 34, WALL)
	draw_circle(end + Vector2(36, 0), 28, LANE)
	for row in 4:
		for j in row + 1:
			draw_circle(end + Vector2(24 + row * 10, (j - row / 2.0) * 12), 4.5, Color.WHITE)
	# A piece someone placed earlier.
	var old := _lane_point(0.2)
	draw_circle(old, 15, Color(0.95, 0.35, 0.35))
	draw_circle(old, 8, Color(1.0, 0.75, 0.7))
	# Your piece slides along the bends, turns, then drops.
	var cycle := fmod(_t, 4.5)
	var slide := clampf(cycle / 2.0, 0.0, 1.0)
	slide = slide * slide * (3.0 - 2.0 * slide)
	var at := _lane_point(lerpf(0.42, 0.68, slide))
	var turn := clampf((cycle - 2.0) / 0.8, 0.0, 1.0) * PI / 2.0
	var dropped := cycle > 3.1
	# Your ring, in your colour (it would turn red over another piece).
	draw_arc(at, 34, 0, TAU, 40, PLAYER_COLORS[0], 4.0)
	var wedge := PackedVector2Array()
	for v in [Vector2(-20, 11), Vector2(20, 11), Vector2(20, -9)]:
		wedge.append(at + v.rotated(turn))
	draw_colored_polygon(wedge, Color(0.95, 0.65, 0.2, 1.0 if dropped else 0.6))
	# Hints round the ring: slide arrows and a turn arrow.
	if not dropped:
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_chevron(at + dir * 46, dir, GOLD)
	var label := "DROPPED!" if dropped else ("TURN IT" if cycle > 2.0 else "SLIDE IT")
	_centered(Vector2(SIZE.x / 2.0, 30), label, 22, PLAYER_COLORS[0] if dropped else GOLD)
	_pointer_tag(at + Vector2(46, -30), "P1", PLAYER_COLORS[0])


# ------------------------------------------------------------ 3. Roll

## The lane seen from behind the marbles: `v` from 0 (near, bottom) to 1
## (far, at the pins). Returns [centre, half width]; it bends left and
## right as it goes, narrowing into the distance.
func _roll_point(v: float) -> Array:
	var y := lerpf(258, 104, 1.0 - pow(1.0 - v, 1.4))
	var x := 320.0 + 95.0 * sin(v * PI * 1.7 + 0.5) * (1.0 - v * 0.55)
	return [Vector2(x, y), lerpf(150, 30, v)]


func _draw_roll() -> void:
	# Both edges of the winding lane, then fill between them.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var wall_l := PackedVector2Array()
	var wall_r := PackedVector2Array()
	for i in 33:
		var cp: Array = _roll_point(i / 32.0)
		var c: Vector2 = cp[0]
		var half: float = cp[1]
		left.append(c + Vector2(-half, 0))
		right.append(c + Vector2(half, 0))
		wall_l.append(c + Vector2(-half - 4 - 8 * (1.0 - i / 32.0), 0))
		wall_r.append(c + Vector2(half + 4 + 8 * (1.0 - i / 32.0), 0))
	_fill_between(wall_l, wall_r, WALL)
	_fill_between(left, right, LANE)
	# Dashes down the middle scroll toward you, so it feels fast.
	for i in 8:
		var v := fmod(i / 8.0 + _t * 0.25, 1.0)
		var a: Vector2 = _roll_point(v)[0]
		var b: Vector2 = _roll_point(minf(v + 0.025, 1.0))[0]
		draw_line(a, b, Color(1, 1, 1, 0.35), lerpf(3.0, 1.0, v))
	# Marbles race toward the rack; when they reach it, the pins scatter.
	var cycle := fmod(_t, 3.6)
	var k := clampf(cycle / 2.2, 0.0, 1.0)
	var hit := cycle > 2.2
	_draw_pins(_roll_point(1.0)[0] + Vector2(0, 10), hit, cycle - 2.2)
	var lanes := [-0.5, -0.17, 0.17, 0.5]
	for i in 4:
		var kk := clampf(k * (1.0 - i * 0.06), 0.0, 0.94)
		var cp: Array = _roll_point(kk)
		var x: float = cp[0].x + lanes[i] * cp[1] + sin(_t * 4.0 + i) * 3.0 * (1.0 - kk)
		var y: float = cp[0].y - lerpf(12, 4, kk)
		var r := lerpf(14, 5, kk)
		draw_circle(Vector2(x, y), r, PLAYER_COLORS[i])
		draw_circle(Vector2(x - r * 0.35, y - r * 0.35), r * 0.3, Color(1, 1, 1, 0.6))
	if hit:
		var pop := clampf((cycle - 2.2) * 4.0, 0.0, 1.0)
		_centered(Vector2(320, 44), "STRIKE!", int(24 + 14 * pop), GOLD)
	else:
		_centered(Vector2(320, 44), "ROLL!", 24, GOLD)


## Fill the strip between two edges that run side by side.
func _fill_between(a: PackedVector2Array, b: PackedVector2Array, color: Color) -> void:
	for i in a.size() - 1:
		draw_colored_polygon(PackedVector2Array([a[i], a[i + 1], b[i + 1], b[i]]), color)


func _draw_pins(head: Vector2, hit: bool, since: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 4:
		for j in row + 1:
			var base := head + Vector2((j - row / 2.0) * 12.0, -row * 5.0)
			var off := Vector2.ZERO
			var spin := 0.0
			if hit:
				var t := minf(since, 1.0)
				off = Vector2(rng.randf_range(-60, 60), rng.randf_range(-30, -5)) * t + Vector2(0, 40 * t * t)
				spin = rng.randf_range(-4, 4) * t
			var a := base + off
			var up := Vector2(0, -14).rotated(spin)
			draw_line(a, a + up, Color.WHITE, 5.0)
			draw_line(a + up * 0.55, a + up * 0.72, Color(0.95, 0.3, 0.3), 5.0)


# ------------------------------------------------------------ Button prompts

## The strip along the bottom: for each thing you do in this step, the
## keyboard key and the controller button, drawn to look like the real
## thing. Player 1's keys; the CONTROLS page has everyone's.
func _draw_prompts() -> void:
	var y := PROMPT_Y + PROMPT_H / 2.0
	draw_line(Vector2(16, PROMPT_Y - 4), Vector2(SIZE.x - 16, PROMPT_Y - 4), Color(1, 1, 1, 0.12), 1.0)
	var items: Array = STEPS[step].prompts
	# Measure every group first so the row can be centred.
	var widths := []
	var total := 0.0
	for it in items:
		var w := _prompt_width(it)
		widths.append(w)
		total += w
	var gap := 34.0
	total += gap * (items.size() - 1)
	var x := (SIZE.x - total) / 2.0
	for i in items.size():
		_draw_prompt(x, y, items[i])
		x += widths[i] + gap


func _prompt_width(it: Array) -> float:
	var w := _key_width(it[1]) + 8 + 14 + 8 + 30 + 10
	return w + TITLE_FONT.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


## One prompt: [keyboard key] / (controller button) LABEL.
func _draw_prompt(x: float, y: float, it: Array) -> void:
	x += _draw_key(Vector2(x, y), it[1])
	x += 8
	_text(Vector2(x, y + 6), "/", 16, Color(1, 1, 1, 0.4))
	x += 14 + 8
	_draw_pad_button(Vector2(x + 15, y), it[2])
	x += 30 + 10
	_text(Vector2(x, y + 6), it[0], 16, Color.WHITE)


func _key_width(key: String) -> float:
	if key == "WASD":
		return 3 * 16 + 2 * 2
	return maxf(26, TITLE_FONT.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16)


## A keyboard key cap: light top, darker edge underneath. "WASD" draws the
## little four-key cluster.
func _draw_key(left_mid: Vector2, key: String) -> float:
	if key == "WASD":
		var s := 16.0
		var g := 2.0
		var top := left_mid.y - s - g / 2.0
		_key_cap(Rect2(left_mid.x + s + g, top, s, s - 1), "W", 10)
		for i in 3:
			_key_cap(Rect2(left_mid.x + i * (s + g), top + s + g, s, s - 1), ["A", "S", "D"][i], 10)
		return _key_width(key)
	var w := _key_width(key)
	_key_cap(Rect2(left_mid.x, left_mid.y - 14, w, 26), key, 13)
	return w


func _key_cap(r: Rect2, label: String, size: int) -> void:
	draw_style_box(_box(Color(0.55, 0.57, 0.65), 5), Rect2(r.position + Vector2(0, 3), r.size))
	draw_style_box(_box(Color(0.94, 0.95, 0.98), 5), r)
	_centered(r.get_center() + Vector2(0, size * 0.36), label, size, INK)


## A controller button like an Xbox-style pad: dark round buttons with a
## coloured letter, or the left stick seen from above.
func _draw_pad_button(c: Vector2, button: String) -> void:
	if button == "LS":
		draw_circle(c, 15, Color(0.16, 0.17, 0.22))
		draw_circle(c, 11, Color(0.3, 0.31, 0.38))
		draw_arc(c, 11, 0, TAU, 24, Color(0.45, 0.46, 0.55), 1.5)
		_centered(c + Vector2(0, 4), "L", 11, Color(0.85, 0.86, 0.92))
		# Little arrows: push it any way.
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = c + d * 19
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 4 + d.orthogonal() * 3, tip - d * 4 - d.orthogonal() * 3]), Color(1, 1, 1, 0.6))
		return
	var colors := {"A": Color(0.4, 0.85, 0.45), "B": Color(1.0, 0.45, 0.45),
			"X": Color(0.45, 0.65, 1.0), "Y": GOLD}
	draw_circle(c + Vector2(0, 2), 13, Color(0, 0, 0, 0.5))
	draw_circle(c, 13, Color(0.16, 0.17, 0.22))
	draw_arc(c, 13, 0, TAU, 24, colors.get(button, Color.WHITE).darkened(0.3), 1.5)
	_centered(c + Vector2(0, 6), button, 16, colors.get(button, Color.WHITE))


# ------------------------------------------------------------ Helpers

## A player's draft pointer: an arrow with their tag.
func _pointer(tip: Vector2, color: Color, tag: String) -> void:
	var pts := PackedVector2Array([tip, tip + Vector2(8, 26), tip + Vector2(14, 16), tip + Vector2(26, 10)])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([tip, tip + Vector2(8, 26), tip + Vector2(14, 16), tip + Vector2(26, 10), tip]), INK, 2.0)
	_pointer_tag(tip + Vector2(30, 34), tag, color)


func _pointer_tag(at: Vector2, tag: String, color: Color) -> void:
	var r := Rect2(at - Vector2(17, 11), Vector2(34, 22))
	draw_style_box(_box(color, 6), r)
	_centered(at + Vector2(0, 6), tag, 15, INK)


func _chevron(at: Vector2, dir: Vector2, color: Color) -> void:
	var side := dir.orthogonal() * 7.0
	draw_polyline(PackedVector2Array([at - dir * 5 + side, at + dir * 4, at - dir * 5 - side]), color, 4.0)


func _box(bg: Color, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	return s


func _text(at: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(TITLE_FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _centered(at: Vector2, text: String, size: int, color: Color) -> void:
	var w := TITLE_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(at - Vector2(w / 2.0, 0), text, size, color)
