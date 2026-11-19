class_name Rack
extends Node3D
## The shared rack of pins at the end of the lane. Place this node where the
## head pin should stand (on the deck surface); rows extend toward -Z.

## Emitted when every pin is down. `player_id` knocked the last one (or -1).
signal swept(player_id: int)

@export var pin_scene: PackedScene = preload("res://scenes/pin.tscn")
## Rows of pins. 7 rows = 28 pins (regular bowling uses 4 rows = 10).
@export_range(1, 8) var rows := 7
## Distance between neighbouring pins.
@export var spacing := 0.78

var pins: Array[Pin] = []
var last_fallen: Pin = null


func reset() -> void:
	for p in pins:
		remove_child(p)
		p.queue_free()
	pins.clear()
	last_fallen = null
	var row_depth := spacing * sqrt(3.0) / 2.0
	for row in rows:
		for i in row + 1:
			var pin: Pin = pin_scene.instantiate()
			var x := (i - row / 2.0) * spacing
			pin.position = Vector3(x, 0.52, -row * row_depth)
			pin.fell.connect(_on_pin_fell)
			add_child(pin)
			pins.append(pin)


func pin_count() -> int:
	return pins.size()


func standing_count() -> int:
	var n := 0
	for p in pins:
		if not p.fallen:
			n += 1
	return n


## One entry per fallen pin: the player id credited with it (-1 = nobody).
func fallen_credits() -> Array:
	var credits := []
	for p in pins:
		if p.fallen:
			credits.append(p.credited_to)
	return credits


func _on_pin_fell(pin: Pin) -> void:
	last_fallen = pin
	if standing_count() == 0:
		swept.emit(pin.credited_to)
