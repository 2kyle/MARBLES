class_name GameSettings
extends RefCounted
## Player settings that stick between sessions (saved to
## user://settings.cfg on this computer): screen, sound, camera and the
## match options last picked on the Play screen.

const PATH := "user://settings.cfg"

## Screen and sound.
var fullscreen := false
var vsync := true
## 0..1 for the whole game's sound (for when sounds arrive).
var master_volume := 0.8
var show_fps := false
## Camera.
var camera_shake := 1.0
## Slow-motion replay from by the pins after a strike.
var strike_replay := true
## Match options from the Play screen.
## How many people play at this computer, and how many bots join them.
var player_count := 1
var bot_count := 1
## How good the bots are: 0 easy, 1 normal, 2 hard, 3 expert.
var bot_level := 1
var frames_per_match := 10
var marbles_collide := true
## True once the HOW TO PLAY guide has popped up before a first match, so
## it only pops up once (it's always on the title screen too).
var seen_how_to_play := false


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = cfg.get_value("screen", "fullscreen", fullscreen)
	vsync = cfg.get_value("screen", "vsync", vsync)
	show_fps = cfg.get_value("screen", "show_fps", show_fps)
	master_volume = cfg.get_value("sound", "master_volume", master_volume)
	camera_shake = cfg.get_value("camera", "shake", camera_shake)
	strike_replay = cfg.get_value("camera", "strike_replay", strike_replay)
	# "humans"/"bots" replaced the old "players" key, so older saves start
	# on the new default of one person and one bot.
	player_count = clampi(cfg.get_value("match", "humans", player_count), 1, 4)
	bot_count = clampi(cfg.get_value("match", "bots", bot_count), 0, 4 - player_count)
	bot_level = clampi(cfg.get_value("match", "bot_level", bot_level), 0, 3)
	frames_per_match = cfg.get_value("match", "frames", frames_per_match)
	marbles_collide = cfg.get_value("match", "bumping", marbles_collide)
	seen_how_to_play = cfg.get_value("help", "seen_how_to_play", seen_how_to_play)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "fullscreen", fullscreen)
	cfg.set_value("screen", "vsync", vsync)
	cfg.set_value("screen", "show_fps", show_fps)
	cfg.set_value("sound", "master_volume", master_volume)
	cfg.set_value("camera", "shake", camera_shake)
	cfg.set_value("camera", "strike_replay", strike_replay)
	cfg.set_value("match", "humans", player_count)
	cfg.set_value("match", "bots", bot_count)
	cfg.set_value("match", "bot_level", bot_level)
	cfg.set_value("match", "frames", frames_per_match)
	cfg.set_value("match", "bumping", marbles_collide)
	cfg.set_value("help", "seen_how_to_play", seen_how_to_play)
	cfg.save(PATH)


## Put the screen and sound settings into effect.
func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
