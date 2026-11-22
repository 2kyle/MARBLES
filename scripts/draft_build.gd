class_name DraftBuild
extends Node
## Draft and build rules: who picked what from the crate, where each
## player's cursor is, and placing pieces on the lane.
##
## Like main.gd, this is "referee" code. Players change it only through the
## request_* functions, which take a player id. main.gd calls them for
## everyone: people at this computer, bots, and (online, on the host)
## players on other computers. Online clients only copy the results.

signal changed
## A piece went down (online, the host tells everyone where).
signal placed(player: int, pos: Vector2, angle: float)

var builder: CourseBuilder
var player_count := 2
var colors: Array = []

## Draft
var crate: Array = []          # piece ids on offer
var taken_by: Array = []       # per crate slot: player id or -1
var picks: Array = []          # per player: piece id or ""
## Each player's pointer over the row of cards, in "card units": card k
## covers x from k to k+1 and y from 0 (top) to 1 (bottom). The HUD draws
## the cards and pointers from these numbers.
var draft_pointer: Array = []  # per player: Vector2

## Build
var cursor_pos: Array = []     # per player: Vector2 lane position
var cursor_angle: Array = []   # per player: degrees
var has_placed: Array = []     # per player: bool
var message: Array = []        # per player: short status text for the HUD

var _ghosts: Array = []
var _markers: Array = []
var _tags: Array = []      # per player: floating name + flow arrow
## Which part of a two-part piece each player is placing (0 = first).
var part: Array = []
var _first_part: Array = []  # per player: the placed first part, or null

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")

const START_X := [-1.2, 1.2, -0.4, 0.4]


func setup(p_builder: CourseBuilder, p_count: int, p_colors: Array) -> void:
	builder = p_builder
	player_count = p_count
	colors = p_colors


# ---------------------------------------------------------------- Draft

func start_draft(crate_size: int, rng: RandomNumberGenerator) -> void:
	crate = PieceCatalog.random_crate(crate_size, rng, not builder.track.layout.is_empty())
	taken_by = _filled(crate.size(), -1)
	picks = _filled(player_count, "")
	draft_pointer = []
	for i in player_count:
		draft_pointer.append(Vector2((i + 0.5) * crate.size() / float(player_count), 1.3))
	message = _filled(player_count, "")


## Online client: show the same crate the host dealt.
func mirror_draft(p_crate: Array) -> void:
	crate = p_crate
	taken_by = _filled(crate.size(), -1)
	picks = _filled(player_count, "")
	draft_pointer = []
	for i in player_count:
		draft_pointer.append(Vector2((i + 0.5) * crate.size() / float(player_count), 1.3))
	message = _filled(player_count, "")


## Slide a player's pointer by `delta` card units.
func request_pointer_move(player: int, delta: Vector2) -> void:
	if picks[player] != "":
		return
	var p: Vector2 = draft_pointer[player] + delta
	draft_pointer[player] = Vector2(clampf(p.x, -0.2, crate.size() + 0.2), clampf(p.y, -0.4, 1.45))  # stays above the key hints


## The card a player's pointer is over, or -1.
func hovered_slot(player: int) -> int:
	var p: Vector2 = draft_pointer[player]
	var k := floori(p.x)
	if k < 0 or k >= crate.size() or p.y < 0.0 or p.y > 1.0:
		return -1
	var fx := p.x - k
	if fx < 0.06 or fx > 0.94:
		return -1
	return k


func request_pick(player: int) -> bool:
	if picks[player] != "":
		return false
	var slot := hovered_slot(player)
	if slot == -1:
		return false
	if taken_by[slot] != -1:
		message[player] = "Taken!"
		return false
	taken_by[slot] = player
	picks[player] = crate[slot]
	message[player] = ""
	return true


func all_picked() -> bool:
	return not picks.has("")


