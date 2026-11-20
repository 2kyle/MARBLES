class_name TrackDecor
extends Node3D
## Looks only, no gameplay: the START and FINISH arches, lanterns along the
## walls, and braces (and foam rings, over water) on the support posts.
## main.gd calls rebuild() whenever the track changes shape. Nothing here
## has collision, so marbles never touch it. The scenery further out
## belongs to the arena (scripts/arena/), which also picks the colours.

## How many lanterns light up the track (each is a real light, so keep it
## modest for slower computers).
@export var lantern_lights := 10
## Metres between lanterns along the track.
@export var lantern_spacing := 6.0
## How high the START and FINISH signs hang over the track (metres), high
## enough to stay clear of the countdown and the camera at the pins.
@export var arch_height := 5.6
## Changes which random scenery you get (main.gd sets it each match).
var seed := 1

const TITLE_FONT := preload("res://fonts/ChakraPetch-Bold.ttf")
const FLAG_COLORS := [Color(0.95, 0.3, 0.25), Color(1.0, 0.8, 0.2),
		Color(0.25, 0.65, 0.95), Color(0.4, 0.85, 0.45), Color(0.9, 0.45, 0.85)]

var _mats := {}
var _glow := Color(1.0, 0.72, 0.35)


## Throw away the old decorations and make new ones to fit the track (and
## the pin deck at its end), in the arena's colours.
func rebuild(track: Track, deck: Node3D, arena: Arena) -> void:
	for c in get_children():
		c.queue_free()
	_glow = arena.lamp_color
	_start_arch(track, arena.start_color)
	_finish_arch(deck, arena.finish_color)
	_lanterns(track)
	_post_trim(track, arena.watery)


# ------------------------------------------------------------ Arches

func _start_arch(track: Track, color: Color) -> void:
	var f := _local(track.world_frame_at(2.2))
	_arch(f, track.lane_width, "START", color)
	_checker_strip(f, track.lane_width, 0.8)
	_bunting(f, track.lane_width)


func _finish_arch(deck: Node3D, color: Color) -> void:
	# The arrival line is 1.7 m onto the deck; the arch spans the gutters.
	var f := _local(deck.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.7)))
	_arch(f, BallReturn.ALLEY_WIDTH, "FINISH", color)
	_checker_strip(f, 5.6, 0.5)


## Two posts outside the walls, a beam across the top and a sign on it.
func _arch(f: Transform3D, width: float, text: String, color: Color) -> void:
	var arch := Node3D.new()
	arch.transform = f
	add_child(arch)
	var half := width / 2.0 + 0.45
	var h := arch_height
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.35, h + 0.6, 0.35)
	for side in [-1.0, 1.0]:
		_box(arch, post_mesh, Vector3(side * half, h / 2.0 - 0.1, 0), _mat(Color(0.95, 0.93, 0.88)))
		# A lantern on top of each post.
		_bulb(arch, Vector3(side * half, h + 0.5, 0), 0.2)
	var beam := BoxMesh.new()
	beam.size = Vector3(half * 2.0 + 0.6, 0.9, 0.3)
	_box(arch, beam, Vector3(0, h, 0), _mat(color))
	# Light bulbs along the bottom edge of the sign.
	for k in 9:
		_bulb(arch, Vector3(lerpf(-half, half, k / 8.0), h - 0.5, 0.0), 0.07)
	for facing in [0.0, PI]:
		var label := Label3D.new()
		label.text = text
		label.font = TITLE_FONT
		label.font_size = 96
		label.pixel_size = 0.0075
		label.outline_size = 16
		label.outline_modulate = color.darkened(0.55)
		label.position = Vector3(0, h, 0.17 if facing == 0.0 else -0.17)
		label.rotation.y = facing
		label.double_sided = false
		arch.add_child(label)


