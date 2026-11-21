class_name AchievementIcon
extends Control
## An achievement's badge, drawn in code: a round coloured badge with a
## chunky white picture on it ("emblem"). Locked ones are drawn grey.
## The same drawing makes the PNG icons for Steam (tools/make_achievement_icons.gd).

const INK := Color(0.12, 0.1, 0.16)
const CREAM := Color(1.0, 0.98, 0.92)
const FONT := preload("res://fonts/Righteous-Regular.ttf")

var emblem := "star"
var color := Color(1, 0.7, 0.2)
var locked := false
## Draw a square coloured tile behind the badge (Steam's square icons).
var tile := false


static func make(entry: Dictionary, is_locked: bool, size := 72) -> AchievementIcon:
	var icon := AchievementIcon.new()
	icon.emblem = entry.emblem
	icon.color = entry.color
	icon.locked = is_locked
	icon.custom_minimum_size = Vector2(size, size)
	icon.size = Vector2(size, size)
	return icon


## Turn a colour grey for locked badges.
func _c(col: Color) -> Color:
	if not locked:
		return col
	var g := col.get_luminance() * 0.75 + 0.12
	return Color(g, g, g * 1.04, col.a)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	# Square tile behind (Steam shows icons square), then the round badge.
	if tile:
		draw_rect(Rect2(Vector2.ZERO, size), _c(color.darkened(0.55)))
		for i in 6:
			draw_circle(c, r * (1.4 - i * 0.08), _c(color.darkened(0.55).lerp(color.darkened(0.35), i / 6.0)))
	draw_circle(c, r * 0.92, _c(color.darkened(0.3)))
	draw_circle(c, r * 0.84, _c(color))
	draw_circle(c + Vector2(0, -r * 0.08), r * 0.76, _c(color.lightened(0.12)))
	# Soft shine on the top left.
	draw_arc(c, r * 0.68, PI * 1.08, PI * 1.42, 16, _c(Color(1, 1, 1, 0.45)), r * 0.07)
	draw_set_transform(c, 0.0, Vector2(r, r))
	_emblem()
	draw_set_transform(Vector2.ZERO)