## Time ran out: anyone who hasn't picked gets the slot under their cursor,
## or the next free one.
func auto_pick_remaining() -> void:
	for p in player_count:
		if picks[p] != "":
			continue
		var best := -1
		for slot in crate.size():
			if taken_by[slot] != -1:
				continue
			if best == -1 or absf(slot + 0.5 - draft_pointer[p].x) < absf(best + 0.5 - draft_pointer[p].x):
				best = slot
		if best != -1:
			draft_pointer[p] = Vector2(best + 0.5, 0.5)
			request_pick(p)


# ---------------------------------------------------------------- Build

func start_build() -> void:
	cursor_pos = []
	cursor_angle = _filled(player_count, 0.0)
	has_placed = _filled(player_count, false)
	part = _filled(player_count, 0)
	_first_part = _filled(player_count, null)
	message = _filled(player_count, "")
	_ghosts = []
	_markers = []
	_tags = []
	for p in player_count:
		var x: float = START_X[p % START_X.size()]
		if PieceCatalog.is_track(picks[p]):
			x = 0.0  # track cards change the whole width of the track
		# Spread the cursors down the lane so the pieces, outlines and labels
		# don't start on top of each other.
		var start := builder.clamp_piece(picks[p], Vector2(x, -10.0 - 5.0 * p), 0.0)
		if picks[p] != "" and not PieceCatalog.is_track(picks[p]):
			# Start somewhere the piece fits (not over a gap).
			var free = builder.nearest_free(picks[p], start, 0.0)
			if free != null:
				start = free
		cursor_pos.append(start)
		if picks[p] == "":
			has_placed[p] = true
			_ghosts.append(null)
			_markers.append(null)
			_tags.append(null)
			continue
		_ghosts.append(builder.make_ghost(picks[p]))
		if PieceCatalog.is_track(picks[p]):
			_markers.append(_make_gate(colors[p]))
		else:
			_markers.append(_make_marker(colors[p], PieceCatalog.info(picks[p]).radius))
		_tags.append(_make_tag(p))
	builder.show_zone(true)
	_update_visuals()


## Slide a player's cursor by `delta` metres (lane space: x across,
## y down the lane, negative toward the pins).
func request_cursor_move(player: int, delta: Vector2) -> void:
	if has_placed[player]:
		return
	if PieceCatalog.is_track(picks[player]):
		delta.x = 0.0  # track cards only slide up and down the track
	# The piece's whole outline stays inside the walls: the cursor slides
	# along a wall instead of pushing the piece through it.
	cursor_pos[player] = builder.clamp_piece(current_id(player), cursor_pos[player] + delta, cursor_angle[player])
	message[player] = ""
	_update_visuals()


## Turn a piece. Track cards that bend only flip between left (0) and
## right (180); other track cards can't turn.
func request_rotate(player: int, degrees: float) -> void:
	if has_placed[player]:
		return
	var id: String = picks[player]
	if PieceCatalog.is_track(id):
		if not PieceCatalog.turns(id):
			return
		cursor_angle[player] = 180.0 if PieceCatalog.turns_left(cursor_angle[player]) else 0.0
	else:
		cursor_angle[player] = fposmod(cursor_angle[player] + degrees, 360.0)
		# A long piece turned sideways may need to step in from the wall.
		cursor_pos[player] = builder.clamp_piece(id, cursor_pos[player], cursor_angle[player])
	message[player] = ""
	_update_visuals()


## The piece a player is placing right now. For a teleporter that's the
## entry first, then its exit.
func current_id(player: int) -> String:
	if picks[player] == "teleporter" and part[player] == 1:
		return "teleporter_exit"
	return picks[player]


## What a player's piece will do, in a few words for the floating tag and
## the HUD, e.g. "TRACK BEND  < LEFT".
func describe(player: int) -> String:
	var id: String = current_id(player)
	if id == "":
		return ""
	var name := PieceCatalog.display_name(id).to_upper()
	if PieceCatalog.parts(picks[player]) > 1:
		name += " %d/%d" % [part[player] + 1, PieceCatalog.parts(picks[player])]
	if PieceCatalog.turns(id):
		return name + ("  < LEFT" if PieceCatalog.turns_left(cursor_angle[player]) else "  RIGHT >")
	return name


