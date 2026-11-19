class_name ItemIcons
extends RefCounted
## Little pictures of cosmetics for the closet and the loot crate reveal.
## Hats, colours, styles and the trophy are tiny 3D scenes drawn once into
## their own viewport, then kept as a plain picture (so the closet stays
## cheap); trails and coins are drawn flat in 2D.

const MARBLE_SCENE := preload("res://scenes/marble.tscn")

## Pictures already drawn, by "slot:id:colour".
static var _cache := {}


## A picture of one item. `base` is the player's ball colour, used for
## hat and style icons so they show what you'd actually look like.
static func make(slot: String, item: Dictionary, base: Color, size := 112) -> Control:
	match slot:
		"trail":
			var t := TrailIcon.new()
			t.kind = item.id
			t.color = base
			t.custom_minimum_size = Vector2(size, size)
			return t
		"coins":
			var c := CoinIcon.new()
			c.custom_minimum_size = Vector2(size, size)
			return c
		"trophy":
			return _viewport("trophy", size, func(world: Node3D): world.add_child(trophy_model(Color.WHITE, "")),
					Vector3(0, 0.95, 2.6), Vector3(0, 0.75, 0))
	var look := {"hat": Cosmetics.HATS[0], "eyes": Cosmetics.EYES[0], "color": {"color": base},
			"style": Cosmetics.STYLES[0], "trail": {"id": "none"}}
	match slot:
		"hat": look.hat = item
		"eyes": look.eyes = item
		"color": look.color = item
		"style": look.style = item
	var hatted: bool = slot == "hat" and item.id != "none"
	var key := "%s:%s:%s" % [slot, item.id, base.to_html()]
	return _viewport(key, size, func(world: Node3D):
		var m: Marble = MARBLE_SCENE.instantiate()
		m.freeze = true
		m.preview = true   # faces the camera
		world.add_child(m)
		m.look = look
		m.get_node("Mesh").rotation = Vector3(0.4, 0.6, 0.0),
		Vector3(0, 0.42 if hatted else 0.05, 1.75 if hatted else 1.0), Vector3(0, 0.2 if hatted else 0.0, 0))


static func _viewport(key: String, size: int, fill: Callable, cam_pos: Vector3, look_at: Vector3) -> Control:
	key += "@%d" % size
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _cache.has(key):
		holder.add_child(_picture(_cache[key]))
		return holder
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(size, size)
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	_studio(world)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.position = cam_pos
	cam.look_at_from_position(cam_pos, look_at)
	fill.call(world)
	_keep_picture.call_deferred(holder, box, vp, key)
	return holder


## Once the little scene has been drawn, keep the picture and throw the
## 3D scene away.
static func _keep_picture(holder: Control, box: SubViewportContainer, vp: SubViewport, key: String) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return
	if DisplayServer.get_name() == "headless":
		return  # nothing is ever drawn in headless runs; keep the viewport
	for i in 3:
		await RenderingServer.frame_post_draw
		if not is_instance_valid(holder):
			return
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	holder.add_child(_picture(tex))
	box.queue_free()


static func _picture(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Soft light for an icon or the closet's big preview.
static func _studio(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 1.0)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.2
	world.add_child(sun)


## The Golden Marble Trophy: a shiny gold marble on a little stepped
## plinth. `plaque` (a player's colour and name) is optional.
static func trophy_model(plaque_color: Color, name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Trophy"
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.95, 0.93, 0.88)
	stone.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.25)
	gold.metallic = 0.9
	gold.roughness = 0.2
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.35
	var steps := [[0.55, 0.12], [0.42, 0.28], [0.3, 0.12]]
	var y := 0.0
	for s in steps:
		var c := CylinderMesh.new()
		c.top_radius = s[0]
		c.bottom_radius = s[0] + 0.03
		c.height = s[1]
		c.radial_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = gold if s == steps[2] else stone
		mi.position.y = y + s[1] / 2.0
		root.add_child(mi)
		y += s[1]
	var cup := CylinderMesh.new()
	cup.top_radius = 0.34
	cup.bottom_radius = 0.12
	cup.height = 0.3
	cup.radial_segments = 8
	var cup_mi := MeshInstance3D.new()
	cup_mi.mesh = cup
	cup_mi.material_override = gold
	cup_mi.position.y = y + 0.15
	root.add_child(cup_mi)
	var ball := SphereMesh.new()
	ball.radius = 0.36
	ball.height = 0.72
	ball.radial_segments = 16
	ball.rings = 8
	var ball_mi := MeshInstance3D.new()
	ball_mi.name = "Ball"
	ball_mi.mesh = ball
	ball_mi.material_override = gold
	ball_mi.position.y = y + 0.62
	root.add_child(ball_mi)
	if name != "":
		var plate := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 0.18, 0.04)
		plate.mesh = b
		var pm := StandardMaterial3D.new()
		pm.albedo_color = plaque_color
		plate.material_override = pm
		plate.position = Vector3(0, 0.26, 0.43)
		root.add_child(plate)
		var l := Label3D.new()
		l.text = name
		l.font = preload("res://fonts/ChakraPetch-Bold.ttf")
		l.font_size = 40
		l.pixel_size = 0.004
		l.outline_size = 8
		l.outline_modulate = plaque_color.darkened(0.6)
		l.position = Vector3(0, 0.26, 0.46)
		root.add_child(l)
	return root


