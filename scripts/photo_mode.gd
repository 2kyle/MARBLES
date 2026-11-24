class_name PhotoMode
extends Node
## PHOTO MODE: freeze the game and fly a free camera round to take a
## screenshot. Opened from the pause menu (main.gd), so the game is already
## paused: marbles, pins and pop words stay frozen mid-air.
##
## It borrows the camera that's showing (so the ink outlines and the retro
## filter stay on) and puts it back exactly where it was on the way out.
## The HUD and menus are hidden while it's open; only the small help panel
## shows, and that hides itself for the picture too.
##
##                 Keyboard               Controller
##   Move          W A S D                left stick
##   Up / down     E / Q                  RB / LB
##   Look          arrows, or drag mouse  right stick
##   Zoom          Z / X, mouse wheel     LT / RT
##   Tilt          C / V                  d-pad left / right
##   Faster        hold Shift             click the left stick
##   Take photo    Enter or P             A
##   Hide help     H                      Y
##   Reset view    Backspace              X
##   Leave         Esc                    B or Start
##
## Photos are saved as PNG files in the game's "screenshots" folder
## (user://screenshots). Press O after taking one to open that folder.

signal closed

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const BODY_FONT := preload("res://fonts/ChakraPetch-SemiBold.ttf")
const GOLD := Color(1.0, 0.82, 0.25)

## Metres a second, and how much faster with Shift / the left stick.
const MOVE_SPEED := 6.0
const FAST := 3.0
## Radians a second for keys and sticks; radians a pixel for the mouse.
const LOOK_SPEED := 1.8
const MOUSE_LOOK := 0.005
## Field of view range (smaller = more zoomed in).
const FOV_MIN := 15.0
const FOV_MAX := 100.0
const ZOOM_SPEED := 40.0
const TILT_SPEED := 0.9
const TILT_MAX := deg_to_rad(45.0)
## How far from where photo mode started the camera may fly, so nobody
## gets lost in the sky.
const MAX_RANGE := 60.0
const DEADZONE := 0.2

## Where photos go. Tests point this somewhere else.
var save_dir := "user://screenshots"
## The file the last photo went to ("" if none yet, or it couldn't save).
var last_photo := ""

var _open := false
var _cam: Camera3D
var _saved_xf: Transform3D
var _saved_fov := 70.0
var _saved_h := 0.0
var _saved_v := 0.0
## The layers (HUD, menus) we hid, to show again on the way out.
var _hidden_layers: Array = []
var _start := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _tilt := 0.0
var _fov := 70.0
var _age := 0.0
var _busy := false
var _ui: CanvasLayer
var _help: PanelContainer
var _keys_text: Label
var _pad_text: Label
var _tag: Label
var _note: Label
var _note_time := 0.0
var _flash: ColorRect
var _used_pad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_ui.visible = false


func is_open() -> bool:
	return _open


## Start flying from wherever the game's camera is now.
func open() -> bool:
	_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return false
	_open = true
	_age = 0.0
	_saved_xf = _cam.global_transform
	_saved_fov = _cam.fov
	_saved_h = _cam.h_offset
	_saved_v = _cam.v_offset
	_cam.h_offset = 0.0
	_cam.v_offset = 0.0
	_start = _cam.global_position
	_fov = _cam.fov
	# Read yaw and pitch from where the camera faces, so nothing jumps.
	var fwd := -_cam.global_transform.basis.z
	_yaw = atan2(-fwd.x, -fwd.z)
	_pitch = asin(clampf(fwd.y, -1.0, 1.0))
	_tilt = 0.0
	_apply()
	# Hide the HUD and menus (layer 1 and up); the retro filter (layer 0)
	# stays, since it's part of the look.
	_hidden_layers.clear()
	for layer in _all_layers(get_tree().root):
		if layer != _ui and layer.layer >= 1 and layer.visible:
			layer.visible = false
			_hidden_layers.append(layer)
	_ui.visible = true
	_help.visible = true
	_note_time = 0.0
	_refresh_help()
	return true


## Put the camera and the HUD back and tell main.gd (it reopens the pause menu).
func close() -> void:
	if not _open:
		return
	_open = false
	if is_instance_valid(_cam):
		_cam.global_transform = _saved_xf
		_cam.fov = _saved_fov
		_cam.h_offset = _saved_h
		_cam.v_offset = _saved_v
	for layer in _hidden_layers:
		if is_instance_valid(layer):
			layer.visible = true
	_hidden_layers.clear()
	_ui.visible = false
	closed.emit()


