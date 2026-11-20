class_name CityArena
extends Arena
## SUNSET CITY: the track runs high over the streets of a city at golden
## hour. Blocks of buildings with lit windows (drawn by a shader, so
## thousands of windows cost nothing), rooftop water towers and aerials,
## neon billboards, street lights, little parks and traffic driving about.
## Skyscrapers fill the skyline further out.

const GROUND := preload("res://shaders/city_ground.gdshader")
const BUILDING := preload("res://shaders/city_building.gdshader")
const BLOCK := 26.0
const ROAD := 9.0
const WALLS := [Color(0.82, 0.62, 0.5), Color(0.62, 0.66, 0.74), Color(0.86, 0.8, 0.68),
		Color(0.55, 0.5, 0.6), Color(0.75, 0.45, 0.4), Color(0.5, 0.6, 0.62), Color(0.9, 0.88, 0.84)]
const NEON := [Color(1.0, 0.3, 0.6), Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.4), Color(0.75, 0.45, 1.0)]
const BILLBOARDS := ["MARBLES 4P", "ROLL ON!", "STRIKE CITY", "PIN PALS", "BOWL-O-RAMA", "GO FAST", "HOT DOGS", "24 HR LANES"]
## No windows on these (alpha 0 tells the building shader).
const TREE := Color(0.3, 0.55, 0.3, 0.0)

var _bmat: ShaderMaterial


func _init() -> void:
	id = "city"
	track_floor = Color(0.56, 0.58, 0.62)
	track_wall = Color(0.95, 0.75, 0.2)
	track_support = Color(0.35, 0.37, 0.42)
	lamp_color = Color(1.0, 0.85, 0.55)
	start_color = Color(0.2, 0.75, 0.95)
	finish_color = Color(1.0, 0.3, 0.55)


func make_environment() -> Environment:
	var env := sky_env(Color(0.28, 0.38, 0.68), Color(1.0, 0.66, 0.42), Color(0.35, 0.3, 0.3), 0.5,
			Color(0.75, 0.55, 0.55), 0.0016)
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	sky.sky_curve = 0.2
	sky.sun_angle_max = 30.0
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	return env


func light_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(-0.42, 2.3, 0)
	sun.light_color = Color(1.0, 0.74, 0.5)
	sun.light_energy = 1.35


func fall_burst(parent: Node, at: Vector3, color: Color) -> void:
	# A puff of street dust.
	_burst(parent, Vector3(at.x, GROUND_Y + 0.1, at.z), Color(0.75, 0.72, 0.68).lerp(color, 0.2), 30, 0.14, 1.5, 3.5, Vector3(0, -2, 0))


func _build_scene() -> void:
	_bmat = ShaderMaterial.new()
	_bmat.shader = BUILDING
	_bmat.set_shader_parameter("ground_y", GROUND_Y)
	var off := Vector2(snappedf(_center.x, BLOCK), snappedf(_center.y, BLOCK))
	_ground(GROUND, {"offset": off, "block": BLOCK, "road": ROAD})
	var reach := _reach()
	var far := reach + 160.0
	var lights := MeshBatch.new()
	var cells := ceili(far / BLOCK)
	for bx in range(-cells, cells + 1):
		for bz in range(-cells, cells + 1):
			# Middle of this block's buildable square.
			var mid := off + Vector2(bx, bz) * BLOCK + Vector2.ONE * (BLOCK / 2.0)
			var dist := mid.distance_to(_center)
			if dist > far:
				continue
			_street_lights(lights, mid, dist)
			var room := BLOCK - ROAD - 3.0
			if not _clear_of_path(mid, room * 0.75 + 3.0):
				# The track passes over this block: a little park or plaza.
				if _clear_of_path(mid, 5.0) and _rng.randf() < 0.6:
					_park(mid, room)
				continue
			if dist < reach + 15.0 and _rng.randf() < 0.25:
				_park(mid, room)
			else:
				_block(mid, room, dist, reach)
	_put(lights, Vector3.ZERO, 0.0, 3.0)
	_traffic(off, reach + 60.0)
	_clouds(12, 140, 260, 45, 80, 4.0, 7.0)