func request_place(player: int) -> bool:
	if has_placed[player]:
		return false
	var id: String = current_id(player)
	if not builder.can_place(id, cursor_pos[player], cursor_angle[player]) and not PieceCatalog.is_track(id):
		# Nearly fits? Snap to the closest free spot within a couple of metres,
		# so a press right next to another piece still works.
		var spot = builder.nearest_free(id, cursor_pos[player], cursor_angle[player], null, 4)
		if spot != null:
			cursor_pos[player] = spot
	if not builder.place(id, cursor_pos[player], cursor_angle[player], player):
		message[player] = "Blocked"
		return false
	placed.emit(player, cursor_pos[player], cursor_angle[player])
	if part[player] + 1 < PieceCatalog.parts(picks[player]):
		# First part down: keep the cursor and switch to the next part.
		_first_part[player] = builder.last_placed
		part[player] += 1
		message[player] = "Now the exit"
		_ghosts[player].queue_free()
		_ghosts[player] = builder.make_ghost(current_id(player))
		if "is_exit" in _ghosts[player]:
			_ghosts[player].is_exit = true
		_update_visuals()
		return true
	if _first_part[player] != null and "partner" in builder.last_placed:
		_first_part[player].partner = builder.last_placed
		builder.last_placed.partner = _first_part[player]
	has_placed[player] = true
	message[player] = "Boom!" if PieceCatalog.is_bomb(id) else "Placed!"
	_free_cursor(player)
	_update_visuals()  # other cursors may be blocked or freed now
	return true


func all_placed() -> bool:
	return not has_placed.has(false)


## Time ran out: place everyone's piece at their cursor, or the nearest
## spot where it fits.
func auto_place_remaining() -> void:
	for p in player_count:
		for attempt in 2:  # two-part pieces need two goes
			if has_placed[p]:
				break
			if part[p] == 1 and _first_part[p] != null:
				# A teleporter exit right next to its entry is pointless:
				# put it further down the track.
				cursor_pos[p] = builder.clamp_pos(cursor_pos[p] + Vector2(0, -8))
			var spot = builder.nearest_free(current_id(p), cursor_pos[p], cursor_angle[p])
			if spot == null:
				break
			cursor_pos[p] = spot
			request_place(p)


func end_build() -> void:
	for p in player_count:
		_free_cursor(p)
	builder.show_zone(false)


## Where each player's build cursor is in the world (for the camera).
func cursor_world_positions() -> Array:
	var out := []
	for p in player_count:
		out.append(builder.to_global(builder.lane_xform(cursor_pos[p]).origin))
	return out


func cursor_blocked(player: int) -> bool:
	return not has_placed[player] and not builder.can_place(current_id(player), cursor_pos[player], cursor_angle[player])


## Why a player's piece won't go down where their cursor is ("WALL",
## "ON A PIECE", ...), or "" if it fits.
func blocked_reason(player: int) -> String:
	if has_placed[player]:
		return ""
	return builder.why_blocked(current_id(player), cursor_pos[player], cursor_angle[player])


# ---------------------------------------------------------------- Visuals

var _pulse := 0.0


## Track card previews breathe gently so they read as "not placed yet".
func _process(delta: float) -> void:
	_pulse += delta
	if builder:
		builder.ta_material().albedo_color.a = 0.8 + 0.2 * sin(_pulse * 4.0)

## Redraw the cursors (online clients call this after a snapshot moves them).
func refresh_visuals() -> void:
	_update_visuals()


