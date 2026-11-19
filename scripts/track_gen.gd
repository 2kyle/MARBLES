class_name TrackGen
extends RefCounted
## Makes random track layouts, and changes them when a player drops a track
## card.
##
## A layout is a list of segments, start to finish. Each segment is a
## Dictionary:
##   len:   length in metres (measured along the ground)
##   turn:  degrees the track turns over the segment (+ = left, - = right)
##   grade: how steep it is (0.25 = drops 0.25 m every metre)
##   gap:   (optional) true = no floor here, marbles have to hop or fly over
##   open:  (optional) true = no side walls here (a Wall Breaker TA)
## The first segment is where marbles start; the last one is the straight
## run into the funnel and pins, and is never changed.
##
## points() turns a layout into a line of points one metre apart, which the
## Track node turns into floor and walls.

## Height of the pin deck surface. The track is raised so it ends here.
const END_Y := -0.02
## Sharpest corner allowed (radius in metres) so walls never fold over.
const MIN_RADIUS := 5.0
## Two parts of the track must stay at least this far apart (top view).
const CLEARANCE := 7.5
## Shortest and longest random track.
const MIN_LENGTH := 60.0
const MAX_LENGTH := 85.0

const START := {"len": 6.0, "turn": 0.0, "grade": 0.24}
const FINISH := {"len": 10.0, "turn": 0.0, "grade": 0.3}


## A random layout that doesn't run into itself.
static func random_layout(rng: RandomNumberGenerator) -> Array:
	for attempt in 300:
		var layout := [START.duplicate()]
		var total: float = START.len + FINISH.len
		var drops := 0
		var gaps := 0
		var target := rng.randf_range(MIN_LENGTH, MAX_LENGTH)
		var last_turn_sign := 1.0 if rng.randf() < 0.5 else -1.0
		while total < target:
			var seg: Array = _random_segment(rng, last_turn_sign, drops)
			# At most one gap per track: missing it puts you out.
			var has_gap := false
			for s in seg:
				has_gap = has_gap or s.get("gap", false)
			if has_gap:
				gaps += 1
				if gaps > 1:
					continue
			for s in seg:
				layout.append(s)
				total += s.len
				if s.turn != 0.0:
					last_turn_sign = signf(s.turn)
				if s.grade > 0.45:
					drops += 1
		if drops == 0:
			continue
		layout.append(FINISH.duplicate())
		if fits(layout):
			return layout
	# Couldn't find one (very unlikely): a gentle S that always fits.
	return [START.duplicate(),
		{"len": 14.0, "turn": 70.0, "grade": 0.22},
		{"len": 8.0, "turn": 0.0, "grade": 0.6},
		{"len": 14.0, "turn": -70.0, "grade": 0.22},
		{"len": 10.0, "turn": 0.0, "grade": 0.25},
		FINISH.duplicate()]


static func _random_segment(rng: RandomNumberGenerator, last_sign: float, drops: int) -> Array:
	var r := rng.randf()
	# Usually turn the other way from last time, so the track snakes.
	var sign := -last_sign if rng.randf() < 0.75 else last_sign
	if r < 0.35:
		return [bend(sign * rng.randf_range(50.0, 110.0), rng.randf_range(0.18, 0.26))]
	if r < 0.55:
		var a := rng.randf_range(40.0, 70.0)
		return [bend(sign * a, 0.22), bend(-sign * a, 0.22)]
	if r < 0.72 or drops == 0 and r < 0.8:
		return [{"len": 3.0, "turn": 0.0, "grade": 0.15}, drop()]
	if r < 0.82:
		return [hairpin(sign)]
	if r < 0.9:
		return [{"len": 4.0, "turn": 0.0, "grade": 0.3}, gap(), {"len": 4.0, "turn": 0.0, "grade": 0.25}]
	return [{"len": rng.randf_range(5.0, 10.0), "turn": 0.0, "grade": rng.randf_range(0.22, 0.32)}]


static func bend(turn_deg: float, grade := 0.2) -> Dictionary:
	var length := maxf(10.0, deg_to_rad(absf(turn_deg)) * (MIN_RADIUS + 2.0))
	return {"len": length, "turn": turn_deg, "grade": grade}


static func drop() -> Dictionary:
	return {"len": 7.0, "turn": 0.0, "grade": 0.6}


static func hairpin(sign: float) -> Dictionary:
	var turn := 165.0 * sign
	return {"len": deg_to_rad(165.0) * (MIN_RADIUS + 0.6), "turn": turn, "grade": 0.13}


## A short hole in the track. Fast marbles fly over; a hop makes it safe.
static func gap() -> Dictionary:
	return {"len": 2.2, "turn": 0.0, "grade": 0.4, "gap": true}


## Where the gaps are, as [start, end] metres from the start (measured
## along the ground, like points()).
static func gap_ranges(layout: Array) -> Array:
	var out := []
	var t := 0.0
	for s in layout:
		var n := float(maxi(1, roundi(s.len)))
		if s.get("gap", false):
			out.append([t, t + n])
		t += n
	return out


## Where the side walls are missing, as [start, end] metres from the start.
static func open_ranges(layout: Array) -> Array:
	var out := []
	var t := 0.0
	for s in layout:
		var n := float(maxi(1, roundi(s.len)))
		if s.get("open", false):
			if not out.is_empty() and absf(out[-1][1] - t) < 0.01:
				out[-1][1] = t + n  # join with the stretch just before
			else:
				out.append([t, t + n])
		t += n
	return out