# Emblems are drawn in a box from -0.6 to 0.6 around the middle.
func _emblem() -> void:
	var w := _c(CREAM)
	var ink := _c(INK)
	var red := _c(Color(0.92, 0.25, 0.3))
	match emblem:
		"marble":
			_ball(Vector2.ZERO, 0.46, _c(Color(0.35, 0.65, 1.0)))
			_eye(Vector2(-0.14, -0.04), 0.1)
			_eye(Vector2(0.14, -0.04), 0.1)
		"pin":
			_pin(Vector2.ZERO, 1.0, w, red)
		"pins":
			_pin(Vector2(-0.3, 0.08), 0.75, w, red)
			_pin(Vector2(0.3, 0.08), 0.75, w, red)
			_pin(Vector2(0, -0.02), 0.85, w, red)
		"crown":
			var pts := PackedVector2Array([Vector2(-0.5, 0.32), Vector2(-0.55, -0.3), Vector2(-0.26, -0.02),
					Vector2(0, -0.42), Vector2(0.26, -0.02), Vector2(0.55, -0.3), Vector2(0.5, 0.32)])
			_outlined(pts, _c(Color(1.0, 0.86, 0.3)))
			for x in [-0.55, 0.0, 0.55]:
				draw_circle(Vector2(x, -0.36 if x != 0.0 else -0.48), 0.07, w)
			draw_circle(Vector2(0, 0.14), 0.07, red)
		"star":
			_outlined(_star(Vector2.ZERO, 0.55, 0.24), _c(Color(1.0, 0.9, 0.35)))
		"stars":
			_outlined(_star(Vector2(-0.33, 0.12), 0.27, 0.12), _c(Color(1.0, 0.9, 0.35)))
			_outlined(_star(Vector2(0.33, 0.12), 0.27, 0.12), _c(Color(1.0, 0.9, 0.35)))
			_outlined(_star(Vector2(0, -0.2), 0.34, 0.15), _c(Color(1.0, 0.9, 0.35)))
		"flag":
			draw_line(Vector2(-0.4, 0.55), Vector2(-0.4, -0.5), ink, 0.1)
			var s := 0.16
			for i in 3:
				for j in 5:
					var col := w if (i + j) % 2 == 0 else ink
					draw_rect(Rect2(Vector2(-0.36 + j * s, -0.48 + i * s), Vector2(s, s)), col)
		"bump":
			_ball(Vector2(-0.22, 0.1), 0.3, _c(Color(0.35, 0.65, 1.0)))
			_ball(Vector2(0.28, -0.12), 0.24, _c(Color(1.0, 0.55, 0.3)))
			for a in [-0.9, -0.3, 0.3]:
				var d := Vector2.from_angle(a - PI * 0.5)
				draw_line(Vector2(0.06, -0.04) + d * 0.08, Vector2(0.06, -0.04) + d * 0.28, w, 0.07)
		"wave":
			_ball(Vector2(0, -0.2), 0.24, _c(Color(0.35, 0.65, 1.0)))
			for k in 2:
				var pts := PackedVector2Array()
				for i in 17:
					var x := -0.55 + i * 1.1 / 16.0
					pts.append(Vector2(x, 0.18 + k * 0.2 + sin(x * 11.0) * 0.05))
				draw_polyline(pts, w, 0.09)
		"globe":
			draw_circle(Vector2.ZERO, 0.5, ink)
			draw_circle(Vector2.ZERO, 0.43, _c(Color(0.45, 0.8, 1.0)))
			for e in [0.15, 0.32]:
				_ellipse_line(Vector2.ZERO, Vector2(e, 0.43), w)
			draw_line(Vector2(-0.43, 0), Vector2(0.43, 0), w, 0.05)
			draw_line(Vector2(-0.38, -0.2), Vector2(0.38, -0.2), w, 0.04)
			draw_line(Vector2(-0.38, 0.2), Vector2(0.38, 0.2), w, 0.04)
		"crate":
			var box := Rect2(Vector2(-0.45, -0.4), Vector2(0.9, 0.82))
			draw_rect(box.grow(0.05), ink)
			draw_rect(box, _c(Color(0.86, 0.62, 0.36)))
			draw_line(Vector2(-0.45, -0.4), Vector2(0.45, 0.42), ink, 0.09)
			draw_rect(Rect2(Vector2(-0.45, -0.06), Vector2(0.9, 0.12)), _c(Color(1.0, 0.82, 0.3)))
		"gem":
			var pts := PackedVector2Array([Vector2(-0.5, -0.15), Vector2(-0.25, -0.42), Vector2(0.25, -0.42),
					Vector2(0.5, -0.15), Vector2(0, 0.5)])
			_outlined(pts, _c(Color(0.55, 0.9, 1.0)))
			draw_line(Vector2(-0.5, -0.15), Vector2(0.5, -0.15), ink, 0.04)
			draw_line(Vector2(-0.15, -0.15), Vector2(0, 0.45), ink, 0.03)
			draw_line(Vector2(0.15, -0.15), Vector2(0, 0.45), ink, 0.03)
		"trophy":
			var gold := _c(Color(1.0, 0.82, 0.25))
			draw_arc(Vector2(-0.32, -0.18), 0.16, PI * 0.5, PI * 1.5, 12, ink, 0.12)
			draw_arc(Vector2(0.32, -0.18), 0.16, -PI * 0.5, PI * 0.5, 12, ink, 0.12)
			draw_arc(Vector2(-0.32, -0.18), 0.16, PI * 0.5, PI * 1.5, 12, gold, 0.06)
			draw_arc(Vector2(0.32, -0.18), 0.16, -PI * 0.5, PI * 0.5, 12, gold, 0.06)
			_outlined(PackedVector2Array([Vector2(-0.34, -0.42), Vector2(0.34, -0.42), Vector2(0.22, 0.05),
					Vector2(0.06, 0.12), Vector2(0.06, 0.3), Vector2(0.24, 0.42), Vector2(-0.24, 0.42),
					Vector2(-0.06, 0.3), Vector2(-0.06, 0.12), Vector2(-0.22, 0.05)]), gold)
		"hat":
			_ball(Vector2(0, 0.24), 0.3, _c(Color(1.0, 0.55, 0.75)))
			_eye(Vector2(-0.1, 0.24), 0.07)
			_eye(Vector2(0.1, 0.24), 0.07)
			_outlined(PackedVector2Array([Vector2(-0.42, 0.0), Vector2(0.42, 0.0), Vector2(0.42, -0.07),
					Vector2(0.24, -0.07), Vector2(0.24, -0.5), Vector2(-0.24, -0.5), Vector2(-0.24, -0.07),
					Vector2(-0.42, -0.07)]), _c(INK.lightened(0.15)))
			draw_rect(Rect2(Vector2(-0.24, -0.17), Vector2(0.48, 0.08)), red)
		"horseshoe", "longshot":
			draw_arc(Vector2(0, -0.04), 0.36, PI * 0.82, PI * 2.18, 24, ink, 0.26)
			draw_arc(Vector2(0, -0.04), 0.36, PI * 0.82, PI * 2.18, 24, _c(Color(0.85, 0.85, 0.9)), 0.17)
			for a in [0.95, 1.3, 1.7, 2.05]:
				draw_circle(Vector2(0, -0.04) + Vector2.from_angle(PI * a) * 0.36, 0.03, ink)
			if emblem == "longshot":
				_text("5x", Vector2(0, 0.28), 0.5, _c(Color(1.0, 0.9, 0.35)))
		"hoop":
			draw_rect(Rect2(Vector2(-0.45, -0.55), Vector2(0.9, 0.5)), w)
			draw_rect(Rect2(Vector2(-0.45, -0.55), Vector2(0.9, 0.5)), ink, false, 0.05)
			draw_rect(Rect2(Vector2(-0.16, -0.4), Vector2(0.32, 0.24)), red, false, 0.05)
			for i in 5:
				var x := -0.24 + i * 0.12
				draw_line(Vector2(x, -0.08), Vector2(x * 0.6, 0.3), w, 0.04)
			draw_line(Vector2(-0.3, -0.08), Vector2(0.3, -0.08), _c(Color(1.0, 0.5, 0.2)), 0.08)
			_ball(Vector2(0.3, 0.32), 0.17, _c(Color(1.0, 0.55, 0.2)))
		"ball":
			_ball(Vector2.ZERO, 0.48, w)
			var pent := PackedVector2Array()
			for i in 5:
				pent.append(Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0) * 0.17)
			draw_colored_polygon(pent, ink)
			for i in 5:
				var d := Vector2.from_angle(-PI * 0.5 + i * TAU / 5.0)
				draw_line(d * 0.17, d * 0.34, ink, 0.04)
				draw_circle(d * 0.42, 0.07, ink)
		"coin":
			for k in 3:
				var at := Vector2(-0.1 + k * 0.1, 0.25 - k * 0.22)
				draw_circle(at, 0.36, ink)
				draw_circle(at, 0.31, _c(Color(1.0, 0.82, 0.3)))
				draw_circle(at, 0.22, _c(Color(1.0, 0.9, 0.5)))
			_text("$", Vector2(0.1, -0.2), 0.42, _c(Color(0.75, 0.5, 0.1)))


