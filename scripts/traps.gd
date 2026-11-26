class_name Traps
extends RefCounted
## TRAPPED! points: when a rival's marble touches your piece and falls off
## the track a moment later, you trapped it. You get a bonus point (and so
## a bonus coin) and "TRAPPED BY P2!" pops up in your colour.
##
## Like Scoring, this is plain rules with no nodes: main.gd says which
## piece each marble is touching, and asks who to credit when one falls.
## That keeps it easy to test on its own (tests/test_traps.gd).
##
## Rules:
##   - Only a piece someone placed counts (not starting pieces), and never
##     your own piece on your own marble.
##   - The last rival piece the marble touched gets the credit, if the
##     marble falls within WINDOW seconds of leaving it.

## Seconds after touching a piece that a fall still counts as a trap.
const WINDOW := 3.0

## Marble player id -> [piece owner, time of the last touch].
var _last_touch := {}
## Traps this frame: one entry per trapped marble, the trapper's id.
var frame_traps: Array = []


## A new frame: forget the touches.
func reset_frame() -> void:
	_last_touch.clear()
	frame_traps.clear()


## `marble`'s ball is touching a piece placed by `owner` at time `now`.
func touch(marble: int, owner: int, now: float) -> void:
	if owner < 0 or owner == marble:
		return
	_last_touch[marble] = [owner, now]


## `marble`'s ball just fell off at time `now`. Returns who trapped it
## (and counts the trap), or -1 if nobody did.
func fell(marble: int, now: float) -> int:
	if not _last_touch.has(marble):
		return -1
	var t: Array = _last_touch[marble]
	_last_touch.erase(marble)
	if now - float(t[1]) > WINDOW:
		return -1
	var by: int = t[0]
	frame_traps.append(by)
	return by
