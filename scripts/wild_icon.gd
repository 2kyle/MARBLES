class_name WildIcon
extends Control
## A little drawn badge for a WILD FRAMES rule: a round disc in the rule's
## colour with a picture on it (a feather for LOW GRAVITY, a spring for
## SUPER BOUNCY, a flame for TURBO, a weight for HEAVY BALLS, a snowflake
## for ICE RINK, an up arrow for BIG HOPS, a tiny ball beside a big one for
## TINY BALLS, swapped arrows for REVERSE STEER, a horseshoe magnet for
## MAGNET MANIA and gusts for WINDY). Rule "?" draws a mystery badge
## (a wild frame that hasn't happened yet).
##
##   var icon := WildIcon.make("ice", 48)

const INK := Color(0.07, 0.04, 0.12)
const FONT := preload("res://fonts/Righteous-Regular.ttf")
## Rules with their own picture (any other rule gets the "?" badge).
const PICTURES := ["low_gravity", "bouncy", "turbo", "heavy", "ice", "big_hops", "tiny", "reverse", "magnet", "windy"]

## The rule's id from WildFrames.LIST, or "?".
var rule := "":
	set(v):
		rule = v
		queue_redraw()
## Spin the badge slowly (for the big splash).
var spin := false


static func has_picture(rule_id: String) -> bool:
	return rule_id in PICTURES


static func make(rule_id: String, size: float) -> WildIcon:
	var w := WildIcon.new()
	w.rule = rule_id
	w.custom_minimum_size = Vector2(size, size)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w


func _process(_d: float) -> void:
	if spin:
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s * 0.5
	var col: Color = WildFrames.info(rule).get("color", Color(1.0, 0.8, 0.25))
	# Disc with a dark rim, and a starburst behind when spinning.
	if spin:
		var t := Time.get_ticks_msec() / 1000.0
		for k in 12:
			var a := t * 0.8 + k * TAU / 12.0
			var pts := PackedVector2Array([c + Vector2.from_angle(a - 0.12) * r * 0.8,
					c + Vector2.from_angle(a) * r * 1.0, c + Vector2.from_angle(a + 0.12) * r * 0.8])
			draw_colored_polygon(pts, Color(col, 0.55))
		r *= 0.78
	draw_circle(c, r, INK)
	draw_circle(c, r * 0.86, col)
	draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.25))
	var u := r * 0.55   # picture size
	var w := maxf(s * 0.06, 2.0)
	match rule:
		"low_gravity":
			# A feather: a curved quill with vanes.
			var tip := c + Vector2(u * 0.7, -u * 0.8)
			var base := c + Vector2(-u * 0.7, u * 0.8)
			draw_line(base, tip, INK, w)
			for k in 5:
				var p := base.lerp(tip, 0.25 + k * 0.15)
				draw_line(p, p + Vector2(-u * 0.45, -u * 0.15), INK, w * 0.8)
				draw_line(p, p + Vector2(u * 0.15, u * 0.45), INK, w * 0.8)
		"bouncy":
			# A spring (zig-zag) with a ball on top.
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(c + Vector2((-1 if k % 2 == 0 else 1) * u * 0.5, u * 0.9 - k * u * 0.22))
			draw_polyline(pts, INK, w)
			draw_circle(c + Vector2(0, -u * 0.75), u * 0.32, INK)
		"turbo":
			# A flame.
			var pts := PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.55, -u * 0.1),
					c + Vector2(u * 0.6, u * 0.45), c + Vector2(0, u * 0.9), c + Vector2(-u * 0.6, u * 0.45),
					c + Vector2(-u * 0.35, -u * 0.2), c + Vector2(-u * 0.1, u * 0.05)])
			draw_colored_polygon(pts, INK)
			draw_circle(c + Vector2(0, u * 0.45), u * 0.28, col.lightened(0.4))
		"heavy":
			# A kettlebell weight.
			draw_arc(c + Vector2(0, -u * 0.45), u * 0.35, PI, TAU, 12, INK, w * 1.2)
			draw_rect(Rect2(c + Vector2(-u * 0.7, -u * 0.35), Vector2(u * 1.4, u * 1.15)), INK)
			draw_string(FONT, c + Vector2(-u * 0.4, u * 0.55), "3x", HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 0.7), col.lightened(0.3))
		"ice":
			# A snowflake.
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3.0 + PI / 2.0) * u
				draw_line(c - d, c + d, INK, w)
				for e in [-1.0, 1.0]:
					var p: Vector2 = c + d * 0.6 * e
					draw_line(p, p + d.rotated(0.8) * 0.3 * e, INK, w * 0.8)
					draw_line(p, p + d.rotated(-0.8) * 0.3 * e, INK, w * 0.8)
		"big_hops":
			# A big up arrow over a little ball.
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -u), c + Vector2(u * 0.7, -u * 0.2),
					c + Vector2(u * 0.25, -u * 0.2), c + Vector2(u * 0.25, u * 0.35), c + Vector2(-u * 0.25, u * 0.35),
					c + Vector2(-u * 0.25, -u * 0.2), c + Vector2(-u * 0.7, -u * 0.2)]), INK)
			draw_circle(c + Vector2(0, u * 0.75), u * 0.22, INK)
		"tiny":
			# A big ball outline and a little solid ball.
			draw_arc(c + Vector2(-u * 0.25, -u * 0.1), u * 0.6, 0.0, TAU, 24, INK, w)
			draw_circle(c + Vector2(u * 0.6, u * 0.55), u * 0.28, INK)
		"reverse":
			# Two arrows, one each way, crossing over.
			for k in [-1.0, 1.0]:
				var y: float = k * u * 0.38
				var tip := c + Vector2(k * u * 0.85, y)
				draw_line(c + Vector2(-k * u * 0.75, y), tip, INK, w * 1.3)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(k * u * 0.15, 0),
						tip + Vector2(-k * u * 0.3, -u * 0.28), tip + Vector2(-k * u * 0.3, u * 0.28)]), INK)
		"magnet":
			# A horseshoe magnet with light tips.
			draw_arc(c + Vector2(0, -u * 0.05), u * 0.62, PI, TAU, 16, INK, w * 2.6)
			for k in [-1.0, 1.0]:
				draw_line(c + Vector2(k * u * 0.62, -u * 0.05), c + Vector2(k * u * 0.62, u * 0.55), INK, w * 2.6)
				draw_rect(Rect2(c + Vector2(k * u * 0.62 - w * 1.3, u * 0.45), Vector2(w * 2.6, u * 0.32)), col.lightened(0.55))
		"windy":
			# Three curly gusts.
			for k in 3:
				var y := (k - 1) * u * 0.55
				var len := u * (1.2 if k == 1 else 0.9)
				var x0 := -u * 0.8
				draw_line(c + Vector2(x0, y), c + Vector2(x0 + len, y), INK, w)
				draw_arc(c + Vector2(x0 + len, y - u * 0.18), u * 0.18, -PI * 0.5, PI * 0.9, 8, INK, w)
		_:
			# A mystery: a question mark.
			draw_string(FONT, c + Vector2(-u * 0.38, u * 0.62), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 1.9), INK)
