extends SceneTree
## Screenshot of every pair of eyes on a marble, up close (not a test).
## Shows the finger holes the eyes sit in, and the thumb-hole mouth.
##   godot --script res://tests/shot_eyes.gd -- <out.png> [wince]
var _t := 0
var _out := "user://eyes.png"
var _wince := false
var _marbles: Array = []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
	_wince = a.has("wince")
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.12, 0.22)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.0, 4.4)
	cam.fov = 40
	world.add_child(cam)
	var colors := [Color(0.95, 0.3, 0.55), Color(1.0, 0.8, 0.15), Color(0.3, 0.6, 1.0), Color(0.6, 0.95, 0.3),
			Color(0.7, 0.45, 0.95), Color(1.0, 0.5, 0.2), Color(0.2, 0.2, 0.25)]
	var kinds := Cosmetics.EYES.map(func(e): return e.id)
	var cols := 7
	for i in kinds.size():
		var m: Marble = load("res://scenes/marble.tscn").instantiate()
		m.freeze = true
		m.face_camera = true
		world.add_child(m)
		var look := {
			"hat": Cosmetics.find("hat", "none"), "eyes": Cosmetics.find("eyes", kinds[i]),
			"color": {"color": colors[i % colors.size()]}, "style": Cosmetics.find("style", "gloss"),
			"trail": Cosmetics.find("trail", "none"),
		}
		m.look = look
		var row := i / cols
		var col := i % cols
		m.global_position = Vector3((col - (cols - 1) / 2.0) * 0.8, 0.45 - row * 0.9, 0)
		_marbles.append(m)


func _process(_d: float) -> bool:
	_t += 1
	if _wince and _t > 20:
		for m in _marbles:
			m.wince(5.0)
	if _t == 40:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved ", _out)
		return true
	return false
