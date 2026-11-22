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
@export var half_width := 1.8
## The build area runs from this z (near the start gate)...
@export var top_z := -3.5
## ...to this many metres before the end of the track (keeps the funnel clear).
@export var end_margin := 8.0
## How much two pieces' footprints may overlap (0 = not at all, 1 = fully).
@export_range(0.0, 1.0) var overlap_allowed := 0.35

## A track card changed the shape of the track (the pin deck must move).
signal track_reshaped
## A bomb went off and blew up `count` placed pieces (for the match awards).
signal blasted(by_player: int, count: int)

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


## True if a piece `id` could go at `pos` without poking through the walls,
## hanging over a gap or sitting on another piece.
func can_place(id: String, pos: Vector2, angle := 0.0) -> bool:
	return why_blocked(id, pos, angle) == ""


## Why a piece can't go at `pos`, in a couple of words for the HUD
## ("WALL", "ON A PIECE", "OVER A GAP", "TOO STEEP"), or "" if it fits.
## `skip` is a placed entry to ignore (a piece checking its own new spot).
func why_blocked(id: String, pos: Vector2, angle := 0.0, skip = null) -> String:
	if PieceCatalog.is_bomb(id):
		return ""
	if PieceCatalog.is_track(id):
		return "" if _reshaped_layout(id, pos, angle) != null else "WON'T FIT"
	if track.in_gap(-pos.y, 1.2) or track.in_narrow(-pos.y, 1.0):
		return "OVER A GAP" if track.in_gap(-pos.y, 1.2) else "TOO NARROW"
	var wall := _wall_problem(id, pos, angle)
	if wall != "":
		return wall
	var mine := floor_outline(id, pos, angle)
	for p in placed:
		if skip != null and p == skip:
			continue
		if not p.has("poly"):
			p.poly = floor_outline(p.id, p.pos, p.angle)
		if _overlap_area(mine, p.poly) > OVERLAP_SLACK:
			return "ON A PIECE"
	return ""


## Two pieces may touch, but not overlap by more than this (square metres).
const OVERLAP_SLACK := 0.0005
## How close a piece may come to the inside of a wall, in metres.
const WALL_MARGIN := 0.04


## The closest spot to `pos` where `id` fits, searching outward. Returns
## `pos` itself if it already fits, or null if nothing nearby fits.
func nearest_free(id: String, pos: Vector2, angle := 0.0, skip = null, max_rings := 15) -> Variant:
	if why_blocked(id, pos, angle, skip) == "":
		return pos
	for ring in range(1, max_rings + 1):
		var dist := ring * 0.5
		for step in 12:
			var a := TAU * step / 12.0
			var p := clamp_piece(id, pos + Vector2(cos(a), sin(a)) * dist, angle)
			if why_blocked(id, p, angle, skip) == "":
				return p
	return null


# ------------------------------------------------------------ Footprints
# Every piece knows its real outline on the floor (measured once from its
# scene, so a new model from Blender gets the right size by itself). The
# outline turns with the piece, keeps it inside the walls and stops it
# sitting on top of another piece.

static var _footprints := {}


## A piece's footprint in its own (turned, scaled) space:
##   c: centre offset (x across, y = z along), h: half size, r: radius if
##   it spins (then the outline is a circle).
func footprint(id: String) -> Dictionary:
	if _footprints.has(id):
		return _footprints[id]
	var info: Dictionary = PieceCatalog.info(id)
	var fp := {"c": Vector2.ZERO, "h": Vector2.ONE * float(info.get("radius", 1.0)) * 0.7, "r": 0.0, "top": 0.5}
	if info.get("kind", "") == "piece" and info.has("scene"):
		var node: Node3D = load(info.scene).instantiate()
		PieceStyle.dress(node, id)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_make_inert(node)
		add_child(node)   # some pieces build themselves in _ready
		var box := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			if m.mesh == null or m.has_meta("no_footprint"):
				continue
			var a: AABB = _local_xf(m, node) * m.mesh.get_aabb()
			box = a if first else box.merge(a)
			first = false
		remove_child(node)
		node.free()
		if not first:
			var s := PieceCatalog.scale_of(id)
			var lo := Vector2(box.position.x, box.position.z) * s
			var hi := Vector2(box.end.x, box.end.z) * s
			fp.c = (lo + hi) / 2.0
			fp.h = (hi - lo) / 2.0
			fp.top = maxf(box.end.y * s, 0.05)
			# Moving parts reach further than they rest.
			var sweep: Vector2 = info.get("sweep", Vector2.ZERO) * s
			fp.h = Vector2(maxf(fp.h.x, sweep.x), maxf(fp.h.y, sweep.y))
			if info.get("spins", false):
				fp.r = fp.h.length()
	_footprints[id] = fp
	return fp