func _update_visuals() -> void:
	for p in player_count:
		if p >= _ghosts.size() or _ghosts[p] == null:
			continue
		var ghost: Node3D = _ghosts[p]
		if ghost.has_meta("track_card"):
			# Track cards show the new track shape from the cursor onward.
			(ghost as MeshInstance3D).mesh = builder.reshape_preview(picks[p], cursor_pos[p], cursor_angle[p])
		else:
			var id := current_id(p)
			ghost.transform = builder.piece_xform(id, cursor_pos[p], cursor_angle[p]) \
					.translated(builder.lane_xform(cursor_pos[p]).basis.y * 0.02)
		var blocked := cursor_blocked(p)
		var floor_xf := builder.lane_xform(cursor_pos[p], 0.0, 0.012 + 0.004 * p)
		if ghost.has_meta("track_card"):
			# The start line sits where the new stretch begins (it snaps a
			# metre at a time, like the preview).
			var gate: Node3D = _markers[p]
			floor_xf = builder.ta_gate_xform(picks[p], cursor_pos[p], cursor_angle[p])
			gate.transform = floor_xf
			var gate_mat: StandardMaterial3D = gate.get_meta("mat")
			gate_mat.albedo_color = Color(0.9, 0.1, 0.1) if blocked else colors[p]
		else:
			var marker: MeshInstance3D = _markers[p]
			var id := current_id(p)
			if PieceCatalog.is_bomb(id):
				marker.transform = floor_xf * Transform3D(Basis.from_scale(Vector3(1, 0.15, 1)), Vector3.ZERO)
			else:
				# The piece's real footprint, turned with it.
				var key := "%s|%d" % [id, roundi(cursor_angle[p])]
				if marker.get_meta("key", "") != key:
					marker.set_meta("key", key)
					marker.mesh = _outline_mesh(builder.outline_offsets(id, cursor_angle[p]), marker.get_meta("mat"))
				marker.transform = floor_xf
			var mat: StandardMaterial3D = marker.get_meta("mat")
			mat.albedo_color = Color(0.9, 0.1, 0.1) if blocked else colors[p]
		var tag: Node3D = _tags[p]
		tag.transform = floor_xf
		var label: Label3D = tag.get_node("Name")
		# One short line in the player's colour, gone once placed. When
		# cursors are close, later players' labels sit higher on screen so they
		# never print over each other.
		label.visible = not has_placed[p]
		label.text = describe(p)
		if blocked:
			label.text = "WON'T FIT HERE" if ghost.has_meta("track_card") else _reason_text(blocked_reason(p))
		label.modulate = Color(1.0, 0.35, 0.3) if blocked else (colors[p] as Color).lightened(0.35)
		var below := 0
		for q in p:
			if not has_placed[q] and cursor_pos[q].distance_to(cursor_pos[p]) < 4.0:
				below += 1
		label.offset = Vector2(0, 80.0 * below)   # pixels, straight up the screen
		var arrow: Node3D = tag.get_node("Arrow")
		arrow.visible = not ghost.has_meta("track_card")
		var cur := current_id(p)
		arrow.rotation.y = deg_to_rad(PieceCatalog.info(cur).base_rotation + cursor_angle[p]) \
				if PieceCatalog.aimed(cur) else 0.0
	changed.emit()


## What the floating label says when a piece won't fit.
static func _reason_text(reason: String) -> String:
	match reason:
		"WALL":
			return "HITS THE WALL"
		"ON A PIECE":
			return "ON ANOTHER PIECE"
		"OVER A GAP":
			return "OVER A GAP"
		"TOO STEEP":
			return "TOO STEEP HERE"
		"TOO NARROW":
			return "TOO NARROW"
	return "BLOCKED"


