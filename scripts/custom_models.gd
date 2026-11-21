class_name CustomModels
## Lets your own Blender models replace the built-in ones, with no code.
##
## Export a model from Blender as a .glb and save it as
##   res://assets/models/<id>/<id>.glb
## (for example res://assets/models/pin/pin.glb). Next time the game runs,
## anything that asks for that id uses your model. Delete or rename the file
## and the game goes back to the built-in look.
##
## The step-by-step guide is docs/BLENDER.md.

const FOLDER := "res://assets/models/"


## The path a model with this id is looked for at.
static func path_for(id: String) -> String:
	return FOLDER + id + "/" + id + ".glb"


## True if you've made a model for this id.
static func has(id: String) -> bool:
	return ResourceLoader.exists(path_for(id))


## A fresh copy of your model for this id, or null if there isn't one (or it
## couldn't be loaded, in which case a warning says why).
static func make(id: String) -> Node3D:
	if not has(id):
		return null
	var scene := load(path_for(id)) as PackedScene
	if scene == null:
		push_warning("Custom model %s couldn't be loaded, using the built-in one." % path_for(id))
		return null
	var node := scene.instantiate() as Node3D
	if node == null:
		push_warning("Custom model %s has no 3D root, using the built-in one." % path_for(id))
	return node
