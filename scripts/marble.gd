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
@export var lean_side_force := 8.0
## Forward/back lean force, a bit weaker than sideways on purpose.
@export var lean_forward_force := 6.0
## How fast the lean builds up when you press a key, and dies away when you
## let go (per second). Higher = snappier, lower = floatier.
@export var lean_attack := 16.0
@export var lean_release := 18.0
## Extra force when you steer against the way you're moving (after a
## bounce off a wall, say), so turning back is quick instead of mushy.
## Up to this many times the normal force, the faster you're going the
## wrong way.
@export var counter_steer_boost := 2.6
## How much the ball's spin follows your steering. A rolling ball has to
## stop spinning one way before it can roll back the other, which feels
## like steering a shopping trolley; this turns the spin with the push.
## 0 = plain physics, 1 = spin always matches.
@export var spin_assist := 1.0
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
## Forgiving hops: a hop pressed this many seconds after rolling off an
## edge still works ("coyote time"), and one pressed this long before
## landing happens the moment it lands (a "buffered" hop). Both make
## gap jumps feel fair instead of frame-perfect.
@export var coyote_time := 0.14
@export var hop_buffer_time := 0.16
## How much the ball squashes and stretches (0 = rigid). Only the picture
## changes, never the physics.
@export var squash_amount := 1.0

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

var _hop_wait := 0.0
## While above 0, leaning does nothing (counts down in seconds). Used when
## something launches the marble, like the trampoline, so it flies true.
var no_steer_time := 0.0
var _lean_now := Vector2.ZERO
var _air_time := 0.0
var _fall_speed := 0.0
## Last floor the marble touched (for coyote-time hops) and a hop waiting
## to happen on landing (seconds left).
var _last_floor := Vector3.UP
var _hop_buffered := 0.0
## Squash spring: 0 = round, + = squashed flat, - = stretched tall.
var _squash := 0.0
var _squash_vel := 0.0
## A soft round shadow straight under the ball while it's in the air, so
## you can see where it will land.
var _blob: MeshInstance3D
static var _blob_mat: StandardMaterial3D

var color := Color.WHITE:
	set(value):
		color = value
		_apply_look()

## The player's chosen look: {hat, eyes, color, style, trail} entries from Cosmetics.
## Empty = plain glossy ball in `color`.
var look: Dictionary = {}:
	set(value):
		look = value
		if look.has("color"):
			color = look.color.color  # also re-applies the look
		else:
			_apply_look()
## Spin slowly in place and show the trail (customize screen preview).
var preview := false:
	set(value):
		preview = value
		if _trail:
			_trail.preview = value

var _trail: MarbleTrail
## Face the camera instead of the way it's rolling (display balls).
var face_camera := false
## The hat rides on top of the ball without rolling with it, so it's a
## top-level node that follows the ball's middle and turns to face the way
## the ball is going.
var _hat: Node3D
var _hat_id := ""
## Which way the face points (yaw, radians), without look_offset.
var _heading := 0.0
## The eyes ride along like the hat, so you can see them blink and wince.
var _eyes: EyeRig
var _eyes_id := ""
## Extra turn of the face (radians), e.g. for shaking its head on the podium.
var look_offset := 0.0
var _face_time := 0.0
var _yaw_ready := false  # false until the first placement (then snap, don't swing)
var _last_pos := Vector3.ZERO
## How fast the ball is moving, worked out from where it was last frame
## (so it also works when the ball is moved by network updates).
var _seen_velocity := Vector3.ZERO

const MARBLE_SHADER := preload("res://shaders/marble.gdshader")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	landed.connect(wince)
	landed.connect(func(strength):
		squash(clampf(strength / 9.0, 0.0, 0.45))
		if strength > 7.5 and not preview:
			PopText.spawn(self, global_position + Vector3.UP * 0.7, "THUD!", Color(0.95, 0.9, 0.8), 0.8))
	hopped.connect(func(): squash(-0.28))
	_last_pos = global_position
	_apply_look()


