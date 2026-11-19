class_name MarbleBot
extends RefCounted
## A computer player for one seat. Every frame main.gd calls think(), and
## the bot answers the same way a person's controller would: a `lean`
## (stick direction) and the buttons it pressed this frame. So the referee
## treats bots exactly like players, locally and online (bots always run on
## the host).
##
## Draft: wanders over to a free card and grabs it.
## Build: picks a spot down the track that fits, slides there and drops.
## Roll: keeps to the middle of the lane, leans forward and hops gaps.
## Practice island: potters about and hops now and then.

var seat := 0
## The stick, as main.gd reads it: x = right, y = back (forward is -1).
var lean := Vector2.ZERO
## Buttons pressed this frame ("confirm", "rotate", ...).
var presses: Array = []
## How sloppy the bot is with steering (0 = perfect).
var wobble := 0.25

var _rng := RandomNumberGenerator.new()
var _last_state := -1
var _wait := 0.0
var _target_slot := -1
var _target_pos := Vector2.ZERO
var _target_part := -1
var _hop_wait := 0.0
var _wander := Vector3.ZERO
var _wander_time := 0.0
var _noise_t := 0.0


func _init(p_seat: int) -> void:
	seat = p_seat
	_rng.seed = 1000 + p_seat * 77 + Time.get_ticks_usec()


## A random look for a bot, the same every time for a given seat, so each
## bot has its own personality.
static func look(seat: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + seat * 131
	var out := {}
	for slot in Cosmetics.SLOTS:
		var list := Cosmetics.items(slot)
		out[slot] = list[rng.randi() % list.size()]
	# Bots never go without eyes: that's half their charm.
	if out.eyes.id == "none":
		out.eyes = Cosmetics.EYES[0]
	return out


func think(game, delta: float) -> void:
	presses = []
	lean = Vector2.ZERO
	_noise_t += delta
	if game.state != _last_state:
		_last_state = game.state
		_wait = _rng.randf_range(0.5, 1.4)
		_target_slot = -1
		_target_part = -1
	_wait -= delta
	match game.state:
		game.State.DRAFT:
			_draft(game)
		game.State.BUILD:
			_build(game)
		game.State.COUNTDOWN, game.State.ROLLING:
			_roll(game, delta)
		game.State.HUB:
			_hub(game, delta)


func _draft(game) -> void:
	var db: DraftBuild = game.draft_build
	if db.picks.size() <= seat or db.picks[seat] != "" or _wait > 0.0:
		return
	if _target_slot == -1 or db.taken_by[_target_slot] != -1:
		var free := []
		for k in db.crate.size():
			if db.taken_by[k] == -1:
				free.append(k)
		if free.is_empty():
			return
		_target_slot = free[_rng.randi() % free.size()]
	var want := Vector2(_target_slot + 0.5, 0.5)
	var to: Vector2 = want - db.draft_pointer[seat]
	lean = (to * 2.5).limit_length(1.0)
	if db.hovered_slot(seat) == _target_slot and to.length() < 0.25:
		presses.append("confirm")
		_wait = 0.3


func _build(game) -> void:
	var db: DraftBuild = game.draft_build
	if db.has_placed.size() <= seat or db.has_placed[seat] or _wait > 0.0:
		return
	var builder: CourseBuilder = db.builder
	var id := db.current_id(seat)
	if _target_part != db.part[seat] or db.message[seat] == "Blocked":
		_target_part = db.part[seat]
		var from: Vector2 = db.cursor_pos[seat]
		var guess := Vector2(_rng.randf_range(-1.6, 1.6), from.y - _rng.randf_range(4.0, 22.0))
		if PieceCatalog.is_track(id):
			guess.x = 0.0
			if PieceCatalog.turns(id) and _rng.randf() < 0.5:
				presses.append("rotate")
		var spot = builder.nearest_free(id, builder.clamp_pos(guess), db.cursor_angle[seat])
		_target_pos = spot if spot != null else from
		db.message[seat] = ""
	var to: Vector2 = _target_pos - db.cursor_pos[seat]
	lean = (to * 1.5).limit_length(1.0)
	if to.length() < 0.12:
		lean = Vector2.ZERO
		presses.append("confirm")
		_wait = 0.4


func _roll(game, delta: float) -> void:
	if game.state != game.State.ROLLING or seat >= game.marbles.size():
		return
	var m: Marble = game.marbles[seat]
	if m.arrived or m.out:
		return
	var track: Track = game.track
	var d := track.distance_of(m.global_position)
	var lane := track.world_frame_at(d)
	var across := lane.basis.x.dot(m.global_position - lane.origin)
	var slide := m.linear_velocity.dot(lane.basis.x)
	var steer := -(across * 0.9 + slide * 0.35)
	steer += sin(_noise_t * 1.7 + seat) * wobble
	lean = Vector2(clampf(steer, -1.0, 1.0), -0.6)
	# Hop just before a gap.
	_hop_wait -= delta
	var speed := m.linear_velocity.length()
	if _hop_wait <= 0.0 and not track.in_gap(d) and track.in_gap(d + 0.9 + speed * 0.12):
		presses.append("confirm")
		_hop_wait = 1.0


func _hub(game, delta: float) -> void:
	if game.hub == null or seat >= game.hub.marbles.size():
		return
	var m: Marble = game.hub.marbles[seat]
	_wander_time -= delta
	if _wander_time <= 0.0:
		# Somewhere on the open lawn in front of the spawn.
		_wander = game.hub.to_global(Hub.SPAWN + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-2, 4)))
		_wander_time = _rng.randf_range(3.0, 6.0)
	var to := _wander - m.global_position
	to.y = 0.0
	if to.length() > 0.6:
		var local: Vector3 = m.lane_basis.inverse() * to.normalized()
		lean = Vector2(local.x, local.z) * 0.6
	if _rng.randf() < delta * 0.25:
		presses.append("confirm")
