extends Area3D
## Slows down any marble rolling across it.

var placed_by := -1
## How hard the carpet drags. Higher = slower marbles.
@export var drag := 2.5


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		if body is Marble:
			var m := body as Marble
			m.apply_central_force(-m.linear_velocity * drag * m.mass)
