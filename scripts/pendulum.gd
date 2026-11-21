extends Node3D
## A heavy bowling ball on a rod, swinging side to side across the lane
## from a little gantry. Time your run (or hop) to get past; get it wrong
## and it bats you sideways.
##
## The ball is an AnimatableBody3D, so the physics engine knows how fast it
## moves and hits marbles properly. Everything is built in code.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## Seconds for one full swing there and back.
@export var period := 2.6
## How far it swings each way, in degrees.
@export var swing_deg := 58.0

const POST_X := 1.05
const PIVOT_Y := 2.0
const ROD := 1.62
const BALL_R := 0.3

var _arm: Node3D
var _ball: AnimatableBody3D
var _t := 0.0


func _init() -> void:
	var frame := StaticBody3D.new()
	frame.name = "Frame"
	add_child(frame)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.22)
	for side in [-1.0, 1.0]:
		var post := _box(Vector3(0.14, PIVOT_Y + 0.1, 0.14), wood, "Post%d" % int(side + 1.0))
		post.position = Vector3(side * POST_X, (PIVOT_Y + 0.1) / 2.0, 0)
		frame.add_child(post)
		var col := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.14, PIVOT_Y + 0.1, 0.14)
		col.shape = b
		col.position = post.position
		frame.add_child(col)
	var bar := _box(Vector3(POST_X * 2.0 + 0.3, 0.16, 0.18), wood, "Bar")
	bar.position = Vector3(0, PIVOT_Y + 0.12, 0)
	frame.add_child(bar)

	_arm = Node3D.new()
	_arm.name = "Arm"
	_arm.position.y = PIVOT_Y
	add_child(_arm)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.75, 0.77, 0.8)
	steel.metallic = 0.7
	steel.roughness = 0.3
	var rod := MeshInstance3D.new()
	rod.name = "Rod"
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.03
	rod_mesh.bottom_radius = 0.03
	rod_mesh.height = ROD
	rod_mesh.material = steel
	rod.mesh = rod_mesh
	rod.position.y = -ROD / 2.0
	_arm.add_child(rod)

	_ball = AnimatableBody3D.new()
	_ball.name = "Swing"
	_ball.sync_to_physics = false
	var phys := PhysicsMaterial.new()
	phys.bounce = 0.4
	_ball.physics_material_override = phys
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_R
	col.shape = sphere
	_ball.add_child(col)
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = BALL_R
	ball_mesh.height = BALL_R * 2.0
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.2, 0.12, 0.45)
	ball_mat.roughness = 0.15
	ball_mat.metallic_specular = 0.9
	ball_mesh.material = ball_mat
	var ball := MeshInstance3D.new()
	ball.name = "Ball"
	ball.mesh = ball_mesh
	_ball.add_child(ball)
	# Three finger holes so it reads as a bowling ball.
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.03, 0.03, 0.05)
	var holes := [Vector3(-0.3, 0.5, 0.81), Vector3(0.3, 0.5, 0.81), Vector3(0, 0.0, 1.0)]
	for k in holes.size():
		var dir: Vector3 = (holes[k] as Vector3).normalized()
		var disc := MeshInstance3D.new()
		disc.name = "Hole%d" % k
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.02
		cyl.material = hole_mat
		disc.mesh = cyl
		disc.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * (BALL_R - 0.006))
		ball.add_child(disc)
	add_child(_ball)
	_place(0.0)


func _box(size: Vector3, mat: Material, name_: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	return mi


func _ready() -> void:
	# Different pendulums start at different points in their swing.
	_t = fposmod(global_position.x * 1.3 + global_position.z * 0.7, period)


func _physics_process(delta: float) -> void:
	_t += delta
	_place(_t)


func _place(t: float) -> void:
	var a := deg_to_rad(swing_deg) * sin(TAU * t / period)
	_arm.rotation.z = a
	_ball.transform = Transform3D(Basis(Vector3.BACK, a), Vector3(sin(a) * ROD, PIVOT_Y - cos(a) * ROD, 0))
