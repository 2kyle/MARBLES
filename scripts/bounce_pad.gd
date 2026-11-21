extends Node3D
## A trampoline set into the lane. Marbles that roll onto it get flung up
## in a high arc and keep their speed down the lane, so they can sail over
## pieces (or the wall, if it's aimed badly on a bend).
##
## Built in code: a dark frame, a red springy mat that dips when it fires,
## little springs round the edge, and the trigger zone.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## Upward speed it gives, metres per second (about 2 m high).
@export var launch := 6.4

const R := 0.6

var _mat_node: MeshInstance3D
var _dip := 0.0
var _cooldown := {}


func _init() -> void:
	var frame := MeshInstance3D.new()
	frame.name = "Frame"
	var tm := TorusMesh.new()
	tm.inner_radius = R - 0.04
	tm.outer_radius = R + 0.1
	tm.rings = 32
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.16, 0.15, 0.2)
	tm.material = frame_mat
	frame.mesh = tm
	frame.position.y = 0.06
	frame.scale = Vector3(1, 0.8, 1)
	add_child(frame)

	_mat_node = MeshInstance3D.new()
	_mat_node.name = "Mat"
	var cm := CylinderMesh.new()
	cm.top_radius = R - 0.02
	cm.bottom_radius = R - 0.02
	cm.height = 0.03
	cm.radial_segments = 32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.3)
	cm.material = mat
	_mat_node.mesh = cm
	_mat_node.position.y = 0.05
	add_child(_mat_node)

	var spring_mat := StandardMaterial3D.new()
	spring_mat.albedo_color = Color(0.85, 0.87, 0.9)
	spring_mat.metallic = 0.7
	for k in 8:
		var a := TAU * k / 8.0
		var s := MeshInstance3D.new()
		s.name = "Spring%d" % k
		var sm := CylinderMesh.new()
		sm.top_radius = 0.025
		sm.bottom_radius = 0.025
		sm.height = 0.12
		sm.material = spring_mat
		s.mesh = sm
		s.position = Vector3(cos(a), 0, sin(a)) * (R + 0.02) + Vector3.UP * 0.07
		add_child(s)

	# A low solid rim so the frame isn't a ghost.
	var body := StaticBody3D.new()
	for k in 12:
		var a := TAU * k / 12.0
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.12, 0.1, 0.34)
		col.shape = box
		col.position = Vector3(cos(a), 0, sin(a)) * (R + 0.03) + Vector3.UP * 0.05
		col.rotation.y = -a
		body.add_child(col)
	add_child(body)

	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var zs := CollisionShape3D.new()
	var zc := CylinderShape3D.new()
	zc.radius = R - 0.1
	zc.height = 0.5
	zs.shape = zc
	zs.position.y = 0.25
	zone.add_child(zs)
	zone.body_entered.connect(_on_body_entered)
	add_child(zone)


func _on_body_entered(body: Node) -> void:
	if not body is Marble or _cooldown.get(body, 0.0) > 0.0:
		return
	var m := body as Marble
	var up := global_basis.y.normalized()
	var v := m.linear_velocity
	v -= up * v.dot(up)
	m.linear_velocity = v + up * launch
	# Fly true for a moment, then steer again in the air.
	m.no_steer_time = 0.35
	m.wince(3.0)
	_cooldown[body] = 0.5
	_dip = 1.0


func _process(delta: float) -> void:
	_dip = maxf(_dip - delta * 3.0, 0.0)
	_mat_node.position.y = 0.05 - sin(_dip * PI) * 0.08
	for k in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
