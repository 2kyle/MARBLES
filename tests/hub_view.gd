extends SceneTree
## Screenshot helper for the hub island from any camera spot (not part of
## the game). Takes one or more views; positions are in the hub's space:
##   godot --script res://tests/hub_view.gd -- <out dir> name:eyeX,Y,Z:lookX,Y,Z [name:eye:look ...]
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
	for i in range(1, a.size()):
		var parts := a[i].split(":")
		views.append([parts[0], _v(parts[1]), _v(parts[2])])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)

func _process(_d: float) -> bool:
	_t += 1
	if _t == 3:
		game.settings.player_count = 1
		game._enter_hub()
	if _t < 4:
		return false
	var hub: Hub = game.hub
	var v: Array = views[_view]
	game.camera.set_process(false)
	game.camera.set_physics_process(false)
	game.camera.global_position = hub.to_global(v[1])
	game.camera.look_at(hub.to_global(v[2]))
	# Park the marble just in front of the camera so it's in the shot.
	hub.marbles[0].global_position = hub.to_global(v[1].lerp(v[2], 0.25) * Vector3(1, 0, 1) + Vector3(0, 0.4, 0))
	hub.marbles[0].linear_velocity = Vector3.ZERO
	if _t == 50 + _view * 25:
		var path := "%s/%s.png" % [out_dir, v[0]]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
		_view += 1
		if _view >= views.size():
			return true
	return false
