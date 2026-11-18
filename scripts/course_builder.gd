class_name CourseBuilder
extends Node3D
## The build grid on the sloped lane, and every piece players have placed.
## Attach to a node under the lane's Slope so positions follow the slope.
##
## Cells are Vector2i(column, row). Column 0 is the left edge of the lane,
## row 0 is just below the start gate and rows count down toward the pins.

## Number of columns across the lane.
@export var columns := 5
## Number of rows down the lane.
@export var rows := 16
## Width of a cell (across the lane), metres.
@export var cell_width := 1.0
## Length of a cell (down the lane), metres.
@export var cell_length := 1.5
## Distance from the top of the lane to the first row, metres.
@export var first_row_z := 4.5

## One entry per placed piece: {id, cell, rot, by, node}.
var placed: Array = []

var _grid: Node3D = null


func cell_to_local(cell: Vector2i) -> Vector3:
	var x := (cell.x - (columns - 1) / 2.0) * cell_width
	var z := -first_row_z - cell.y * cell_length
	return Vector3(x, 0.0, z)


func clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, columns - 1), clampi(cell.y, 0, rows - 1))


func is_free(cell: Vector2i) -> bool:
	for p in placed:
		if p.cell == cell:
			return false
	return true


## Nearest free cell to `cell`, or Vector2i(-1, -1) if the grid is full.
func nearest_free(cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for r in rows:
		for c in columns:
			var here := Vector2i(c, r)
			if is_free(here):
				var d := Vector2(here - cell).length()
				if d < best_d:
					best_d = d
					best = here
	return best


func rotation_for(id: String, rot_steps: int) -> float:
	return deg_to_rad(PieceCatalog.info(id).base_rotation + 90.0 * rot_steps)


## Put a piece on the lane. Returns false if the cell is taken.
func place(id: String, cell: Vector2i, rot_steps: int, by_player: int) -> bool:
	if not is_free(cell):
		return false
	var node: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	node.position = cell_to_local(cell)
	node.rotation.y = rotation_for(id, rot_steps)
	if "placed_by" in node:
		node.placed_by = by_player
	add_child(node)
	placed.append({"id": id, "cell": cell, "rot": rot_steps, "by": by_player, "node": node})
	return true


## Show faint tiles for every free cell while players are building.
func show_grid(visible_now: bool) -> void:
	if _grid == null:
		_grid = Node3D.new()
		add_child(_grid)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(cell_width - 0.08, 0.01, cell_length - 0.08)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 1, 1, 0.18)
		mesh.material = mat
		for r in rows:
			for c in columns:
				var tile := MeshInstance3D.new()
				tile.mesh = mesh
				tile.position = cell_to_local(Vector2i(c, r)) + Vector3(0, 0.006, 0)
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_grid.add_child(tile)
	_grid.visible = visible_now


func clear() -> void:
	for p in placed:
		p.node.queue_free()
	placed.clear()


## A see-through copy of a piece that does nothing, for build cursors.
func make_ghost(id: String) -> Node3D:
	var ghost: Node3D = load(PieceCatalog.info(id).scene).instantiate()
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	_make_inert(ghost)
	add_child(ghost)
	return ghost


func _make_inert(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area3D:
		node.monitoring = false
	if node is GeometryInstance3D:
		node.transparency = 0.45
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_make_inert(child)
