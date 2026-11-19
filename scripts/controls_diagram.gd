class_name ControlsDiagram
extends Control
## Drawings for the Controls page: a keyboard with every player's keys
## coloured in, or a controller with each button labelled. Drawn in code,
## so it always matches the bindings in controls.gd.

enum Kind { KEYBOARD, CONTROLLER }

const PLAYER_COLORS := [Color(1.0, 0.45, 0.65), Color(1.0, 0.8, 0.25), Color(0.7, 0.5, 1.0), Color(0.5, 0.9, 0.45)]
const GAME_COLOR := Color(0.55, 0.8, 1.0)
const KEY_BG := Color(1, 1, 1, 0.1)
const INK := Color(0.08, 0.08, 0.14)
const TITLE_FONT := preload("res://fonts/LilitaOne-Regular.ttf")

var kind := Kind.KEYBOARD:
	set(v):
		kind = v
		queue_redraw()

## Which keyboard keys light up, and in what colour.
var _key_color := {}


func _ready() -> void:
	custom_minimum_size = Vector2(860, 330)
	for p in Controls.PLAYER_KEYS.size():
		for key in Controls.PLAYER_KEYS[p]:
			_key_color[key] = PLAYER_COLORS[p]
	_key_color[KEY_ENTER] = PLAYER_COLORS[1]
	_key_color[KEY_KP_ENTER] = PLAYER_COLORS[1]
	for action in Controls.GAME_KEYS:
		for key in Controls.GAME_KEYS[action]:
			_key_color[key] = GAME_COLOR


func _draw() -> void:
	# A solid backing so the world behind the menu doesn't show through.
	draw_style_box(_box(Color(0.06, 0.07, 0.12, 0.92), 12), Rect2(Vector2(-12, -10), size + Vector2(24, 20)))
	if kind == Kind.KEYBOARD:
		_draw_keyboard()
	else:
		_draw_controller()


# ------------------------------------------------------------ Keyboard

## [label, keycode, width in key units]; 0 keycode = blank key.
const ROWS := [
	[["Esc", KEY_ESCAPE, 1.0], ["", 0, 0.5], ["F1", 0, 1.0], ["F2", 0, 1.0], ["F3", 0, 1.0], ["F4", 0, 1.0], ["", 0, 0.5], ["F5", 0, 1.0], ["F6", 0, 1.0], ["F7", 0, 1.0], ["F8", 0, 1.0]],
	[["`", 0, 1.0], ["1", 0, 1.0], ["2", 0, 1.0], ["3", 0, 1.0], ["4", 0, 1.0], ["5", 0, 1.0], ["6", 0, 1.0], ["7", 0, 1.0], ["8", 0, 1.0], ["9", 0, 1.0], ["0", 0, 1.0], ["-", 0, 1.0], ["=", 0, 1.0], ["Bksp", 0, 2.0]],
	[["Tab", KEY_TAB, 1.5], ["Q", KEY_Q, 1.0], ["W", KEY_W, 1.0], ["E", KEY_E, 1.0], ["R", KEY_R, 1.0], ["T", 0, 1.0], ["Y", 0, 1.0], ["U", KEY_U, 1.0], ["I", KEY_I, 1.0], ["O", KEY_O, 1.0], ["P", 0, 1.0], ["[", 0, 1.0], ["]", 0, 1.0], ["\\", 0, 1.5]],
	[["Caps", 0, 1.75], ["A", KEY_A, 1.0], ["S", KEY_S, 1.0], ["D", KEY_D, 1.0], ["F", 0, 1.0], ["G", 0, 1.0], ["H", 0, 1.0], ["J", KEY_J, 1.0], ["K", KEY_K, 1.0], ["L", KEY_L, 1.0], [";", 0, 1.0], ["'", 0, 1.0], ["Enter", KEY_ENTER, 2.25]],
	[["Shift", 0, 2.25], ["Z", 0, 1.0], ["X", 0, 1.0], ["C", KEY_C, 1.0], ["V", KEY_V, 1.0], ["B", 0, 1.0], ["N", 0, 1.0], ["M", 0, 1.0], [",", 0, 1.0], [".", 0, 1.0], ["/", 0, 1.0], ["Shift", KEY_SHIFT, 2.75]],
	[["Ctrl", 0, 1.5], ["", 0, 1.0], ["Alt", 0, 1.5], ["Space", KEY_SPACE, 6.0], ["Alt", 0, 1.5], ["", 0, 1.0], ["Ctrl", 0, 1.5]],
]
const ARROWS := [["", 0, 1.0], ["^", KEY_UP, 1.0], ["", 0, 1.0]]
const NUMPAD := [
	[["7", KEY_KP_7], ["8", KEY_KP_8], ["9", KEY_KP_9]],
	[["4", KEY_KP_4], ["5", KEY_KP_5], ["6", KEY_KP_6]],
	[["1", 0], ["2", 0], ["3", 0]],
]


