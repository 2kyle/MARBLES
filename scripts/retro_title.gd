class_name RetroTitle
extends Control
## The game's name drawn like a 70s bowling alley sign: chunky white
## letters that bob one after another in a slow wave, sitting on a stack of
## coloured "stripe" shadows (orange, red, purple), with a little tilted
## sticker in the corner.
##
## Change the words with `text` and `sticker`. Colours are in STRIPES.

const FONT := preload("res://fonts/Righteous-Regular.ttf")
## The stacked shadows, front to back.
const STRIPES := [Color(1.0, 0.62, 0.2), Color(0.93, 0.27, 0.32), Color(0.45, 0.22, 0.6)]
const INK := Color(0.05, 0.05, 0.12)

@export var text := "BOWLING WIP":
	set(v):
		text = v
		_measure()
@export var font_size := 104:
	set(v):
		font_size = v
		_measure()
## Words on the tilted sticker ("" = no sticker).
@export var sticker := "PARTY BOWLING!"
## How far each stripe shadow steps down and right, in pixels.
@export var stripe_step := Vector2(5, 6)
## How high the letters bob, in pixels.
@export var bob := 5.0

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure()


func _measure() -> void:
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(w + stripe_step.x * STRIPES.size() + 30, font_size * 1.15 + stripe_step.y * STRIPES.size())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var base_y := font_size * 0.92
	var x := 0.0
	var outline := maxi(6, font_size / 6)
	for i in text.length():
		var ch := text[i]
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var y := base_y + sin(_t * 2.4 - i * 0.55) * bob
		# Back to front: the stripes, then the white letter on top.
		for k in range(STRIPES.size() - 1, -1, -1):
			var off: Vector2 = stripe_step * (k + 1)
			draw_string_outline(FONT, Vector2(x, y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
			draw_string(FONT, Vector2(x, y) + off, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, STRIPES[k])
		draw_string_outline(FONT, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
		draw_string(FONT, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.98, 0.92))
		x += w
	if sticker != "":
		_draw_sticker(Vector2(x - 40, font_size * 1.05))


## A little rounded sticker, tilted, gently rocking.
func _draw_sticker(at: Vector2) -> void:
	var size := 22
	var w := FONT.get_string_size(sticker, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 26
	var h := size + 14.0
	var angle := deg_to_rad(-7.0 + sin(_t * 1.7) * 2.0)
	draw_set_transform(at, angle, Vector2.ONE)
	var r := Rect2(Vector2(-w, -h / 2.0), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = STRIPES[1]
	sb.set_corner_radius_all(int(h / 2.0))
	sb.border_color = INK
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(3, 4)
	sb.shadow_size = 1
	draw_style_box(sb, r)
	draw_string(FONT, Vector2(-w + 13, size * 0.38), sticker, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.97, 0.88))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Three thin stripes (orange, red, purple) to run across the top of a
## panel, like the trim on an old alley's score desk.
class Trim:
	extends Control
	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for k in STRIPES.size():
			draw_rect(Rect2(0, k * 5, size.x, 3), STRIPES[k])