## A copy of `layout` with the walls taken off from `from` for `length`
## metres. The track keeps exactly the same shape: segments are only split
## at whole metres and marked open. The start and finish keep their walls.
static func open_range(layout: Array, from: float, length: float) -> Array:
	var out := []
	for s in layout:
		out.append(s.duplicate())
	var first_ok: int = maxi(1, roundi(out[0].len))
	var last_ok := 0
	for i in out.size() - 1:
		last_ok += maxi(1, roundi(out[i].len))
	var a := clampi(roundi(from), first_ok, last_ok - 1)
	var b := clampi(roundi(from + length), a + 1, last_ok)
	out = _split_at(out, a)
	out = _split_at(out, b)
	var t := 0
	for s in out:
		var n := maxi(1, roundi(s.len))
		if t >= a and t + n <= b:
			s.open = true
		t += n
	return out


## Split the segment that whole-metre mark `at` falls inside, so a segment
## starts exactly there. Shape is unchanged.
static func _split_at(layout: Array, at: int) -> Array:
	var t := 0
	for i in layout.size():
		var s: Dictionary = layout[i]
		var n := maxi(1, roundi(s.len))
		if at > t and at < t + n:
			var k := at - t
			var first := s.duplicate()
			first.len = float(k)
			first.turn = s.turn * k / n
			var second := s.duplicate()
			second.len = float(n - k)
			second.turn = s.turn * (n - k) / n
			layout[i] = first
			layout.insert(i + 1, second)
			return layout
		t += n
	return layout


static func total_length(layout: Array) -> float:
	var t := 0.0
	for s in layout:
		t += s.len
	return t


## Points one metre apart along the layout, starting at `start_xz` (the
## top view position of the start) and ending at the deck height.
static func points(layout: Array, start_xz := Vector2.ZERO) -> PackedVector3Array:
	# Per-metre turn rate and grade, then smoothed so corners and drops ease
	# in and out instead of kinking.
	var turn := PackedFloat32Array()
	var grade := PackedFloat32Array()
	for s in layout:
		var n := maxi(1, roundi(s.len))
		for i in n:
			turn.append(deg_to_rad(s.turn) / n)
			grade.append(s.grade)
	var finish_n := roundi(layout[-1].len)
	turn = _smooth(turn, 3, finish_n)
	grade = _smooth(grade, 5, finish_n)

	var pts := PackedVector3Array()
	var yaw := 0.0
	var p := Vector3(start_xz.x, 0.0, start_xz.y)
	pts.append(p)
	for i in turn.size():
		yaw += turn[i] * 0.5
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
		yaw += turn[i] * 0.5
		p += dir
		p.y -= grade[i]
		pts.append(p)
	var lift := END_Y - p.y
	for i in pts.size():
		pts[i].y += lift
	return pts


## True if the layout never comes close to running into itself or into
## the pin deck at its end.
static func fits(layout: Array, start_xz := Vector2.ZERO) -> bool:
	var pts := points(layout, start_xz)
	var flat := []
	for q in pts:
		flat.append(Vector2(q.x, q.z))
	# The pin deck and pit stick out about 20 m past the end.
	var end: Vector2 = flat[-1]
	var dir: Vector2 = (flat[-1] - flat[-4]).normalized()
	var deck := []
	for k in range(2, 22, 2):
		deck.append(end + dir * k)
	var n := flat.size()
	for i in range(0, n, 2):
		for j in range(i + 14, n, 2):
			if flat[i].distance_to(flat[j]) < CLEARANCE:
				return false
		if i < n - 14:
			for d in deck:
				if flat[i].distance_to(d) < CLEARANCE + 1.5:
					return false
	return true


## Which segment `distance` metres from the start falls in, and how far into
## it. Returns [index, metres_in].
static func segment_at(layout: Array, distance: float) -> Array:
	var t := 0.0
	for i in layout.size():
		if distance < t + layout[i].len:
			return [i, distance - t]
		t += layout[i].len
	return [layout.size() - 1, layout[-1].len]


## A copy of `layout` with `seg` spliced in at `distance` metres. The start
## and the finish straight are never cut, so the splice may move a little
## to the nearest allowed spot.
static func insert(layout: Array, distance: float, seg: Dictionary) -> Array:
	var out := []
	for s in layout:
		out.append(s.duplicate())
	var first_ok: float = out[0].len
	var last_ok: float = total_length(out) - out[-1].len
	distance = clampf(distance, first_ok, last_ok)
	var at := segment_at(out, distance)
	var i: int = at[0]
	var into: float = at[1]
	if i >= out.size() - 1:
		i = out.size() - 2
		into = out[i].len
	var s: Dictionary = out[i]
	if into > 0.5 and into < s.len - 0.5:
		var f: float = into / s.len
		var a := s.duplicate()
		a.len = s.len * f
		a.turn = s.turn * f
		var b := s.duplicate()
		b.len = s.len * (1.0 - f)
		b.turn = s.turn * (1.0 - f)
		out[i] = a
		out.insert(i + 1, b)
		out.insert(i + 1, seg.duplicate())
	elif into <= 0.5:
		out.insert(i, seg.duplicate())
	else:
		out.insert(i + 1, seg.duplicate())
	return out


static func _smooth(values: PackedFloat32Array, half: int, keep_last: int) -> PackedFloat32Array:
	var out := values.duplicate()
	var n := values.size()
	for i in n - keep_last:
		var sum := 0.0
		var c := 0
		for k in range(i - half, i + half + 1):
			if k >= 0 and k < n - keep_last:
				sum += values[k]
				c += 1
		out[i] = sum / c
	return out
