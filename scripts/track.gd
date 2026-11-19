@tool
class_name Track
extends Node3D
## The lane, built from a curve. Edit the child "Path" node in the Godot
## editor (select it, then drag its points around, add points with the
## toolbar buttons, change a point's Tilt to bank a corner) and the lane's
## floor, walls, supports and collision rebuild to follow it.
##
## Corners bank themselves (see `bank_speed`). The last few metres of the
## curve should run straight into the pin deck, with the funnel on them.
##
## Lane space: everything placed on the track uses Vector2(x, z), where
## x runs across the lane (0 = centre line) and -z is the distance travelled
## along the track from the start (so z = -10 means 10 m down the track).
## lane_transform() turns that into a real position on the bendy track.

## Width of the rolling surface, metres.
@export var lane_width := 5.0:
	set(v):
		lane_width = v
		_queue_rebuild()
## Height of the side walls, metres.
@export var wall_height := 1.0:
	set(v):
		wall_height = v
		_queue_rebuild()
## Corners tilt inward as if a marble went round them at this speed (m/s).
## 0 = flat corners. Higher = steeper banking.
@export var bank_speed := 5.0:
	set(v):
		bank_speed = v
		_queue_rebuild()
## Steepest automatic bank, degrees.
@export var max_bank_deg := 12.0:
	set(v):
		max_bank_deg = v
		_queue_rebuild()
## The funnel sits this many metres before the end of the track.
@export var funnel_from_end := 5.0:
	set(v):
		funnel_from_end = v
		_queue_rebuild()
## Support posts run down to this height (the water).
@export var support_bottom_y := -4.5:
	set(v):
		support_bottom_y = v
		_queue_rebuild()
## Distance between support posts.
@export var support_spacing := 7.0:
	set(v):
		support_spacing = maxf(v, 1.0)
		_queue_rebuild()
## Distance between generated slices along the track. Smaller = smoother.
@export var step := 0.5:
	set(v):
		step = maxf(v, 0.1)
		_queue_rebuild()
@export var floor_color := Color(0.62, 0.45, 0.28):
	set(v):
		floor_color = v
		_queue_rebuild()
@export var wall_color := Color(0.5, 0.34, 0.22):
	set(v):
		wall_color = v
		_queue_rebuild()
@export var support_color := Color(0.36, 0.27, 0.2):
	set(v):
		support_color = v
		_queue_rebuild()

const WALL_THICKNESS := 0.25
const FLOOR_THICKNESS := 0.35
## How far ahead/behind to look when measuring how sharply the track turns.
const BANK_LOOK := 4.0

var _path: Path3D
var _body: StaticBody3D
var _mesh: MeshInstance3D
var _supports: MeshInstance3D
var _dirty := false
var _tilts := PackedFloat32Array()


func _ready() -> void:
	_path = get_node_or_null("Path")
	if _path and not _path.curve_changed.is_connected(_queue_rebuild):
		_path.curve_changed.connect(_queue_rebuild)
	rebuild()


## The layout the track was last built from (see TrackGen), or empty if
## it's the hand-drawn curve from the editor.
var layout: Array = []
## Top-view position of the start, kept when the layout changes mid-match
## so the start stays put and the rest of the track swings round.
var start_xz := Vector2.ZERO
## Holes in the track, as [start, end] distances along it.
var gaps: Array = []


## Replace the track with one built from a TrackGen layout.
func apply_layout(new_layout: Array, new_start_xz: Vector2) -> void:
	layout = new_layout
	start_xz = new_start_xz
	var pts := TrackGen.points(layout, start_xz)
	# Gap positions are in ground metres (= point index); turn them into
	# distances along the sloping track.
	var along := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		along.append(along[i - 1] + pts[i].distance_to(pts[i - 1]))
	gaps = []
	for g in TrackGen.gap_ranges(layout):
		gaps.append([along[clampi(int(g[0]), 0, pts.size() - 1)], along[clampi(int(g[1]), 0, pts.size() - 1)]])
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	var keep := []
	for i in range(0, pts.size(), 3):
		keep.append(pts[i])
	if (pts.size() - 1) % 3 != 0:
		keep.append(pts[-1])
	for i in keep.size():
		var prev: Vector3 = keep[maxi(i - 1, 0)]
		var next: Vector3 = keep[mini(i + 1, keep.size() - 1)]
		var handle: Vector3 = (next - prev) / 6.0
		if i == 0 or i == keep.size() - 1:
			handle *= 2.0
		curve.add_point(keep[i], -handle, handle)
	if _path == null:
		_path = get_node("Path")
	_path.transform = Transform3D.IDENTITY
	if _path.curve_changed.is_connected(_queue_rebuild):
		_path.curve_changed.disconnect(_queue_rebuild)
	_path.curve = curve
	_path.curve_changed.connect(_queue_rebuild)
	rebuild()