## One city block: one tall building, or two to four smaller ones.
func _block(mid: Vector2, room: float, dist: float, reach: float) -> void:
	var b := MeshBatch.new()
	# Low near the track (so the camera can see), taller further out.
	var t := clampf((dist - reach * 0.5) / 140.0, 0.0, 1.0)
	var tall := lerpf(8.0, 70.0, t * t) * _rng.randf_range(0.6, 1.4)
	var parts := 1 if _rng.randf() < 0.45 or t > 0.6 else (2 if _rng.randf() < 0.5 else 4)
	var size := room / (1 if parts == 1 else 2)
	for k in parts:
		var o := Vector3.ZERO
		if parts == 2:
			o = Vector3((k - 0.5) * size, 0, 0)
		elif parts == 4:
			o = Vector3(((k % 2) - 0.5) * size, 0, (floori(k / 2.0) - 0.5) * size)
		var w := size * _rng.randf_range(0.75, 0.95)
		var d := (room if parts == 2 else size) * _rng.randf_range(0.75, 0.95)
		_building(b, o, w, d, maxf(tall * _rng.randf_range(0.6, 1.1), 6.0))
	_put(b, v3(mid, GROUND_Y), 0.0, 2.5, room * 0.75, _bmat)
	if _rng.randf() < 0.35 and tall > 12.0:
		_billboard(mid, tall)


## A building: a box (sometimes set back in tiers), a roof trim and things
## on the roof.
func _building(b: MeshBatch, at: Vector3, w: float, d: float, h: float) -> void:
	var col: Color = WALLS[_rng.randi() % WALLS.size()]
	var tiers := 1 if h < 25.0 else _rng.randi_range(1, 3)
	var y := 0.0
	var tw := w
	var td := d
	for k in tiers:
		var th := h / tiers * (1.2 if k == 0 else 0.9)
		b.box(Vector3(tw, th, td), at + Vector3(0, y + th / 2.0, 0), col)
		y += th
		b.box(Vector3(tw + 0.3, 0.4, td + 0.3), at + Vector3(0, y + 0.2, 0), Color(col.darkened(0.3), 0.0))
		tw *= 0.72
		td *= 0.72
	# Shop awnings round the bottom on low buildings.
	if h < 30.0:
		var awn: Color = NEON[_rng.randi() % NEON.size()].darkened(0.2)
		b.box(Vector3(w + 0.8, 0.15, 1.0), at + Vector3(0, 3.0, d / 2.0 + 0.5), Color(awn, 0.0))
		b.glow_box(Vector3(w * 0.7, 1.4, 0.05), at + Vector3(0, 1.4, d / 2.0 + 0.02), Color(1.0, 0.85, 0.6))
	# Roof stuff.
	var top := at + Vector3(0, y + 0.4, 0)
	match _rng.randi() % 4:
		0:
			# Water tower on legs.
			for x in [-0.8, 0.8]:
				for z in [-0.8, 0.8]:
					b.beam(top + Vector3(x, 0, z), top + Vector3(x * 0.8, 2.2, z * 0.8), 0.12, Color(0.3, 0.25, 0.22, 0.0))
			b.cyl(1.2, 1.2, 2.0, top + Vector3(0, 3.2, 0), Color(0.55, 0.38, 0.28, 0.0), 10)
			b.cyl(0.0, 1.3, 0.8, top + Vector3(0, 4.6, 0), Color(0.35, 0.25, 0.2, 0.0), 10)
		1:
			# Air-con boxes.
			for k in 3:
				b.box(Vector3(1.4, 0.9, 1.0), top + Vector3((k - 1) * 1.8, 0.45, _rng.randf_range(-1, 1)), Color(0.75, 0.75, 0.78, 0.0))
		2:
			if h > 35.0:
				# An aerial with a red light on top.
				b.beam(top, top + Vector3(0, 10, 0), 0.2, Color(0.8, 0.8, 0.82, 0.0))
				b.ball(top + Vector3(0, 10.2, 0), 0.35, Color(1.0, 0.15, 0.1), 6, Vector3.ONE, true)
		3:
			# A rooftop garden.
			b.box(Vector3(tw * 1.2, 0.5, td * 1.2), top + Vector3(0, 0.25, 0), Color(0.35, 0.55, 0.3, 0.0))
			b.ball(top + Vector3(0.8, 1.2, 0.5), 0.9, TREE, 6)


