extends SceneTree
## Finds scenery that pokes into other scenery (clipping): a tree trunk
## through a temple wall, a sign inside a rock, a bench in a hedge.
## It is a helper for finding problems, not part of the game.
##
##   godot --headless --script res://tests/find_clipping.gd -- hub
##   godot --headless --script res://tests/find_clipping.gd -- world <0-5> [seed]
##
## How it works: every simple shape (box, cylinder, cone, ball) in the scene
## is listed along with which bit of the game built it ("jungle.gd:_temple").
## For every two shapes built by DIFFERENT bits that overlap, it checks how
## far the corners of one sink inside the other. Shapes from the same bit
## are skipped, because those are meant to touch (a trunk and its leaves).
## It prints the worst overlaps first, with where they are.

const MIN_DEPTH := 0.12      # metres; smaller overlaps are just "touching"
const CELL := 4.0
## Bits that are fine to overlap anything (the ground itself, sky stuff).
const SKIP := ["hub.gd:_island", "hub.gd:_cloud_sea", "hub.gd:_sky_life", "hub.gd:_balloons",
		"hub.gd:_birds", "jungle.gd:_fireflies", "jungle.gd:_falling_leaves",
		"jungle.gd:_parrots_fly"]

var game: Node
var _t := 0
var mode := "hub"
var verbose := OS.get_cmdline_user_args().has("-v")
var world := 0
var seed_ := 1
var shapes: Array = []   # {kind, inv (Transform3D), xf, size/params, verts, aabb, src, path}


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	MeshBatch.record = true
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		mode = a[0]
	if a.size() > 1:
		world = int(a[1])
	if a.size() > 2:
		seed_ = int(a[2])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		if mode == "hub":
			game.settings.player_count = 1
			game._enter_hub()
		else:
			game.force_theme = Arena.THEMES[world]
			game._rng.seed = seed_
			game._new_track()
			print("world: ", Arena.THEMES[world], "  seed ", seed_)
	if _t < 12:
		return false
	_collect(root)
	print("shapes: ", shapes.size())
	var hits := _find()
	if mode != "hub":
		hits.append_array(_against_lane())
	# Drifting clouds: move them right round their circle and check again.
	var layers := root.find_children("*", "CloudLayer", true, false)
	var cloud_paths := layers.map(func(l): return str(l.get_path()) + "/")
	var is_cloud := func(path: String) -> bool:
		return cloud_paths.any(func(c): return path.begins_with(c))
	for step in 24:
		for l in layers:
			l._time = step * TAU / 24.0 / maxf(l.speed * 0.6, 0.0001)
			l._place()
		shapes.clear()
		_collect(root)
		for h in _find():
			if is_cloud.call(h.a.path) != is_cloud.call(h.b.path):   # cloud into scenery (not cloud into cloud)
				hits.append(h)
	_report(hits.filter(func(h): return not (is_cloud.call(h.a.path) and is_cloud.call(h.b.path))))
	return true


func _src(n: Node) -> String:
	if n.has_meta("clip_src"):
		return n.get_meta("clip_src")
	var p := n.get_parent()
	while p and p != root:
		if p.has_meta("clip_src"):
			return p.get_meta("clip_src")
		p = p.get_parent()
	return str(n.get_parent().get_path()).trim_prefix("/root/")