func _local_xf(n: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## The corners of a piece's footprint offsets (lane metres, relative to its
## centre), turned by `angle` plus the piece's own starting turn.
func outline_offsets(id: String, angle: float) -> PackedVector2Array:
	var fp := footprint(id)
	var out := PackedVector2Array()
	var t := deg_to_rad(PieceCatalog.info(id).get("base_rotation", 0.0) + angle)
	var pts := []
	if fp.r > 0.0:
		for k in 12:
			var a := TAU * k / 12.0
			pts.append(fp.c + Vector2(cos(a), sin(a)) * fp.r)
	else:
		var h: Vector2 = fp.h
		pts = [fp.c + Vector2(-h.x, -h.y), fp.c + Vector2(h.x, -h.y), fp.c + Vector2(h.x, h.y), fp.c + Vector2(-h.x, h.y)]
	for v in pts:
		# Same turn as Basis(Vector3.UP, t) on (x, 0, z).
		out.append(Vector2(v.x * cos(t) + v.y * sin(t), -v.x * sin(t) + v.y * cos(t)))
	return out


## A piece's footprint where it really sits on the (bendy) track, seen
## from above: track-local x and z. Two pieces on a bend are turned a
## little differently, so this is what tells if they overlap.
##
## On a banked bend a tall piece leans over, so its top is in a slightly
## different place to its foot: the outline covers both.
func floor_outline(id: String, pos: Vector2, angle: float) -> PackedVector2Array:
	var base := lane_xform(pos)
	var top: Vector3 = base.basis.y * float(footprint(id).top)
	var pts := PackedVector2Array()
	for v in outline_offsets(id, angle):
		var p := base.origin + base.basis.x * v.x + base.basis.z * v.y
		pts.append(Vector2(p.x, p.z))
		pts.append(Vector2(p.x + top.x, p.z + top.z))
	return Geometry2D.convex_hull(pts)


func _overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var area := 0.0
	for poly in Geometry2D.intersect_polygons(a, b):
		var p: PackedVector2Array = poly
		var s := 0.0
		for i in p.size():
			s += p[i].cross(p[(i + 1) % p.size()])
		area += absf(s) / 2.0
	return area


## Checks the footprint against the real (bendy, banked) track: every
## corner and edge middle must be over the floor, inside the walls, and
## not floating above or sunk into a hill.
func _wall_problem(id: String, pos: Vector2, angle: float) -> String:
	var base := lane_xform(pos)
	var offs := outline_offsets(id, angle)
	var probes := PackedVector2Array()
	for i in offs.size():
		probes.append(offs[i])
		probes.append((offs[i] + offs[(i + 1) % offs.size()]) / 2.0)
	# Tall pieces are checked at wall height too (they lean on a bend).
	var lift := minf(float(footprint(id).top), track.wall_height)
	for v in probes:
		var p := base.origin + base.basis.x * v.x + base.basis.z * v.y
		var d := track.distance_of(track.to_global(p))
		if d <= 0.05 or d >= track.length() - 0.05:
			return "WALL"
		if track.in_gap(d, 0.2):
			return "OVER A GAP"
		var f := track.frame_at(d)
		var rel := p - f.origin
		var hw := track.half_width_at(d) - WALL_MARGIN
		if absf(rel.dot(f.basis.x)) > hw:
			return "WALL"
		if absf(rel.dot(f.basis.y)) > 0.15:
			return "TOO STEEP"
		var high := p + base.basis.y * lift
		var fh := track.frame_at(track.distance_of(track.to_global(high)))
		if absf((high - fh.origin).dot(fh.basis.x)) > hw:
			return "WALL"
	return ""


## Like clamp_pos(), but also keeps the piece's whole footprint inside the
## walls on a straight stretch, so build cursors slide along the wall
## instead of pushing the piece through it.
func clamp_piece(id: String, pos: Vector2, angle: float) -> Vector2:
	pos = clamp_pos(pos)
	if PieceCatalog.is_track(id) or PieceCatalog.is_bomb(id) or id == "":
		return pos
	var lo := INF
	var hi := -INF
	for v in outline_offsets(id, angle):
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	var hw := track.half_width_at(-pos.y) - WALL_MARGIN - 0.02
	var x_min := -hw - lo
	var x_max := hw - hi
	pos.x = (x_min + x_max) / 2.0 if x_min > x_max else clampf(pos.x, x_min, x_max)
	return pos


## Where a placed piece goes: on the track at `pos`, turned, and scaled up
## to its in-game size.
func piece_xform(id: String, pos: Vector2, angle: float) -> Transform3D:
	var xf := lane_xform(pos, PieceCatalog.info(id).base_rotation + angle)
	return xf.scaled_local(Vector3.ONE * PieceCatalog.scale_of(id))


## The node most recently placed by `place()` (the teleporter uses it to
## link its entry and exit).
var last_placed: Node3D = null


## Put a piece on the lane (or set off a bomb). Returns false if blocked.
func place(id: String, pos: Vector2, angle: float, by_player: int) -> bool:
	pos = clamp_pos(pos)
	if PieceCatalog.is_bomb(id):
		blasted.emit(by_player, explode(pos, PieceCatalog.info(id).radius))
		return true
	if PieceCatalog.is_track(id):
		return _reshape(id, pos, angle)
	if not can_place(id, pos, angle):
		return false
	var node: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	PieceStyle.dress(node, id)
	node.transform = piece_xform(id, pos, angle)
	if "placed_by" in node:
		node.placed_by = by_player
	if "is_exit" in node:
		node.is_exit = id == "teleporter_exit"
	add_child(node)
	last_placed = node
	placed.append({"id": id, "pos": pos, "angle": angle, "by": by_player, "node": node})
	return true


## What dropping track card `id` at `pos` would do: a Dictionary with
##   layout: the new layout (even if it doesn't fit)
##   fits:   false if the track would run into itself
##   from, to: where the new (or changed) stretch is, in layout metres
## or null if the track wasn't made from a layout. Cached per whole metre,
## so the preview only changes when the cursor crosses a metre mark.
func ta_plan(id: String, pos: Vector2, angle: float) -> Variant:
	if track.layout.is_empty():
		return null
	var left := PieceCatalog.turns_left(angle)
	var ground := roundf(track.distance_to_ground(-clamp_pos(pos).y))
	var key := "%s|%d|%s|%d" % [id, ground, left, track.layout.hash()]
	if _fit_cache.has(key):
		return _fit_cache[key]
	var seg = PieceCatalog.track_segment(id, left)
	var plan := {}
	if seg is Dictionary and seg.get("open", false):
		# Wall Breaker: same shape, the walls just come off.
		var opened := TrackGen.open_range(track.layout, ground, seg.len)
		plan = {"layout": opened, "fits": true, "from": ground, "to": ground + seg.len}
		for r in TrackGen.open_ranges(opened):
			if r[0] <= ground + 0.5 and r[1] >= ground + 0.5:
				plan.from = r[0]
				plan.to = r[1]
		# The start and finish keep their walls, so the stretch may be cut short.
		var first_ok: float = maxf(1.0, roundf(track.layout[0].len))
		plan.from = maxf(plan.from, first_ok)
	else:
		plan = TrackGen.insert_info(track.layout, ground, seg)
		plan.fits = TrackGen.fits(plan.layout, track.start_xz)
	if _fit_cache.size() > 200:
		_fit_cache.clear()
	_fit_cache[key] = plan
	return plan


func _reshaped_layout(id: String, pos: Vector2, angle: float) -> Variant:
	var plan = ta_plan(id, pos, angle)
	return plan.layout if plan != null and plan.fits else null


func _reshape(id: String, pos: Vector2, angle: float) -> bool:
	var plan = ta_plan(id, pos, angle)
	if plan == null or not plan.fits:
		return false
	var old_len := track.length()
	var at := track.ground_to_distance(plan.from)
	track.apply_layout(plan.layout, track.start_xz)
	var added := track.length() - old_len
	# Pieces further down the track move along with it.
	for p in placed:
		if -p.pos.y > at:
			p.pos.y -= added
		p.erase("poly")   # the track moved under it
		if is_instance_valid(p.node):
			p.node.transform = piece_xform(p.id, p.pos, p.angle)
	_fit_cache.clear()
	_settle_pieces()
	if _zone:
		_zone.queue_free()
		_zone = null
		show_zone(true)
	_reshape_flash(id, track.ground_to_distance(plan.from), track.ground_to_distance(plan.to))
	track_reshaped.emit()
	return true


## After a track card changes the track, a piece may now poke through a
## new bend's wall or hang over a new gap. Nudge each one to the nearest
## spot where it fits, or pop it off the track if there's no room.
func _settle_pieces() -> void:
	for i in range(placed.size() - 1, -1, -1):
		var p: Dictionary = placed[i]
		if why_blocked(p.id, p.pos, p.angle, p) == "":
			continue
		var spot = nearest_free(p.id, clamp_piece(p.id, p.pos, p.angle), p.angle, p, 6)
		if spot != null:
			p.pos = spot
			p.erase("poly")
			if is_instance_valid(p.node):
				p.node.transform = piece_xform(p.id, p.pos, p.angle)
		else:
			if is_instance_valid(p.node):
				_boom_effect(lane_xform(p.pos).origin, 1.0)
				p.node.queue_free()
			placed.remove_at(i)


## Where a track card's start line goes for a cursor at `pos`: across the
## track at the start of the new stretch. Track-local.
func ta_gate_xform(id: String, pos: Vector2, angle: float) -> Transform3D:
	var plan = ta_plan(id, pos, angle)
	var d := -clamp_pos(pos).y if plan == null else track.ground_to_distance(plan.from)
	return track.frame_at(d)


# Preview colours. Gold = new track, red = danger (gaps, missing walls,
# or a card that won't fit), white dots = where the rest of the track goes.
const TA_NEW := Color(1.0, 0.8, 0.15, 0.5)
const TA_NEW_EDGE := Color(1.0, 0.92, 0.45, 0.85)
const TA_DANGER := Color(1.0, 0.22, 0.15, 0.5)
const TA_BAD := Color(1.0, 0.15, 0.12, 0.45)
const TA_DOT := Color(1.0, 1.0, 1.0, 0.75)
## An Oil Slick's floor: slick cyan instead of gold.
const TA_OIL := Color(0.2, 0.85, 1.0, 0.55)


## For a track card's ghost: what the track would look like with the card
## dropped at `pos`, as one mesh (vertex colours, see-through):
##   - the new stretch as a gold see-through piece of track, walls and all,
##     with arrows showing which way marbles roll
##   - gaps, missing walls and a Narrow Bridge's missing floor in red
##   - a dotted line down the middle of where the rest of the track will go
##   - everything red if the card won't fit there
func reshape_preview(id: String, pos: Vector2, angle: float) -> ArrayMesh:
	var plan = ta_plan(id, pos, angle)
	if plan == null:
		return null
	if plan.has("mesh"):
		return plan.mesh
	var kind: String = PieceCatalog.info(id).segment
	var new_layout: Array = plan.layout
	var pts := TrackGen.points(new_layout, track.start_xz)
	var curve := Track.curve_through(pts)
	var along := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		along.append(along[i - 1] + pts[i].distance_to(pts[i - 1]))
	var g0 := clampi(int(plan.from), 0, pts.size() - 1)
	var g1 := clampi(int(plan.to), 0, pts.size() - 1)
	var a0 := along[g0]
	var a1 := along[g1]
	var shift_at := a0
	if kind == "gap":
		# A gap is short: show a little track either side so it reads.
		a0 = maxf(a0 - 2.0, 0.0)
		a1 = minf(a1 + 2.0, along[-1])
	# The new track sits a little higher or lower (it always ends at the
	# pins), so line it up with the real track where the card goes.
	var shift := track.frame_at(track.ground_to_distance(plan.from)).origin - curve.sample_baked(shift_at, true)
	var hw := track.lane_width / 2.0
	var wall_h := track.wall_height
	var bad: bool = not plan.fits
	var new_col := TA_BAD if bad else (TA_OIL if kind == "oil" else TA_NEW)
	var edge_col := TA_BAD if bad else TA_NEW_EDGE

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var holes := TrackGen.gap_ranges(new_layout)
	var narrow_ranges := []
	for r in TrackGen.narrow_ranges(new_layout):
		narrow_ranges.append([along[clampi(int(r[0]), 0, along.size() - 1)], along[clampi(int(r[1]), 0, along.size() - 1)]])
	var n := maxi(2, ceili((a1 - a0) / 0.5) + 1)
	var prev := {}
	for k in n:
		var d := lerpf(a0, a1, k / float(n - 1))
		var xf := track.frame_on(curve, d)
		xf.origin += shift
		var o := xf.origin + xf.basis.y * 0.04
		var r := xf.basis.x
		var u := xf.basis.y
		var ground_m := 0.0
		for i in range(1, along.size()):
			if along[i] >= d:
				ground_m = i - 1 + (d - along[i - 1]) / maxf(along[i] - along[i - 1], 0.001)
				break
		var in_hole := false
		for h in holes:
			in_hole = in_hole or (ground_m > h[0] and ground_m < h[1])
		var plank := hw
		for nr in narrow_ranges:
			if d > nr[0] and d < nr[1]:
				var t := clampf(minf(d - nr[0], nr[1] - d) / Track.NARROW_TAPER, 0.0, 1.0)
				plank = lerpf(hw, Track.NARROW_WIDTH / 2.0, smoothstep(0.0, 1.0, t))
		var row := {
			"l": o - r * hw, "r": o + r * hw,
			"pl": o - r * plank, "pr": o + r * plank,
			"lt": o - r * hw + u * wall_h, "rt": o + r * hw + u * wall_h,
			"lo": o - r * (hw + 0.25) + u * wall_h, "ro": o + r * (hw + 0.25) + u * wall_h,
			"hole": in_hole, "o": o, "u": u, "r_dir": r, "d": d,
		}
		if not prev.is_empty():
			var hole: bool = row.hole or prev.hole
			if kind == "open":
				# Same track, walls marked red: these are what disappear.
				var red := TA_BAD if bad else Color(1, 0.2, 0.15, 0.7)
				for sd in [-1.0, 1.0]:
					var pin: Vector3 = (prev.l if sd < 0 else prev.r) - prev.r_dir * sd * 0.05
					var rin: Vector3 = (row.l if sd < 0 else row.r) - row.r_dir * sd * 0.05
					var ptop: Vector3 = (prev.lt if sd < 0 else prev.rt) + prev.u * 0.05
					var rtop: Vector3 = (row.lt if sd < 0 else row.rt) + row.u * 0.05
					var pout: Vector3 = (prev.lo if sd < 0 else prev.ro) + prev.u * 0.05
					var rout: Vector3 = (row.lo if sd < 0 else row.ro) + row.u * 0.05
					_tri_quad(st, red, pin, rin, rtop - row.r_dir * sd * 0.05, ptop - prev.r_dir * sd * 0.05)
					_tri_quad(st, red, ptop, rtop, rout, pout)
			elif hole:
				# A gap: a red hole with bright lips at both ends.
				_tri_quad(st, TA_BAD if bad else Color(1, 0.2, 0.15, 0.6), prev.l, row.l, row.r, prev.r)
			else:
				# The floor (only the plank on a Narrow Bridge, with the
				# missing sides in red).
				_tri_quad(st, new_col, prev.pl, row.pl, row.pr, prev.pr)
				if kind == "narrow":
					_tri_quad(st, TA_BAD if bad else TA_DANGER, prev.l, row.l, row.pl, prev.pl)
					_tri_quad(st, TA_BAD if bad else TA_DANGER, prev.pr, row.pr, row.r, prev.r)
				else:
					# Walls: inside face and top.
					_tri_quad(st, new_col, prev.l, row.l, row.lt, prev.lt)
					_tri_quad(st, new_col, prev.r, row.r, row.rt, prev.rt)
					_tri_quad(st, edge_col, prev.lt, row.lt, row.lo, prev.lo)
					_tri_quad(st, edge_col, prev.rt, row.rt, row.ro, prev.ro)
		prev = row
	# Lips at the ends of any gap, and arrows down the middle of the new stretch.
	for h in holes:
		if h[1] < plan.from or h[0] > plan.to:
			continue
		for gm in [h[0], h[1]]:
			var lip := track.frame_on(curve, along[clampi(int(gm), 0, along.size() - 1)])
			lip.origin += shift + lip.basis.y * 0.06
			_tri_quad(st, TA_BAD if bad else Color(1, 0.3, 0.2, 0.95),
					lip.origin - lip.basis.x * hw - lip.basis.z * 0.2, lip.origin + lip.basis.x * hw - lip.basis.z * 0.2,
					lip.origin + lip.basis.x * hw + lip.basis.z * 0.2, lip.origin - lip.basis.x * hw + lip.basis.z * 0.2)
	var arrow_col := Color(1, 1, 1, 0.8) if not bad else Color(1, 0.8, 0.8, 0.6)
	var ad := a0 + 1.2
	while ad < a1 - 0.6:
		var ax := track.frame_on(curve, ad)
		ax.origin += shift + ax.basis.y * 0.07
		var on_hole := false
		var gm := 0.0
		for i in range(1, along.size()):
			if along[i] >= ad:
				gm = float(i)
				break
		for h in holes:
			on_hole = on_hole or (gm > h[0] and gm < h[1] + 1)
		if not on_hole:
			_chevron(st, ax, 0.5, arrow_col)
		ad += 1.8
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, ta_material())
	# Where the rest of the track will go: a dotted line down its middle,
	# drawn on top of everything so the real track can't hide it.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_dots := false
	if kind != "open":
		var len := curve.get_baked_length()
		var dd := a1 + 1.0
		while dd < len - 1.0:
			var dx := track.frame_on(curve, dd)
			dx.origin += shift + dx.basis.y * 0.1
			_dot(st, dx, 0.16, TA_BAD if bad else TA_DOT)
			any_dots = true
			dd += 1.6
	if any_dots:
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(1, ta_material(true))
	plan.mesh = mesh
	return plan.mesh


