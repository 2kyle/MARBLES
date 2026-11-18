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
var cursor_cell: Array = []    # per player: Vector2i
var cursor_rot: Array = []     # per player: 0..3 quarter turns
var has_placed: Array = []     # per player: bool
var message: Array = []        # per player: short status text for the HUD

var _ghosts: Array = []
var _markers: Array = []

const START_COLUMNS := [1, 3, 0, 4]


func setup(p_builder: CourseBuilder, p_count: int, p_colors: Array) -> void:
	builder = p_builder
	player_count = p_count
	colors = p_colors


# ---------------------------------------------------------------- Draft

func start_draft(crate_size: int, rng: RandomNumberGenerator) -> void:
	crate = PieceCatalog.random_crate(crate_size, rng)
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
	cursor_cell = []
	cursor_rot = _filled(player_count, 0)
	has_placed = _filled(player_count, false)
	message = _filled(player_count, "")
	_ghosts = []
	_markers = []
	for p in player_count:
		var start := Vector2i(START_COLUMNS[p % START_COLUMNS.size()], builder.rows / 3)
		cursor_cell.append(start)
		if picks[p] == "":
			has_placed[p] = true
			_ghosts.append(null)
			_markers.append(null)
			continue
		_ghosts.append(builder.make_ghost(picks[p]))
		_markers.append(_make_marker(colors[p]))
	builder.show_grid(true)
	_update_visuals()


func request_cursor_move(player: int, delta: Vector2i) -> void:
	if has_placed[player]:
		return
	cursor_cell[player] = builder.clamp_cell(cursor_cell[player] + delta)
	message[player] = ""
	_update_visuals()


func request_rotate(player: int) -> void:
	if has_placed[player]:
		return
	cursor_rot[player] = (cursor_rot[player] + 1) % 4
	_update_visuals()


func request_place(player: int) -> bool:
	if has_placed[player]:
		return false
	if not builder.place(picks[player], cursor_cell[player], cursor_rot[player], player):
		message[player] = "That spot is taken."
		return false
	has_placed[player] = true
	message[player] = "Placed!"
	_free_cursor(player)
	return true


func all_placed() -> bool:
	return not has_placed.has(false)


## Time ran out: place everyone's piece at their cursor, or the nearest
## free spot.
func auto_place_remaining() -> void:
	for p in player_count:
		if has_placed[p]:
			continue
		var cell := builder.nearest_free(cursor_cell[p])
		if cell.x < 0:
			continue
		cursor_cell[p] = cell
		request_place(p)


func end_build() -> void:
	for p in player_count:
		_free_cursor(p)
	builder.show_grid(false)


# ---------------------------------------------------------------- Visuals

func _update_visuals() -> void:
	for p in player_count:
		if p >= _ghosts.size() or _ghosts[p] == null:
			continue
		var pos := builder.cell_to_local(cursor_cell[p])
		var ghost: Node3D = _ghosts[p]
		ghost.position = pos + Vector3(0, 0.02, 0)
		ghost.rotation.y = builder.rotation_for(picks[p], cursor_rot[p])
		var marker: Node3D = _markers[p]
		marker.position = pos + Vector3(0, 0.015 + 0.005 * p, 0)
		var free := builder.is_free(cursor_cell[p])
		(marker as MeshInstance3D).transparency = 0.35 if free else 0.8
	changed.emit()


func _make_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(builder.cell_width - 0.02, 0.02, builder.cell_length - 0.02)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	marker.mesh = mesh
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
