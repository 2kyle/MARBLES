extends Area3D
## Fires any marble that rolls over it in the direction the arrow points.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## Speed added to the marble, in metres per second.
@export var boost := 5.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Marble:
		var forward := -global_basis.z
		forward.y = 0.0
		(body as Marble).apply_central_impulse(forward.normalized() * boost * (body as Marble).mass)
		(body as Marble).pop_word("WHOOSH!", Color(1.0, 0.6, 0.2))
