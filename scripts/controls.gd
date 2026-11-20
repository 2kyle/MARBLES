class_name Controls
extends RefCounted
## Keyboard and controller controls for local play. Actions are created in
## code so all the bindings live in one readable place. To rebind, change
## them here.
##
## Controllers: controller 1 plays as P1, controller 2 as P2, and so on
## (in the order Godot sees them plugged in). A player can use their keys
## or their controller, whichever they touch last.

const PLAYER_KEYS := [
	# left, right, forward, back, rotate, confirm
	[KEY_A, KEY_D, KEY_W, KEY_S, KEY_Q, KEY_SPACE],                   # Player 1 (E works too)
	[KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_ENTER],    # Player 2
	[KEY_J, KEY_L, KEY_I, KEY_K, KEY_U, KEY_O],                       # Player 3
	[KEY_KP_4, KEY_KP_6, KEY_KP_8, KEY_KP_5, KEY_KP_7, KEY_KP_9],     # Player 4
]
const DIRECTIONS := ["left", "right", "forward", "back", "rotate", "confirm"]

## Each player's controller (the same device number as the player).
## Move is the left stick or the D-pad.
const PAD_BUTTONS := {
	"rotate": [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER],
	"confirm": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B],
}
const PAD_MOVE := {
	"left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
	"forward": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
	"back": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
}
## Game-wide buttons, on any controller.
const GAME_PAD := {
	"roll": [JOY_BUTTON_Y],
	"toggle_camera": [JOY_BUTTON_LEFT_SHOULDER],
	"scoreboard": [JOY_BUTTON_BACK],
	"quit": [JOY_BUTTON_START],
}
## How far the stick must move before it counts (the lean is still analog).
const STICK_DEADZONE := 0.2

## Which players last used their controller (for the on-screen hints).
static var using_pad: Array = [false, false, false, false]

const GAME_KEYS := {
	"roll": [KEY_SPACE],
	"restart_frame": [KEY_R],
	"toggle_collision": [KEY_C],
	"toggle_camera": [KEY_V],
	"scoreboard": [KEY_TAB],
	"quit": [KEY_ESCAPE],
	# Turn the camera on the practice island (the mouse and right stick
	# turn it too).
	"cam_left": [KEY_Z],
	"cam_right": [KEY_X],
}


static func setup() -> void:
	for p in PLAYER_KEYS.size():
		for d in DIRECTIONS.size():
			_add(action_name(p, DIRECTIONS[d]), [PLAYER_KEYS[p][d]])
		_add(action_name(p, "cancel"), [])
		# This player's controller.
		for dir in PAD_MOVE:
			var m: Array = PAD_MOVE[dir]
			var axis := InputEventJoypadMotion.new()
			axis.device = p
			axis.axis = m[0]
			axis.axis_value = m[1]
			InputMap.action_add_event(action_name(p, dir), axis)
			_add_button(action_name(p, dir), m[2], p)
		for what in PAD_BUTTONS:
			for b in PAD_BUTTONS[what]:
				_add_button(action_name(p, what), b, p)
	for action in GAME_KEYS:
		_add(action, GAME_KEYS[action])
	for action in GAME_PAD:
		for b in GAME_PAD[action]:
			_add_button(action, b, -1)
	_add_menu_pad()


## Menus: any controller's D-pad or left stick moves, A picks, B goes back.
static func _add_menu_pad() -> void:
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN],
			["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT],
			["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		_add_button(pair[0], pair[1], -1)
	for pair in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
			["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var ev := InputEventJoypadMotion.new()
		ev.device = -1
		ev.axis = pair[1]
		ev.axis_value = pair[2]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)


static func _add_button(action: String, button: int, device: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## Remember whether each player last touched their keys or their controller,
## so the hints on screen show the right buttons. main.gd calls this.
static func note_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.device >= 0 and event.device < using_pad.size():
			using_pad[event.device] = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		if event.device >= 0 and event.device < using_pad.size():
			using_pad[event.device] = true
	elif event is InputEventKey and event.pressed:
		for p in PLAYER_KEYS.size():
			for d in DIRECTIONS:
				if event.is_action(action_name(p, d)):
					using_pad[p] = false
					return


## True if anyone is playing on a controller (for the game-wide hints).
static func any_pad() -> bool:
	return using_pad.has(true)


## Readable key names for the on-screen help, e.g. "W A S D, Q rotate, E place".
static func describe(player: int) -> String:
	var k: Array = PLAYER_KEYS[player]
	var names := []
	for key in k:
		names.append(OS.get_keycode_string(key))
	if player == 0:
		return "W A S D move, Q rotate, Space place"
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
	InputMap.add_action(action, STICK_DEADZONE)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		if action == "p2_rotate":
			ev.location = KEY_LOCATION_RIGHT  # right Shift only
		InputMap.action_add_event(action, ev)
	if action == "p1_confirm":
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		InputMap.action_add_event(action, e)
	if action == "p2_confirm":
		var kp := InputEventKey.new()
		kp.physical_keycode = KEY_KP_ENTER
		InputMap.action_add_event(action, kp)
