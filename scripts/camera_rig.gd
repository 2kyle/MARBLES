class_name CameraRig
extends Camera3D
## Smoothly follows a point chosen by the game (usually the middle of the
## marbles still rolling) from behind and above, looking down the lane.
## The offsets are relative to `heading`, so the camera swings round to stay
## behind the marbles when the track bends.

@export var follow_offset := Vector3(0, 8.0, 7.0)
@export var look_ahead := Vector3(0, -2.0, -10.0)
@export var smoothing := 3.0

var target := Vector3.ZERO
## Direction "down the lane" for the camera (only its flat part is used).
var heading := Vector3.FORWARD
var _look := Vector3.ZERO
var _yaw := 0.0


func snap_to(point: Vector3) -> void:
	target = point
	_yaw = _heading_yaw()
	var rot := Basis(Vector3.UP, _yaw)
	global_position = point + rot * follow_offset
	_look = point + rot * look_ahead
	look_at(_look)


func _process(delta: float) -> void:
	var w := 1.0 - exp(-smoothing * delta)
	_yaw = lerp_angle(_yaw, _heading_yaw(), 1.0 - exp(-smoothing * 0.6 * delta))
	var rot := Basis(Vector3.UP, _yaw)
	global_position = global_position.lerp(target + rot * follow_offset, w)
	_look = _look.lerp(target + rot * look_ahead, w)
	look_at(_look)


func _heading_yaw() -> float:
	if Vector2(heading.x, heading.z).length() < 0.01:
		return _yaw
	return atan2(-heading.x, -heading.z)