func _ball(at: Vector2, rad: float, col: Color) -> void:
	draw_circle(at, rad + 0.05, _c(INK))
	draw_circle(at, rad, col)
	draw_circle(at + Vector2(-rad, -rad) * 0.38, rad * 0.25, _c(Color(1, 1, 1, 0.75)))


func _eye(at: Vector2, rad: float) -> void:
	draw_circle(at, rad, _c(CREAM))
	draw_circle(at + Vector2(0.01, 0.015), rad * 0.55, _c(INK))


func _pin(at: Vector2, s: float, body: Color, stripe: Color) -> void:
	var pts := PackedVector2Array()
	# A bowling pin outline: head, neck, belly, flat foot.
	var right := [Vector2(0, -0.55), Vector2(0.1, -0.52), Vector2(0.13, -0.42), Vector2(0.08, -0.26),
			Vector2(0.07, -0.16), Vector2(0.17, 0.05), Vector2(0.2, 0.25), Vector2(0.15, 0.45), Vector2(0.1, 0.52)]
	for p in right:
		pts.append(at + p * s)
	for i in range(right.size() - 1, -1, -1):
		pts.append(at + Vector2(-right[i].x, right[i].y) * s)
	_outlined(pts, body)
	draw_rect(Rect2(at + Vector2(-0.075, -0.24) * s, Vector2(0.15, 0.05) * s), stripe)
	draw_rect(Rect2(at + Vector2(-0.08, -0.16) * s, Vector2(0.16, 0.05) * s), stripe)


func _star(at: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := outer if i % 2 == 0 else inner
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * rad)
	return pts


## A filled shape with a dark outline.
func _outlined(pts: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(pts, col)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, _c(INK), 0.06)


func _ellipse_line(at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var a := i * TAU / 24.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_polyline(pts, col, 0.04)


## Text in emblem units (drawn at real size so it stays sharp).
func _text(t: String, at: Vector2, height: float, col: Color) -> void:
	var r := minf(size.x, size.y) * 0.5
	var px := maxi(int(height * r), 8)
	draw_set_transform(size * 0.5)
	var w := FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := at * r + Vector2(-w * 0.5, px * 0.35)
	draw_string_outline(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, maxi(px / 6, 2), _c(INK))
	draw_string(FONT, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	draw_set_transform(size * 0.5, 0.0, Vector2(r, r))