## A flat outline of the piece's footprint on the floor (a strip 0.07 m
## wide just inside the edge), so you can see exactly where it will sit.
func _outline_mesh(offsets: PackedVector2Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := offsets.size()
	var centre := Vector2.ZERO
	for v in offsets:
		centre += v / n
	for i in n:
		var a: Vector2 = offsets[i]
		var b: Vector2 = offsets[(i + 1) % n]
		var ai := a + (centre - a).normalized() * 0.08
		var bi := b + (centre - b).normalized() * 0.08
		for v in [a, b, bi, a, bi, ai]:
			st.add_vertex(Vector3(v.x, 0.0, v.y))
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A flat ring in the player's colour showing their cursor and the piece's
## footprint. It turns red when the piece can't go there.
func _make_marker(color: Color, radius: float) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - 0.08, 0.1)
	mesh.outer_radius = radius
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mesh.material = mat
	marker.set_meta("mat", mat)
	marker.mesh = mesh
	marker.scale = Vector3(1, 0.15, 1)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.add_child(marker)
	return marker


## A start line for track cards, in the player's colour: a stripe across
## the floor with a little flag on each wall. The new stretch starts here.
func _make_gate(color: Color) -> Node3D:
	var gate := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	gate.set_meta("mat", mat)
	var w: float = builder.track.lane_width
	var h: float = builder.track.wall_height
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(w, 0.04, 0.22)
	stripe.mesh = stripe_mesh
	stripe.position.y = 0.04
	gate.add_child(stripe)
	for side in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.05
		pole_mesh.height = 1.1
		pole.mesh = pole_mesh
		pole.position = Vector3(side * (w / 2.0 + 0.12), h + 0.55, 0)
		gate.add_child(pole)
		# A little pennant pointing down the track.
		var flag := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(0, 0, 0), Vector3(0, -0.36, 0), Vector3(0, -0.18, -0.55)]:
			st.add_vertex(v)
		flag.mesh = st.commit()
		flag.position = Vector3(side * (w / 2.0 + 0.12), h + 1.08, 0)
		gate.add_child(flag)
	for c in gate.get_children():
		(c as MeshInstance3D).material_override = mat
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	builder.add_child(gate)
	return gate


## A floating label with the piece's name (and which way it bends), plus an
## arrow on the floor showing which way the marbles roll through it.
func _make_tag(player: int) -> Node3D:
	var tag := Node3D.new()
	var label := Label3D.new()
	label.name = "Name"
	label.font = TITLE_FONT
	label.font_size = 64
	label.pixel_size = 0.0075
	label.outline_size = 16
	label.outline_modulate = Color(0.06, 0.05, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.position = Vector3(0, 2.2, 0)
	tag.add_child(label)

	# Three chevrons pointing down the track (lane -z), like road markings.
	var arrow := MeshInstance3D.new()
	arrow.name = "Arrow"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = PieceCatalog.info(picks[player]).radius
	for k in 3:
		var z := -r - 0.3 - 0.5 * k
		var a := Vector3(-0.45, 0, z + 0.32)
		var tip := Vector3(0, 0, z)
		var b := Vector3(0.45, 0, z + 0.32)
		var a2 := a + Vector3(0, 0, -0.2)
		var tip2 := tip + Vector3(0, 0, -0.2)
		var b2 := b + Vector3(0, 0, -0.2)
		for v in [a, tip, tip2, a, tip2, a2, tip, b, b2, tip, b2, tip2]:
			st.add_vertex(v)
	arrow.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = colors[player]
	mat.no_depth_test = true
	mat.render_priority = 1
	arrow.material_override = mat
	arrow.position.y = 0.03
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tag.add_child(arrow)
	builder.add_child(tag)
	return tag


func _free_cursor(player: int) -> void:
	if player < _ghosts.size() and _ghosts[player] != null:
		_ghosts[player].queue_free()
		_ghosts[player] = null
	if player < _markers.size() and _markers[player] != null:
		_markers[player].queue_free()
		_markers[player] = null
	if player < _tags.size() and _tags[player] != null:
		_tags[player].queue_free()
		_tags[player] = null


func _filled(n: int, value) -> Array:
	var a := []
	a.resize(n)
	a.fill(value)
	return a
