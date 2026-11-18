class_name Controls
extends RefCounted
## Keyboard controls for local play. Actions are created in code so all the
## key bindings live in one readable place. To rebind a key, change it here.

const PLAYER_KEYS := [
	# left, right, forward, back, rotate, confirm
	[KEY_A, KEY_D, KEY_W, KEY_S, KEY_Q, KEY_E],                       # Player 1
	[KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_ENTER],    # Player 2
	[KEY_J, KEY_L, KEY_I, KEY_K, KEY_U, KEY_O],                       # Player 3
	[KEY_KP_4, KEY_KP_6, KEY_KP_8, KEY_KP_5, KEY_KP_7, KEY_KP_9],     # Player 4
]
const DIRECTIONS := ["left", "right", "forward", "back", "rotate", "confirm"]

const GAME_KEYS := {
	"roll": [KEY_SPACE],
	"restart_frame": [KEY_R],
	"toggle_collision": [KEY_C],
	"toggle_camera": [KEY_V],
	"quit": [KEY_ESCAPE],
}


static func setup() -> void:
	for p in PLAYER_KEYS.size():
		for d in DIRECTIONS.size():
			_add(action_name(p, DIRECTIONS[d]), [PLAYER_KEYS[p][d]])
	for action in GAME_KEYS:
		_add(action, GAME_KEYS[action])


## Readable key names for the on-screen help, e.g. "W A S D, Q rotate, E place".
static func describe(player: int) -> String:
	var k: Array = PLAYER_KEYS[player]
	var names := []
	for key in k:
		names.append(OS.get_keycode_string(key))
	if player == 1:
		return "arrows move, Right Shift rotate, Enter place"
	return "%s %s %s %s move, %s rotate, %s place" % [
			names[2], names[0], names[3], names[1], names[4], names[5]]


static func action_name(player: int, direction: String) -> String:
	return "p%d_%s" % [player + 1, direction]


## The lean a player is holding right now, as lane-space Vector2
## (x = right, y = back; so forward is y = -1).
static func read_lean(player: int) -> Vector2:
	return Input.get_vector(
		action_name(player, "left"), action_name(player, "right"),
		action_name(player, "forward"), action_name(player, "back"))


static func _add(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		if action == "p2_rotate":
			ev.location = KEY_LOCATION_RIGHT  # right Shift only
		InputMap.action_add_event(action, ev)
	if action == "p2_confirm":
		var kp := InputEventKey.new()
		kp.physical_keycode = KEY_KP_ENTER
		InputMap.action_add_event(action, kp)
