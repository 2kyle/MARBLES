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
var draft_cursor: Array = []   # per player: crate slot index

## Build
var cursor_pos: Array = []     # per player: Vector2 lane position
var cursor_angle: Array = []   # per player: degrees
var has_placed: Array = []     # per player: bool
var message: Array = []        # per player: short status text for the HUD

var _ghosts: Array = []
var _markers: Array = []

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
	draft_cursor = []
	for i in player_count:
		draft_cursor.append(i % crate.size())
	message = _filled(player_count, "")


func request_draft_move(player: int, step: int) -> void:
	if picks[player] != "":
		return
	draft_cursor[player] = wrapi(draft_cursor[player] + step, 0, crate.size())


func request_pick(player: int) -> bool:
	if picks[player] != "":
		return false
	var slot: int = draft_cursor[player]
	if taken_by[slot] != -1:
		message[player] = "Taken! Pick another."
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
		for step in crate.size():
			var slot: int = wrapi(draft_cursor[p] + step, 0, crate.size())
			if taken_by[slot] == -1:
				draft_cursor[p] = slot
				request_pick(p)
				break


# ---------------------------------------------------------------- Build

func start_build() -> void:
	cursor_pos = []
	cursor_angle = _filled(player_count, 0.0)
	has_placed = _filled(player_count, false)
	message = _filled(player_count, "")
	_ghosts = []
	_markers = []
	for p in player_count:
		cursor_pos.append(Vector2(START_X[p % START_X.size()], -12.0))
		if picks[p] == "":
			has_placed[p] = true
			_ghosts.append(null)
			_markers.append(null)
			continue
		_ghosts.append(builder.make_ghost(picks[p]))
		_markers.append(_make_marker(colors[p], PieceCatalog.info(picks[p]).radius))
	builder.show_zone(true)
	_update_visuals()


## Slide a player's cursor by `delta` metres (lane space: x across,
## y down the lane, negative toward the pins).
func request_cursor_move(player: int, delta: Vector2) -> void:
	if has_placed[player]:
		return
	cursor_pos[player] = builder.clamp_pos(cursor_pos[player] + delta)
	message[player] = ""
	_update_visuals()


func request_rotate(player: int, degrees: float) -> void:
	if has_placed[player]:
		return
	cursor_angle[player] = fposmod(cursor_angle[player] + degrees, 360.0)
	_update_visuals()


func request_place(player: int) -> bool:
	if has_placed[player]:
		return false
	var id: String = picks[player]
	if not builder.place(id, cursor_pos[player], cursor_angle[player], player):
		message[player] = "The track would hit itself" if PieceCatalog.is_track(id) else "Too close to another piece"
		return false
	has_placed[player] = true
	message[player] = "Boom!" if PieceCatalog.is_bomb(id) else ("Track changed!" if PieceCatalog.is_track(id) else "Placed!")
	_free_cursor(player)
	_update_visuals()  # other cursors may be blocked or freed now
	return true


func all_placed() -> bool:
	return not has_placed.has(false)


## Time ran out: place everyone's piece at their cursor, or the nearest
## spot where it fits.
func auto_place_remaining() -> void:
	for p in player_count:
		if has_placed[p]:
			continue
		var spot = builder.nearest_free(picks[p], cursor_pos[p])
		if spot == null:
			continue
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
	return not has_placed[player] and not builder.can_place(picks[player], cursor_pos[player])


# ---------------------------------------------------------------- Visuals

func _update_visuals() -> void:
	for p in player_count:
		if p >= _ghosts.size() or _ghosts[p] == null:
			continue
		var ghost: Node3D = _ghosts[p]
		if ghost.has_meta("track_card"):
			# Track cards show the new track shape from the cursor onward.
			(ghost as MeshInstance3D).mesh = builder.reshape_preview(picks[p], cursor_pos[p])
		else:
			ghost.transform = builder.lane_xform(cursor_pos[p],
				PieceCatalog.info(picks[p]).base_rotation + cursor_angle[p], 0.02)
		var marker: MeshInstance3D = _markers[p]
		marker.transform = builder.lane_xform(cursor_pos[p], 0.0, 0.012 + 0.004 * p) \
				* Transform3D(Basis.from_scale(Vector3(1, 0.15, 1)), Vector3.ZERO)
		var blocked := cursor_blocked(p)
		var mat: StandardMaterial3D = marker.mesh.material
		mat.albedo_color = Color(0.9, 0.1, 0.1) if blocked else colors[p]
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


func _free_cursor(player: int) -> void:
	if player < _ghosts.size() and _ghosts[player] != null:
		_ghosts[player].queue_free()
		_ghosts[player] = null
	if player < _markers.size() and _markers[player] != null:
		_markers[player].queue_free()
		_markers[player] = null


func _filled(n: int, value) -> Array:
	var a := []
	a.resize(n)
	a.fill(value)
	return a
