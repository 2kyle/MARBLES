extends SceneTree
## Draws every achievement badge into steam/achievements/ as 256x256 PNGs,
## ready to upload on the Steamworks site: ID.png (unlocked) and
## ID_locked.png (the grey one Steam shows before you have it).
## Needs a screen to draw on, so run it without --headless:
##   godot --script res://tools/make_achievement_icons.gd

const SIZE := 256
const OUT := "res://steam/achievements/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_draw_all.call_deferred()


func _draw_all() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var made := 0
	for a in Achievements.LIST:
		for locked in [false, true]:
			var icon := AchievementIcon.make(a, locked, SIZE)
			icon.tile = true
			vp.add_child(icon)
			await process_frame
			await process_frame
			var img := vp.get_texture().get_image()
			img.save_png(OUT + a.id + ("_locked" if locked else "") + ".png")
			icon.free()
			made += 1
	print("Saved %d icons to %s" % [made, ProjectSettings.globalize_path(OUT)])
	quit()
