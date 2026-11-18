extends Node3D
## A paddle that never stops turning and swats any marble it meets.

var placed_by := -1
## Turning speed in turns per second. Negative spins the other way.
@export var turns_per_second := 0.45

@onready var _paddle: AnimatableBody3D = $Paddle


func _physics_process(delta: float) -> void:
	_paddle.rotate_y(TAU * turns_per_second * delta)
