class_name CameraRig
extends Camera3D
## Smoothly follows a point chosen by the game (usually the middle of the
## marbles still rolling) from behind and above, looking down the lane.

@export var follow_offset := Vector3(0, 5.5, 9.0)
@export var look_ahead := Vector3(0, -0.5, -6.0)
@export var smoothing := 3.0

var target := Vector3.ZERO
var _look := Vector3.ZERO


func snap_to(point: Vector3) -> void:
	target = point
	global_position = point + follow_offset
	_look = point + look_ahead
	look_at(_look)


func _process(delta: float) -> void:
	var w := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(target + follow_offset, w)
	_look = _look.lerp(target + look_ahead, w)
	look_at(_look)