## True if `distance` is inside a gap (or within `margin` metres of one).
func in_gap(distance: float, margin := 0.0) -> bool:
	for g in gaps:
		if distance > g[0] - margin and distance < g[1] + margin:
			return true
	return false


## Where the track ends (track-local) and which way it points, flattened.
## The pin deck goes here.
func end_transform() -> Transform3D:
	var len := length()
	var f := frame_at(len)
	var fwd := -f.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var yaw := atan2(-fwd.x, -fwd.z)
	return Transform3D(Basis(Vector3.UP, yaw), f.origin)


func _queue_rebuild() -> void:
	if not is_inside_tree():
		return
	if not _dirty:
		_dirty = true
		rebuild.call_deferred()


func length() -> float:
	return _path.curve.get_baked_length() if _path and _path.curve else 0.0


## Which way the track heads at `distance` (unit vector, track-local).
func direction_at(distance: float) -> Vector3:
	var curve := _path.curve
	var len := curve.get_baked_length()
	var d := clampf(distance, 0.0, len)
	var ahead := curve.sample_baked(minf(d + 0.75, len), true)
	var behind := curve.sample_baked(maxf(d - 0.75, 0.0), true)
	return _path.transform.basis * (ahead - behind).normalized()


## Bank angle (radians, + = right side lower) at `distance`.
func bank_at(distance: float) -> float:
	var tilt := _tilt_at(distance)
	if bank_speed <= 0.0:
		return tilt
	var a := direction_at(distance - BANK_LOOK)
	var b := direction_at(distance + BANK_LOOK)
	a.y = 0.0
	b.y = 0.0
	if a.length() < 0.01 or b.length() < 0.01:
		return tilt
	a = a.normalized()
	b = b.normalized()
	# Turn rate in radians per metre; negative cross.y = turning right.
	var turn := atan2(a.cross(b).y, a.dot(b)) / (BANK_LOOK * 2.0)
	var bank := atan(-turn * bank_speed * bank_speed / 9.8)
	var limit := deg_to_rad(max_bank_deg)
	return clampf(bank, -limit, limit) + tilt


## The hand-set Tilt of the curve at `distance`, radians.
func _tilt_at(distance: float) -> float:
	if _tilts.is_empty():
		return 0.0
	var f := clampf(distance / _path.curve.bake_interval, 0.0, _tilts.size() - 1.0)
	var i := mini(floori(f), _tilts.size() - 2) if _tilts.size() > 1 else 0
	if _tilts.size() == 1:
		return _tilts[0]
	return lerpf(_tilts[i], _tilts[i + 1], f - i)


## A transform on the track surface at `distance` metres from the start,
## `side` metres right of the centre line. Basis: -Z points down the track,
## Y is the lane's "up", X points to the lane's right. Track-local space.
func frame_at(distance: float, side := 0.0) -> Transform3D:
	var curve := _path.curve
	var len := curve.get_baked_length()
	var d := clampf(distance, 0.0, len)
	var p := _path.transform * curve.sample_baked(d, true)
	var forward := direction_at(d)
	var right := forward.cross(Vector3.UP).normalized()
	var bank := bank_at(d)
	if bank != 0.0:
		right = right.rotated(forward, bank)
	var up := right.cross(forward).normalized()
	var basis := Basis(right, up, -forward)
	return Transform3D(basis, p + basis * Vector3(side, 0, 0))


## Same as frame_at but in world space.
func world_frame_at(distance: float, side := 0.0) -> Transform3D:
	return global_transform * frame_at(distance, side)


## Lane-space position and angle (degrees) to a transform on the track
## (track-local space).
func lane_transform(pos: Vector2, angle_deg := 0.0) -> Transform3D:
	var xf := frame_at(-pos.y, pos.x)
	return xf * Transform3D(Basis(Vector3.UP, deg_to_rad(angle_deg)), Vector3.ZERO)


## How far along the track the point closest to `world_point` is.
func distance_of(world_point: Vector3) -> float:
	var local := _path.transform.affine_inverse() * to_local(world_point)
	return _path.curve.get_closest_offset(local)


