class_name WildFrames
extends RefCounted
## WILD FRAMES: every third frame (3, 6, 9) bends one rule for everyone,
## announced with a big banner when the draft starts. Settings > WILD
## FRAMES turns them off.
##
## To add one: add an entry to LIST and a branch in apply(). Every rule is
## just a change to the marbles' own settings, so it's undone by itself
## when the next frame makes fresh marbles.

const LIST := [
	{"id": "low_gravity", "name": "LOW GRAVITY", "about": "Floaty marbles and moon-high hops", "color": Color(0.55, 0.75, 1.0)},
	{"id": "bouncy", "name": "SUPER BOUNCY", "about": "Everything bounces like rubber", "color": Color(1.0, 0.45, 0.75)},
	{"id": "turbo", "name": "TURBO", "about": "Faster marbles, stronger leaning", "color": Color(1.0, 0.55, 0.15)},
	{"id": "heavy", "name": "HEAVY BALLS", "about": "Triple weight: pins go flying", "color": Color(0.7, 0.6, 1.0)},
	{"id": "ice", "name": "ICE RINK", "about": "Slippery lane, hard to steer", "color": Color(0.6, 0.95, 1.0)},
	{"id": "big_hops", "name": "BIG HOPS", "about": "Hops go twice as high", "color": Color(0.55, 1.0, 0.5)},
]

## Every this many frames is wild (frame 3, 6, 9...).
const EVERY := 3


static func info(id: String) -> Dictionary:
	for w in LIST:
		if w.id == id:
			return w
	return {}


## Which rule frame `frame` bends, or "" for a normal frame. `seed` makes
## each match different but the same on every computer in an online game.
static func pick(frame: int, seed: int, enabled := true) -> String:
	if not enabled or frame < EVERY or frame % EVERY != 0:
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, frame])
	return LIST[rng.randi() % LIST.size()].id


## Bend a fresh marble's rules for this frame.
static func apply(id: String, m: Marble) -> void:
	match id:
		"low_gravity":
			m.gravity_scale = 0.55
			m.hop_speed *= 1.25
		"bouncy":
			var pm := (m.physics_material_override as PhysicsMaterial).duplicate() as PhysicsMaterial
			pm.bounce = 0.8
			m.physics_material_override = pm
		"turbo":
			m.max_speed *= 1.35
			m.lean_forward_force *= 1.6
			m.lean_side_force *= 1.3
		"heavy":
			m.mass *= 3.0
		"ice":
			var pm := (m.physics_material_override as PhysicsMaterial).duplicate() as PhysicsMaterial
			pm.friction = 0.02
			m.physics_material_override = pm
			m.lean_side_force *= 0.55
			m.spin_assist *= 0.3
		"big_hops":
			m.hop_speed *= 1.6
