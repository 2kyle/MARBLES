extends Node3D
## LOOP-DE-LOOP: a full vertical loop on the lane. Marbles roll in on the
## left lane, round the loop (upside down at the top!) and come out on the
## right lane, a little to the side so the track never runs into itself.
## A booster in the way in makes sure every marble that goes in has the
## speed to make it round.
##
## Built in code, in the piece's own (unscaled) space: marbles roll toward
## -Z. The track is a ribbon with low side walls, swept round a circle of
## radius R while it drifts sideways by SHIFT. A divider keeps the way in
## and the way out apart, and two angled rails in front funnel marbles
## into the way in.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## Speed added along the way in, and the least speed a marble leaves the
## booster with (metres per second, after scaling). About 5 m/s is the
## least that gets round, so this has some room to spare.
@export var kick := 1.0
@export var min_speed := 7.0

## Loop radius, half the ribbon's width, wall height, ribbon thickness and
## how far the way out sits to the side of the way in (scene metres; the
## builder scales pieces up by PieceCatalog.PIECE_SCALE).
const R := 0.62
const HW := 0.33
const WALL := 0.13
const THICK := 0.05
const SHIFT := 0.74
const STEPS := 56

var _cooldown := {}
var _top_seen := {}


func _init() -> void:
	var track_mat := StandardMaterial3D.new()
	track_mat.albedo_color = Color(0.98, 0.55, 0.15)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.98, 0.97, 0.94)

	var ribbon := _ribbon_mesh()
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Ribbon"
	floor_mi.mesh = ribbon.floor
	floor_mi.material_override = track_mat
	add_child(floor_mi)
	var walls_mi := MeshInstance3D.new()
	walls_mi.name = "Walls"
	walls_mi.mesh = ribbon.walls
	walls_mi.material_override = wall_mat
	add_child(walls_mi)

	var body := StaticBody3D.new()
	body.name = "Body"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.25
	pm.bounce = 0.0
	body.physics_material_override = pm
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(ribbon.faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

	# The divider between the way in and the way out, and the angled rails
	# that funnel marbles into the way in.
	_box(body, "Divider", Vector3(0.03, 0.3, 2.0 * R + 0.1), Vector3(0.0, 0.15, 0.0), 0.0, wall_mat)
	_rail(body, "Rail", Vector2(SHIFT / 2.0 + HW + 0.02, R + 0.95), Vector2(0.0, R + 0.06), wall_mat)
	_rail(body, "Flare", Vector2(-SHIFT / 2.0 - HW - 0.4, R + 0.95), Vector2(-SHIFT / 2.0 - HW, 0.0), wall_mat)

	# Two posts hold the top of the loop up (solid, so marbles passing
	# beside the loop bump them instead of rolling through).
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "Post%d" % (0 if side < 0 else 1)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.05
		cm.height = 2.0 * R + THICK
		cm.radial_segments = 8
		cm.rings = 0
		post.mesh = cm
		post.material_override = wall_mat
		post.position = Vector3(side * (SHIFT / 2.0 + HW + 0.08), (2.0 * R + THICK) / 2.0, 0.0)
		add_child(post)
		var pc := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.05
		cs.height = cm.height
		pc.shape = cs
		pc.position = post.position
		body.add_child(pc)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var bm := BoxMesh.new()
	bm.size = Vector3(SHIFT + 2.0 * HW + 0.2, 0.05, 0.08)
	beam.mesh = bm
	beam.material_override = wall_mat
	beam.position = Vector3(0, 2.0 * R + THICK + 0.02, 0)
	add_child(beam)

	# The kick zone at the way in, and a zone at the top for the pop word.
	add_child(_zone(Vector3(2.0 * HW - 0.08, 0.4, 0.5), Vector3(-SHIFT / 2.0, 0.2, 0.1), _on_enter))
	add_child(_zone(Vector3(0.9, 0.35, 0.35), Vector3(0.0, 2.0 * R - 0.2, 0.0), _on_top))


## Where the middle of the floor is at angle `a` round the loop (0 = the
## bottom of the way in, PI = the top, TAU = the bottom of the way out).
static func point(a: float) -> Vector3:
	# The sideways drift eases in and out, so both ends run straight.
	var x := -SHIFT / 2.0 + SHIFT * (a - sin(a)) / TAU
	return Vector3(x, R - R * cos(a) + 0.012, -R * sin(a))


## The ribbon, its walls and their collision faces.
func _ribbon_mesh() -> Dictionary:
	var fl := SurfaceTool.new()
	fl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wl := SurfaceTool.new()
	wl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for k in STEPS:
		var a0 := TAU * k / STEPS
		var a1 := TAU * (k + 1) / STEPS
		var p0 := point(a0)
		var p1 := point(a1)
		# Inward (towards the loop's middle) is "up" for the floor.
		var n0 := Vector3(0, cos(a0), sin(a0))
		var n1 := Vector3(0, cos(a1), sin(a1))
		var x := Vector3.RIGHT
		# Floor: top face, bottom face and the two edges.
		var tl0 := p0 - x * HW
		var tr0 := p0 + x * HW
		var tl1 := p1 - x * HW
		var tr1 := p1 + x * HW
		var bl0 := tl0 - n0 * THICK
		var br0 := tr0 - n0 * THICK
		var bl1 := tl1 - n1 * THICK
		var br1 := tr1 - n1 * THICK
		_quad(fl, faces, tl0, tr0, tr1, tl1, n0)
		_quad(fl, faces, br0, bl0, bl1, br1, -n0)
		_quad(fl, faces, bl0, tl0, tl1, bl1, -x)
		_quad(fl, faces, tr0, br0, br1, tr1, x)
		# Walls: a thin fin on each side, standing up from the floor.
		for side in [-1.0, 1.0]:
			var e0: Vector3 = tl0 if side < 0 else tr0
			var e1: Vector3 = tl1 if side < 0 else tr1
			var w0 := e0 + n0 * WALL
			var w1 := e1 + n1 * WALL
			var nx: Vector3 = x * -side
			_quad(wl, faces, e0, e1, w1, w0, nx)
			_quad(wl, faces, e1, e0, w0, w1, -nx)
	return {"floor": fl.commit(), "walls": wl.commit(), "faces": faces}


func _quad(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	# Wind each triangle so its front faces along n.
	var flip := (b - a).cross(c - a).dot(n) < 0.0
	var tris := [a, c, b, a, d, c] if flip else [a, b, c, a, c, d]
	for v in tris:
		st.set_normal(n)
		st.add_vertex(v)
		faces.append(v)


func _box(body: StaticBody3D, part: String, size: Vector3, at: Vector3, yaw: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = at
	col.rotation.y = yaw
	body.add_child(col)


func _rail(body: StaticBody3D, part: String, from: Vector2, to: Vector2, mat: Material) -> void:
	var mid := (from + to) / 2.0
	var d := to - from
	_box(body, part, Vector3(0.05, 0.2, d.length()), Vector3(mid.x, 0.1, mid.y), atan2(d.x, d.y), mat)


func _zone(size: Vector3, at: Vector3, on_enter: Callable) -> Area3D:
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.monitorable = false
	var zs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	zs.shape = bs
	zs.position = at
	zone.add_child(zs)
	zone.body_entered.connect(on_enter)
	return zone


func _on_enter(body: Node) -> void:
	if not body is Marble or _cooldown.get(body, 0.0) > 0.0:
		return
	var m := body as Marble
	var fwd := -global_basis.z.normalized()
	if m.linear_velocity.dot(fwd) < 0.5:
		return   # rolling back out after not making it
	# Line it up with the loop (no sideways drift scraping the walls) and
	# make sure it's fast enough.
	var along := m.linear_velocity.dot(fwd)
	m.linear_velocity = fwd * maxf(along + kick, min_speed)
	# Round the loop the lane's "left" and "forward" mean nothing, so it
	# rolls on its own until it's back out.
	m.no_steer_time = 0.9
	_cooldown[body] = 1.5
	_top_seen.erase(body)


func _on_top(body: Node) -> void:
	if not body is Marble or _top_seen.has(body):
		return
	_top_seen[body] = true
	PopText.spawn(self, global_position + global_basis.y * (2.0 * R + 0.5), "WHEEE!", Color(1.0, 0.6, 0.2), 0.9)


func _process(delta: float) -> void:
	for k in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
			_top_seen.erase(k)
