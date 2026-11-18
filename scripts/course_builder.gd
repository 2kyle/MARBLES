class_name CourseBuilder
extends Node3D
## The build area on the track, and every piece players have placed.
## Must be a child of the Track node: pieces sit on the bendy track by
## asking it where a lane position really is.
##
## Positions are Vector2(x, z) in lane space: x runs across the lane
## (0 = centre), z runs down it (0 = start gate, -10 = ten metres down the
## track toward the pins). Angles are degrees.

## How far from the centre line a piece's centre may go.
@export var half_width := 2.2
## The build area runs from this z (near the start gate)...
@export var top_z := -3.5
## ...to this many metres before the end of the track (keeps the funnel clear).
@export var end_margin := 8.0
## How much two pieces' footprints may overlap (0 = not at all, 1 = fully).
@export_range(0.0, 1.0) var overlap_allowed := 0.35

## A track card changed the shape of the track (the pin deck must move).
signal track_reshaped

## One entry per placed piece: {id, pos, angle, by, node}.
var placed: Array = []

var _zone: MeshInstance3D = null
var _fit_cache := {}

@onready var track: Track = get_parent()


## The far end of the build area, in lane space.
func bottom_z() -> float:
	return -(track.length() - end_margin)


## Where a lane position (and angle) really is on the track, `lift` metres
## above the floor.
func lane_xform(pos: Vector2, angle := 0.0, lift := 0.0) -> Transform3D:
	var xf := track.lane_transform(pos, angle)
	xf.origin += xf.basis.y * lift
	return xf


func clamp_pos(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, -half_width, half_width), clampf(pos.y, bottom_z(), top_z))


## True if a piece `id` could go at `pos` without sitting on another piece.
func can_place(id: String, pos: Vector2) -> bool:
	if PieceCatalog.is_bomb(id):
		return true
	if PieceCatalog.is_track(id):
		return _reshaped_layout(id, pos) != null
	var r: float = PieceCatalog.info(id).radius
	for p in placed:
		var min_gap: float = (r + PieceCatalog.info(p.id).radius) * (1.0 - overlap_allowed)
		if pos.distance_to(p.pos) < min_gap:
			return false
	return true


## The closest spot to `pos` where `id` fits, searching outward. Returns
## `pos` itself if it already fits, or null if nothing nearby fits.
func nearest_free(id: String, pos: Vector2) -> Variant:
	if can_place(id, pos):
		return pos
	for ring in range(1, 16):
		var dist := ring * 0.5
		for step in 12:
			var a := TAU * step / 12.0
			var p := clamp_pos(pos + Vector2(cos(a), sin(a)) * dist)
			if can_place(id, p):
				return p
	return null


## Put a piece on the lane (or set off a bomb). Returns false if blocked.
func place(id: String, pos: Vector2, angle: float, by_player: int) -> bool:
	pos = clamp_pos(pos)
	if PieceCatalog.is_bomb(id):
		explode(pos, PieceCatalog.info(id).radius)
		return true
	if PieceCatalog.is_track(id):
		return _reshape(id, pos)
	if not can_place(id, pos):
		return false
	var node: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	node.transform = lane_xform(pos, PieceCatalog.info(id).base_rotation + angle)
	if "placed_by" in node:
		node.placed_by = by_player
	add_child(node)
	placed.append({"id": id, "pos": pos, "angle": angle, "by": by_player, "node": node})
	return true


## The layout with track card `id` dropped at `pos`, or null if the track
## would run into itself (or the track wasn't made from a layout).
func _reshaped_layout(id: String, pos: Vector2) -> Variant:
	if track.layout.is_empty():
		return null
	var key := "%s|%d|%d|%d" % [id, roundi(-pos.y), signi(roundi(pos.x * 10.0)), track.layout.hash()]
	if _fit_cache.has(key):
		return _fit_cache[key]
	var seg := PieceCatalog.track_segment(id, pos.x)
	var result = TrackGen.insert(track.layout, -pos.y, seg)
	if not TrackGen.fits(result, track.start_xz):
		result = null
	if _fit_cache.size() > 200:
		_fit_cache.clear()
	_fit_cache[key] = result
	return result