func _collect(n: Node) -> void:
	if n is SubViewport or (n is Node3D and not (n as Node3D).is_visible_in_tree()):
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.has_meta("clip_parts"):
			for p in mi.get_meta("clip_parts"):
				_add(p[0], mi.global_transform * p[1], p[2], str(mi.get_path()))
		elif mi.mesh is PrimitiveMesh:
			_add(mi.mesh, mi.global_transform, _src(mi), str(mi.get_path()))
	elif n is Label3D and (n as Label3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		var l := n as Label3D
		var bb := l.get_aabb()
		if bb.size.x > 0.01:
			var bm := BoxMesh.new()
			bm.size = Vector3(bb.size.x, bb.size.y, 0.02)
			_add(bm, l.global_transform * Transform3D(Basis.IDENTITY, bb.get_center()), _src(l) + " [label '%s']" % l.text.left(14), str(l.get_path()))
	for c in n.get_children():
		_collect(c)


func _add(mesh: Mesh, xf: Transform3D, src: String, path: String) -> void:
	if src in SKIP or src.begins_with("hub.gd:_island"):
		return
	var kind := ""
	var p := Vector3.ZERO
	if mesh is BoxMesh:
		kind = "box"
		p = (mesh as BoxMesh).size
	elif mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		kind = "cyl"
		p = Vector3(c.top_radius, c.bottom_radius, c.height)
	elif mesh is SphereMesh:
		var s := mesh as SphereMesh
		kind = "ball"
		p = Vector3(s.radius, s.height / 2.0, 0)
	else:
		return
	if xf.basis.determinant() == 0.0:
		return
	var verts := PackedVector3Array()
	var local: PackedVector3Array = mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
	var seen := {}
	for v in local:
		if not seen.has(v):
			seen[v] = true
			verts.append(xf * v)
	if kind == "box":
		# Box corners alone miss a box through a box; add the face middles.
		for ax in 3:
			for sgn in [-1.0, 1.0]:
				var f := Vector3.ZERO
				f[ax] = sgn * p[ax] / 2.0
				verts.append(xf * f)
	var bb := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		bb = bb.expand(v)
	shapes.append({kind = kind, xf = xf, inv = xf.affine_inverse(), p = p, verts = verts, aabb = bb,
			src = src, path = path, scale = xf.basis.get_scale()})


## How deep (metres, roughly) world point `w` is inside shape `s`; <= 0 if outside.
func _depth(s: Dictionary, w: Vector3) -> float:
	var l: Vector3 = s.inv * w
	var p: Vector3 = s.p
	var sc: Vector3 = s.scale
	match s.kind:
		"box":
			var d := minf(p.x / 2.0 - absf(l.x), minf(p.y / 2.0 - absf(l.y), p.z / 2.0 - absf(l.z)))
			return d * minf(sc.x, minf(sc.y, sc.z))
		"cyl":
			var h: float = p.z
			if absf(l.y) >= h / 2.0:
				return 0.0
			var r: float = lerpf(p.y, p.x, (l.y + h / 2.0) / h)
			var rho := Vector2(l.x, l.z).length()
			return minf(h / 2.0 - absf(l.y), r - rho) * minf(sc.x, minf(sc.y, sc.z))
		"ball":
			var q := Vector3(l.x / p.x, l.y / p.y, l.z / p.x)
			return (1.0 - q.length()) * minf(p.x, p.y) * minf(sc.x, minf(sc.y, sc.z))
	return 0.0


func _find() -> Array:
	var grid := {}
	for i in shapes.size():
		var bb: AABB = shapes[i].aabb
		var a := (bb.position / CELL).floor()
		var b := (bb.end / CELL).floor()
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					var k := Vector3i(x, y, z)
					if not grid.has(k):
						grid[k] = []
					grid[k].append(i)
	var done := {}
	var hits: Array = []
	for k in grid:
		var cell: Array = grid[k]
		for ii in cell.size():
			for jj in range(ii + 1, cell.size()):
				var i: int = cell[ii]
				var j: int = cell[jj]
				var A: Dictionary = shapes[i]
				var B: Dictionary = shapes[j]
				if A.src == B.src:
					continue
				var key := Vector2i(mini(i, j), maxi(i, j))
				if done.has(key):
					continue
				done[key] = true
				if not (A.aabb as AABB).intersects(B.aabb):
					continue
				var best := 0.0
				var at := Vector3.ZERO
				for v in A.verts:
					var d := _depth(B, v)
					if d > best:
						best = d
						at = v
				for v in B.verts:
					var d := _depth(A, v)
					if d > best:
						best = d
						at = v
				if best > MIN_DEPTH:
					hits.append({d = best, at = at, a = A, b = B})
	return hits


## Scenery poking into the lane itself (the track's floor and walls, and
## the pin deck), using the physics shapes of the lane.
func _against_lane() -> Array:
	var lane: Array = [game.track._body.get_rid()]
	for b in game.deck.find_children("*", "StaticBody3D", true, false):
		lane.append(b.get_rid())
	var skip := [str(game.track.get_path()), str(game.deck.get_path()), str(game.rack.get_path())]
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var out: Array = []
	for sh in shapes:
		if skip.any(func(p): return sh.path.begins_with(p)) or "RigidBody" in sh.path or "/Marble" in sh.path:
			continue   # the lane itself, and marbles rolling on it
		var sc: Vector3 = sh.scale
		var shape: Shape3D
		match sh.kind:
			"box":
				shape = BoxShape3D.new()
				shape.size = sh.p * sc
			"cyl":
				shape = CylinderShape3D.new()
				shape.radius = (sh.p.x + sh.p.y) / 2.0 * maxf(sc.x, sc.z)
				shape.height = sh.p.z * sc.y
			"ball":
				shape = SphereShape3D.new()
				shape.radius = minf(sh.p.x, sh.p.y) * minf(sc.x, minf(sc.y, sc.z))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D((sh.xf as Transform3D).basis.orthonormalized(), (sh.xf as Transform3D).origin)
		q.collide_with_areas = false
		var pts := space.collide_shape(q, 16)
		var best := 0.0
		var at := Vector3.ZERO
		for i in range(0, pts.size(), 2):
			var d: float = (pts[i] as Vector3).distance_to(pts[i + 1])
			if d > best:
				best = d
				at = pts[i]
		if best > MIN_DEPTH:
			# Only count it if what it hit is the lane.
			var hit := space.intersect_shape(q, 8)
			if hit.any(func(h): return lane.has(h.rid)):
				out.append({d = best, at = at, a = sh, b = {src = "THE LANE (track/deck)", kind = "", p = Vector3.ZERO, path = ""}})
	return out


func _report(hits: Array) -> void:
	# Group by the two bits involved, worst first.
	var groups := {}
	for h in hits:
		var names := [h.a.src, h.b.src]
		names.sort()
		var key := "%s  <->  %s" % names
		if not groups.has(key):
			groups[key] = []
		groups[key].append(h)
	var keys := groups.keys()
	keys.sort_custom(func(x, y): return _worst(groups[x]) > _worst(groups[y]))
	print("overlapping pairs: ", hits.size(), " in ", keys.size(), " groups")
	for key in keys:
		var g: Array = groups[key]
		g.sort_custom(func(x, y): return x.d > y.d)
		print("\n%s   (%d, worst %.2fm)" % [key, g.size(), g[0].d])
		for h in g.slice(0, 6):
			var hub_at: Vector3 = h.at
			if game.get("hub") and game.hub and mode == "hub":
				hub_at = game.hub.to_local(h.at)
			print("   %.2fm at (%.1f, %.1f, %.1f)  %s %s / %s %s" % [h.d, hub_at.x, hub_at.y, hub_at.z,
					h.a.kind, _vec(h.a.p), h.b.kind, _vec(h.b.p)])
			if verbose:
				print("        ", h.a.path.trim_prefix("/root/"), "  |  ", h.b.path.trim_prefix("/root/"))


func _worst(g: Array) -> float:
	var w := 0.0
	for h in g:
		w = maxf(w, h.d)
	return w


func _vec(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