func _draw_keyboard() -> void:
	var u := 34.0      # one key unit
	var gap := 4.0
	var origin := Vector2(0, 0)
	for r in ROWS.size():
		var x := origin.x
		var y := origin.y + r * (u + gap) + (8.0 if r > 0 else 0.0)
		for k in ROWS[r]:
			var w: float = k[2] * u + (k[2] - 1.0) * gap
			if k[0] != "" or k[1] != 0:
				_key(Rect2(x, y, w, u), k[0], k[1])
			x += w + gap
	# Arrow keys.
	var ax := origin.x + 15.0 * (u + gap) + 10.0
	var ay := origin.y + 4 * (u + gap) + 8.0
	_key(Rect2(ax + u + gap, ay, u, u), "^", KEY_UP)
	_key(Rect2(ax, ay + u + gap, u, u), "<", KEY_LEFT)
	_key(Rect2(ax + u + gap, ay + u + gap, u, u), "v", KEY_DOWN)
	_key(Rect2(ax + 2 * (u + gap), ay + u + gap, u, u), ">", KEY_RIGHT)
	# Number pad.
	var nx := ax + 3 * (u + gap) + 16.0
	var ny := origin.y + 1 * (u + gap) + 8.0
	for r in NUMPAD.size():
		for c in 3:
			var k: Array = NUMPAD[r][c]
			_key(Rect2(nx + c * (u + gap), ny + r * (u + gap), u, u), k[0], k[1])
	_key(Rect2(nx + 3 * (u + gap), ny + 2 * (u + gap), u, 2 * u + gap), "Ent", KEY_KP_ENTER)

	# Legend underneath.
	var ly := origin.y + 6 * (u + gap) + 22.0
	var names := ["P1", "P2", "P3", "P4"]
	for p in 4:
		var x := 0.0 if p % 2 == 0 else 430.0
		var y := ly + (p / 2) * 22.0
		draw_rect(Rect2(x, y - 13, 16, 16), PLAYER_COLORS[p])
		_text(Vector2(x + 22, y), names[p] + "  " + Controls.describe(p), 14, Color.WHITE)
	ly += 22.0
	ly += 26.0
	draw_rect(Rect2(0, ly - 13, 16, 16), GAME_COLOR)
	_text(Vector2(22, ly), "Space start / next   Tab scores   R retry   V camera   C bumping   Esc pause", 14, Color.WHITE)


func _key(rect: Rect2, label: String, code: int) -> void:
	var lit: bool = code != 0 and _key_color.has(code)
	var bg: Color = _key_color[code] if lit else KEY_BG
	draw_style_box(_box(bg), rect)
	if label != "":
		var size := 13 if label.length() > 1 else 16
		var col := INK if lit else Color(1, 1, 1, 0.45)
		var w := TITLE_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_text(rect.get_center() + Vector2(-w / 2.0, size * 0.35), label, size, col)


# ------------------------------------------------------------ Controller

