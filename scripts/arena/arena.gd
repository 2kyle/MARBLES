class_name Arena
extends Node3D
## The world around the match track: sky, light, the ground far below the
## track, and all the scenery. Each match picks one at random:
##
##   beach   - sunny lagoon, sandy islands, palms, a lighthouse, sailboats
##   city    - sunset streets, lit skyscrapers, traffic, neon billboards
##   caves   - an underground cavern of giant glowing gems and a mine
##   snow    - a frosty village with pine forests, cottages and snowfall
##   clouds  - a cloud kingdom of floating castles, rainbows and columns
##
## Each one is its own script in this folder (arena_city.gd and so on) that
## fills in the functions below. They're looks only: nothing out here
## touches the marbles, except that falling below the track counts as out.
## main.gd makes one with Arena.create(id) and calls build() each match.
##
## Tip: to see one theme every time while you work on it, set
## `force_theme` on the Main node (in main.tscn) to its id.

const THEMES := ["beach", "city", "caves", "snow", "clouds"]
## The ground (or water) is this high. Marbles below `out_of_bounds_y`
## (in main.gd, just above this) are out for the frame.
const GROUND_Y := -4.0
const TITLE_FONT := preload("res://fonts/ChakraPetch-Bold.ttf")

## This arena's id (see THEMES).
var id := "beach"
## Track and deck colours for this theme (the track reads them).
var track_floor := Color(0.62, 0.45, 0.28)
var track_wall := Color(0.5, 0.34, 0.22)
var track_support := Color(0.36, 0.27, 0.2)
## Lantern glow and the START / FINISH arch colours.
var lamp_color := Color(1.0, 0.72, 0.35)
var start_color := Color(0.15, 0.55, 0.95)
var finish_color := Color(0.85, 0.2, 0.18)
## True if the ground is water (foam rings round posts, splashes).
var watery := false

## Things near the track (a building, a tree), so they can be hidden if a
## Track Altering card swings the track into them. [node, xz, radius]
var _props: Array = []
## Things that move every frame: Callables taking (time, delta).
var _movers: Array = []
var _time := 0.0
var _env: Environment
## Top-view points along the track and deck, for keeping scenery clear.
var _path: Array = []
var _center := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
## Ground already used by scenery from _spot(): [xz, radius]. Keeps a
## cottage from being built inside a clump of pines, and so on.
var _taken: Array = []
## Rings round the middle that scenery from _spot() keeps off (a mine
## railway, a road): [radius, half width].
var _keep_off_rings: Array = []


static func create(theme: String) -> Arena:
	var a: Arena
	match theme:
		"city": a = CityArena.new()
		"caves": a = CavesArena.new()
		"snow": a = SnowArena.new()
		"clouds": a = CloudsArena.new()
		_: a = BeachArena.new()
	a.name = "Arena"
	return a


static func random_theme(rng: RandomNumberGenerator) -> String:
	return THEMES[rng.randi() % THEMES.size()]


# ------------------------------------------------------------ For main.gd

## Build the whole scene round the track. `seed` keeps it the same for
## everyone in an online game.
func build(track: Track, deck: Node3D, seed: int) -> void:
	for c in get_children():
		c.queue_free()
	_props.clear()
	_movers.clear()
	_taken.clear()
	_keep_off_rings.clear()
	_rng.seed = seed
	_sample_path(track, deck)
	_build_scene()


## The track changed shape (a Track Altering card): hide anything near
## the track that it would now poke through.
func refit(track: Track, deck: Node3D) -> void:
	_sample_path(track, deck)
	for p in _props:
		var node: Node3D = p[0]
		if is_instance_valid(node):
			node.visible = _clear_of_path(p[1], p[2])


## The sky and light (made once, then kept).
func environment() -> Environment:
	if _env == null:
		_env = make_environment()
	return _env


## The sky and light. Each arena overrides this.
func make_environment() -> Environment:
	return ArtStyle.environment(Color(0.35, 0.62, 0.72))


## A gradient sky with soft light, like ArtStyle's, in this theme's colours.
static func sky_env(top: Color, horizon: Color, below: Color, ambient := 0.75, fog := Color(), fog_density := 0.0015) -> Environment:
	var env := ArtStyle.environment(below)
	var sky: ProceduralSkyMaterial = env.sky.sky_material
	sky.sky_top_color = top
	sky.sky_horizon_color = horizon
	sky.ground_horizon_color = horizon
	env.ambient_light_energy = ambient
	env.fog_light_color = fog if fog != Color() else horizon
	env.fog_density = fog_density
	return env


## Point and colour the sun (the scene's DirectionalLight3D).
func light_sun(sun: DirectionalLight3D) -> void:
	plain_sun(sun)


## The plain afternoon sun (the practice island uses it too).
static func plain_sun(sun: DirectionalLight3D) -> void:
	sun.rotation = Vector3(-0.55, 0.9, 0)
	sun.light_color = Color(1, 0.86, 0.7)
	sun.light_energy = 0.95


## A burst where a marble falls off the track and hits the ground.
func fall_burst(parent: Node, at: Vector3, color: Color) -> void:
	_burst(parent, Vector3(at.x, GROUND_Y + 0.1, at.z), Color(0.85, 0.95, 1.0).lerp(color, 0.15), 40, 0.08, 3.0, 6.5)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for m in _movers:
		(m as Callable).call(_time, delta)


# ------------------------------------------------------------ For the themes

## Each theme builds its ground, background and scenery here.
func _build_scene() -> void:
	pass


