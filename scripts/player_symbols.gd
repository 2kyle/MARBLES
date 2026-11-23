class_name PlayerSymbols
extends RefCounted
## Colour-blind friendly player symbols. When PLAYER SYMBOLS is on in
## Settings, every seat gets a shape as well as a colour, so you can tell
## players apart without seeing colour: P1 a circle, P2 a triangle, P3 a
## square and P4 a cross. The shape shows on a little badge floating over
## the marble, on the name tags, the score chips, the scoreboard rows, the
## coins screen and the draft pointers.
##
## The shapes are white with a dark edge (not coloured), so they read the
## same for everyone. They're drawn in code into small pictures, once.
##
##   PlayerSymbols.enabled = true
##   PlayerSymbols.mark(label, seat)          # a shape before a Label's text
##   PlayerSymbols.mark_3d(label3d, seat)     # the same for a Label3D
##   var tex := PlayerSymbols.texture(seat)   # the picture itself

enum Shape { CIRCLE, TRIANGLE, SQUARE, CROSS }
## Which shape each seat gets (seat 0 is P1).
const SEAT_SHAPES := [Shape.CIRCLE, Shape.TRIANGLE, Shape.SQUARE, Shape.CROSS]
const NAMES := ["CIRCLE", "TRIANGLE", "SQUARE", "CROSS"]
const FILL := Color(1, 1, 1)
const EDGE := Color(0.06, 0.05, 0.12)
## Size of the drawn pictures in pixels (they're scaled to fit).
const PIXELS := 64

## Set from the PLAYER SYMBOLS setting (main.gd keeps it up to date).
static var enabled := false
static var _textures := {}


static func shape_for(seat: int) -> int:
	return SEAT_SHAPES[posmod(seat, SEAT_SHAPES.size())]


static func name_for(seat: int) -> String:
	return NAMES[shape_for(seat)]


## The shape's outline as points round the middle (0, 0), about 1 across
## (the circle has none: it's worked out by distance instead).
static func outline(shape: int) -> PackedVector2Array:
	match shape:
		Shape.TRIANGLE:
			return PackedVector2Array([Vector2(0, -0.5), Vector2(0.5, 0.4), Vector2(-0.5, 0.4)])
		Shape.SQUARE:
			var s := 0.4
			return PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		Shape.CROSS:
			var a := 0.17
			var b := 0.48
			return PackedVector2Array([Vector2(-a, -b), Vector2(a, -b), Vector2(a, -a), Vector2(b, -a),
					Vector2(b, a), Vector2(a, a), Vector2(a, b), Vector2(-a, b), Vector2(-a, a),
					Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a)])
	return PackedVector2Array()


## 0 outside, 1 for the dark edge, 2 for the white middle. `p` is in the
## same units as outline(); `edge` is how thick the dark edge is.
static func coverage(shape: int, p: Vector2, edge := 0.11) -> int:
	if shape == Shape.CIRCLE:
		var d := p.length()
		return 0 if d > 0.47 else (1 if d > 0.47 - edge else 2)
	var pts := outline(shape)
	if not Geometry2D.is_point_in_polygon(p, pts):
		return 0
	var near := INF
	for i in pts.size():
		var c := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])
		near = minf(near, p.distance_to(c))
	return 1 if near < edge else 2


## The seat's shape as a picture (white with a dark edge, see-through
## round it). Made once and kept.
static func texture(seat: int) -> ImageTexture:
	var shape := shape_for(seat)
	if _textures.has(shape):
		return _textures[shape]
	var img := Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	# 3 x 3 samples a pixel, for smooth edges.
	var n := 3
	for y in PIXELS:
		for x in PIXELS:
			var fill := 0
			var edge := 0
			for sy in n:
				for sx in n:
					var p := Vector2((x + (sx + 0.5) / n) / PIXELS - 0.5, (y + (sy + 0.5) / n) / PIXELS - 0.5)
					var c := coverage(shape, p)
					if c == 2:
						fill += 1
					elif c == 1:
						edge += 1
			var total := fill + edge
			if total == 0:
				continue
			var col := EDGE.lerp(FILL, float(fill) / total)
			col.a = float(total) / (n * n)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_textures[shape] = tex
	return tex


## Put the seat's shape in front of a Label's text (or hide it when
## symbols are off). Safe to call every frame. The Label gets room on its
## left for it, so nothing else about the Label changes. `above` puts it
## over the middle of the words instead (for big words with no room
## beside them, like the stamp on a grabbed draft card).
static func mark(label: Label, seat: int, on := enabled, above := false) -> void:
	var icon := label.get_node_or_null("Symbol") as TextureRect
	if icon == null and not on:
		return
	var h := label.get_theme_font_size("font_size") * 0.95
	var centred := label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
	var wide := 0.0
	if centred:
		wide = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size")).x
	# Nothing to do if it's already showing this.
	var key := [seat, on, h, wide, above]
	if icon and label.get_meta("symbol_key", []) == key:
		return
	label.set_meta("symbol_key", key)
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Symbol"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label.add_child(icon)
	icon.texture = texture(seat)
	icon.visible = on
	var room := h + 5.0
	if above:
		h *= 0.6
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -h / 2.0
		icon.offset_right = h / 2.0
		icon.offset_bottom = -label.get_theme_font_size("font_size") * 0.55
		icon.offset_top = icon.offset_bottom - h
		return
	if centred:
		# Centred words move right by half the room, and the shape sits
		# just left of them.
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_right = room / 2.0 - wide / 2.0 - 4.0
		icon.offset_left = icon.offset_right - h
	else:
		icon.anchor_left = 0.0
		icon.anchor_right = 0.0
		icon.offset_left = 0
		icon.offset_right = h
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_top = -h / 2.0
	icon.offset_bottom = h / 2.0
	# Room on the left for the shape (a see-through box with a margin).
	var box := StyleBoxEmpty.new()
	box.content_margin_left = room if on else 0.0
	label.add_theme_stylebox_override("normal", box)


## The same for a 3D name tag: a flat shape just left of its words.
static func mark_3d(label: Label3D, seat: int, on := enabled) -> void:
	var icon := label.get_node_or_null("Symbol") as Sprite3D
	if icon == null and not on:
		return
	if icon == null:
		icon = Sprite3D.new()
		icon.name = "Symbol"
		icon.billboard = label.billboard
		icon.no_depth_test = label.no_depth_test
		icon.render_priority = label.render_priority + 1
		icon.shaded = false
		label.add_child(icon)
	icon.texture = texture(seat)
	icon.visible = on
	# As tall as the writing, sitting just left of it.
	var tall := label.font_size * label.pixel_size
	icon.pixel_size = tall / PIXELS
	var font: Font = label.font if label.font else ThemeDB.fallback_font
	var wide := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
	icon.position = Vector3(-wide / 2.0 - tall * 0.65, 0, 0)


## Draw the seat's shape straight onto a Control (for things drawn in
## code, like the draft pointers). `at` is the middle, `size` across.
static func draw(canvas: CanvasItem, seat: int, at: Vector2, size: float) -> void:
	canvas.draw_texture_rect(texture(seat), Rect2(at - Vector2(size, size) / 2.0, Vector2(size, size)), false)
