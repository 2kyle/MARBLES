class_name CameraRig
extends Camera3D
## Smoothly follows a point chosen by the game (usually the middle of the
## marbles still rolling) from behind and above, looking down the lane.
## The offsets are relative to `heading`, so the camera swings round to stay
## behind the marbles when the track bends.
##
## If the game fills `frame_points` (world positions that must stay on
## screen, like every marble or every build cursor), the camera pulls back
## just far enough to keep them all in view, and moves in again when they
## bunch up.

@export var follow_offset := Vector3(0, 8.0, 7.0)
@export var look_ahead := Vector3(0, -2.0, -10.0)
@export var smoothing := 3.0
## How much of the screen the framed points may use (1 = right to the edge).
@export_range(0.3, 1.0) var frame_margin := 0.72
## Furthest the camera will pull back, as a multiple of `follow_offset`.
@export var max_zoom := 4.5
## How fast the camera pulls back (fast) and moves in again (slow).
@export var zoom_out_speed := 4.0
@export var zoom_in_speed := 0.9

var target := Vector3.ZERO
## Direction "down the lane" for the camera (only its flat part is used).
var heading := Vector3.FORWARD
## World points to keep on screen. Empty = just follow `target`.
var frame_points: Array = []

var _look := Vector3.ZERO
var _yaw := 0.0
var _zoom := 1.0
var _shake := 0.0
var _shake_t := 0.0


func snap_to(point: Vector3) -> void:
	target = point
	_yaw = _heading_yaw()
	var rot := Basis(Vector3.UP, _yaw)
	_zoom = _fit_zoom(rot)
	global_position = point + rot * follow_offset * _zoom
	_look = point + rot * look_ahead
	look_at(_look)


## A short shake for big hits. `amount` 0..1; shakes add up but fade fast.
func shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	var w := 1.0 - exp(-smoothing * delta)
	_yaw = lerp_angle(_yaw, _heading_yaw(), 1.0 - exp(-smoothing * 0.6 * delta))
	var rot := Basis(Vector3.UP, _yaw)
	var want := _fit_zoom(rot)
	var speed := zoom_out_speed if want > _zoom else zoom_in_speed
	_zoom = lerpf(_zoom, want, 1.0 - exp(-speed * delta))
	global_position = global_position.lerp(target + rot * follow_offset * _zoom, w)
	_look = _look.lerp(target + rot * look_ahead, w)
	look_at(_look)
	if _shake > 0.0:
		_shake_t += delta * 40.0
		var s := _shake * _shake * 0.35
		global_position += global_basis * Vector3(sin(_shake_t * 1.3), cos(_shake_t * 1.7), 0) * s
		rotate_object_local(Vector3.FORWARD, sin(_shake_t * 0.9) * s * 0.06)
		_shake = maxf(_shake - delta * 2.5, 0.0)


## The smallest zoom (1 = follow_offset as set) that keeps every frame
## point on screen, found by trying zooms and halving the gap.
func _fit_zoom(rot: Basis) -> float:
	if frame_points.is_empty() or _fits(1.0, rot):
		return 1.0
	if not _fits(max_zoom, rot):
		return max_zoom
	var lo := 1.0
	var hi := max_zoom
	for i in 10:
		var mid := (lo + hi) / 2.0
		if _fits(mid, rot):
			hi = mid
		else:
			lo = mid
	return hi


func _fits(zoom: float, rot: Basis) -> bool:
	var pos := target + rot * follow_offset * zoom
	var look := target + rot * look_ahead
	var basis := Basis.looking_at(look - pos, Vector3.UP)
	var tan_v := tan(deg_to_rad(fov) / 2.0) * frame_margin
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var tan_h := tan_v * size.x / maxf(size.y, 1.0)
	var inv := basis.inverse()
	for p in frame_points:
		var local: Vector3 = inv * ((p as Vector3) - pos)
		var depth := -local.z
		if depth < 1.0:
			return false
		if absf(local.x) / depth > tan_h or absf(local.y) / depth > tan_v:
			return false
	return true


func _heading_yaw() -> float:
	if Vector2(heading.x, heading.z).length() < 0.01:
		return _yaw
	return atan2(-heading.x, -heading.z)