## A black and white chequered line across the track.
func _checker_strip(f: Transform3D, width: float, depth: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 14
	var rows := 2
	var cw := width / cols
	var rh := depth / rows
	for r in rows:
		for c in cols:
			st.set_color(Color(0.95, 0.95, 0.95) if (r + c) % 2 == 0 else Color(0.08, 0.08, 0.1))
			var x0 := -width / 2.0 + c * cw
			var z0 := -depth / 2.0 + r * rh
			var a := Vector3(x0, 0, z0)
			var b := Vector3(x0 + cw, 0, z0)
			var cc := Vector3(x0 + cw, 0, z0 + rh)
			var d := Vector3(x0, 0, z0 + rh)
			for v in [a, b, cc, a, cc, d]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	mi.material_override = mat
	mi.transform = f.translated_local(Vector3(0, 0.012, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Little coloured flags strung from the arch, sagging a bit.
func _bunting(f: Transform3D, width: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := width / 2.0 + 0.45
	for row in 1:
		var z := -2.2 - row * 2.4   # strings past the arch, over the first drop
		var count := 12
		for k in count:
			var t0 := float(k) / count
			var t1 := float(k + 0.8) / count
			var p0 := Vector3(lerpf(-half, half, t0), arch_height + 0.2 - sin(t0 * PI) * 0.5, z)
			var p1 := Vector3(lerpf(-half, half, t1), arch_height + 0.2 - sin(t1 * PI) * 0.5, z)
			var tip := (p0 + p1) / 2.0 + Vector3(0, -0.45, 0)
			st.set_color(FLAG_COLORS[(k + row) % FLAG_COLORS.size()])
			for v in [p0, p1, tip]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.transform = f
	add_child(mi)
	# Strings from the arch posts to two poles behind it.
	var pole := BoxMesh.new()
	pole.size = Vector3(0.12, arch_height + 0.4, 0.12)
	var holder := Node3D.new()
	holder.transform = f
	add_child(holder)
	for side in [-1.0, 1.0]:
		_box(holder, pole, Vector3(side * half, arch_height / 2.0, -4.2), _mat(Color(0.95, 0.93, 0.88)))


# ------------------------------------------------------------ Lanterns

## Lamp posts on alternate walls. A few of them carry real lights; the rest
## just glow (the glow effect makes them look lit).
func _lanterns(track: Track) -> void:
	var len := track.length()
	var count := floori((len - 8.0) / lantern_spacing)
	var light_every := maxi(1, ceili(float(count) / lantern_lights))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.07
	pole.height = 1.5
	var pole_mat := _mat(Color(0.18, 0.16, 0.15), 0.4, 0.6)
	for i in count:
		var d := 5.0 + i * lantern_spacing
		if track.in_gap(d, 1.0) or track.in_narrow(d, 1.0):
			continue
		var side := -1.0 if i % 2 == 0 else 1.0
		var f := _local(track.world_frame_at(d))
		var top := f.origin + f.basis.x * side * (track.lane_width / 2.0 + 0.05) + Vector3.UP * track.wall_height
		var holder := Node3D.new()
		holder.position = top
		add_child(holder)
		_box(holder, pole, Vector3(0, 0.75, 0), pole_mat)
		# Arm reaching out over the track, lantern hanging from it.
		var arm := BoxMesh.new()
		arm.size = Vector3(0.6, 0.06, 0.06)
		var inward: Vector3 = -f.basis.x * side
		var arm_node := _box(holder, arm, Vector3(0, 1.45, 0) + inward * 0.25, pole_mat)
		arm_node.basis = Basis(inward.normalized(), Vector3.UP, inward.normalized().cross(Vector3.UP)).orthonormalized()
		_bulb(holder, Vector3(0, 1.3, 0) + inward * 0.5, 0.15)
		if i % light_every == 0:
			var light := OmniLight3D.new()
			light.light_color = _glow
			light.light_energy = 1.6
			light.omni_range = 5.0
			light.omni_attenuation = 1.4
			light.shadow_enabled = false
			light.position = Vector3(0, 1.2, 0) + inward * 0.5
			holder.add_child(light)


func _bulb(parent: Node3D, pos: Vector3, r: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _glow
	mat.emission_enabled = true
	mat.emission = _glow
	mat.emission_energy_multiplier = 3.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ------------------------------------------------------------ Posts

## X braces between each pair of support posts, and a ring of foam where
## every post meets the water.
func _post_trim(track: Track, watery: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foam_spots := []
	var len := track.length()
	var count := maxi(1, floori(len / track.support_spacing))
	for i in count:
		var d := track.support_spacing * (i + 0.5)
		var f := _local(track.world_frame_at(d))
		var tops := []
		for side in [-1.0, 1.0]:
			var top: Vector3 = f.origin + f.basis.x * side * (track.half_width_at(d) - 0.3) - f.basis.y * 0.25
			tops.append(top)
			if watery and top.y - track.support_bottom_y > 0.5:
				foam_spots.append(Vector3(top.x, Arena.GROUND_Y + 0.03, top.z))
		var l: Vector3 = tops[0]
		var r: Vector3 = tops[1]
		var bottom := Arena.GROUND_Y + 0.6
		if minf(l.y, r.y) - bottom < 1.2:
			continue
		var low_l := Vector3(l.x, bottom, l.z)
		var low_r := Vector3(r.x, bottom, r.z)
		var high_l := l + Vector3(0, -0.3, 0)
		var high_r := r + Vector3(0, -0.3, 0)
		_beam(st, high_l, low_r, 0.07)
		_beam(st, high_r, low_l, 0.07)
		_beam(st, low_l.lerp(high_l, 0.5), low_r.lerp(high_r, 0.5), 0.06)
	st.generate_normals()
	var braces := MeshInstance3D.new()
	braces.mesh = st.commit()
	braces.material_override = _mat(track.support_color.darkened(0.1), 0.85)
	add_child(braces)

	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.55
	ring.rings = 16
	ring.ring_segments = 6
	var foam := StandardMaterial3D.new()
	foam.albedo_color = Color(0.92, 0.97, 1.0, 0.7)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for p in foam_spots:
		var mi := MeshInstance3D.new()
		mi.mesh = ring
		mi.material_override = foam
		mi.position = p
		mi.scale = Vector3(1, 0.12, 1)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## A square beam from a to b.
func _beam(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * r
	var up := side.cross(along).normalized() * r
	var corners := [side + up, -side + up, -side - up, side - up]
	for k in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		for v in [a + c0, b + c0, b + c1, a + c0, b + c1, a + c1]:
			st.add_vertex(v)


# ------------------------------------------------------------ Helpers

## A world transform turned into this node's own space.
func _local(xf: Transform3D) -> Transform3D:
	return global_transform.affine_inverse() * xf


func _box(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	return _mesh(parent, mesh, pos, mat)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color, roughness, metallic]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic = metallic
		_mats[key] = m
	return _mats[key]