## A lit billboard on a roof, with a neon slogan.
func _billboard(mid: Vector2, h: float) -> void:
	var col: Color = NEON[_rng.randi() % NEON.size()]
	var yaw := atan2(_center.x - mid.x, _center.y - mid.y)
	var at := v3(mid, GROUND_Y + h * 1.0 + 0.5)
	var b := MeshBatch.new()
	b.beam(Vector3(-3, 0, 0), Vector3(-3, 3, 0), 0.2, Color(0.25, 0.25, 0.28, 0.0))
	b.beam(Vector3(3, 0, 0), Vector3(3, 3, 0), 0.2, Color(0.25, 0.25, 0.28, 0.0))
	b.box(Vector3(9.0, 3.6, 0.3), Vector3(0, 4.6, 0), Color(0.1, 0.1, 0.14, 0.0))
	b.glow_box(Vector3(9.2, 0.15, 0.35), Vector3(0, 6.45, 0), col)
	b.glow_box(Vector3(9.2, 0.15, 0.35), Vector3(0, 2.75, 0), col)
	var mi := _put(b, at, yaw, 3.0, 5.0, _bmat)
	var text: String = BILLBOARDS[_rng.randi() % BILLBOARDS.size()]
	var l := _sign(Vector3(0, 4.6, 0.2), text, 100, col.lightened(0.3), col.darkened(0.6), 0.0, 1.2)
	l.pixel_size = 0.012
	l.reparent(mi, false)
	var back := l.duplicate() as Label3D
	back.rotation.y = PI
	back.position.z = -0.2
	mi.add_child(back)


## A street light on each corner of the block, glowing.
func _street_lights(b: MeshBatch, mid: Vector2, dist: float) -> void:
	if dist > _reach() + 70.0:
		return
	var half := (BLOCK - ROAD) / 2.0 - 0.8
	for c in [Vector2(-1, -1), Vector2(1, 1)]:
		var p: Vector2 = mid + c * half
		if not _clear_of_path(p, 2.0):
			continue
		var base := v3(p, GROUND_Y)
		b.beam(base, base + Vector3(0, 4.5, 0), 0.14, Color(0.2, 0.22, 0.26))
		b.beam(base + Vector3(0, 4.5, 0), base + Vector3(c.x * 1.2, 4.6, 0), 0.1, Color(0.2, 0.22, 0.26))
		b.ball(base + Vector3(c.x * 1.2, 4.45, 0), 0.25, lamp_color, 6, Vector3(1, 0.6, 1), true)


