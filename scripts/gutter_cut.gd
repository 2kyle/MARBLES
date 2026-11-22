extends Area3D
## A hole in the lane. A marble that rolls in is out for the frame, and the
## player who placed the hole gets credit for knocking it out.

var placed_by := -1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Marble:
		if not (body as Marble).out:
			(body as Marble).pop_word("GUTTER!", Color(0.7, 0.75, 0.85), true)
		(body as Marble).knock_out(placed_by)
