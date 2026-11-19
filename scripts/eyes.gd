class_name EyeRig
extends Node3D
## A marble's eyes. Built from a few simple low-poly shapes, sized for a
## ball of radius 1 whose middle is at (0, 0, 0) and facing -Z; the marble
## scales and turns this node to fit. The eyes blink now and then and
## squeeze shut (a wince) when the marble gets knocked about.
##
## To add a pair: add it to Cosmetics.EYES and a `match` branch in setup().

const INK := Color(0.08, 0.07, 0.1)
const WHITE := Color(0.98, 0.98, 1.0)
## How far every pair sits below the height it's drawn at in setup().
const EYE_DROP := 0.08

var kind := "classic"
## The marble's colour (for eyelids).
var color := Color.WHITE

var _eyes: Array = []        # the Squash node of each eye (scaled to blink/wince)
var _pupils: Array = []      # googly pupils that wobble
var _pupil_vel: Array = []
var _blink_wait := 2.0
var _blink_t := -1.0         # time into a blink, or < 0
var _wince := 0.0            # 1 = fully squeezed, eases back to 0
var _rng := RandomNumberGenerator.new()


func setup(p_kind: String, p_color: Color) -> void:
	kind = p_kind
	color = p_color
	for c in get_children():
		c.queue_free()
	_eyes.clear()
	_pupils.clear()
	_pupil_vel.clear()
	_rng.randomize()
	_blink_wait = _rng.randf_range(1.0, 4.0)
	var lid := color.darkened(0.25)
	match kind:
		"classic":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.28)
				_disc(e, 0.24, WHITE)
				_disc(e, 0.12, INK, Vector3(0, -0.02, -0.06))
				_disc(e, 0.04, WHITE, Vector3(0.04, 0.04, -0.09))
		"dots":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.32, 0.24)
				_disc(e, 0.11, INK)
				_disc(e, 0.035, WHITE, Vector3(0.03, 0.03, -0.04))
		"googly":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.38, 0.3)
				_disc(e, 0.3, WHITE)
				var pupil := _disc(e, 0.14, INK, Vector3(0, -0.08, -0.07))
				_pupils.append(pupil)
				_pupil_vel.append(Vector2.ZERO)
		"sleepy":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.24)
				_disc(e, 0.24, WHITE)
				_disc(e, 0.11, INK, Vector3(0, -0.08, -0.06))
				var cover := _disc(e, 0.26, lid, Vector3(0, 0.1, -0.1))
				cover.scale.y *= 0.6
		"happy":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.3)
				_bar(e, Vector3(0.2, 0.06, 0.06), INK, Vector3(-0.08, 0, -0.02), 0.6)
				_bar(e, Vector3(0.2, 0.06, 0.06), INK, Vector3(0.08, 0, -0.02), -0.6)
		"angry":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.26)
				_disc(e, 0.22, WHITE)
				_disc(e, 0.11, INK, Vector3(0, -0.04, -0.06))
				_bar(e, Vector3(0.34, 0.08, 0.08), INK, Vector3(0, 0.24, -0.08), side * -0.45)
		"cute":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.26)
				_disc(e, 0.25, INK)
				_disc(e, 0.08, WHITE, Vector3(0.08, 0.08, -0.06))
				_disc(e, 0.04, WHITE, Vector3(-0.07, -0.08, -0.06))
		"cyclops":
			var e := _eye(0.0, 0.0, 0.2)
			_disc(e, 0.4, WHITE)
			_disc(e, 0.2, Color(0.2, 0.55, 0.3), Vector3(0, -0.02, -0.08))
			_disc(e, 0.1, INK, Vector3(0, -0.02, -0.12))
			_disc(e, 0.05, WHITE, Vector3(0.06, 0.06, -0.15))
		"shades":
			var e := _eye(0.0, 0.0, 0.28)
			for side in [-1.0, 1.0]:
				var lens := _disc(e, 0.24, Color(0.05, 0.05, 0.08), Vector3(side * 0.34, 0, -0.04))
				lens.scale.y *= 0.75
				_disc(e, 0.05, Color(0.6, 0.65, 0.8), Vector3(side * 0.34 + 0.08, 0.06, -0.1))
			_bar(e, Vector3(0.3, 0.06, 0.06), Color(0.05, 0.05, 0.08), Vector3(0, 0.06, -0.02), 0.0)
		"robot":
			var e := _eye(0.0, 0.0, 0.26)
			_bar(e, Vector3(1.0, 0.3, 0.12), Color(0.15, 0.16, 0.2), Vector3.ZERO, 0.0)
			_bar(e, Vector3(0.84, 0.12, 0.08), Color(0.3, 0.95, 1.0), Vector3(0, 0, -0.06), 0.0, 3.0)
		"hearts":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.28)
				var pink := Color(0.95, 0.12, 0.3)
				_disc(e, 0.11, pink, Vector3(-0.08, 0.05, -0.02), 1.2)
				_disc(e, 0.11, pink, Vector3(0.08, 0.05, -0.02), 1.2)
				_bar(e, Vector3(0.2, 0.2, 0.08), pink, Vector3(0, -0.06, -0.02), PI / 4.0, 1.2)
		"stars":
			for side in [-1.0, 1.0]:
				var e := _eye(side, 0.36, 0.28)
				_disc(e, 0.24, INK)
				var star := MeshInstance3D.new()
				star.mesh = _star_mesh(0.18)
				star.material_override = _mat(Color(1.0, 0.85, 0.25), 2.0)
				(star.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
				star.position = Vector3(0, 0, -0.1)
				e.add_child(star)


## Call every frame. `velocity` makes googly pupils wobble.
func update(delta: float, velocity := Vector3.ZERO) -> void:
	# Blink now and then.
	_blink_wait -= delta
	if _blink_wait <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_wait = _rng.randf_range(2.0, 5.0)
		if _rng.randf() < 0.2:
			_blink_wait = 0.25  # a quick double blink
	var open := 1.0
	if _blink_t >= 0.0:
		_blink_t += delta
		open = absf(_blink_t - 0.07) / 0.07
		if _blink_t >= 0.14:
			_blink_t = -1.0
			open = 1.0
	_wince = maxf(_wince - delta * 2.2, 0.0)
	var w := smoothstep(0.0, 1.0, _wince)
	var keep_shape := kind in ["robot", "shades"]
	for i in _eyes.size():
		var e: Node3D = _eyes[i]
		var y := minf(open, 1.0) * (1.0 - w * 0.85)
		if keep_shape:
			y = 1.0 - w * 0.5
		e.scale = Vector3(1.0 + w * 0.15, maxf(y, 0.08), 1.0)
		# Squeezed eyes tilt into a > < shape.
		e.rotation.z = -signf(e.position.x) * w * 0.35 if not keep_shape else 0.0
	for i in _pupils.size():
		var pupil: Node3D = _pupils[i]
		var v: Vector2 = _pupil_vel[i]
		var pos := Vector2(pupil.position.x, pupil.position.y)
		var rest := Vector2(0, -0.1)
		v += (rest - pos) * 60.0 * delta - Vector2(velocity.x, velocity.y) * 0.4 * delta
		v *= 0.9
		pos += v * delta
		if pos.length() > 0.14:
			pos = pos.normalized() * 0.14
		_pupil_vel[i] = v
		pupil.position = Vector3(pos.x, pos.y, pupil.position.z)


func blink() -> void:
	_blink_t = 0.0


## Squeeze the eyes shut for a moment. `strength` is the impact speed.
func wince(strength: float) -> void:
	if strength < 2.0:
		return
	_wince = clampf(_wince + strength / 5.0, 0.0, 1.0)


# ---------------------------------------------------------------- shapes

## One eye, sitting on the front of the ball. `side` -1 left, +1 right.
func _eye(side: float, across: float, up: float) -> Node3D:
	# A little below where the shapes were drawn, so hat brims and bands
	# never cover them.
	var out := Vector3(side * across, up - EYE_DROP, -1.0).normalized()
	var holder := Node3D.new()
	holder.basis = Basis.looking_at(out, Vector3.UP)
	holder.position = out * 0.98
	add_child(holder)
	var squash := Node3D.new()
	holder.add_child(squash)
	# Remember which side it's on (for the wince tilt) in its x position.
	squash.position.x = side * 0.0001
	_eyes.append(squash)
	return squash


func _disc(parent: Node3D, r: float, c: Color, at := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 4
	mi.mesh = m
	mi.material_override = _mat(c, glow)
	mi.position = at
	mi.scale = Vector3(1, 1, 0.35)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _bar(parent: Node3D, size: Vector3, c: Color, at: Vector3, roll: float, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c, glow)
	mi.position = at
	mi.rotation.z = roll
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## A flat five-pointed star facing -Z.
static func _star_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for i in 10:
		var a := PI / 2.0 + i * TAU / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(Vector3(cos(a) * rr, sin(a) * rr, 0))
	for i in 10:
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[(i + 1) % 10])
		st.add_vertex(pts[i])
	return st.commit()
