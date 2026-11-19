class_name DraftBuild
extends Node
## Draft and build rules: who picked what from the crate, where each
## player's cursor is, and placing pieces on the lane.
##
## Like main.gd, this is "referee" code. Players change it only through the
## request_* functions, which take a player id. Today main.gd calls them from
## keyboard input; in online play the host will call them when a player's
## request arrives over the network.

signal changed

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

const TITLE_FONT := preload("res://fonts/LilitaOne-Regular.ttf")

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
		draft_pointer.append(Vector2((i + 0.5) * crate.size() / float(player_count), 1.45))
	message = _filled(player_count, "")


## Slide a player's pointer by `delta` card units.
func request_pointer_move(player: int, delta: Vector2) -> void:
	if picks[player] != "":
		return
	var p: Vector2 = draft_pointer[player] + delta
	draft_pointer[player] = Vector2(clampf(p.x, -0.2, crate.size() + 0.2), clampf(p.y, -0.4, 1.7))


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
		cursor_pos.append(Vector2(x, -12.0 - 1.5 * p))
		if picks[p] == "":
			has_placed[p] = true
			_ghosts.append(null)
			_markers.append(null)
			_tags.append(null)
			continue
		_ghosts.append(builder.make_ghost(picks[p]))
		if PieceCatalog.is_track(picks[p]):
			_markers.append(_make_bar(colors[p]))
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
	cursor_pos[player] = builder.clamp_pos(cursor_pos[player] + delta)
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
	if PieceCatalog.is_track(id):
		name = "TRACK ALTERING\n" + name
	if PieceCatalog.parts(picks[player]) > 1:
		name += "  (%d/%d)" % [part[player] + 1, PieceCatalog.parts(picks[player])]
	if PieceCatalog.turns(id):
		return name + ("  < LEFT" if PieceCatalog.turns_left(cursor_angle[player]) else "  RIGHT >")
	return name


func request_place(player: int) -> bool:
	if has_placed[player]:
		return false
	var id: String = current_id(player)
	if not builder.place(id, cursor_pos[player], cursor_angle[player], player):
		message[player] = "Blocked"
		return false
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


# ---------------------------------------------------------------- Visuals

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
		var marker: MeshInstance3D = _markers[p]
		var blocked := cursor_blocked(p)
		var floor_xf := builder.lane_xform(cursor_pos[p], 0.0, 0.012 + 0.004 * p)
		marker.transform = floor_xf * Transform3D(Basis.from_scale(Vector3(1, 0.15, 1)), Vector3.ZERO)
		var mat: StandardMaterial3D = marker.mesh.material
		mat.albedo_color = Color(0.9, 0.1, 0.1) if blocked else colors[p]
		var tag: Node3D = _tags[p]
		tag.transform = floor_xf
		var label: Label3D = tag.get_node("Name")
		label.text = describe(p) + ("\nBLOCKED" if blocked else "")
		label.modulate = Color(1.0, 0.35, 0.3) if blocked else Color.WHITE
		var arrow: Node3D = tag.get_node("Arrow")
		arrow.visible = not ghost.has_meta("track_card")
		var cur := current_id(p)
		arrow.rotation.y = deg_to_rad(PieceCatalog.info(cur).base_rotation + cursor_angle[p]) \
				if PieceCatalog.aimed(cur) else 0.0
	changed.emit()


## A flat ring in the player's colour showing their cursor and the piece's
## footprint. It turns red when the piece can't go there.
func _make_marker(color: Color, radius: float) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - 0.08, 0.1)
	mesh.outer_radius = radius
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	marker.mesh = mesh
	marker.scale = Vector3(1, 0.15, 1)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.add_child(marker)
	return marker


## A bar across the track for track cards: the new stretch starts here.
func _make_bar(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(builder.track.lane_width + 0.3, 2.4, 0.25)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.add_child(marker)
	return marker


## A floating label with the piece's name (and which way it bends), plus an
## arrow on the floor showing which way the marbles roll through it.
func _make_tag(player: int) -> Node3D:
	var tag := Node3D.new()
	var label := Label3D.new()
	label.name = "Name"
	label.font = TITLE_FONT
	label.font_size = 72
	label.pixel_size = 0.009
	label.outline_size = 18
	label.outline_modulate = Color(0.06, 0.05, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.position = Vector3(0, 2.7, 0)
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