## A flat ribbon lying on the track from distance d0 to d1, `half_w` either
## side of the centre, `lift` metres above the floor. For the build zone.
func ribbon_mesh(d0: float, d1: float, half_w: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(2, ceili((d1 - d0) / step) + 1)
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	for i in n:
		var xf := frame_at(lerpf(d0, d1, i / float(n - 1)))
		var o := xf.origin + xf.basis.y * lift
		var l := o - xf.basis.x * half_w
		var r := o + xf.basis.x * half_w
		if i > 0:
			for v in [pl, r, pr, pl, l, r]:
				st.add_vertex(v)
		pl = l
		pr = r
	st.generate_normals()
	return st.commit()


func rebuild() -> void:
	_dirty = false
	if _path == null or _path.curve == null or _path.curve.point_count < 2:
		return
	_tilts = _path.curve.get_baked_tilts()
	var len := length()
	var slices := maxi(2, ceili(len / step) + 1)
	var hw := lane_width / 2.0

	var floor_st := SurfaceTool.new()
	floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision: Array = []  # regular Array so _quad can append to it

	var prev := {}
	for i in slices:
		var d := len * i / float(slices - 1)
		if in_gap(d):
			prev = {}
			continue
		var xf := frame_at(d)
		var o := xf.origin
		var r := xf.basis.x
		var u := xf.basis.y
		var s := {
			"fl": o - r * hw, "fr": o + r * hw,
			"bl": o - r * hw - u * FLOOR_THICKNESS, "br": o + r * hw - u * FLOOR_THICKNESS,
			"wli": o - r * hw + u * wall_height, "wri": o + r * hw + u * wall_height,
			"wlo": o - r * (hw + WALL_THICKNESS) + u * wall_height,
			"wro": o + r * (hw + WALL_THICKNESS) + u * wall_height,
			"wlb": o - r * (hw + WALL_THICKNESS) - u * FLOOR_THICKNESS,
			"wrb": o + r * (hw + WALL_THICKNESS) - u * FLOOR_THICKNESS,
		}
		if i == 0:
			# Back wall behind the start gate.
			_quad(wall_st, collision, s.wlb, s.wrb, s.wro, s.wlo)
		if not prev.is_empty():
			# Rolling surface and underside.
			_quad(floor_st, collision, prev.fl, prev.fr, s.fr, s.fl)
			_quad(floor_st, null, prev.br, prev.bl, s.bl, s.br)
			# Inner wall faces, tops, outsides.
			_quad(wall_st, collision, prev.wli, prev.fl, s.fl, s.wli)
			_quad(wall_st, collision, prev.fr, prev.wri, s.wri, s.fr)
			_quad(wall_st, collision, prev.wlo, prev.wli, s.wli, s.wlo)
			_quad(wall_st, collision, prev.wri, prev.wro, s.wro, s.wri)
			_quad(wall_st, collision, prev.wlb, prev.wlo, s.wlo, s.wlb)
			_quad(wall_st, collision, prev.wro, prev.wrb, s.wrb, s.wro)
			# Floor underside out to the wall bottoms.
			_quad(wall_st, null, prev.bl, prev.wlb, s.wlb, s.bl)
			_quad(wall_st, null, prev.wrb, prev.br, s.br, s.wrb)
		prev = s

	floor_st.generate_normals()
	wall_st.generate_normals()
	var mesh := floor_st.commit()
	wall_st.commit(mesh)
	mesh.surface_set_material(0, _material(floor_color, 0.55))
	mesh.surface_set_material(1, _material(wall_color, 0.7))

	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "TrackMesh"
		add_child(_mesh)
	_mesh.mesh = mesh

	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "TrackBody"
		var mat := PhysicsMaterial.new()
		mat.friction = 0.6
		mat.bounce = 0.15
		_body.physics_material_override = mat
		var shape_node := CollisionShape3D.new()
		_body.add_child(shape_node)
		add_child(_body)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(PackedVector3Array(collision))
	(_body.get_child(0) as CollisionShape3D).shape = shape

	_build_supports(len)

	var funnel := get_node_or_null("Funnel") as Node3D
	if funnel:
		funnel.transform = frame_at(len - funnel_from_end)


func _build_supports(len: float) -> void:
	if _supports == null:
		_supports = MeshInstance3D.new()
		_supports.name = "Supports"
		add_child(_supports)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := maxi(1, floori(len / support_spacing))
	for i in count:
		var d := support_spacing * (i + 0.5)
		var xf := frame_at(d)
		for side in [-1.0, 1.0]:
			var top: Vector3 = xf.origin + xf.basis.x * side * (lane_width / 2.0 - 0.3) - xf.basis.y * FLOOR_THICKNESS
			if top.y - support_bottom_y > 0.5:
				_post(st, top, support_bottom_y, 0.16)
	st.generate_normals()
	_supports.mesh = st.commit()
	_supports.material_override = _material(support_color, 0.8)


func _post(st: SurfaceTool, top: Vector3, bottom_y: float, r: float) -> void:
	var sides := 8
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var o0 := Vector3(cos(a0), 0, sin(a0)) * r
		var o1 := Vector3(cos(a1), 0, sin(a1)) * r
		var t0 := top + o0
		var t1 := top + o1
		var b0 := Vector3(t0.x, bottom_y, t0.z)
		var b1 := Vector3(t1.x, bottom_y, t1.z)
		for v in [t0, b1, b0, t0, t1, b1]:
			st.add_vertex(v)


func _quad(st: SurfaceTool, faces, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, c, b, a, d, c]:
		st.add_vertex(v)
	if faces != null:
		faces.append_array([a, c, b, a, d, c])


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
