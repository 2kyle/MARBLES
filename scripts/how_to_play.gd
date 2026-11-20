class_name HowToPlay
extends Control
## The pictures for the HOW TO PLAY guide: one little animated drawing for
## each step of a frame (draft, build, roll). Drawn in code like the
## controls diagram, so there are no image files to keep up to date.
##
## main_menu.gd puts this on its "howto" page with the words and the
## NEXT / SKIP buttons; this only draws the picture for `step`.

const TITLE_FONT := preload("res://fonts/ChakraPetch-Bold.ttf")
const PLAYER_COLORS := [Color(1.0, 0.45, 0.65), Color(1.0, 0.8, 0.25), Color(0.7, 0.5, 1.0), Color(0.5, 0.9, 0.45)]
const GOLD := Color(1.0, 0.82, 0.25)
const INK := Color(0.08, 0.08, 0.14)
const LANE := Color(0.42, 0.62, 0.86)
const WALL := Color(0.9, 0.93, 1.0)
const SIZE := Vector2(640, 260)

## One entry per step: the heading and what to do. The keys named are
## Player 1's; the CONTROLS page has everyone's.
const STEPS := [
	{"name": "1. DRAFT",
	"text": "A crate opens with picture cards. Steer your pointer onto a piece and press your place key (Space, or A on a controller) to grab it. First to grab a piece gets it!"},
	{"name": "2. BUILD",
	"text": "Slide your piece anywhere on the lane, turn it (Q, or X) and press your place key to drop it. The ring turns red where it won't fit. Pieces stay for the whole match."},
	{"name": "3. ROLL",
	"text": "Everyone's marble races down the lane to one shared rack of pins. Lean a little, tap your place key to hop over gaps, and smash as many pins as you can!"},
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

func _draw_build() -> void:
	# The lane seen from above, running left to right.
	var lane := Rect2(40, 80, 560, 120)
	_draw_lane_from_above(lane)
	# A piece someone placed earlier.
	draw_circle(Vector2(170, 112), 18, Color(0.95, 0.35, 0.35))
	draw_circle(Vector2(170, 112), 10, Color(1.0, 0.75, 0.7))
	# Your piece slides along, turns, then drops.
	var cycle := fmod(_t, 4.5)
	var slide := clampf(cycle / 2.0, 0.0, 1.0)
	slide = slide * slide * (3.0 - 2.0 * slide)
	var at := Vector2(lerpf(300, 430, slide), lerpf(170, 140, slide))
	var turn := clampf((cycle - 2.0) / 0.8, 0.0, 1.0) * PI / 2.0
	var dropped := cycle > 3.1
	# Your ring, in your colour (it would turn red over another piece).
	var ring := PLAYER_COLORS[0]
	draw_arc(at, 44, 0, TAU, 40, ring, 4.0)
	var wedge := PackedVector2Array()
	for v in [Vector2(-26, 14), Vector2(26, 14), Vector2(26, -12)]:
		wedge.append(at + v.rotated(turn))
	var piece_col := Color(0.95, 0.65, 0.2, 1.0 if dropped else 0.6)
	draw_colored_polygon(wedge, piece_col)
	# Hints round the ring: slide arrows and a turn arrow.
	if not dropped:
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_chevron(at + dir * 58, dir, GOLD)
		draw_arc(at, 56, -PI * 0.9, -PI * 0.55, 10, Color(1, 1, 1, 0.8), 3.0)
	var label := "DROPPED!" if dropped else ("TURN IT" if cycle > 2.0 else "SLIDE IT")
	_centered(Vector2(SIZE.x / 2.0, 44), label, 22, PLAYER_COLORS[0] if dropped else GOLD)
	_pointer_tag(at + Vector2(0, -60), "P1", PLAYER_COLORS[0])


func _draw_lane_from_above(lane: Rect2) -> void:
	draw_style_box(_box(WALL, 10), lane.grow(7))
	draw_style_box(_box(LANE, 6), lane)
	# START arch at the left, pins at the right.
	_text(lane.position + Vector2(8, -14), "START", 14, WALL)
	for row in 4:
		for j in row + 1:
			var c := Vector2(lane.end.x - 46 + row * 11, lane.get_center().y + (j - row / 2.0) * 13)
			draw_circle(c, 5, Color.WHITE)


# ------------------------------------------------------------ 3. Roll

func _draw_roll() -> void:
	# The lane in perspective, narrowing toward the pins at the far end.
	var near_l := Vector2(150, 250)
	var near_r := Vector2(490, 250)
	var far_l := Vector2(266, 100)
	var far_r := Vector2(374, 100)
	draw_colored_polygon(PackedVector2Array([near_l + Vector2(-12, 0), near_r + Vector2(12, 0), far_r + Vector2(4, 0), far_l + Vector2(-4, 0)]), WALL)
	draw_colored_polygon(PackedVector2Array([near_l, near_r, far_r, far_l]), LANE)
	for i in 5:
		var y := lerpf(250, 100, i / 5.0 + fmod(_t * 0.6, 0.2))
		draw_line(Vector2(320 - 3, y), Vector2(320 + 3, y), Color(1, 1, 1, 0.35), 2.0)
	# Marbles race toward the rack; when they reach it, the pins scatter.
	var cycle := fmod(_t, 3.6)
	var k := clampf(cycle / 2.2, 0.0, 1.0)
	var hit := cycle > 2.2
	_draw_pins(Vector2(320, 116), hit, cycle - 2.2)
	var lanes := [-0.55, -0.18, 0.2, 0.55]
	for i in 4:
		var kk := clampf(k * (1.0 - i * 0.06), 0.0, 1.0)
		var y := lerpf(236, 126, kk)
		var half := lerpf(170, 54, kk)
		var x: float = 320.0 + lanes[i] * half + sin(_t * 4.0 + i) * 4.0 * (1.0 - kk)
		var r := lerpf(16, 6, kk)
		draw_circle(Vector2(x, y), r, PLAYER_COLORS[i])
		draw_circle(Vector2(x - r * 0.35, y - r * 0.35), r * 0.3, Color(1, 1, 1, 0.6))
	if hit:
		var pop := clampf((cycle - 2.2) * 4.0, 0.0, 1.0)
		_centered(Vector2(320, 44), "STRIKE!", int(24 + 14 * pop), GOLD)
	else:
		_centered(Vector2(320, 44), "ROLL!", 24, GOLD)


func _draw_pins(head: Vector2, hit: bool, since: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for row in 4:
		for j in row + 1:
			var base := head + Vector2((j - row / 2.0) * 17.0, -row * 7.0)
			var off := Vector2.ZERO
			var spin := 0.0
			if hit:
				var t := minf(since, 1.0)
				off = Vector2(rng.randf_range(-60, 60), rng.randf_range(-30, -5)) * t + Vector2(0, 40 * t * t)
				spin = rng.randf_range(-4, 4) * t
			var a := base + off
			var up := Vector2(0, -18).rotated(spin)
			draw_line(a, a + up, Color.WHITE, 7.0)
			draw_line(a + up * 0.55, a + up * 0.72, Color(0.95, 0.3, 0.3), 7.0)


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
