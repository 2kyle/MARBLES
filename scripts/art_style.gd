class_name ArtStyle
extends RefCounted
## One place for the game's look, so the match island and the practice
## island feel like the same world.
##
## The direction (a starting point to react to): "toy diorama in the sky".
## Soft, matte, low-poly shapes in a pastel palette, like painted wooden
## toys. Lighting is a plain sunny day: a blue sky, puffy white 3D clouds,
## light haze in the distance, and no heavy bloom or glare. Effects stay
## cheap: no screen-space ambient occlusion, no noise-heavy sky shader.

const SKY_TOP := Color(0.32, 0.56, 0.9)
const SKY_HORIZON := Color(0.78, 0.86, 0.96)
const HAZE := Color(0.8, 0.86, 0.95)
const CLOUD := Color(1.0, 1.0, 1.0)
const CLOUD_SHADE := Color(0.82, 0.86, 0.95)


## The sky and light for a scene. `below` is the colour under the horizon:
## water blue for the match lake, cloud white for the practice island.
static func environment(below: Color) -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = SKY_TOP
	sky_mat.sky_horizon_color = SKY_HORIZON
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = SKY_HORIZON
	sky_mat.ground_bottom_color = below
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_sky_contribution = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# Just enough glow for lanterns and neon marbles, no haze over everything.
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.5
	env.fog_enabled = true
	env.fog_light_color = HAZE
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.0
	return env


## One puffy cloud: a few flattened white balls. Opaque, so it's cheap.
static func cloud(rng: RandomNumberGenerator, size := 1.0) -> Node3D:
	var node := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CLOUD
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = CLOUD_SHADE * 0.25
	var puffs := rng.randi_range(3, 5)
	for k in puffs:
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(1.3, 2.4) * size
		s.height = s.radius * 1.5
		s.radial_segments = 10
		s.rings = 5
		puff.mesh = s
		puff.material_override = mat
		var middle := 1.0 - absf(k - (puffs - 1) / 2.0) / puffs
		puff.position = Vector3((k - (puffs - 1) / 2.0) * 1.7 * size, middle * 0.6 * size, rng.randf_range(-0.6, 0.6) * size)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(puff)
	return node
