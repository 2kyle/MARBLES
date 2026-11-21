@tool
extends Node3D
## A little model of a track card's shape, for the draft card pictures:
## a short bit of track with the new part (bend, drop or hairpin) in yellow.

@export_enum("bend", "drop", "hairpin", "gap", "open", "sbend", "narrow", "zigzag", "hill", "oil") var shape := "bend":
	set(v):
		shape = v
		if is_inside_tree():
			_build()

const SCALE := 0.16
const WIDTH := 5.0


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var seg: Dictionary
	match shape:
		"sbend":
			# Two bends drawn as one yellow stretch.
			var pair := TrackGen.s_bend(1.0)
			seg = pair[0].duplicate()
			seg.len = pair[0].len + pair[1].len
			seg.turn = 0.0
			seg["wiggle"] = pair
		"zigzag":
			var three := TrackGen.zigzag(1.0)
			seg = three[0].duplicate()
			seg.len = three[0].len + three[1].len + three[2].len
			seg.turn = 0.0
			seg["wiggle"] = three
		"hill":
			var two := TrackGen.hill()
			seg = two[0].duplicate()
			seg.len = two[0].len + two[1].len
			seg["wiggle"] = two
		"oil": seg = TrackGen.oil()
		"narrow": seg = TrackGen.narrow()
		"drop": seg = TrackGen.drop()
		"hairpin": seg = TrackGen.hairpin(1.0)
		"gap": seg = TrackGen.gap()
		"open": seg = {"len": 10.0, "turn": 60.0, "grade": 0.12, "open": true}
		_: seg = TrackGen.bend(75.0)
	var lead := {"len": 6.0, "turn": 0.0, "grade": 0.12}
	var layout := [lead, seg, lead.duplicate()]
	if seg.has("wiggle"):
		layout = [lead] + seg.wiggle + [lead.duplicate()]
	var pts := TrackGen.points(layout)
	# Centre it.
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var mid := (lo + hi) / 2.0
	var a := int(lead.len)
	var b := a + int(round(seg.len))
	_add_strip(pts, 0, a, mid, Color(0.72, 0.55, 0.36))
	if seg.get("open", false):
		_add_strip(pts, a, b, mid, Color(1.0, 0.35, 0.25), false)
	elif seg.get("oil", false):
		_add_strip(pts, a, b, mid, Color(0.25, 0.85, 0.95))
	elif seg.get("narrow", false):
		_add_strip(pts, a, b, mid, Color(1.0, 0.82, 0.2), false, Track.NARROW_WIDTH)
	elif not seg.get("gap", false):
		_add_strip(pts, a, b, mid, Color(1.0, 0.82, 0.2))
	_add_strip(pts, b, pts.size() - 1, mid, Color(0.72, 0.55, 0.36))


func _add_strip(pts: PackedVector3Array, from: int, to: int, mid: Vector3, color: Color, walls := true, width := WIDTH) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := []
	for i in range(from, to + 1):
		var p := (pts[i] - mid) * SCALE
		var ahead := pts[mini(i + 1, pts.size() - 1)]
		var behind := pts[maxi(i - 1, 0)]
		var fwd := (ahead - behind).normalized()
		var right := fwd.cross(Vector3.UP).normalized() * width * 0.5 * SCALE
		var up := Vector3.UP * (0.9 if walls else 0.05) * SCALE
		var row := [p - right + up, p - right, p + right, p + right + up]
		if not prev.is_empty():
			for k in 3:
				for v in [prev[k], row[k + 1], prev[k + 1], prev[k], row[k], row[k + 1]]:
					st.add_vertex(v)
		prev = row
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
