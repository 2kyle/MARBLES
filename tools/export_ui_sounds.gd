extends SceneTree
## Saves the made-in-code placeholder UI sounds as .wav files, so you can
## listen to them, or open them in a sound editor as a starting point.
##   godot --headless --script res://tools/export_ui_sounds.gd -- <folder>
## (The folder defaults to user://ui_sounds.)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var folder := args[0] if args.size() > 0 else "user://ui_sounds"
	DirAccess.make_dir_recursive_absolute(folder)
	var sfx := UISfx.new()
	for sound in UISfx.NAMES:
		var wav := sfx._make(sound)
		var path := folder.path_join(sound + ".wav")
		wav.save_to_wav(path)
		print("saved ", ProjectSettings.globalize_path(path))
	sfx.free()
	quit()