## Back to the view photo mode started with.
func reset_view() -> void:
	if not _open:
		return
	_cam.global_transform = _saved_xf
	_fov = _saved_fov
	var fwd := -_saved_xf.basis.z
	_yaw = atan2(-fwd.x, -fwd.z)
	_pitch = asin(clampf(fwd.y, -1.0, 1.0))
	_tilt = 0.0
	_apply()


## One step of flying. `move` is (right, up, forward) from -1 to 1,
## `look` is (turn right, look up) in radians, `zoom` > 0 zooms in and
## `tilt` > 0 leans the picture clockwise. Tests call this directly.
func fly(delta: float, move: Vector3, look: Vector2, zoom: float, tilt: float) -> void:
	if not _open:
		return
	_yaw -= look.x
	_pitch = clampf(_pitch + look.y, deg_to_rad(-89.0), deg_to_rad(89.0))
	_tilt = clampf(_tilt - tilt * TILT_SPEED * delta, -TILT_MAX, TILT_MAX)
	_fov = clampf(_fov - zoom * ZOOM_SPEED * delta, FOV_MIN, FOV_MAX)
	# Move along where the camera faces (flat), plus straight up and down,
	# so W always goes "into the picture" even when looking down.
	var flat_fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var flat_right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var step := (flat_right * move.x + Vector3.UP * move.y + flat_fwd * move.z) * MOVE_SPEED * delta
	var pos := _cam.global_position + step
	var off := pos - _start
	if off.length() > MAX_RANGE:
		pos = _start + off.limit_length(MAX_RANGE)
	_cam.global_position = pos
	_apply()


## Save what's on screen (without the help panel) as a PNG.
## Returns the file it saved to, or "" if it couldn't.
func take_photo() -> String:
	if not _open or _busy:
		return ""
	_busy = true
	_ui.visible = false
	# Wait for a frame drawn without the help panel.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ""
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex else null
	if img and not img.is_empty():
		DirAccess.make_dir_recursive_absolute(save_dir)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
		path = "%s/photo_%s.png" % [save_dir, stamp]
		# Two photos in the same second get a number on the end.
		var n := 2
		while FileAccess.file_exists(path):
			path = "%s/photo_%s_%d.png" % [save_dir, stamp, n]
			n += 1
		if img.save_png(path) != OK:
			path = ""
	_busy = false
	if not _open:
		return path
	_ui.visible = true
	last_photo = path
	if path != "":
		_flash.modulate.a = 1.0
		_say("PHOTO SAVED!" + ("" if _used_pad else "   (O opens the folder)"))
	else:
		_say("Couldn't save the photo")
	return path


func _apply() -> void:
	var b := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.FORWARD, _tilt)
	_cam.global_basis = b.orthonormalized()
	_cam.fov = _fov