## How fast the ball is moving (also right for network-moved marbles).
func seen_velocity() -> Vector3:
	return _seen_velocity


## Rub out the trail behind the ball (when it jumps somewhere, like at the
## start and end of a strike replay, so no streak is drawn across the lane).
func clear_trail() -> void:
	if _trail:
		_trail.clear()
	_last_pos = global_position


## Squeeze the eyes shut after a knock. `strength` is the impact speed.
func wince(strength: float) -> void:
	if _eyes:
		_eyes.wince(strength)


func _process(delta: float) -> void:
	if preview:
		var mesh := get_node_or_null("Mesh") as Node3D
		if mesh:
			mesh.rotate_y(delta * 1.2)
			mesh.rotate_x(delta * 0.5)
	_place_hat(delta)
	_update_squash(delta)
	_update_blob()


## Give the ball a squash (+, flatten) or stretch (-, tall) that springs
## back. Landings squash it, hops stretch it.
func squash(amount: float) -> void:
	_squash_vel += amount * 22.0 * squash_amount


func _update_squash(delta: float) -> void:
	var mesh := get_node_or_null("Mesh") as Node3D
	if mesh == null or delta <= 0.0:
		return
	# A springy wobble: stiff, so it settles in about a third of a second.
	_squash_vel += (-_squash * 260.0 - _squash_vel * 14.0) * delta
	_squash = clampf(_squash + _squash_vel * delta, -0.35, 0.45)
	if absf(_squash) < 0.002 and absf(_squash_vel) < 0.01:
		_squash = 0.0
		_squash_vel = 0.0
		if mesh.basis != Basis.IDENTITY and not preview:
			mesh.basis = Basis.IDENTITY
		return
	# Squash along the world's up, whichever way the ball has rolled: turn
	# the world-space squash into the ball's own (rolling) space.
	var f := 1.0 - _squash
	var g := 1.0 + _squash * 0.5
	var up := Vector3.UP
	var s := Basis(Vector3(g, 0, 0), Vector3(0, g, 0), Vector3(0, 0, g))
	s.x += up * up.x * (f - g)
	s.y += up * up.y * (f - g)
	s.z += up * up.z * (f - g)
	var b := global_basis.orthonormalized()
	mesh.basis = b.inverse() * s * b


func _update_blob() -> void:
	if preview or face_camera or not is_inside_tree() or not visible or out:
		if _blob:
			_blob.visible = false
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 8.0, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var h: float = global_position.y - hit.position.y if not hit.is_empty() else 99.0
	# Only while airborne (on the ground the sun's shadow does the job),
	# and fading out when very high.
	var a := clampf((h - 0.45) / 0.35, 0.0, 1.0) * clampf((7.0 - h) / 3.0, 0.0, 1.0)
	if a <= 0.01:
		if _blob:
			_blob.visible = false
		return
	if _blob == null:
		_blob = MeshInstance3D.new()
		_blob.top_level = true
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75, 0.75)
		quad.orientation = PlaneMesh.FACE_Y
		_blob.mesh = quad
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _blob_mat == null:
			var grad := Gradient.new()
			grad.set_color(0, Color(0, 0, 0, 0.6))
			grad.set_color(1, Color(0, 0, 0, 0))
			var tex := GradientTexture2D.new()
			tex.gradient = grad
			tex.fill = GradientTexture2D.FILL_RADIAL
			tex.fill_from = Vector2(0.5, 0.5)
			tex.fill_to = Vector2(1.0, 0.5)
			_blob_mat = StandardMaterial3D.new()
			_blob_mat.albedo_texture = tex
			_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_blob_mat.vertex_color_use_as_albedo = false
		_blob.material_override = _blob_mat
		add_child(_blob)
	_blob.visible = true
	var n: Vector3 = hit.normal
	var x := n.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	# Shrinks a little the higher the ball is.
	var size := lerpf(1.0, 0.6, clampf(h / 6.0, 0.0, 1.0)) * a
	_blob.global_transform = Transform3D(Basis(x, n, x.cross(n)).scaled(Vector3.ONE * maxf(size, 0.05)), hit.position + n * 0.03)


