class_name Pin
extends RigidBody3D
## One bowling pin. Remembers which player gets credit for it:
## the first marble to touch it, or, if another pin knocks it, whoever
## owns that pin (so chain reactions credit the player who started them).

signal fell(pin: Pin)

## Tilt past this angle (degrees) counts as knocked down.
const FALL_ANGLE := 55.0
## Dropping this far below its start counts as knocked down (off the deck).
const FALL_DROP := 0.5

## Player id credited with this pin, or -1 if nobody has touched it.
var credited_to := -1
var fallen := false

var _start_y := 0.0


func _ready() -> void:
	_start_y = global_position.y
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if credited_to == -1:
		# Also check ongoing contacts, in case a neighbour got its credit
		# after it first touched us (contact order within a tick varies).
		for body in get_colliding_bodies():
			_on_body_entered(body)
	if fallen:
		return
	var tilt := rad_to_deg(global_basis.y.angle_to(Vector3.UP))
	if tilt > FALL_ANGLE or global_position.y < _start_y - FALL_DROP:
		fallen = true
		fell.emit(self)


## Give this pin to a player, unless someone already has it.
func credit(player_id: int) -> void:
	if credited_to == -1 and player_id != -1:
		credited_to = player_id


func _on_body_entered(body: Node) -> void:
	if body is Marble:
		credit((body as Marble).player_id)
	elif body is Pin:
		var other := body as Pin
		if credited_to == -1:
			credit(other.credited_to)
		elif other.credited_to == -1:
			# The engine may report a pin-pin contact to only one of the two.
			other.credit(credited_to)