func _process(delta: float) -> void:
	_note_time -= delta
	_note.modulate.a = clampf(_note_time, 0.0, 1.0)
	_flash.modulate.a = maxf(_flash.modulate.a - delta * 4.0, 0.0)
	if not _open:
		return
	if not is_instance_valid(_cam):
		close()
		return
	_age += delta
	var move := Vector3.ZERO
	var look := Vector2.ZERO
	var zoom := 0.0
	var tilt := 0.0
	var fast := Input.is_key_pressed(KEY_SHIFT)
	# Keyboard.
	move.x += _key(KEY_D) - _key(KEY_A)
	move.z += _key(KEY_W) - _key(KEY_S)
	move.y += _key(KEY_E) - _key(KEY_Q)
	look.x += (_key(KEY_RIGHT) - _key(KEY_LEFT)) * LOOK_SPEED * delta
	look.y += (_key(KEY_UP) - _key(KEY_DOWN)) * LOOK_SPEED * delta
	zoom += _key(KEY_Z) - _key(KEY_X)
	tilt += _key(KEY_V) - _key(KEY_C)
	# Every controller plugged in.
	for pad in Input.get_connected_joypads():
		move.x += _axis(pad, JOY_AXIS_LEFT_X)
		move.z -= _axis(pad, JOY_AXIS_LEFT_Y)
		move.y += _btn(pad, JOY_BUTTON_RIGHT_SHOULDER) - _btn(pad, JOY_BUTTON_LEFT_SHOULDER)
		look.x += _axis(pad, JOY_AXIS_RIGHT_X) * LOOK_SPEED * delta
		look.y -= _axis(pad, JOY_AXIS_RIGHT_Y) * LOOK_SPEED * delta
		zoom += _axis(pad, JOY_AXIS_TRIGGER_RIGHT) - _axis(pad, JOY_AXIS_TRIGGER_LEFT)
		tilt += _btn(pad, JOY_BUTTON_DPAD_RIGHT) - _btn(pad, JOY_BUTTON_DPAD_LEFT)
		fast = fast or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_STICK)
	move = move.limit_length(1.0) * (FAST if fast else 1.0)
	fly(delta, move, look, clampf(zoom, -1.0, 1.0), clampf(tilt, -1.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_set_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_pad(false)
	if event is InputEventMouseMotion and event.button_mask != 0:
		fly(0.0, Vector3.ZERO, event.relative * Vector2(MOUSE_LOOK, -MOUSE_LOOK), 0.0, 0.0)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			fly(0.05, Vector3.ZERO, Vector2.ZERO, 1.0, 0.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			fly(0.05, Vector3.ZERO, Vector2.ZERO, -1.0, 0.0)
		return
	if not event.is_pressed() or event.is_echo() or _age < 0.25 or _busy:
		return
	if _is(event, [KEY_ESCAPE], [JOY_BUTTON_B, JOY_BUTTON_START]):
		close()
	elif _is(event, [KEY_ENTER, KEY_KP_ENTER, KEY_P], [JOY_BUTTON_A]):
		take_photo()
	elif _is(event, [KEY_H], [JOY_BUTTON_Y]):
		_help.visible = not _help.visible
	elif _is(event, [KEY_BACKSPACE], [JOY_BUTTON_X]):
		reset_view()
		_say("View reset")
	elif _is(event, [KEY_O], []) and last_photo != "":
		OS.shell_open(ProjectSettings.globalize_path(save_dir))


func _is(event: InputEvent, keys: Array, buttons: Array) -> bool:
	if event is InputEventKey:
		return event.physical_keycode in keys or event.keycode in keys
	if event is InputEventJoypadButton:
		return event.button_index in buttons
	return false


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _btn(pad: int, b: JoyButton) -> float:
	return 1.0 if Input.is_joy_button_pressed(pad, b) else 0.0


func _axis(pad: int, a: JoyAxis) -> float:
	var v := Input.get_joy_axis(pad, a)
	return 0.0 if absf(v) < DEADZONE else v


func _all_layers(node: Node) -> Array:
	var out := []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasLayer:
			out.append(n)
		stack.append_array(n.get_children())
	return out


func _say(text: String) -> void:
	_note.text = text
	_note_time = 2.5


func _set_pad(on: bool) -> void:
	if on != _used_pad:
		_used_pad = on
		_refresh_help()


func _refresh_help() -> void:
	_keys_text.visible = not _used_pad
	_pad_text.visible = _used_pad


# ------------------------------------------------------------ Screen bits

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.85)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_flash)

	_tag = Label.new()
	_tag.text = "PHOTO MODE"
	_tag.add_theme_font_override("font", TITLE_FONT)
	_tag.add_theme_font_size_override("font_size", 34)
	_tag.add_theme_color_override("font_color", GOLD)
	_tag.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	_tag.add_theme_constant_override("outline_size", 10)
	_tag.position = Vector2(32, 24)
	_ui.add_child(_tag)

	_help = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.16, 0.78)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_help.add_theme_stylebox_override("panel", style)
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_left = 32
	_help.offset_bottom = -28
	_ui.add_child(_help)
	var box := VBoxContainer.new()
	_help.add_child(box)
	_keys_text = _help_label(box, "\n".join([
		"MOVE  W A S D        UP / DOWN  E / Q",
		"LOOK  ARROWS or drag the mouse",
		"ZOOM  Z / X or wheel     TILT  C / V",
		"FASTER  hold SHIFT     RESET  BACKSPACE",
		"PHOTO  ENTER or P     HIDE HELP  H     LEAVE  ESC",
	]))
	_pad_text = _help_label(box, "\n".join([
		"MOVE  L-STICK        UP / DOWN  RB / LB",
		"LOOK  R-STICK        ZOOM  RT / LT",
		"TILT  D-PAD LEFT / RIGHT     FASTER  click L-STICK",
		"PHOTO  A     HIDE HELP  Y     RESET  X     LEAVE  B",
	]))

	_note = Label.new()
	_note.add_theme_font_override("font", TITLE_FONT)
	_note.add_theme_font_size_override("font_size", 28)
	_note.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	_note.add_theme_constant_override("outline_size", 10)
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_note.offset_top = 28
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.modulate.a = 0.0
	_ui.add_child(_note)


func _help_label(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", BODY_FONT)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("line_spacing", 2)
	parent.add_child(l)
	return l
