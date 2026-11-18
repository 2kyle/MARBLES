extends Node3D
## A square of lane that rocks from side to side, tipping marbles off line.

var placed_by := -1
## Biggest tilt, in degrees.
@export var max_tilt := 11.0
## Rocks back and forth this many times per second.
@export var rocks_per_second := 0.35

var _time := 0.0

@onready var _plate: AnimatableBody3D = $Plate


func _physics_process(delta: float) -> void:
	_time += delta
	_plate.rotation.z = deg_to_rad(max_tilt) * sin(TAU * rocks_per_second * _time)
