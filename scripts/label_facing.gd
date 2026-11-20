class_name LabelFacing
extends Node
## Keeps every word in the 3D world readable: if the camera ends up behind a
## sign's words, they turn round so you never read them backwards.
##
## It watches every Label3D that is added to the game. Labels that already
## turn to face the camera (billboards), and ones with a separate copy for
## each side (double_sided off), are left alone.

var _labels: Array[Label3D] = []


func _ready() -> void:
	# Run after everything else each frame, so labels that other code turns
	# are checked once they've been turned.
	process_priority = 1000
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "Label3D", true, false):
		_on_node_added(n)


func _on_node_added(n: Node) -> void:
	if n is Label3D:
		_labels.append(n)


func _process(_delta: float) -> void:
	var i := _labels.size() - 1
	while i >= 0:
		var l := _labels[i]
		if not is_instance_valid(l):
			_labels.remove_at(i)
		elif l.is_visible_in_tree():
			face(l)
		i -= 1


## Turns one label round if its camera is looking at its back.
static func face(l: Label3D) -> void:
	if l.billboard != BaseMaterial3D.BILLBOARD_DISABLED or not l.double_sided:
		return
	var cam := l.get_viewport().get_camera_3d()
	if cam == null:
		return
	var t := l.global_transform
	if (cam.global_position - t.origin).dot(t.basis.z) < 0.0:
		# Half a turn round the label's own up direction keeps any tilt.
		l.global_transform = Transform3D(t.basis * Basis(Vector3.UP, PI), t.origin)
