class_name CloudLayer
extends Node3D
## A ring of puffy clouds slowly drifting round a point. Used by the match
## island and the practice island so both skies match (see ArtStyle).

@export var count := 14
@export var radius_min := 60.0
@export var radius_max := 140.0
@export var height_min := 18.0
@export var height_max := 40.0
@export var size_min := 1.6
@export var size_max := 3.2
## Radians per second round the middle (very slow).
@export var speed := 0.01
@export var seed := 7

var _clouds: Array = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in count:
		var c := ArtStyle.cloud(rng, rng.randf_range(size_min, size_max))
		add_child(c)
		_clouds.append({"node": c, "angle": rng.randf() * TAU,
				"radius": rng.randf_range(radius_min, radius_max),
				"y": rng.randf_range(height_min, height_max),
				"speed": speed * rng.randf_range(0.6, 1.4)})
	_place()


func _process(delta: float) -> void:
	_time += delta
	_place()


func _place() -> void:
	for c in _clouds:
		var a: float = c.angle + _time * c.speed
		var node: Node3D = c.node
		node.position = Vector3(cos(a) * c.radius, c.y + sin(_time * 0.2 + c.angle) * 0.5, sin(a) * c.radius)
		node.rotation.y = -(a + PI / 2)
