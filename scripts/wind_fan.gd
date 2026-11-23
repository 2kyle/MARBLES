extends Node3D
## A big fan that blows marbles. Anything rolling through the wind in front
## of it gets pushed the way the fan faces (turn it to aim). Point it
## across the track to blow marbles off the edge, or down the track to
## speed them up.
##
## Built in code: the fan housing (solid), the spinning blades, the wind
## zone, and drifting streaks so you can see the wind.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## How hard the wind pushes (metres per second, every second).
@export var push := 15.0

const ZONE_LENGTH := 2.6
const ZONE_WIDTH := 1.2

var _zone: Area3D
var _blades: Node3D


func _init() -> void:
	# The fan sits at the back (+z) and blows toward -z.
	var housing := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.9, 0.3)
	shape.shape = box
	housing.add_child(shape)
	housing.position = Vector3(0, 0.45, ZONE_LENGTH / 2.0 + 0.15)
	add_child(housing)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.85, 0.88, 0.92)
	frame_mat.metallic = 0.6
	frame_mat.roughness = 0.35
	var frame := BoxMesh.new()
	frame.size = box.size
	frame.material = frame_mat
	var frame_node := MeshInstance3D.new()
	frame_node.mesh = frame
	housing.add_child(frame_node)

	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.12, 0.14, 0.18)
	var face := CylinderMesh.new()
	face.radial_segments = 16
	face.rings = 0
	face.top_radius = 0.4
	face.bottom_radius = 0.4
	face.height = 0.04
	face.material = face_mat
	var face_node := MeshInstance3D.new()
	face_node.mesh = face
	face_node.rotation.x = PI / 2
	face_node.position.z = -0.16
	housing.add_child(face_node)

	_blades = Node3D.new()
	_blades.position = Vector3(0, 0, -0.19)
	housing.add_child(_blades)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.2, 0.75, 0.95)
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.05, 0.3, 0.4)
	for k in 4:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.12, 0.36, 0.02)
		blade.material = blade_mat
		var b := MeshInstance3D.new()
		b.mesh = blade
		var a := TAU * k / 4.0
		b.position = Vector3(sin(a), cos(a), 0) * 0.18
		b.rotation.z = -a
		_blades.add_child(b)

	_zone = Area3D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	_zone.monitorable = false
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(ZONE_WIDTH, 1.0, ZONE_LENGTH)
	zone_shape.shape = zone_box
	zone_shape.position.y = 0.5
	_zone.add_child(zone_shape)
	add_child(_zone)

	# Wind streaks drifting out of the fan.
	var streaks := CPUParticles3D.new()
	streaks.amount = 14
	streaks.lifetime = 0.7
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	streaks.emission_box_extents = Vector3(ZONE_WIDTH * 0.4, 0.25, 0.05)
	streaks.direction = Vector3(0, 0, -1)
	streaks.spread = 4.0
	streaks.initial_velocity_min = 3.5
	streaks.initial_velocity_max = 4.5
	streaks.gravity = Vector3.ZERO
	var streak := BoxMesh.new()
	streak.size = Vector3(0.025, 0.025, 0.35)
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.albedo_color = Color(1, 1, 1, 0.55)
	streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.material = streak_mat
	streaks.mesh = streak
	streaks.local_coords = true
	streaks.position = Vector3(0, 0.45, ZONE_LENGTH / 2.0)
	add_child(streaks)


func _process(delta: float) -> void:
	_blades.rotate_z(delta * 14.0)


func _physics_process(_delta: float) -> void:
	if not _zone.monitoring:
		return
	var dir := -global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	for body in _zone.get_overlapping_bodies():
		if body is Marble:
			(body as Marble).apply_central_force(dir * push * (body as Marble).mass)
