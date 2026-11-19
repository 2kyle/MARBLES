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
@export var lean_side_force := 7.5
## Forward/back lean force, weaker than sideways on purpose.
@export var lean_forward_force := 4.0
## How fast the lean builds up when you press a key, and dies away when you
## let go (per second). Higher = snappier, lower = floatier.
@export var lean_attack := 7.0
@export var lean_release := 10.0
## Extra sideways force when you steer against the way you're sliding, so
## changing direction feels quick instead of mushy.
@export var counter_steer_boost := 1.7
## Top speed in metres per second. Keeps boosted marbles from launching
## off the end of the lane over the pins.
@export var max_speed := 11.0
## Extra push when the marble hits a bumper post.
@export var bumper_kick := 2.5
## How hard a hop pushes off the floor (metres per second). 4.0 is a small
## hop: about 0.8 m high, enough to clear a gap if timed well but not the
## walls.
@export var hop_speed := 4.0
## Seconds before the marble can hop again.
@export var hop_cooldown := 0.8

## Fired when the marble hops (for the puff effect and sound later).
signal hopped
## Fired when the marble comes down hard after being in the air, or hits
## another marble. `strength` is roughly the impact speed in m/s.
signal landed(strength: float)
signal bumped(strength: float)

## Lean input in lane space: x = left/right (-1..1), y = forward/back
## (-1 = forward, toward the pins).
var lean := Vector2.ZERO
## Which way the lane runs under the marble right now (the game updates it
## every tick from the track): x = lane's right, z = back up the lane.
var lane_basis := Basis.IDENTITY
## Set by the game when the marble crosses the arrival line or falls out.
var arrived := false
var out := false
## Player whose piece knocked this marble out (-1 = nobody, e.g. it just
## rolled off the edge).
var knocked_out_by := -1
## Seconds this marble has been nearly still (the game nudges stuck marbles).
var still_time := 0.0
## Furthest the marble has got down the track, and when (the game rescues
## marbles that stop making progress).
var best_distance := 0.0
var best_time := 0.0
## Seconds left sitting still after missing a jump (the game sets it).
var hold_time := 0.0

var _hop_wait := 0.0
var _lean_now := Vector2.ZERO
var _air_time := 0.0
var _fall_speed := 0.0

var color := Color.WHITE:
	set(value):
		color = value
		_apply_look()

## The player's chosen look: {color, style, trail} entries from Cosmetics.
## Empty = plain glossy ball in `color`.
var look: Dictionary = {}:
	set(value):
		look = value
		if look.has("color"):
			color = look.color.color  # also re-applies the look
		else:
			_apply_look()
## Spin slowly in place and show the trail (locker screen preview).
var preview := false:
	set(value):
		preview = value
		if _trail:
			_trail.preview = value

var _trail: MarbleTrail

const MARBLE_SHADER := preload("res://shaders/marble.gdshader")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_look()


func _process(delta: float) -> void:
	if preview:
		var mesh := get_node_or_null("Mesh") as Node3D
		if mesh:
			mesh.rotate_y(delta * 1.2)
			mesh.rotate_x(delta * 0.5)


func _physics_process(delta: float) -> void:
	if freeze or out:
		return
	_hop_wait = maxf(_hop_wait - delta, 0.0)
	if hold_time > 0.0:
		hold_time -= delta
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		return
	# Ease the lean in and out so steering is smooth, not twitchy.
	var want := lean.limit_length(1.0)
	var rate := lean_attack if want.length() > _lean_now.length() - 0.01 else lean_release
	_lean_now = _lean_now.move_toward(want, rate * delta)
	var l := _lean_now
	# Lean is relative to the lane, so "left" always means the lane's left
	# even when the track bends.
	var side := l.x * lean_side_force
	var slide := linear_velocity.dot(lane_basis.x)
	if absf(slide) > 0.3 and signf(slide) != signf(l.x):
		side *= counter_steer_boost
	var force := lane_basis.x * side + lane_basis.z * l.y * lean_forward_force
	apply_central_force(force * mass)
	_track_landing(delta)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.limit_length(max_speed)


## Notice when the marble lands after some time in the air.
func _track_landing(delta: float) -> void:
	if floor_normal() == Vector3.ZERO:
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -linear_velocity.y)
		return
	if _air_time > 0.25 and _fall_speed > 2.0:
		landed.emit(_fall_speed)
		_hop_puff()
	_air_time = 0.0
	_fall_speed = 0.0


## Hop off the floor. Only works when touching the ground and not too soon
## after the last hop, so there's no flying. Returns true if it hopped.
## Like `lean`, the game calls this when the player presses the hop key.
func request_hop() -> bool:
	if freeze or out or arrived or hold_time > 0.0 or _hop_wait > 0.0:
		return false
	var normal := floor_normal()
	if normal == Vector3.ZERO:
		return false
	# Cancel any speed into the floor, then push off it.
	var into := linear_velocity.dot(normal)
	if into < 0.0:
		linear_velocity -= normal * into
	linear_velocity += normal * hop_speed
	_hop_wait = hop_cooldown
	hopped.emit()
	_hop_puff()
	return true


## The floor's up direction under the marble, or zero if it's in the air.
func floor_normal() -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position,
			global_position + Vector3.DOWN * 0.48, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.ZERO
	return hit.normal


## A little ring of dust where the marble pushed off.
func _hop_puff() -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 14
	puff.lifetime = 0.45
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 80.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.2
	puff.gravity = Vector3(0, -3, 0)
	puff.scale_amount_min = 0.6
	puff.scale_amount_max = 1.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.5)
	mesh.material = mat
	puff.mesh = mesh
	get_parent().add_child(puff)
	puff.global_position = global_position + Vector3.DOWN * 0.25
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)


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
	if body is Marble:
		var hit := (linear_velocity - (body as Marble).linear_velocity).length()
		if hit > 2.5 and player_id < (body as Marble).player_id:
			bumped.emit(hit)  # once per crash, from the lower player id
	elif body is Pin:
		# Credit from this side too: with fast hits the physics engine
		# sometimes reports the contact to only one of the two bodies.
		(body as Pin).credit(player_id)
	elif body.is_in_group("bumper"):
		# Kick sideways only, so bumpers scatter marbles across the lane
		# instead of sending them back up the hill.
		var side: float = lane_basis.x.dot(global_position - (body as Node3D).global_position)
		var dir := signf(side) if absf(side) > 0.02 else (1.0 if randf() < 0.5 else -1.0)
		apply_central_impulse(lane_basis.x * dir * bumper_kick * mass)


func _apply_look() -> void:
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var style: Dictionary = look.get("style", Cosmetics.STYLES[0])
	if style.pattern < 0:
		# Glass: see-through, so it uses a plain material.
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(color.r, color.g, color.b, 0.35)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.02
		glass.metallic_specular = 1.0
		glass.rim_enabled = true
		glass.rim = 0.8
		glass.clearcoat_enabled = true
		mesh.material_override = glass
	else:
		var mat := ShaderMaterial.new()
		mat.shader = MARBLE_SHADER
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("pattern", style.pattern)
		mat.set_shader_parameter("metallic_amount", style.metallic)
		mat.set_shader_parameter("roughness_amount", style.roughness)
		mat.set_shader_parameter("glow", style.glow)
		mesh.material_override = mat
	var trail_id: String = look.get("trail", {"id": "none"}).id
	if _trail == null:
		_trail = MarbleTrail.new()
		add_child(_trail)
	_trail.setup(trail_id, color)
	_trail.preview = preview
