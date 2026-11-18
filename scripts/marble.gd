class_name Marble
extends RigidBody3D
## A player's marble. Gravity and the lane do most of the work; the player
## can only lean it gently.
##
## The marble never reads the keyboard itself. Whoever runs the game sets
## `lean` every physics tick (main.gd does it from local keys today). In
## online play the host will set it from each player's network input
## instead, so this script won't need to change.

## Which player owns this marble (0-based).
@export var player_id := 0
## Sideways lean force. Raise it for sharper steering.
@export var lean_side_force := 5.5
## Forward/back lean force, weaker than sideways on purpose.
@export var lean_forward_force := 3.0
## Top speed in metres per second. Keeps boosted marbles from launching
## off the end of the lane over the pins.
@export var max_speed := 11.0
## Extra push when the marble hits a bumper post.
@export var bumper_kick := 2.5

## Lean input in lane space: x = left/right (-1..1), y = forward/back
## (-1 = forward, toward the pins).
var lean := Vector2.ZERO
## Set by the game when the marble crosses the arrival line or falls out.
var arrived := false
var out := false
## Player whose piece knocked this marble out (-1 = nobody, e.g. it just
## rolled off the edge).
var knocked_out_by := -1
## Seconds this marble has been nearly still (the game nudges stuck marbles).
var still_time := 0.0

var color := Color.WHITE:
	set(value):
		color = value
		_apply_color()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_color()


func _physics_process(_delta: float) -> void:
	if freeze or out:
		return
	var l := lean.limit_length(1.0)
	# The lane runs along -Z and is not rotated sideways, so lane space and
	# world space line up on the X and Z axes.
	var force := Vector3(l.x * lean_side_force, 0.0, l.y * lean_forward_force)
	apply_central_force(force * mass)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.limit_length(max_speed)


## Take this marble out of the frame (fell in a gutter, for example).
func knock_out(by_player: int) -> void:
	if out or arrived:
		return
	out = true
	knocked_out_by = by_player
	set_deferred("freeze", true)
	visible = false


func set_marble_collision(enabled: bool) -> void:
	## Turn marble-vs-marble collision on or off (the design doc's
	## "one setting" to compare). Layer 2 is marbles.
	set_collision_mask_value(2, enabled)


func _on_body_entered(body: Node) -> void:
	if body is Pin:
		# Credit from this side too: with fast hits the physics engine
		# sometimes reports the contact to only one of the two bodies.
		(body as Pin).credit(player_id)
	elif body.is_in_group("bumper"):
		# Kick sideways only, so bumpers scatter marbles across the lane
		# instead of sending them back up the hill.
		var side: float = global_position.x - (body as Node3D).global_position.x
		var dir := signf(side) if absf(side) > 0.02 else (1.0 if randf() < 0.5 else -1.0)
		apply_central_impulse(Vector3(dir * bumper_kick * mass, 0.0, 0.0))


func _apply_color() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.1
	mat.roughness = 0.15
	mat.clearcoat_enabled = true
	mesh.material_override = mat
