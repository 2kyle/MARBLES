extends Node3D
## A big floor magnet. Marbles rolling near it get dragged toward its
## middle; fast ones whip round it and fly off at a new angle, slow ones
## get stuck circling until they push their way out.
##
## Built in code: a horseshoe magnet lying flat, a disc it sits on, rings
## that shrink toward the middle to show the pull, and the pull zone.

## Player who placed this piece (-1 = part of the starting lane).
var placed_by := -1
## Pull strength at the edge of the zone (metres per second, every second).
## It gets stronger closer in.
@export var pull := 9.0

const ZONE_R := 1.35

var _zone: Area3D
var _rings: Array = []
var _t := 0.0


func _init() -> void:
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var dm := CylinderMesh.new()
	dm.top_radius = ZONE_R
	dm.bottom_radius = ZONE_R
	dm.height = 0.02
	dm.radial_segments = 40
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.3, 0.32, 0.42)
	dm.material = disc_mat
	disc.mesh = dm
	disc.position.y = 0.01
	add_child(disc)

	# A horseshoe: half a torus plus two straight legs with silver tips.
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.92, 0.18, 0.2)
	var shoe := MeshInstance3D.new()
	shoe.name = "Shoe"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.38
	torus.material = red
	shoe.mesh = torus
	shoe.position = Vector3(0, 0.09, 0.08)
	shoe.scale = Vector3(1, 0.6, 1)
	add_child(shoe)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.85, 0.87, 0.9)
	silver.metallic = 0.8
	silver.roughness = 0.25
	for side in [-1.0, 1.0]:
		var tip := MeshInstance3D.new()
		tip.name = "Tip%d" % int(side + 1.0)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.11, 0.2)
		bm.material = silver
		tip.mesh = bm
		tip.position = Vector3(side * 0.29, 0.06, -0.2)
		add_child(tip)
	# Low and smooth, so marbles roll over it instead of getting caught.
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.42
	cyl.height = 0.08
	col.shape = cyl
	col.position.y = 0.04
	body.add_child(col)
	add_child(body)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.6, 0.85, 1.0, 0.6)
	for k in 3:
		var ring := MeshInstance3D.new()
		ring.name = "Ring%d" % k
		var tm := TorusMesh.new()
		tm.inner_radius = 0.96
		tm.outer_radius = 1.0
		tm.rings = 32
		tm.ring_segments = 4
		tm.material = ring_mat
		ring.mesh = tm
		ring.position.y = 0.04
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)

	_zone = Area3D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	_zone.monitorable = false
	var zs := CollisionShape3D.new()
	var zc := CylinderShape3D.new()
	zc.radius = ZONE_R
	zc.height = 1.2
	zs.shape = zc
	zs.position.y = 0.6
	_zone.add_child(zs)
	add_child(_zone)


func _process(delta: float) -> void:
	_t += delta
	for k in _rings.size():
		var f := fposmod(_t * 0.6 + k / 3.0, 1.0)
		var r: float = lerpf(ZONE_R, 0.35, f)
		(_rings[k] as Node3D).scale = Vector3(r, 1.0, r)


func _physics_process(_delta: float) -> void:
	if not _zone.monitoring:
		return
	var reach := ZONE_R * global_basis.get_scale().x
	for body in _zone.get_overlapping_bodies():
		if body is Marble:
			var m := body as Marble
			var to := global_position - m.global_position
			to.y = 0.0
			var d := to.length()
			if d < 0.05:
				continue
			# Twice as strong in the middle as at the edge.
			var k := 1.0 + (1.0 - clampf(d / reach, 0.0, 1.0))
			m.apply_central_force(to / d * pull * k * m.mass)
