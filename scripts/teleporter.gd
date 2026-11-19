extends Area3D
## A teleporter pad. It comes in two parts: players drop the entry, then
## the exit. A marble that rolls onto the entry pops out of the exit, at
## the same speed, heading the way the exit's arrow points. Each marble
## can use a teleporter once per frame, so it can't loop forever.
##
## Everything is built in code so the pad's colour can show which part it
## is (blue = entry, orange = exit).

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## The other half (entry <-> exit). Set by the build code.
var partner: Node3D = null
## Practice pads can be used again and again (with a short pause per
## marble). Match teleporters work once per marble per frame.
var reusable := false
## True for the exit pad. Exits don't send marbles anywhere.
var is_exit := false:
	set(value):
		is_exit = value
		_paint()

const ENTRY_COLOR := Color(0.25, 0.6, 1.0)
const EXIT_COLOR := Color(1.0, 0.55, 0.15)
const RADIUS := 0.55

var _used := {}
var _disc_mat := StandardMaterial3D.new()
var _ring_mat := StandardMaterial3D.new()
var _swirl: MeshInstance3D


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = 0.5
	shape.shape = cyl
	shape.position.y = 0.25
	add_child(shape)

	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.03
	disc.radial_segments = 24
	_disc_mat.emission_enabled = true
	_disc_mat.emission_energy_multiplier = 1.4
	disc.material = _disc_mat
	var disc_node := MeshInstance3D.new()
	disc_node.mesh = disc
	disc_node.position.y = 0.015
	add_child(disc_node)

	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.06
	ring.outer_radius = RADIUS + 0.04
	ring.rings = 24
	ring.ring_segments = 8
	_ring_mat.emission_enabled = true
	_ring_mat.emission_energy_multiplier = 2.5
	ring.material = _ring_mat
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.position.y = 0.04
	ring_node.scale = Vector3(1, 0.6, 1)
	add_child(ring_node)

	# A spinning swirl of three blades on the pad.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := TAU * k / 3.0
		for j in 6:
			var r0 := 0.08 + j * 0.07
			var r1 := r0 + 0.07
			var a0 := a + j * 0.35
			var a1 := a0 + 0.35
			var w := 0.06
			var p0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			var side := Vector3(cos(a0 + PI / 2), 0, sin(a0 + PI / 2)) * w
			for v in [p0 - side, p1, p0 + side]:
				st.add_vertex(v)
	_swirl = MeshInstance3D.new()
	_swirl.mesh = st.commit()
	var swirl_mat := StandardMaterial3D.new()
	swirl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swirl_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	swirl_mat.albedo_color = Color(1, 1, 1, 0.9)
	swirl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swirl.material_override = swirl_mat
	_swirl.position.y = 0.035
	add_child(_swirl)

	# Arrow showing which way marbles leave the exit.
	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.35, 0.02)
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.albedo_color = Color.WHITE
	prism.material = arrow_mat
	arrow.mesh = prism
	arrow.rotation.x = -PI / 2
	arrow.position = Vector3(0, 0.05, -RADIUS - 0.25)
	add_child(arrow)
	_paint()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_swirl.rotate_y(delta * (-4.0 if is_exit else 4.0))


func _paint() -> void:
	var c := EXIT_COLOR if is_exit else ENTRY_COLOR
	_disc_mat.albedo_color = c.darkened(0.35)
	_disc_mat.emission = c.darkened(0.5)
	_ring_mat.albedo_color = c
	_ring_mat.emission = c
	var arrow := get_node_or_null("Arrow")
	if arrow:
		arrow.visible = is_exit


func _on_body_entered(body: Node) -> void:
	if is_exit or not body is Marble or not is_instance_valid(partner):
		return
	var id := body.get_instance_id()
	var now := Time.get_ticks_msec()
	if _used.has(id) and (not reusable or now - _used[id] < 1000):
		return
	_used[id] = now
	_send.call_deferred(body)


func _send(m: Marble) -> void:
	if not is_instance_valid(m) or m.out or m.arrived:
		return
	var fwd := -partner.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var speed := maxf(m.linear_velocity.length(), 3.0)
	_flash(global_position)
	m.global_position = partner.global_position + partner.global_basis.y.normalized() * 0.4 + fwd * 0.5
	m.linear_velocity = fwd * (2.0 if reusable else speed)
	m.angular_velocity = Vector3.ZERO
	_flash(partner.global_position)


func _flash(at: Vector3) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 24
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3.ZERO
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ENTRY_COLOR.lerp(Color.WHITE, 0.4)
	mesh.material = mat
	burst.mesh = mesh
	get_parent().add_child(burst)
	burst.global_position = at + Vector3.UP * 0.3
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