## Keep the hat and eyes on the ball. They don't roll with it: they turn to
## face the way the ball is going, like a head, and keep facing that way
## when it stops. Display balls (closet, ready screen, podium) face the
## camera instead.
func _place_hat(delta: float) -> void:
	if delta > 0.0 and is_inside_tree():
		_seen_velocity = _seen_velocity.lerp((global_position - _last_pos) / delta, 0.3)
		_last_pos = global_position
	if (_hat == null and _eyes == null) or not is_inside_tree():
		return
	_face_time += delta
	var flat := Vector3(_seen_velocity.x, 0.0, _seen_velocity.z)
	var cam := get_viewport().get_camera_3d()
	var to_cam := Vector3.BACK
	if cam:
		to_cam = cam.global_position - global_position
	var showing := preview or face_camera
	var want := _heading
	var turn_rate := 6.0
	if showing or not _yaw_ready:
		want = atan2(-to_cam.x, -to_cam.z)
		if preview:
			# Showing off (closet, ready screen): look about a little.
			want += sin(_face_time * 1.1) * 0.3
	elif flat.length() > 0.6:
		want = atan2(-flat.x, -flat.z)
		# Turn quicker the faster it's going, so it never looks backwards for long.
		turn_rate = clampf(flat.length() * 1.5, 4.0, 12.0)
	if delta > 0.0 and _yaw_ready:
		_heading = lerp_angle(_heading, want, clampf(delta * turn_rate, 0.0, 1.0))
	else:
		_heading = want
		_yaw_ready = true
	var yaw := _heading + look_offset
	var size := global_transform.basis.get_scale().x * 0.3
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), global_position)
	if _hat:
		_hat.global_transform = t
		Hats.animate(_hat, delta, flat.length())
	if _eyes:
		# Display balls tip their eyes up a little toward a camera above them.
		var pitch := 0.0
		if showing:
			var flat_dist := Vector2(to_cam.x, to_cam.z).length()
			pitch = clampf(atan2(to_cam.y, flat_dist) * 0.6, 0.0, 0.6)
		_eyes.global_transform = Transform3D(t.basis * Basis(Vector3.RIGHT, pitch), t.origin)
		_eyes.update(delta, Basis(Vector3.UP, -yaw) * _seen_velocity)


func _physics_process(delta: float) -> void:
	if freeze or out:
		return
	_hop_wait = maxf(_hop_wait - delta, 0.0)
	if _hop_buffered > 0.0:
		_hop_buffered -= delta
		if _hop_wait <= 0.0 and floor_normal() != Vector3.ZERO:
			_hop_buffered = 0.0
			request_hop()
	if no_steer_time > 0.0:
		no_steer_time -= delta
		_track_landing(delta)
		return
	if arrived:
		# Past the finish line: no more steering, just the momentum it has.
		_lean_now = Vector2.ZERO
		_track_landing(delta)
		return
	# Ease the lean in and out so steering is smooth, not twitchy.
	var want := lean.limit_length(1.0)
	var rate := lean_attack if want.length() > _lean_now.length() - 0.01 else lean_release
	_lean_now = _lean_now.move_toward(want, rate * delta)
	var l := _lean_now
	# Lean is relative to the lane, so "left" always means the lane's left
	# even when the track bends.
	var force := lane_basis.x * l.x * lean_side_force + lane_basis.z * l.y * lean_forward_force
	var push_dir := force.normalized() if force.length() > 0.001 else Vector3.ZERO
	# Steering against the way it's moving: push harder, more so the
	# faster it's going the wrong way.
	var against := -linear_velocity.dot(push_dir)
	if against > 0.3:
		force *= lerpf(1.0, counter_steer_boost, clampf(against / 2.0, 0.0, 1.0))
	apply_central_force(force * mass)
	# Turn the spin with the push so the ball rolls the new way straight
	# away instead of skidding while its old spin wears off.
	var up := floor_normal()
	if up != Vector3.ZERO and spin_assist > 0.0:
		var radius := 0.3
		var want_spin := up.cross(linear_velocity) / radius
		var k := clampf(spin_assist * 10.0 * delta, 0.0, 1.0) if push_dir != Vector3.ZERO else 0.0
		angular_velocity = angular_velocity.lerp(want_spin, k)
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
	_last_floor = floor_normal()
	_air_time = 0.0
	_fall_speed = 0.0


