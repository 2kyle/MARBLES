class_name RetroFilter
extends CanvasLayer
## The screen filter that gives the game its retro bowling alley look
## (shaders/retro_screen.gdshader). It sits over the 3D world but under
## the HUD, menus and closet, so text stays crisp.
##
## Three looks, picked in Settings > RETRO LOOK:
##   OFF     the plain picture
##   LOUNGE  warm film colours, dark corners and a little grain (default)
##   ARCADE  LOUNGE plus faint CRT scanlines and colour fringing

enum Look { OFF, LOUNGE, ARCADE }
const NAMES := ["OFF", "LOUNGE", "ARCADE"]

const SHADER := preload("res://shaders/retro_screen.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	# The HUD is on layer 1 and menus higher, so this draws under them.
	layer = 0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func set_look(look: int) -> void:
	_rect.visible = look != Look.OFF
	var arcade := look == Look.ARCADE
	_mat.set_shader_parameter("scanlines", 1.0 if arcade else 0.0)
	_mat.set_shader_parameter("fringe", 1.6 if arcade else 0.0)
	_mat.set_shader_parameter("vignette", 0.5 if arcade else 0.38)
	_mat.set_shader_parameter("grain", 0.05 if arcade else 0.035)
