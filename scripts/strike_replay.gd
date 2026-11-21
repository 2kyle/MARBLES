class_name StrikeReplay
extends RefCounted
## The slow-motion replay after a strike.
##
## While the marbles roll, this keeps a short recording of where every
## marble and pin is (a "video" of positions, not pictures). After a strike
## the game plays the important bit back: from just before the first pin is
## hit until just after the last one falls. It slows right down for the
## moment of impact, then puts everything back exactly where it ended up.
##
## Nothing is simulated during the replay: every body is frozen and simply
## moved to its recorded spot, so the replay always matches what happened.

## Snapshots per second (in between, positions are blended smoothly).
const RATE := 60.0
## Seconds of recording kept (older snapshots are thrown away).
const KEEP := 8.0
## Seconds shown before the first pin is hit, and after the last one falls.
const BEFORE := 0.9
const AFTER := 0.8
## Longest clip, in game seconds (so a slow chain reaction doesn't drag on).
const MAX_LENGTH := 3.0
## Playback speed: quicker on the way in, very slow for the crash.
const SPEED_IN := 0.7
const SPEED_HIT := 0.3

## True while the replay is playing.
var playing := false

var _bodies: Array = []   # every marble and pin, in a fixed order
var _frames: Array = []   # [{t, xf: Array of Transform3D}], oldest first
var _time := 0.0          # game seconds since the roll started
var _since_frame := 0.0
var _first_hit := -1.0    # when a marble first touched a pin
var _swept_at := -1.0     # when the last pin fell
var _stopped := false     # recording is over (we have the strike on tape)

var _clock := 0.0
var _clip_from := 0.0
var _clip_to := 0.0
var _ending: Array = []   # [body, transform, velocity, spin, frozen]


## Start a fresh recording for a new roll.
func start(bodies: Array) -> void:
	_bodies = bodies.duplicate()
	_frames.clear()
	_ending.clear()
	_time = 0.0
	_since_frame = 0.0
	_first_hit = -1.0
	_swept_at = -1.0
	_stopped = false
	playing = false


## Call every physics tick while the marbles roll. `pins` is the rack's pins
## (anything with `credited_to` and `fallen`).
func record(delta: float, pins: Array) -> void:
	if _stopped or playing or _bodies.is_empty():
		return
	_time += delta
	if _first_hit < 0.0:
		for p in pins:
			if p.credited_to != -1:
				_first_hit = _time
				break
	if _swept_at < 0.0 and not pins.is_empty() and pins.all(func(p): return p.fallen):
		_swept_at = _time
	var last := _swept_at >= 0.0 and _time >= _swept_at + AFTER
	_since_frame += delta
	if _since_frame >= 1.0 / RATE or _frames.is_empty() or last:
		_since_frame = 0.0
		_capture()
	if last:
		_stopped = true   # keep what we have; the rest of the roll isn't needed
	while _frames.size() > 2 and _frames[0].t < _time - KEEP:
		_frames.pop_front()


## True if there's a strike on tape to show.
func has_clip() -> bool:
	return _first_hit >= 0.0 and _swept_at >= 0.0 and _frames.size() >= 2


## Game seconds the clip covers (0 if there's none).
func clip_length() -> float:
	if not has_clip():
		return 0.0
	var span := _span()
	return span.y - span.x


## Real seconds the replay takes to play at its slow-motion speeds.
func play_time() -> float:
	if not has_clip():
		return 0.0
	var span := _span()
	var t := span.x
	var real := 0.0
	while t < span.y:
		var step := 1.0 / 120.0
		real += step
		t += step * _speed_at(t)
	return real


## Freeze everything and jump back to the start of the clip.
func begin() -> bool:
	if not has_clip():
		return false
	var span := _span()
	_clip_from = span.x
	_clip_to = span.y
	_ending.clear()
	for b in _bodies:
		if is_instance_valid(b):
			_ending.append([b, b.global_transform, b.linear_velocity, b.angular_velocity, b.freeze])
			b.freeze = true
	_clock = _clip_from
	playing = true
	_show(_clock)
	return true


## Move the replay on by `delta` real seconds. Returns false once it's over.
func update(delta: float) -> bool:
	if not playing:
		return false
	_clock += delta * _speed_at(_clock)
	if _clock >= _clip_to:
		finish()
		return false
	_show(_clock)
	return true


## Stop (finished or skipped) and put everything back how the roll ended.
func finish() -> void:
	if not playing:
		return
	playing = false
	for e in _ending:
		var b: RigidBody3D = e[0]
		if not is_instance_valid(b):
			continue
		b.global_transform = e[1]
		b.freeze = e[4]
		if not b.freeze:
			b.linear_velocity = e[2]
			b.angular_velocity = e[3]
	_ending.clear()


## How far through the clip we are, 0 to 1 (for the HUD).
func progress() -> float:
	if _clip_to <= _clip_from:
		return 1.0
	return clampf((_clock - _clip_from) / (_clip_to - _clip_from), 0.0, 1.0)


# ------------------------------------------------------------ Inside

func _span() -> Vector2:
	var first: float = _frames[0].t
	var last: float = _frames[-1].t
	var from := maxf(_first_hit - BEFORE, first)
	var to := minf(minf(_swept_at + AFTER, last), from + MAX_LENGTH)
	return Vector2(from, maxf(to, from))


## Slow down smoothly just before the first pin is hit.
func _speed_at(t: float) -> float:
	var k := clampf((_first_hit - 0.2 - t) / 0.5, 0.0, 1.0)
	return lerpf(SPEED_HIT, SPEED_IN, k)


func _capture() -> void:
	var xf := []
	for b in _bodies:
		xf.append(b.global_transform if is_instance_valid(b) else Transform3D.IDENTITY)
	_frames.append({"t": _time, "xf": xf})


## Put every body where it was at game time `t`, blending between the two
## nearest snapshots.
func _show(t: float) -> void:
	var i := 0
	while i < _frames.size() - 2 and _frames[i + 1].t <= t:
		i += 1
	var a: Dictionary = _frames[i]
	var b: Dictionary = _frames[i + 1]
	var w := 0.0
	if b.t > a.t:
		w = clampf((t - a.t) / (b.t - a.t), 0.0, 1.0)
	for k in _bodies.size():
		var body = _bodies[k]
		if not is_instance_valid(body):
			continue
		var xa: Transform3D = a.xf[k]
		var xb: Transform3D = b.xf[k]
		body.global_transform = xa.interpolate_with(xb, w)