func _reshape(id: String, pos: Vector2) -> bool:
	var new_layout = _reshaped_layout(id, pos)
	if new_layout == null:
		return false
	var added := TrackGen.total_length(new_layout) - TrackGen.total_length(track.layout)
	var at := -pos.y
	track.apply_layout(new_layout, track.start_xz)
	# Pieces further down the track move along with it.
	for p in placed:
		if -p.pos.y > at:
			p.pos.y -= added
		p.node.transform = lane_xform(p.pos, PieceCatalog.info(p.id).base_rotation + p.angle)
	_fit_cache.clear()
	if _zone:
		_zone.queue_free()
		_zone = null
		show_zone(true)
	track_reshaped.emit()
	return true


## For a track card's ghost: the new shape of the track from where the
## card would go, as a see-through ribbon. Empty if it doesn't fit.
func reshape_preview(id: String, pos: Vector2) -> ArrayMesh:
	var new_layout = _reshaped_layout(id, pos)
	if new_layout == null:
		return null
	var at := clampf(-pos.y, 0.0, track.length())
	var pts := TrackGen.points(new_layout, track.start_xz)
	var i0 := clampi(roundi(at), 0, pts.size() - 1)
	# Line the preview up with the real track where the card goes.
	var shift := track.frame_at(at).origin - pts[i0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := track.lane_width / 2.0
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	for i in range(i0, pts.size()):
		var fwd := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var right := fwd.cross(Vector3.UP).normalized() * hw
		var o := pts[i] + shift + Vector3.UP * 0.05
		var l := o - right
		var r := o + right
		if i > i0:
			for v in [pl, r, pr, pl, l, r]:
				st.add_vertex(v)
		pl = l
		pr = r
	st.generate_normals()
	return st.commit()


## Remove every placed piece whose centre is within `radius` of `pos`.
## Returns how many were removed.
func explode(pos: Vector2, radius: float) -> int:
	var removed := 0
	for i in range(placed.size() - 1, -1, -1):
		var p: Dictionary = placed[i]
		if p.pos.distance_to(pos) <= radius:
			p.node.queue_free()
			placed.remove_at(i)
			removed += 1
	_boom_effect(lane_xform(pos).origin, radius)
	return removed


## Show the area pieces can go while players are building.
func show_zone(visible_now: bool) -> void:
	if _zone == null:
		_zone = MeshInstance3D.new()
		var mesh := track.ribbon_mesh(-top_z - 0.5, -bottom_z() + 0.5, half_width + 0.3, 0.006)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.12)
		mesh.surface_set_material(0, mat)
		_zone.mesh = mesh
		_zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_zone)
	_zone.visible = visible_now


func clear() -> void:
	for p in placed:
		p.node.queue_free()
	placed.clear()


## A see-through copy of a piece that does nothing, for build cursors.
## Bombs also show a red disc for their blast radius.
func make_ghost(id: String) -> Node3D:
	if PieceCatalog.is_track(id):
		var ribbon := MeshInstance3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		ribbon.material_override = mat
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.set_meta("track_card", id)
		add_child(ribbon)
		return ribbon
	var ghost: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_make_inert(ghost)
	if PieceCatalog.is_bomb(id):
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		var r: float = PieceCatalog.info(id).radius
		mesh.top_radius = r
		mesh.bottom_radius = r
		mesh.height = 0.02
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0.2, 0.1, 0.3)
		mesh.material = mat
		disc.mesh = mesh
		disc.position.y = 0.02
		ghost.add_child(disc)
	add_child(ghost)
	return ghost


func _make_inert(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area3D:
		node.monitoring = false
	if node is GeometryInstance3D:
		node.transparency = 0.4
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_make_inert(child)


func _boom_effect(at: Vector3, radius: float) -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.1, 0.9)
	mesh.material = mat
	ball.mesh = mesh
	ball.position = at + Vector3(0, 0.3, 0)
	ball.scale = Vector3.ONE * 0.2
	add_child(ball)
	var tw := ball.create_tween().set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * radius, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(ball.queue_free)
