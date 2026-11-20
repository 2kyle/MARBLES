class_name Pin
extends RigidBody3D
## One bowling pin. Remembers which player gets credit for it:
## the first marble to touch it, or, if another pin knocks it, whoever
## owns that pin (so chain reactions credit the player who started them).
##
## Looks: a classic curvy pin (wide belly, slim neck, round head) with two
## red neck stripes, and a little face. Every pin gets its own personality
## (most look normal, some are sleepy, googly, happy or grumpy). They blink,
## squeeze their eyes shut when something hits them, and stay knocked out
## once they fall over.

signal fell(pin: Pin)

## Tilt past this angle (degrees) counts as knocked down.
const FALL_ANGLE := 55.0
## Dropping this far below its start counts as knocked down (off the deck).
const FALL_DROP := 0.5

## Player id credited with this pin, or -1 if nobody has touched it.
var credited_to := -1
var fallen := false

var _start_y := 0.0
var _face: EyeRig

## The pin's outline from bottom to top: [height, radius] in metres. It fits
## inside the collision cylinder (radius 0.1265, height 1.035).
const PROFILE := [
	[-0.5175, 0.0], [-0.5175, 0.078], [-0.49, 0.096], [-0.42, 0.115], [-0.32, 0.1265],
	[-0.2, 0.122], [-0.1, 0.108], [0.0, 0.088], [0.09, 0.07], [0.16, 0.062],
	[0.22, 0.068], [0.28, 0.085], [0.34, 0.097], [0.39, 0.097], [0.44, 0.088],
	[0.48, 0.07], [0.505, 0.044], [0.5175, 0.0],
]
## The red neck stripes: [from height, to height].
const STRIPES := [[0.07, 0.1], [0.125, 0.15]]
const PIN_WHITE := Color(0.97, 0.96, 0.93)
const PIN_RED := Color(0.85, 0.1, 0.1)
## Where the middle of the head is, and about how round it is.
const HEAD_Y := 0.36
const HEAD_R := 0.098
## Faces, and how often each turns up (most pins look classic).
const FACES := ["classic", "classic", "classic", "dots", "dots", "googly", "sleepy", "happy", "angry"]

static var _mesh: ArrayMesh


func _ready() -> void:
	_start_y = global_position.y
	body_entered.connect(_on_body_entered)
	_build_looks()


func _process(delta: float) -> void:
	if _face == null:
		return
	if fallen:
		_face.wince(5.0)   # knocked out: eyes stay squeezed shut
	_face.update(delta, linear_velocity)


func _build_looks() -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = pin_mesh()
	add_child(body)
	# The face looks back up the lane (+Z), toward the marbles coming in.
	_face = EyeRig.new()
	_face.name = "Face"
	add_child(_face)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(position.x * 100.0), roundi(position.z * 100.0)))
	_face.setup(FACES[rng.randi() % FACES.size()], PIN_WHITE)
	_face.position = Vector3(0, HEAD_Y, 0)
	_face.rotation.y = PI
	# Big cartoon eyes: wider and taller than the head, but not deeper, so
	# they stay on its surface.
	_face.scale = Vector3(HEAD_R * 1.6, HEAD_R * 1.6, HEAD_R)
	# A small smile under the eyes.
	var mouth := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = 0.01
	m.height = 0.06
	m.radial_segments = 8
	m.rings = 2
	mouth.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EyeRig.INK
	mouth.material_override = mat
	mouth.position = Vector3(0, HEAD_Y - 0.05, 0.084)
	mouth.rotation = Vector3(-0.5, 0, PI / 2)
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mouth)


## The pin's body, made once and shared by every pin: the PROFILE spun round
## like on a lathe, white with red stripes, glossy like a real pin.
static func pin_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	# Add extra rings at the stripe edges so the colours change sharply.
	var rings: Array = []
	for i in PROFILE.size():
		rings.append(PROFILE[i])
	for s in STRIPES:
		for y in [s[0] - 0.002, s[0], s[1], s[1] + 0.002]:
			rings.append([y, _radius_at(y)])
	rings.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var sides := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings.size() - 1:
		var y0: float = rings[i][0]
		var r0: float = rings[i][1]
		var y1: float = rings[i + 1][0]
		var r1: float = rings[i + 1][1]
		if y1 - y0 < 0.0001 and absf(r1 - r0) < 0.0001:
			continue
		var mid := (y0 + y1) * 0.5
		var col := PIN_WHITE
		for s in STRIPES:
			if mid > s[0] and mid < s[1]:
				col = PIN_RED
		# Slope of the outline, for smooth shading.
		var n0 := _slope(y0)
		var n1 := _slope(y1)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var verts := [
				[d0 * r0 + Vector3.UP * y0, (d0 + Vector3.UP * n0).normalized()],
				[d0 * r1 + Vector3.UP * y1, (d0 + Vector3.UP * n1).normalized()],
				[d1 * r1 + Vector3.UP * y1, (d1 + Vector3.UP * n1).normalized()],
				[d1 * r0 + Vector3.UP * y0, (d1 + Vector3.UP * n0).normalized()],
			]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_color(col)
				st.set_normal(verts[idx][1])
				st.add_vertex(verts[idx][0])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.22
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh


static func _radius_at(y: float) -> float:
	for i in PROFILE.size() - 1:
		var a: Array = PROFILE[i]
		var b: Array = PROFILE[i + 1]
		if y >= a[0] and y <= b[0] and b[0] > a[0]:
			return lerpf(a[1], b[1], (y - a[0]) / (b[0] - a[0]))
	return 0.0


## How much the surface faces up (+) or down (-) at height y.
static func _slope(y: float) -> float:
	var e := 0.01
	var dr := _radius_at(clampf(y + e, -0.5174, 0.5174)) - _radius_at(clampf(y - e, -0.5174, 0.5174))
	if y <= -0.5174:
		return -1.5
	if y >= 0.5174:
		return 1.5
	return -dr / (2.0 * e)


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
		if _face:
			_face.wince((body as Marble).linear_velocity.length())
	elif body is Pin:
		var other := body as Pin
		if credited_to == -1:
			credit(other.credited_to)
		elif other.credited_to == -1:
			# The engine may report a pin-pin contact to only one of the two.
			other.credit(credited_to)