## A small park: grass, paths, round trees and a fountain.
func _park(mid: Vector2, room: float) -> void:
	var b := MeshBatch.new()
	b.box(Vector3(room, 0.2, room), Vector3(0, 0.1, 0), Color(0.36, 0.6, 0.32, 0.0))
	b.box(Vector3(room, 0.22, 1.4), Vector3(0, 0.11, 0), Color(0.8, 0.74, 0.62, 0.0))
	b.box(Vector3(1.4, 0.22, room), Vector3(0, 0.11, 0), Color(0.8, 0.74, 0.62, 0.0))
	b.cyl(1.8, 2.0, 0.6, Vector3(0, 0.3, 0), Color(0.75, 0.75, 0.78, 0.0), 14)
	b.cyl(1.5, 1.5, 0.1, Vector3(0, 0.58, 0), Color(0.4, 0.75, 0.95, 0.0), 14)
	b.cyl(0.2, 0.3, 1.4, Vector3(0, 1.0, 0), Color(0.75, 0.75, 0.78, 0.0), 8)
	for k in 6:
		var x := _rng.randf_range(2.5, room / 2.0 - 1.5) * (1 if k % 2 == 0 else -1)
		var z := _rng.randf_range(2.5, room / 2.0 - 1.5) * (1 if k % 3 == 0 else -1)
		var h := _rng.randf_range(1.6, 2.6)
		b.cyl(0.12, 0.18, h, Vector3(x, h / 2.0, z), Color(0.45, 0.32, 0.2, 0.0), 6)
		b.ball(Vector3(x, h + 0.6, z), _rng.randf_range(1.0, 1.5), Color(TREE.lightened(_rng.randf_range(-0.1, 0.15)), 0.0), 8)
	_put(b, v3(mid, GROUND_Y), 0.0, 2.5, room * 0.6, _bmat)


## Little cars driving up and down the roads, headlights on.
func _traffic(off: Vector2, extent: float) -> void:
	var lanes := []
	var n := ceili(extent / BLOCK)
	for k in range(-n, n + 1):
		lanes.append(k)
	for i in 34:
		var b := MeshBatch.new()
		var body: Color = [Color(0.9, 0.25, 0.2), Color(0.95, 0.8, 0.2), Color(0.3, 0.55, 0.9), Color(0.95, 0.95, 0.95),
				Color(0.25, 0.25, 0.3), Color(0.4, 0.8, 0.5)][i % 6]
		var bus := i % 9 == 0
		var length := 6.0 if bus else 2.6
		b.box(Vector3(1.4, 0.6 if not bus else 2.0, length), Vector3(0, 0.5 if not bus else 1.2, 0), body)
		if not bus:
			b.box(Vector3(1.2, 0.5, 1.4), Vector3(0, 1.05, -0.1), body.lightened(0.15))
			b.box(Vector3(1.22, 0.32, 1.2), Vector3(0, 1.05, -0.1), Color(0.3, 0.4, 0.55))
		else:
			b.box(Vector3(1.42, 0.6, length - 1.0), Vector3(0, 1.6, 0), Color(0.3, 0.4, 0.55))
		for x in [-0.5, 0.5]:
			b.glow_box(Vector3(0.3, 0.18, 0.05), Vector3(x, 0.55, length / 2.0 + 0.01), Color(1.0, 0.95, 0.75))
			b.glow_box(Vector3(0.3, 0.15, 0.05), Vector3(x, 0.55, -length / 2.0 - 0.01), Color(1.0, 0.1, 0.1))
			for z in [-length * 0.3, length * 0.3]:
				b.cyl(0.32, 0.32, 0.25, Vector3(x * 1.45, 0.32, z), Color(0.1, 0.1, 0.1), 8)
		var car := _put(b, Vector3.ZERO, 0.0, 3.0)
		var along_x := i % 2 == 0
		var lane: int = lanes[_rng.randi() % lanes.size()]
		var dir := 1.0 if _rng.randf() < 0.5 else -1.0
		# Drive on the right: each direction keeps to its own side.
		var line := off[1 if along_x else 0] + lane * BLOCK + dir * ROAD * 0.22
		var speed := _rng.randf_range(5.0, 9.0) * dir * (0.7 if bus else 1.0)
		var start := _rng.randf_range(-extent, extent)
		var mid := off[0 if along_x else 1]
		_movers.append(func(t: float, _d: float):
			var s := wrapf(start + t * speed, -extent, extent) + mid
			if along_x:
				car.position = Vector3(s, GROUND_Y, line)
				car.rotation.y = PI / 2 if speed > 0 else -PI / 2
			else:
				car.position = Vector3(line, GROUND_Y, s)
				car.rotation.y = 0.0 if speed > 0 else PI)