## Hop off the floor. Only works when touching the ground and not too soon
## after the last hop, so there's no flying. Returns true if it hopped.
## Like `lean`, the game calls this when the player presses the hop key.
func request_hop() -> bool:
	if freeze or out or arrived:
		return false
	if _hop_wait > 0.0:
		# Pressed a little early (still cooling down from the last hop):
		# keep it and hop as soon as it's allowed.
		_hop_buffered = hop_buffer_time
		return false
	var normal := floor_normal()
	if normal == Vector3.ZERO:
		if _air_time < coyote_time and linear_velocity.dot(_last_floor) < 1.0:
			# Just rolled off an edge: still allowed (coyote time).
			normal = _last_floor
		else:
			# In the air: hop the moment it lands, if that's soon.
			_hop_buffered = hop_buffer_time
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
		if hit > 2.5:
			wince(hit)
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
		wince(4.0)


## Bowling ball finger holes: two fingers side by side and a thumb below.
## They're on the ball's mesh, so they roll round with it.
const FINGER_HOLES := [[Vector3(-0.32, 0.55, 0.77), 0.042], [Vector3(0.32, 0.55, 0.77), 0.042],
		[Vector3(0.0, 0.05, 1.0), 0.05]]
static var _hole_mat: StandardMaterial3D


func _add_finger_holes(mesh: MeshInstance3D) -> void:
	if mesh.has_node("Holes"):
		return
	if _hole_mat == null:
		_hole_mat = StandardMaterial3D.new()
		_hole_mat.albedo_color = Color(0.04, 0.03, 0.04)
		_hole_mat.roughness = 0.9
	var holes := Node3D.new()
	holes.name = "Holes"
	mesh.add_child(holes)
	var r := 0.3
	for h in FINGER_HOLES:
		var dir: Vector3 = (h[0] as Vector3).normalized()
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = h[1]
		cyl.bottom_radius = h[1]
		cyl.height = 0.03
		cyl.radial_segments = 10
		cyl.rings = 1
		disc.mesh = cyl
		disc.material_override = _hole_mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Stand the disc on the surface, pointing out from the middle.
		disc.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * (r - 0.008))
		holes.add_child(disc)


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
	_add_finger_holes(mesh)
	var trail_id: String = look.get("trail", {"id": "none"}).id
	if _trail == null:
		_trail = MarbleTrail.new()
		add_child(_trail)
	_trail.setup(trail_id, color)
	_trail.preview = preview
	var hat_id: String = look.get("hat", {"id": "none"}).id
	if hat_id != _hat_id:
		_hat_id = hat_id
		if _hat:
			_hat.queue_free()
			_hat = null
		if hat_id != "none":
			_hat = Hats.build(hat_id)
			_hat.top_level = true
			add_child(_hat)
			_place_hat(0.0)
	var eyes_id: String = look.get("eyes", {"id": "none"}).id
	if eyes_id != _eyes_id or (_eyes and _eyes.color != color):
		_eyes_id = eyes_id
		if _eyes:
			_eyes.queue_free()
			_eyes = null
		if eyes_id != "none":
			_eyes = EyeRig.new()
			_eyes.top_level = true
			add_child(_eyes)
			_eyes.setup(eyes_id, color)
			_place_hat(0.0)
	# With eyes, the finger holes ARE the eyes (and the thumb hole the
	# mouth), so the plain rolling holes hide; they'd slide under the eyes.
	var holes := mesh.get_node_or_null("Holes") as Node3D
	if holes:
		holes.visible = _eyes == null