## A flat picture of a trail: a wavy ribbon, sparkles, bubbles and so on.
class TrailIcon extends Control:
	var kind := "none"
	var color := Color.WHITE

	func _draw() -> void:
		var s := size
		var c := s / 2.0
		var r := minf(s.x, s.y) * 0.17
		var ball := c + Vector2(s.x * 0.22, -s.y * 0.05)
		var tail_end := Vector2(s.x * 0.08, s.y * 0.62)
		match kind:
			"none":
				draw_arc(c, r * 1.8, 0, TAU, 24, Color(1, 1, 1, 0.35), 4.0)
				draw_line(c + Vector2(-r, r) * 1.27, c + Vector2(r, -r) * 1.27, Color(1, 1, 1, 0.35), 4.0)
				return
			"ribbon":
				var pts := PackedVector2Array()
				for i in 16:
					var t := i / 15.0
					var p := tail_end.lerp(ball, t)
					p.y += sin(t * 5.0) * s.y * 0.06 * (1.0 - t)
					pts.append(p)
				for i in pts.size() - 1:
					var w := lerpf(2.0, r * 1.4, i / 15.0)
					draw_line(pts[i], pts[i + 1], Color(color, lerpf(0.1, 0.9, i / 15.0)), w)
			"rainbow":
				var bands := [Color(1, 0.3, 0.3), Color(1, 0.65, 0.2), Color(1, 0.9, 0.3), Color(0.4, 0.85, 0.4), Color(0.35, 0.6, 1), Color(0.65, 0.4, 0.95)]
				for k in bands.size():
					var off := (k - 2.5) * r * 0.28
					var pts := PackedVector2Array()
					for i in 12:
						var t := i / 11.0
						var p := tail_end.lerp(ball, t)
						p.y += off + sin(t * 4.0) * s.y * 0.04
						pts.append(p)
					draw_polyline(pts, bands[k], r * 0.3)
			"sparkles":
				var rng := RandomNumberGenerator.new()
				rng.seed = 3
				for i in 9:
					var t := rng.randf()
					var p := tail_end.lerp(ball, t) + Vector2(0, rng.randf_range(-1, 1) * s.y * 0.12)
					_star(p, lerpf(3.0, 8.0, t), color.lightened(0.6))
			"bubbles":
				var rng := RandomNumberGenerator.new()
				rng.seed = 5
				for i in 7:
					var t := rng.randf()
					var p := tail_end.lerp(ball, t) + Vector2(0, rng.randf_range(-1.2, 0.4) * s.y * 0.14)
					draw_arc(p, lerpf(3.0, 9.0, rng.randf()), 0, TAU, 16, Color(0.8, 0.95, 1.0, 0.9), 2.0)
			"flame":
				for i in 10:
					var t := i / 9.0
					var p := tail_end.lerp(ball, t)
					var col := Color(1.0, 0.25, 0.1, 0.5).lerp(Color(1.0, 0.85, 0.3, 0.95), t)
					draw_circle(p + Vector2(0, -sin(t * 9.0) * 3.0), lerpf(2.0, r * 0.9, t), col)
		draw_circle(ball, r, color)
		draw_circle(ball + Vector2(-r, -r) * 0.35, r * 0.3, Color(1, 1, 1, 0.55))

	func _star(p: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			var a := i * TAU / 8.0
			pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.35))
		draw_colored_polygon(pts, col)


## A stack of gold coins.
class CoinIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.22
		for i in 3:
			var p := c + Vector2((i - 1) * r * 0.9, r * 0.5 - (1 - absi(i - 1)) * r * 0.6)
			draw_circle(p + Vector2(0, 3), r, Color(0.7, 0.45, 0.05))
			draw_circle(p, r, Color(1.0, 0.8, 0.25))
			draw_arc(p, r * 0.7, 0, TAU, 20, Color(0.85, 0.6, 0.1), 2.5)