## A big flat ground plane at GROUND_Y with a shader on it.
func _ground(shader: Shader, params := {}, size := 1600.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	var m := ShaderMaterial.new()
	m.shader = shader
	for k in params:
		m.set_shader_parameter(k, params[k])
	plane.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.position = Vector3(_center.x, GROUND_Y, _center.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Add a finished MeshBatch to the scene. If `xz` is given it's a prop near
## the track that gets hidden when the track swings into it.
func _put(batch: MeshBatch, at := Vector3.ZERO, yaw := 0.0, glow := 2.5, radius := -1.0, matte: Material = null) -> MeshInstance3D:
	var mi := batch.make(glow, true, matte)
	mi.position = at
	mi.rotation.y = yaw
	add_child(mi)
	if radius > 0.0:
		_props.append([mi, Vector2(at.x, at.z), radius])
	return mi


## Somewhere at least `clear` metres from the track (and the pin deck),
## between `near` and `far` metres from the middle. null if none found.
## `room` is how wide the thing going there is (its radius): when given, the
## spot also keeps clear of everything else placed with a room, so props
## don't grow into each other.
func _spot(near: float, far: float, clear: float, room := 0.0) -> Variant:
	for attempt in 30:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf_range(near * near, far * far))
		var p := _center + Vector2(cos(a), sin(a)) * r
		if _clear_of_path(p, clear) and _room_free(p, room):
			if room > 0.0:
				_taken.append([p, room])
			return p
	return null


func _room_free(p: Vector2, room: float) -> bool:
	if room <= 0.0:
		return true
	for t in _taken:
		if p.distance_to(t[0]) < room + t[1]:
			return false
	var from_middle := p.distance_to(_center)
	for ring in _keep_off_rings:
		if absf(from_middle - ring[0]) < ring[1] + room:
			return false
	return true


## A point on a ring round the middle (for far-off background things).
func _ring(r: float, a: float) -> Vector2:
	return _center + Vector2(cos(a), sin(a)) * r


func _clear_of_path(p: Vector2, clear: float) -> bool:
	for q in _path:
		if p.distance_squared_to(q) < clear * clear:
			return false
	return true


## How far the track reaches from the middle (for sizing the scenery).
func _reach() -> float:
	var far := 0.0
	for q in _path:
		far = maxf(far, (q as Vector2).distance_to(_center))
	return far


func _sample_path(track: Track, deck: Node3D) -> void:
	_path.clear()
	var inv := global_transform.affine_inverse()
	var len := track.length()
	var d := 0.0
	while d < len:
		var o := inv * track.world_frame_at(d).origin
		_path.append(Vector2(o.x, o.z))
		d += 2.5
	for k in range(-2, 26, 2):
		var o := inv * (deck.global_transform * Vector3(0, 0, -k))
		_path.append(Vector2(o.x, o.z))
		# The ball return runs along the deck's right side.
		var r := inv * (deck.global_transform * Vector3(5.0, 0, -k))
		_path.append(Vector2(r.x, r.z))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in _path:
		lo = lo.min(q)
		hi = hi.max(q)
	_center = (lo + hi) / 2.0


## A one-off burst of little balls (splashes, puffs, sparkles).
func _burst(parent: Node, at: Vector3, color: Color, amount: int, size: float, v_min: float, v_max: float,
		gravity := Vector3(0, -9.8, 0), glow := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 1.2
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## Slow drifting specks in a big box round the track (snow, dust, motes).
func _drift(color: Color, amount: int, size: float, fall: float, glow := 0.0, extent := 70.0, height := 40.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = height / maxf(fall, 0.3)
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-extent, -height, -extent), Vector3(extent * 2, height * 2, extent * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent, 1.0, extent)
	pm.direction = Vector3.DOWN
	pm.spread = 15.0
	pm.initial_velocity_min = fall * 0.7
	pm.initial_velocity_max = fall * 1.3
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _soft_dot()
	m.albedo_color = color
	if glow > 0.0:
		m.albedo_color = Color(color.r * glow, color.g * glow, color.b * glow, color.a)
	quad.material = m
	p.draw_pass_1 = quad
	p.position = Vector3(_center.x, GROUND_Y + height, _center.y)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


static var _dot: GradientTexture2D
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot


## A ring of drifting puffy clouds (see CloudLayer).
func _clouds(count: int, r_min: float, r_max: float, y_min: float, y_max: float, size_min := 3.0, size_max := 5.5) -> CloudLayer:
	var c := CloudLayer.new()
	c.count = count
	c.radius_min = r_min
	c.radius_max = r_max
	c.height_min = y_min
	c.height_max = y_max
	c.size_min = size_min
	c.size_max = size_max
	c.seed = _rng.randi()
	c.position = Vector3(_center.x, 0, _center.y)
	add_child(c)
	return c


## A real light (use a handful at most: they cost the most).
func _light(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.position = at
	add_child(l)
	return l


## Big floating words (billboard signs, neon).
func _sign(at: Vector3, text: String, size: int, color: Color, outline: Color, yaw := 0.0, glow := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = TITLE_FONT
	l.font_size = size
	l.pixel_size = 0.02
	l.outline_size = maxi(8, size / 6)
	l.modulate = Color(color.r * (1.0 + glow), color.g * (1.0 + glow), color.b * (1.0 + glow))
	l.outline_modulate = outline
	l.position = at
	l.rotation.y = yaw
	l.shaded = false
	add_child(l)
	return l


## A top-view point at a height.
static func v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
