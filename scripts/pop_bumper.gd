extends Node3D
## A pinball pop bumper. Any marble that touches it gets thrown away from
## its middle, hard, and the cap flashes and squashes. Much stronger than
## the bumper post, and it throws in every direction (even back up the
## lane), so a cluster of them makes a pinball table.
##
## Built in code: a solid base and cap, a ring skirt, and a trigger zone a
## little bigger than the cap.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## How hard it throws marbles (metres per second added).
@export var kick := 6.5

const RADIUS := 0.34
const HEIGHT := 0.42

var _cap: MeshInstance3D
var _cap_mat: StandardMaterial3D
var _flash := 0.0
var _cooldown := {}  # marble -> seconds before this bumper can throw it again


func _init() -> void:
	var body := StaticBody3D.new()
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.5
	phys.friction = 0.2
	body.physics_material_override = phys
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	shape.shape = cyl
	shape.position.y = HEIGHT / 2.0
	body.add_child(shape)
	add_child(body)

	var base := MeshInstance3D.new()
	base.name = "Base"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = RADIUS
	base_mesh.bottom_radius = RADIUS + 0.04
	base_mesh.height = HEIGHT * 0.55
	base_mesh.radial_segments = 24
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.98, 0.97, 0.94)
	base_mesh.material = base_mat
	base.mesh = base_mesh
	base.position.y = HEIGHT * 0.275
	add_child(base)

	var skirt := MeshInstance3D.new()
	skirt.name = "Skirt"
	var skirt_mesh := TorusMesh.new()
	skirt_mesh.inner_radius = RADIUS - 0.02
	skirt_mesh.outer_radius = RADIUS + 0.1
	skirt_mesh.rings = 24
	var skirt_mat := StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.16, 0.15, 0.2)
	skirt_mesh.material = skirt_mat
	skirt.mesh = skirt_mesh
	skirt.position.y = 0.05
	add_child(skirt)

	_cap = MeshInstance3D.new()
	_cap.name = "Cap"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = RADIUS * 0.8
	cap_mesh.bottom_radius = RADIUS + 0.02
	cap_mesh.height = HEIGHT * 0.45
	cap_mesh.radial_segments = 24
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color = Color(1.0, 0.25, 0.45)
	_cap_mat.emission_enabled = true
	_cap_mat.emission = Color(1.0, 0.25, 0.45)
	_cap_mat.emission_energy_multiplier = 0.3
	_cap_mat.roughness = 0.3
	cap_mesh.material = _cap_mat
	_cap.mesh = cap_mesh
	_cap.position.y = HEIGHT * 0.775
	add_child(_cap)

	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var zone_shape := CollisionShape3D.new()
	var zone_cyl := CylinderShape3D.new()
	zone_cyl.radius = RADIUS + 0.1
	zone_cyl.height = HEIGHT + 0.3
	zone_shape.shape = zone_cyl
	zone_shape.position.y = HEIGHT / 2.0
	zone.add_child(zone_shape)
	zone.body_entered.connect(_on_body_entered)
	add_child(zone)


func _on_body_entered(body: Node) -> void:
	if not body is Marble or _cooldown.get(body, 0.0) > 0.0:
		return
	var m := body as Marble
	var away := m.global_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = -global_basis.z
	away = away.normalized()
	# Cancel the speed into the bumper, then throw it out.
	var into := m.linear_velocity.dot(-away)
	if into > 0.0:
		m.linear_velocity += away * into
	m.apply_central_impulse(away * kick * m.mass)
	m.wince(6.0)
	_cooldown[body] = 0.15
	_flash = 1.0
	PopText.spawn(self, global_position + Vector3.UP * 0.9, "POP!", Color(1.0, 0.45, 0.65))


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_cap_mat.emission_energy_multiplier = 0.3 + _flash * 3.5
	# Squash down and spring back when it fires.
	var s := 1.0 - 0.3 * _flash * _flash
	_cap.scale = Vector3(1.0 + (1.0 - s) * 0.6, s, 1.0 + (1.0 - s) * 0.6)
	for k in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
