extends SceneTree
## Screenshot helper for a match world from any camera spot (not part of the
## game). World 0-4 is beach, city, caves, snow, clouds; seed picks the track:
##   godot --script res://tests/world_view.gd -- <out dir> <world> <seed> name:eyeX,Y,Z:lookX,Y,Z [...]
var game: Node
var _t := 0
var out_dir := "user://"
var views: Array = []
var _view := 0


func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	var a := OS.get_cmdline_user_args()
	out_dir = a[0]
	for i in range(3, a.size()):
		var parts := a[i].split(":")
		views.append([parts[0], _v(parts[1]), _v(parts[2])])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_meta("world", int(a[1]))
	game.set_meta("seed", int(a[2]))


func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		game.force_theme = Arena.THEMES[game.get_meta("world")]
		game._rng.seed = game.get_meta("seed")
		game._new_track()
		for c in game.find_children("*", "CanvasLayer", true, false):
			c.visible = false   # no title menu in the way
	if _t < 6:
		return false
	var v: Array = views[_view]
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.global_position = v[1]
	game.camera.look_at(v[2])
	if _t == 50 + _view * 25:
		var path := "%s/%s.png" % [out_dir, v[0]]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
		_view += 1
		if _view >= views.size():
			return true
	return false
