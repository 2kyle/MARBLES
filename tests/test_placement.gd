extends SceneTree
## Checks that placed pieces never clip: drops lots of random pieces at
## random spots and turns on several tracks, then asks the physics engine
## whether any piece's solid shape pokes into the track's walls or into
## another piece. Also checks the build cursor slides along the walls
## instead of pushing a piece through them, and that a track card nudges
## pieces out of the way.
##   godot --headless --script res://tests/test_placement.gd

var game: Node
var _t := 0
var _fails := 0
var _rng := RandomNumberGenerator.new()
var _round := 0
const ROUNDS := 10


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_rng.seed = 7


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_t += 1
	if game.state == game.State.MENU:
		game._on_play_requested()
	if _t < 5:
		return false
	# Every few frames: fill a track with pieces, then check them a couple
	# of physics frames later (once the shapes are really in the world).
	var phase := (_t - 5) % 6
	if phase == 0:
		if _round >= ROUNDS:
			_cursor_checks()
			print("ALL PASSED" if _fails == 0 else "%d placement checks FAILED" % _fails)
			quit(1 if _fails > 0 else 0)
			return true
		_fill()
	elif phase == 4:
		_verify()
		_round += 1
	return false


var _tried := 0


func _fill() -> void:
	var b: CourseBuilder = game.builder
	b.clear()
	var ids := PieceCatalog.PIECES.keys().filter(func(id): return PieceCatalog.info(id).kind == "piece")
	_tried = 0
	var placed := 0
	for i in 400:
		var id: String = ids[_rng.randi() % ids.size()]
		var pos := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(b.bottom_z(), b.top_z))
		var angle := 15.0 * _rng.randi_range(0, 23)
		pos = b.clamp_piece(id, pos, angle)
		_tried += 1
		if b.place(id, pos, angle, 0):
			placed += 1
	print("round %d: placed %d of %d tries, track %.0f m" % [_round, placed, _tried, game.track.length()])


func _verify() -> void:
	var b: CourseBuilder = game.builder
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var track_rid: RID = game.track._body.get_rid()
	var wall_hits := []
	var piece_hits := []
	for entry in b.placed:
		var node: Node3D = entry.node
		var own := []
		for body in node.find_children("*", "CollisionObject3D", true, false) + ([node] if node is CollisionObject3D else []):
			own.append((body as CollisionObject3D).get_rid())
		for cs in node.find_children("*", "CollisionShape3D", true, false):
			var shape: CollisionShape3D = cs
			if shape.shape == null or shape.disabled or not (shape.get_parent() is PhysicsBody3D):
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			# Shrink a touch: resting on the floor is fine, poking through isn't.
			q.shape = shape.shape
			q.transform = shape.global_transform.scaled_local(Vector3.ONE * 0.97)
			q.transform.origin += shape.global_basis.y.normalized() * 0.03
			q.exclude = own
			q.collide_with_areas = false
			for hit in space.intersect_shape(q, 8):
				var other: Object = hit.collider
				if hit.rid == track_rid:
					# The floor is under every piece; only count the walls,
					# i.e. contacts well above the floor.
					var info := space.get_rest_info(q)
					if not info.is_empty():
						var d: float = game.track.distance_of(info.point)
						var f: Transform3D = game.track.world_frame_at(d)
						var up: float = (info.point - f.origin).dot(f.basis.y)
						if up > 0.08:
							wall_hits.append("%s at %s a%.0f (%.2f up, side %.2f, slope %.2f, d %.1f vs %.1f)" % [entry.id, entry.pos, entry.angle, up, (info.point - f.origin).dot(f.basis.x), game.track.direction_at(d).y, d, -entry.pos.y])
				elif other is Node and _piece_of(other) != null and _piece_of(other) != node:
					var o: Node = _piece_of(other)
					var oe := {}
					for e2 in b.placed:
						if e2.node == o:
							oe = e2
					piece_hits.append("%s %s %.0f <-> %s %s %.0f" % [entry.id, entry.pos, entry.angle, oe.get("id", o.name), oe.get("pos", ""), oe.get("angle", 0.0)])
	_check(wall_hits.is_empty(), "round %d: no piece pokes into a wall (%d pieces)%s" % [_round, b.placed.size(), "" if wall_hits.is_empty() else "  " + str(wall_hits.slice(0, 4))])
	_check(piece_hits.is_empty(), "round %d: no two pieces overlap%s" % [_round, "" if piece_hits.is_empty() else "  " + str(piece_hits.slice(0, 4))])
	_check(b.placed.size() >= 6, "round %d: still room for plenty of pieces (%d)" % [_round, b.placed.size()])
	# Next round: a different random track.
	game._new_match()


func _piece_of(n: Node) -> Node:
	var b: CourseBuilder = game.builder
	while n != null and n.get_parent() != b:
		n = n.get_parent()
	return n


## A plain stretch of track (no gap or narrow bridge nearby), in lane z.
func _plain_z() -> float:
	var t: Track = game.track
	var z := -12.0
	while z > game.builder.bottom_z():
		var ok := true
		for k in range(-4, 5):
			if t.in_gap(-z + k, 0.5) or t.in_narrow(-z + k, 0.5) or t.is_open(-z + k):
				ok = false
		if ok:
			return z
		z -= 1.0
	return -15.0


func _cursor_checks() -> void:
	var b: CourseBuilder = game.builder
	b.clear()
	var z := _plain_z()
	# A spinner pushed hard against the right wall stops with its blades
	# inside the lane.
	var pos := b.clamp_piece("spinner", Vector2(5.0, z), 0.0)
	var reach: float = b.footprint("spinner").r
	_check(pos.x + reach <= game.track.lane_width / 2.0, "spinner cursor stops at the wall (x %.2f + %.2f)" % [pos.x, reach])
	# Turning a long piece sideways next to the wall pulls it back in.
	var long := b.clamp_piece("drop_step", Vector2(5.0, z), 90.0)
	var hi := -INF
	for v in b.outline_offsets("drop_step", 90.0):
		hi = maxf(hi, v.x)
	_check(long.x + hi <= game.track.lane_width / 2.0, "sideways Ledge stays inside the walls")
	# The wind fan sits by the wall it blows from, not floating off the track.
	var fan := b.clamp_piece("wind_fan", Vector2(2.0, z), 0.0)
	_check(b.can_place("wind_fan", fan, 0.0) or b.why_blocked("wind_fan", fan, 0.0) != "WALL", "wind fan pushed right fits by the wall")
	# Two pieces on the same spot: the second is refused with a reason.
	b.place("hump", Vector2(0, z), 0.0, 0)
	_check(b.why_blocked("hump", Vector2(0.3, z - 0.5), 0.0) == "ON A PIECE", "a piece can't sit on another piece (%s)" % b.why_blocked("hump", Vector2(0.3, z - 0.5), 0.0))
	# ... but a press right next to it snaps to the nearest free spot.
	var db: DraftBuild = game.draft_build
	db.picks = ["bumper_post", ""]
	db.player_count = 2
	db.start_build()
	db.cursor_pos[0] = Vector2(0.0, z - 1.3)   # overlapping the hump's edge
	_check(db.request_place(0), "placing on a busy spot snaps to a free one nearby")
	db.end_build()