func _draw_controller() -> void:
	var c := Vector2(430, 165)
	var body := Color(0.92, 0.93, 0.97)
	var dark := Color(0.2, 0.22, 0.3)
	# Grips and body.
	draw_circle(c + Vector2(-120, 50), 62, body)
	draw_circle(c + Vector2(120, 50), 62, body)
	draw_style_box(_box(body, 70), Rect2(c + Vector2(-175, -80), Vector2(350, 150)))
	# Shoulder buttons.
	draw_style_box(_box(GAME_COLOR, 10), Rect2(c + Vector2(-165, -100), Vector2(90, 22)))
	draw_style_box(_box(PLAYER_COLORS[1], 10), Rect2(c + Vector2(75, -100), Vector2(90, 22)))
	_centered(c + Vector2(-120, -84), "LB", 14, INK)
	_centered(c + Vector2(120, -84), "RB", 14, INK)
	# Left stick and D-pad.
	draw_circle(c + Vector2(-110, -20), 30, dark)
	draw_circle(c + Vector2(-110, -20), 20, PLAYER_COLORS[0])
	var dp := c + Vector2(-55, 40)
	draw_rect(Rect2(dp + Vector2(-27, -9), Vector2(54, 18)), PLAYER_COLORS[0].darkened(0.1))
	draw_rect(Rect2(dp + Vector2(-9, -27), Vector2(18, 54)), PLAYER_COLORS[0].darkened(0.1))
	# Right stick (unused).
	draw_circle(c + Vector2(55, 40), 26, dark)
	draw_circle(c + Vector2(55, 40), 16, dark.lightened(0.2))
	# Face buttons.
	var face := c + Vector2(110, -20)
	var buttons := [["Y", Vector2(0, -26), GAME_COLOR], ["A", Vector2(0, 26), Color(0.4, 0.85, 0.45)],
			["X", Vector2(-26, 0), Color(0.45, 0.65, 1.0)], ["B", Vector2(26, 0), Color(1.0, 0.45, 0.45)]]
	for b in buttons:
		draw_circle(face + b[1], 15, b[2])
		_centered(face + b[1] + Vector2(0, 7), b[0], 19, INK)
	# Back and Start.
	draw_style_box(_box(dark, 8), Rect2(c + Vector2(-38, -42), Vector2(26, 14)))
	draw_style_box(_box(dark, 8), Rect2(c + Vector2(12, -42), Vector2(26, 14)))
	_centered(c + Vector2(-25, -50), "BACK", 11, Color(0.3, 0.3, 0.4))
	_centered(c + Vector2(25, -50), "START", 11, Color(0.3, 0.3, 0.4))

	# Call-outs.
	var left := [
		[c + Vector2(-140, -20), Vector2(20, 60), "Left stick / D-pad", "move, lean, steer"],
		[c + Vector2(-140, -90), Vector2(20, 0), "LB", "whole-track camera"],
		[c + Vector2(-25, -35), Vector2(20, 236), "Back (hold)", "scoreboard"],
	]
	var right := [
		[face + Vector2(0, 26), Vector2(860, 250), "A", "pick, grab, drop, hop, buy, bet"],
		[face + Vector2(-26, 0), Vector2(860, 180), "X or RB", "turn / flip a piece, done"],
		[face + Vector2(26, 0), Vector2(860, 120), "B", "back, leave a plate"],
		[face + Vector2(0, -26), Vector2(860, 60), "Y", "start match / next frame"],
		[c + Vector2(25, -35), Vector2(860, 0), "Start", "pause"],
	]
	for item in left:
		_callout(item[0], item[1], item[2], item[3], false)
	for item in right:
		_callout(item[0], item[1], item[2], item[3], true)
	_text(Vector2(0, 322), "Controller 1 plays as P1, controller 2 as P2, and so on. Keys still work alongside.", 14, Color(1, 1, 1, 0.7))


func _callout(from: Vector2, to: Vector2, title: String, what: String, right: bool) -> void:
	var tw := TITLE_FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var ww := get_theme_default_font().get_string_size(what, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var x := to.x - maxf(tw, ww) if right else to.x
	# The line runs from the button to the near edge of its label.
	var anchor := Vector2(x - 8.0 if right else x + maxf(tw, ww) + 8.0, to.y + 10)
	draw_line(from, anchor, Color(1, 1, 1, 0.45), 1.5, true)
	draw_circle(from, 3, Color.WHITE)
	_text(Vector2(x, to.y + 6), title, 17, Color.WHITE)
	draw_string(get_theme_default_font(), Vector2(x, to.y + 24), what, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))


# ------------------------------------------------------------ Helpers

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
