class_name MeshBatch
extends RefCounted
## Glues lots of simple shapes (boxes, cylinders, cones, balls) into ONE
## mesh, each shape keeping its own colour. One mesh is one draw call, so a
## whole city block or a forest costs about the same as a single box.
## The arenas (scripts/arena/) build almost all their scenery this way.
##
##   var b := MeshBatch.new()
##   b.box(Vector3(2, 6, 2), Vector3(0, 3, 0), Color.GRAY)
##   b.glow_box(Vector3(0.4, 0.4, 0.05), Vector3(0, 4, 1.01), Color.YELLOW)
##   add_child(b.make())
##
## "glow" shapes go in a second surface that lights itself up (windows,
## neon, crystals, lamps). Shapes are built facing +Z, standing on `pos`
## as their middle, turned `yaw` radians around up.

const MATTE := preload("res://shaders/batch_matte.gdshader")
const GLOW := preload("res://shaders/batch_glow.gdshader")

## Only for tests/find_clipping.gd: when true, every batch remembers each
## shape it glues in (and which bit of the game built it), so the clipping
## finder can check them. Off in the game, so it costs nothing.
static var record := false
var parts: Array = []

var _st := SurfaceTool.new()
var _glow := SurfaceTool.new()
var _has := [false, false]


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_glow.begin(Mesh.PRIMITIVE_TRIANGLES)


## Add any primitive mesh with a full transform.
func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color, glow := false) -> void:
	var st := _glow if glow else _st
	if record:
		parts.append([mesh, xf, feature()])
	_has[1 if glow else 0] = true
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	st.set_color(color)
	if idx.is_empty():
		for i in verts.size():
			st.set_normal((nb * norms[i]).normalized())
			st.add_vertex(xf * verts[i])
		return
	for i in idx:
		st.set_normal((nb * norms[i]).normalized())
		st.add_vertex(xf * verts[i])


func box(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> void:
	add(_box_mesh(size), Transform3D(Basis(Vector3.UP, yaw), pos), color)


func glow_box(size: Vector3, pos: Vector3, color: Color, yaw := 0.0) -> void:
	add(_box_mesh(size), Transform3D(Basis(Vector3.UP, yaw), pos), color, true)


## A cylinder (a cone when `top` is 0) standing on its middle at `pos`.
func cyl(top: float, bottom: float, h: float, pos: Vector3, color: Color, sides := 10, glow := false) -> void:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	m.cap_top = top > 0.0
	add(m, Transform3D(Basis.IDENTITY, pos), color, glow)


func ball(pos: Vector3, r: float, color: Color, segments := 8, squash := Vector3.ONE, glow := false) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 3)
	add(m, Transform3D(Basis.from_scale(squash), pos), color, glow)


## Any shape with a full basis (tilted things).
func shape(mesh: PrimitiveMesh, basis: Basis, pos: Vector3, color: Color, glow := false) -> void:
	add(mesh, Transform3D(basis, pos), color, glow)


## A box from `a` to `b` (a beam or a post), `thick` metres square.
func beam(a: Vector3, b: Vector3, thick: float, color: Color, glow := false) -> void:
	var along := b - a
	var len := along.length()
	if len < 0.001:
		return
	var y := along / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	add(_box_mesh(Vector3(thick, len, thick)), Transform3D(Basis(x, y, z), (a + b) / 2.0), color, glow)


func is_empty() -> bool:
	return not (_has[0] or _has[1])


## The finished mesh in a MeshInstance3D, ready to add to the scene.
## `glow_energy` is how bright the glowing shapes are.
## `matte` swaps the plain painted look for another material (the city's
## buildings use one that draws windows).
func make(glow_energy := 2.5, shadows := true, matte: Material = null) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var mi := MeshInstance3D.new()
	if _has[0]:
		_st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, matte if matte else matte_material())
	if _has[1]:
		_glow.commit(mesh)
		var g := ShaderMaterial.new()
		g.shader = GLOW
		g.set_shader_parameter("energy", glow_energy)
		mesh.surface_set_material(mesh.get_surface_count() - 1, g)
	mi.mesh = mesh
	if record:
		mi.set_meta("clip_parts", parts)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Which bit of the game is building right now, like "jungle.gd:_temple":
## the function called by the nearest build()/_build() on the call stack.
static func feature() -> String:
	var st := get_stack()
	for i in range(1, st.size()):
		if st[i].function in ["build", "_build", "_build_scene", "rebuild", "_ready", "start", "_enter_hub", "_initialize"]:
			var f: Dictionary = st[i - 1]
			return "%s:%s" % [f.source.get_file(), f.function]
	return "?"


static var _matte: ShaderMaterial
static func matte_material() -> ShaderMaterial:
	if _matte == null:
		_matte = ShaderMaterial.new()
		_matte.shader = MATTE
	return _matte


static var _boxes := {}
static func _box_mesh(size: Vector3) -> BoxMesh:
	if not _boxes.has(size):
		var m := BoxMesh.new()
		m.size = size
		_boxes[size] = m
	return _boxes[size]