var _ta_mats := {}


## The see-through material track card previews use. `on_top` draws over
## everything (for the dotted line). The build cursors pulse its alpha.
func ta_material(on_top := false) -> StandardMaterial3D:
	if not _ta_mats.has(on_top):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if on_top:
			mat.no_depth_test = true
			mat.render_priority = 1
		else:
			# A faint second pass drawn over everything, so any part of the
			# new track hidden behind the real one still shows through.
			var ghost := mat.duplicate() as StandardMaterial3D
			ghost.no_depth_test = true
			ghost.albedo_color = Color(1, 1, 1, 0.3)
			mat.next_pass = ghost
		_ta_mats[on_top] = mat
	return _ta_mats[on_top]


func _tri_quad(st: SurfaceTool, col: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_color(col)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## A flat arrow lying on the track at `xf`, pointing down the track.
func _chevron(st: SurfaceTool, xf: Transform3D, size: float, col: Color) -> void:
	var fwd := -xf.basis.z
	var side := xf.basis.x
	var tip := xf.origin + fwd * size * 0.5
	var back := xf.origin - fwd * size * 0.15
	var t := size * 0.28
	_tri_quad(st, col, back - side * size, tip, tip - fwd * t, back - side * size - fwd * t)
	_tri_quad(st, col, tip, back + side * size, back + side * size - fwd * t, tip - fwd * t)


## A small flat diamond lying on the track at `xf`.
func _dot(st: SurfaceTool, xf: Transform3D, r: float, col: Color) -> void:
	var fwd := -xf.basis.z * r * 1.4
	var side := xf.basis.x * r
	_tri_quad(st, col, xf.origin - fwd, xf.origin + side, xf.origin + fwd, xf.origin - side)


## A quick glow over the stretch a track card just changed, so everyone
## sees what happened. Gold for new track, red where walls came off.
func _reshape_flash(id: String, d0: float, d1: float) -> void:
	if d1 - d0 < 0.5:
		return
	var kind: String = PieceCatalog.info(id).segment
	var glow := MeshInstance3D.new()
	var mesh := track.ribbon_mesh(d0, d1, track.lane_width / 2.0 + 0.3, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1, 0.3, 0.2, 0.85) if kind in ["open", "narrow", "gap"] else Color(1, 0.85, 0.25, 0.85)
	mesh.surface_set_material(0, mat)
	glow.mesh = mesh
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var tw := glow.create_tween().set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_property(glow, "position:y", 0.6, 0.9).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(glow.queue_free)


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
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ribbon.set_meta("track_card", id)
		add_child(ribbon)
		return ribbon
	var ghost: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	PieceStyle.dress(ghost, id)
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
