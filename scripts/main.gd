extends Node3D
## Runs the game: the title menu, then local matches.
## Looks are changed between games on the practice island (the closet and
## loot crates). A match starts on a short ready screen, then each frame goes:
##   Draft (pick a piece from the crate) -> Build (place it on the lane)
##   -> Countdown -> Roll -> Results
## Placed pieces stay on the lane for the rest of the match.
##
## This script (with DraftBuild) is the "referee": everything that decides
## an outcome happens here. Each seat is played by someone at this computer
## (keys or a controller), a bot (MarbleBot), or, online, a player on
## another computer. Input only reaches the game through seat_lean() and
## seat_pressed(), so the rules don't care which.
##
## Online (NetSession): the host runs this script as normal and sends
## snapshots and events; a client runs it in "mirror" mode, sending its
## input and showing what the host sends (see the Online section below).

## MENU is the title screen (the camera slowly circles the island).
## WAITING is the ready screen before a match (press Space / Y to start).
enum State { WAITING, DRAFT, BUILD, COUNTDOWN, ROLLING, RESULTS, MATCH_OVER, MENU, HUB }

const PLAYER_COLORS := [
	Color(0.95, 0.3, 0.55),  # pink
	Color(1.0, 0.8, 0.15),   # yellow
	Color(0.7, 0.45, 0.95),  # violet
	Color(0.6, 0.95, 0.3),   # lime
]
const PLAYER_NAMES := ["Player 1", "Player 2", "Player 3", "Player 4"]
## Where each marble starts across the lane, metres from the centre.
## The practice island is its own place, far away from the match island
## (which is hidden while you're there).
const HUB_SCENE := preload("res://scenes/hub.tscn")
const HUB_POSITION := Vector3(0, 60, 3000)
const SPAWN_X := [-1.5, 1.5, -0.5, 0.5]

## Marbles in the match (1 to 4). Each extra player uses the next key set.
@export_range(1, 4) var player_count := 2
## Make a new random track layout at the start of every match. Turn off
## to play on the hand-drawn curve in scenes/course.tscn (Track/Path).
@export var random_track := true
## Marbles bump into each other. Press C in game to flip it.
@export var marbles_collide := true
## Frames in a match.
@export var frames_per_match := 10
## Seconds to pick a piece from the crate.
@export var draft_time := 15.0
## Seconds to place it on the lane.
@export var build_time := 30.0
## How fast build cursors glide, metres per second.
@export var cursor_speed := 7.0
## How fast draft pointers move, in cards per second.
@export var pointer_speed := 2.6
## Degrees per rotate tap (hold to keep turning).
@export var rotate_step := 15.0
## Extra pieces in the crate beyond one per player.
@export var crate_extra := 2
## Longest a roll can last, in seconds.
@export var roll_time_limit := 45.0
## After the last marble reaches the pins (or falls out), wait this long
## for pins to finish falling before scoring.
@export var settle_time := 4.0
## A marble below this height has fallen off the course (into the water).
@export var out_of_bounds_y := -3.7
## Seconds the camera watches the pins after a marble reaches them.
@export var pin_cam_time := 2.5
## A marble that barely moves for this many seconds (wedged in a corner)
## gets a little hop down the lane.
@export var stuck_time := 2.0
## A marble that hasn't got any further down the track for this many
## seconds is lifted out and put back a little further on.
@export var rescue_time := 6.0
## Who the rolling camera keeps on screen. ALL_MARBLES frames every marble
## still rolling (couch play). ONE_MARBLE follows only `camera_player`'s
## marble, for online play where each screen shows its own player.
enum CameraFollow { ALL_MARBLES, ONE_MARBLE }
@export var camera_follow := CameraFollow.ALL_MARBLES
@export var camera_player := 0
## How hard big crashes and landings shake the camera (0 = never).
@export_range(0.0, 2.0) var camera_shake := 1.0


@export var marble_scene: PackedScene = preload("res://scenes/marble.tscn")

var state := State.MENU

## Who plays each seat.
enum Seat { LOCAL, BOT, REMOTE }
var seat_kinds: Array = [Seat.LOCAL, Seat.BOT, Seat.LOCAL, Seat.LOCAL]
## For seats played at this computer: which key set / controller.
var seat_keys: Array = [0, 1, 2, 3]
## Each seat's look (hat, eyes, colour, style, trail entries).
var seat_looks: Array = []
## Bot brains, one per bot seat (null for people).
var bots: Array = [null, null, null, null]
## Online play (host or join). Offline unless the Online menu is used.
var net: NetSession
## Screen, sound and match options (saved between sessions).
var settings := GameSettings.new()
var menu: MainMenu
## The practice island (built the first time someone opens it).
var hub: Hub
## The full-screen closet and loot crate screens on the practice island.
## One player uses each at a time.
var closet: Closet
var crate_screen: CrateScreen
## Players who have the Marble Derby betting panel open.
var derby_open: Array = [false, false, false, false]
var _match_env: Environment
var _hub_env: Environment
var _menu_time := 0.0
## Coins, owned looks and equipped looks for each seat (saved to disk).
var profiles := Profiles.new()
## Each player's marble colour (from the closet).
var player_colors: Array = PLAYER_COLORS.duplicate()
## Coins each player earned in the last frame / match, for the scoreboard.
var coins_earned: Array = [0, 0, 0, 0]
var match_coins: Array = [0, 0, 0, 0]
var frame := 1
var totals: Array = []
var marbles: Array[Marble] = []
var arrival_order: Array = []
var sweep_player := -1
var last_result: Dictionary = {}
## Points each player scored in each finished frame: frame_points[frame][player].
var frame_points: Array = []

var _countdown := 0.0
var _phase_left := 0.0
var _roll_time := 0.0
var _settle_left := 0.0
var _settling := false
var _overhead_camera := false
var _last_arrival_time := -100.0
var _rng := RandomNumberGenerator.new()
var _repeat := {}  # held-key repeat timers for build cursors
## Buttons each seat pressed this frame (see _poll_seats).
var _pressed: Array = [[], [], [], []]
## A hop asked for since the last physics tick, per seat.
var _hop_latch: Array = [false, false, false, false]
## Online client: the newest snapshot from the host.
var _snap: Dictionary = {}

@onready var course: Node3D = $Course
@onready var rack: Rack = $Rack
@onready var camera: CameraRig = $Camera
@onready var hud: Hud = $Hud
@onready var arrival_line: Area3D = $Course/Deck/ArrivalLine
@onready var deck: Node3D = $Course/Deck
@onready var track: Track = $Course/Track
@onready var builder: CourseBuilder = $Course/Track/Placed
@onready var draft_build: DraftBuild = $DraftBuild


func _ready() -> void:
	Controls.setup()
	_rng.randomize()
	builder.track_reshaped.connect(_on_track_reshaped)
	rack.swept.connect(_on_rack_swept)
	arrival_line.body_entered.connect(_on_arrival_line_body_entered)
	profiles.load_from_disk()
	settings.load_from_disk()
	settings.apply()
	camera_shake = settings.camera_shake
	draft_build.setup(builder, player_count, player_colors)
	hud.thumbnails = $Thumbnails
	_setup_sky()
	menu = MainMenu.new()
	menu.settings = settings
	add_child(menu)
	menu.play_requested.connect(_on_play_requested)
	menu.resume_requested.connect(_resume)
	menu.restart_frame_requested.connect(_on_restart_frame_requested)
	menu.quit_to_menu_requested.connect(_on_quit_to_menu)
	menu.quit_requested.connect(func(): get_tree().quit())
	menu.settings_changed.connect(func(): camera_shake = settings.camera_shake)
	menu.practice_requested.connect(_enter_hub)
	closet = Closet.new()
	add_child(closet)
	crate_screen = CrateScreen.new()
	add_child(crate_screen)
	crate_screen.trophy_won.connect(func(_p): hub.refresh_trophies(profiles, settings.player_count))
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	net.event_received.connect(_on_net_event)
	net.snapshot_received.connect(func(d): _snap = d)
	net.lobby_changed.connect(_refresh_lobby)
	net.joined.connect(func(): menu.open_lobby(false))
	net.failed.connect(func(reason): menu.toast(reason); menu.back_to_online())
	net.left.connect(_on_net_left)
	draft_build.placed.connect(func(p, pos, angle):
		net.send_event("place", {"p": p, "pos": pos, "angle": angle}))
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	menu.lobby_leave_requested.connect(func(): net.leave(); menu.back_to_online())
	menu.lobby_start_requested.connect(_start_online_match)
	menu.lobby_bots_changed.connect(func(n): net.set_bots(n))
	_setup_local_seats()
	_new_match()
	show_title()


## The match sky (see ArtStyle): plain blue with drifting puffy clouds.
func _setup_sky() -> void:
	($WorldEnvironment as WorldEnvironment).environment = ArtStyle.environment(Color(0.35, 0.62, 0.72))
	var clouds := CloudLayer.new()
	clouds.name = "Clouds"
	clouds.count = 26
	clouds.radius_min = 110.0
	clouds.radius_max = 220.0
	clouds.height_min = 22.0
	clouds.height_max = 48.0
	clouds.size_min = 3.0
	clouds.size_max = 5.5
	course.add_child(clouds)


# ------------------------------------------------------------ Menus

## Back to the title screen, with the camera circling the island.
func show_title() -> void:
	get_tree().paused = false
	if net and net.active():
		if net.has_meta("in_match"):
			net.remove_meta("in_match")
		net.leave()
		_setup_local_seats()
	if hub:
		hub.stop()
	_show_hub_world(false)
	state = State.MENU
	_overhead_camera = false
	menu.open_main()


## PLAY -> START: set up a local match from the menu's options and go to
## the ready screen. The island shown behind the menu is the one you play on.
func _on_play_requested() -> void:
	_setup_local_seats()
	frames_per_match = settings.frames_per_match
	marbles_collide = settings.marbles_collide
	camera_shake = settings.camera_shake
	draft_build.setup(builder, player_count, player_colors)
	menu.close()
	_new_match(false)


## PRACTICE ISLAND: put everyone's marble on the floating hub island.
## Only people go to the island: bots join when a match starts.
func _enter_hub() -> void:
	menu.close()
	_setup_local_seats()
	player_count = clampi(settings.player_count, 1, 4)
	camera_shake = settings.camera_shake
	if hub == null:
		hub = HUB_SCENE.instantiate()
		hub.position = HUB_POSITION
		add_child(hub)
		hub.customize_requested.connect(_on_hub_customize)
		hub.play_requested.connect(_on_hub_play)
		hub.derby_requested.connect(_on_hub_derby)
		hub.crates_requested.connect(_on_hub_crates)
	_close_screens()
	derby_open = [false, false, false, false]
	hub.start(player_count, seat_looks, marble_scene)
	hub.refresh_trophies(profiles, settings.player_count)
	hub.derby.profiles = profiles
	_show_hub_world(true)
	state = State.HUB
	_refresh_colors()
	camera.snap_to(hub.to_global(Hub.SPAWN))


## A marble rolled onto the Customize plate: open the closet (one player
## at a time; anyone else is sent back off the plate).
func _on_hub_customize(p: int) -> void:
	if p >= player_count:
		return
	if seat_kinds[p] != Seat.LOCAL or closet.is_open() or crate_screen.is_open():
		hub.release_from_plate.call_deferred(p)
		return
	# Deferred: the plate fires from inside the physics step, which is no
	# time to build a new little 3D world.
	closet.open.call_deferred(p, profiles)
	_hide_world(true)


func _close_closet() -> void:
	var p := closet.player
	closet.close()
	profiles.save_to_disk()
	_after_screen(p)


## A marble rolled onto the Loot Crates plate.
func _on_hub_crates(p: int) -> void:
	if p >= player_count:
		return
	if seat_kinds[p] != Seat.LOCAL or closet.is_open() or crate_screen.is_open():
		hub.release_from_plate.call_deferred(p)
		return
	crate_screen.open.call_deferred(p, profiles)
	_hide_world(true)


func _close_crates() -> void:
	var p := crate_screen.player
	crate_screen.close()
	_after_screen(p)


## The closet and crate screens cover everything, so stop drawing the 3D
## world behind them (saves a lot of work on slower computers).
func _hide_world(hidden: bool) -> void:
	get_viewport().disable_3d = hidden


## Back on the island after the closet or crates: wear the new look.
func _after_screen(p: int) -> void:
	_hide_world(false)
	if p >= 0 and p < seat_looks.size():
		seat_looks[p] = profiles.look(p)
	if hub and p >= 0 and p < hub.marbles.size():
		hub.marbles[p].look = seat_looks[p]
		hub.release_from_plate(p)
		hub.refresh_trophies(profiles, settings.player_count)
	_refresh_colors()


## Shut the closet and crate screens without fuss (leaving the island).
func _close_screens() -> void:
	_hide_world(false)
	if closet and closet.is_open():
		closet.close()
	if crate_screen and crate_screen.is_open():
		crate_screen.close()


## Swap between the match world and the practice island's own world: its
## own sky, and the lake, track and pins hidden.
func _show_hub_world(on: bool) -> void:
	var env: WorldEnvironment = $WorldEnvironment
	if _match_env == null:
		_match_env = env.environment
	if on and _hub_env == null:
		_hub_env = hub.make_environment()
	env.environment = _hub_env if on else _match_env
	course.visible = not on
	rack.visible = not on
	for m in marbles:
		m.visible = not on


## A marble rolled onto the Marble Derby betting plate.
func _on_hub_derby(p: int) -> void:
	if p < player_count and seat_kinds[p] == Seat.LOCAL:
		derby_open[p] = true
	elif hub:
		hub.release_from_plate.call_deferred(p)


## Someone rolled through the PLAY arch: start a real match.
func _on_hub_play() -> void:
	if state != State.HUB:
		return
	hub.stop.call_deferred()
	_show_hub_world(false)
	_on_play_requested()


func _pause() -> void:
	# Online, the game keeps going for everyone else.
	get_tree().paused = not net.active()
	menu.open_pause()


func _resume() -> void:
	menu.close()
	get_tree().paused = false


func _on_restart_frame_requested() -> void:
	_resume()
	if net.active():
		menu.toast("No retries in online games")
		return
	if state == State.HUB:
		hub.stop_marbles()
		_close_screens()
		hub.start(player_count, seat_looks, marble_scene)
		derby_open = [false, false, false, false]
	elif state in [State.COUNTDOWN, State.ROLLING, State.RESULTS]:
		_prepare_roll()
		_start_countdown()
	else:
		menu.toast("You can retry once the marbles are rolling")


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	_close_screens()
	if hub:
		hub.stop()
	_new_match()
	show_title()


## Start a fresh match on the ready screen. `new_track` false keeps the island
## that's already built (the one behind the title screen).
func _new_match(new_track := true) -> void:
	frame = 1
	totals.resize(player_count)
	totals.fill(0)
	frame_points.clear()
	last_result = {}
	builder.clear()
	if random_track and (new_track or track.layout.is_empty()):
		_new_track()
	_place_deck()
	state = State.WAITING
	match_coins = [0, 0, 0, 0]
	_refresh_colors()
	_prepare_roll()
	if net.is_host():
		net.send_event("match", {"layout": track.layout, "start": track.start_xz,
				"decor": ($Course/Decor as TrackDecor).seed, "lobby": net.lobby,
				"frames": frames_per_match, "collide": marbles_collide})


## A fresh random track, centred over the water.
func _new_track() -> void:
	var layout := TrackGen.random_layout(_rng)
	var pts := TrackGen.points(layout)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	($Course/Decor as TrackDecor).seed = _rng.randi()
	track.apply_layout(layout, -(lo + hi) / 2.0)


func _put_marbles_at_gate() -> void:
	for m in marbles:
		var gate := track.world_frame_at(1.0, SPAWN_X[m.player_id])
		m.global_position = gate.origin + gate.basis.y * 0.32
		m.linear_velocity = Vector3.ZERO
		m.angular_velocity = Vector3.ZERO


func _on_track_reshaped() -> void:
	_place_deck()
	if state != State.ROLLING:
		_put_marbles_at_gate()
		rack.reset()
		_freeze_if_client()


## Move the pin deck (and the rack) to wherever the track ends.
func _place_deck() -> void:
	var end := track.global_transform * track.end_transform()
	deck.global_transform = Transform3D(end.basis, end.origin + Vector3(0, -TrackGen.END_Y, 0))
	rack.global_transform = ($Course/Deck/RackSpot as Node3D).global_transform
	($Course/Decor as TrackDecor).rebuild(track, deck)


func _prepare_roll() -> void:
	## Put fresh marbles at the start gate (frozen) and a fresh rack of pins.
	for m in marbles:
		remove_child(m)
		m.queue_free()
	marbles.clear()
	arrival_order.clear()
	sweep_player = -1
	_roll_time = 0.0
	_settling = false
	_last_arrival_time = -100.0

	for i in player_count:
		var m: Marble = marble_scene.instantiate()
		m.player_id = i
		m.look = look_for(i)
		m.preview = state == State.WAITING
		m.freeze = true
		add_child(m)
		m.set_marble_collision(marbles_collide)
		m.landed.connect(_on_marble_impact.bind(9.0))
		m.bumped.connect(_on_marble_impact.bind(7.0))
		marbles.append(m)

	_put_marbles_at_gate()
	rack.reset()
	_freeze_if_client()
	_hop_latch = [false, false, false, false]
	_update_camera()
	camera.snap_to(camera.target)


# ------------------------------------------------------------ Phases

func _start_draft() -> void:
	draft_build.start_draft(player_count + crate_extra, _rng)
	_phase_left = draft_time
	state = State.DRAFT
	net.send_event("draft", {"crate": draft_build.crate, "frame": frame})


func _start_build() -> void:
	draft_build.auto_pick_remaining()
	draft_build.start_build()
	_phase_left = build_time
	_repeat.clear()
	state = State.BUILD
	net.send_event("build", {"picks": draft_build.picks, "taken": draft_build.taken_by})


func _end_build() -> void:
	draft_build.auto_place_remaining()
	draft_build.end_build()
	_start_countdown()


func _start_countdown() -> void:
	_countdown = 3.0
	state = State.COUNTDOWN
	net.send_event("countdown", {})


func _release_marbles() -> void:
	for m in marbles:
		m.freeze = false
	state = State.ROLLING
	net.send_event("rolling", {})


func _process(delta: float) -> void:
	if net.is_client():
		_client_process(delta)
		return
	_poll_seats(delta)
	if state == State.DRAFT or state == State.BUILD:
		_gather_build_inputs(delta)
	elif state == State.HUB:
		_gather_hub_inputs()
	_update_camera()
	hud.refresh(self)


func _physics_process(delta: float) -> void:
	if net.is_client():
		return
	net.send_snapshot(delta, _make_snapshot)
	match state:
		State.DRAFT:
			_phase_left -= delta
			if _phase_left <= 0.0 or draft_build.all_picked():
				_start_build()
		State.BUILD:
			_phase_left -= delta
			if _phase_left <= 0.0 or draft_build.all_placed():
				_end_build()
		State.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				_release_marbles()
		State.ROLLING:
			_gather_inputs()
			_update_roll(delta)
		State.HUB:
			hub.physics_update(delta)


# ------------------------------------------------------------ Input

func _gather_inputs() -> void:
	## The only place player input reaches the marbles.
	for m in marbles:
		var p := m.player_id
		if m.arrived:
			m.lean = Vector2.ZERO  # past the finish line: momentum only
			_hop_latch[p] = false
			continue
		m.lean = seat_lean(p)
		m.lane_basis = _lane_frame(m.global_position).basis
		# The place key doubles as hop while rolling.
		if _hop_latch[p]:
			_hop_latch[p] = false
			m.request_hop()


func _gather_build_inputs(delta: float) -> void:
	## The only place player input reaches the draft and build.
	for p in player_count:
		if state == State.DRAFT:
			# Move the pointer over the cards (screen up = card space up).
			var dir := seat_lean(p)
			if dir != Vector2.ZERO:
				draft_build.request_pointer_move(p, dir * pointer_speed * delta)
			if seat_pressed(p, "confirm"):
				draft_build.request_pick(p)
		else:
			# Glide the cursor while keys are held (lean keys double as
			# cursor keys: forward moves toward the pins).
			var dir := seat_lean(p)
			if dir != Vector2.ZERO:
				draft_build.request_cursor_move(p, dir * cursor_speed * delta)
			if PieceCatalog.is_track(draft_build.picks[p]):
				# Track cards flip left/right: one flip per tap.
				if seat_pressed(p, "rotate"):
					draft_build.request_rotate(p, 180.0)
			elif _pressed_or_repeat(p, "rotate", delta, 0.04):
				draft_build.request_rotate(p, rotate_step)
			if seat_pressed(p, "confirm"):
				draft_build.request_place(p)


func _gather_hub_inputs() -> void:
	## Practice island: roll about and hop. While the closet or a loot
	## crate fills the screen, only that player's keys do anything.
	if closet.is_open() or crate_screen.is_open():
		for m in hub.marbles:
			m.lean = Vector2.ZERO
		if closet.is_open():
			var p := closet.player
			closet.request_move(_menu_dir(p))
			if seat_pressed(p, "confirm"):
				closet.request_confirm()
			if _leave_pressed(p):
				_close_closet()
		else:
			var p := crate_screen.player
			if seat_pressed(p, "confirm"):
				crate_screen.request_confirm()
			if _leave_pressed(p) and not crate_screen.busy():
				_close_crates()
		return
	var cam := camera.global_basis
	var flat := Basis(Vector3.UP, atan2(cam.z.x, cam.z.z))
	for m in hub.marbles:
		var p := m.player_id
		if derby_open[p]:
			# Betting: left/right picks a horse, up/down the wager,
			# place key bets, turn key leaves.
			m.lean = Vector2.ZERO
			var derby := hub.derby
			if seat_pressed(p, "left"):
				derby.request_pick(p, -1)
			if seat_pressed(p, "right"):
				derby.request_pick(p, 1)
			if seat_pressed(p, "forward"):
				derby.request_wager(p, 1)
			if seat_pressed(p, "back"):
				derby.request_wager(p, -1)
			if seat_pressed(p, "confirm"):
				derby.request_bet(p)
			if _leave_pressed(p):
				derby_open[p] = false
				hub.release_from_plate(p)
			continue
		m.lean = seat_lean(p)
		m.lane_basis = flat
		if seat_pressed(p, "confirm"):
			m.request_hop()


## Done / leave on the island: the turn key, or B on a controller.
func _leave_pressed(p: int) -> bool:
	return seat_pressed(p, "rotate") or seat_pressed(p, "cancel")


## One menu step from a player's move keys / stick: a tap moves once.
func _menu_dir(p: int) -> Vector2i:
	var d := Vector2i.ZERO
	if seat_pressed(p, "left"):
		d.x -= 1
	if seat_pressed(p, "right"):
		d.x += 1
	if seat_pressed(p, "forward"):
		d.y -= 1
	if seat_pressed(p, "back"):
		d.y += 1
	return d


func _refresh_colors() -> void:
	for p in player_count:
		player_colors[p] = look_for(p).color.color
	draft_build.colors = player_colors


func _pressed_or_repeat(p: int, action: String, delta: float, rate := 0.09) -> bool:
	## True on the first press, then repeatedly while held, so a piece can
	## keep turning.
	var key := "%d:%s" % [p, action]
	if seat_pressed(p, action):
		_repeat[key] = 0.3
		return true
	if seat_held(p, action):
		_repeat[key] = _repeat.get(key, 0.3) - delta
		if _repeat[key] <= 0.0:
			_repeat[key] = rate
			return true
	return false


func _input(event: InputEvent) -> void:
	Controls.note_input(event)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.MENU or menu.is_open():
		return  # the menu handles its own keys
	if event.is_action_pressed("quit") and closet.is_open():
		_close_closet()
	elif event.is_action_pressed("quit") and crate_screen.is_open():
		if not crate_screen.busy():
			_close_crates()
	elif event.is_action_pressed("quit"):
		_pause()
	elif net.active() and (event.is_action_pressed("toggle_collision") or event.is_action_pressed("restart_frame")):
		return  # not in online games
	elif event.is_action_pressed("roll") and net.is_client():
		return  # sent to the host with the rest of our input
	elif event.is_action_pressed("toggle_collision"):
		marbles_collide = not marbles_collide
		for m in marbles:
			m.set_marble_collision(marbles_collide)
	elif event.is_action_pressed("toggle_camera"):
		_overhead_camera = not _overhead_camera
	elif event.is_action_pressed("restart_frame"):
		# Re-roll this frame on the same lane (handy for testing a layout).
		if state in [State.COUNTDOWN, State.ROLLING, State.RESULTS]:
			_prepare_roll()
			_start_countdown()
	elif event.is_action_pressed("roll"):
		request_next()


## Space / Y: start the match, the next frame, or a new match.
func request_next() -> void:
	match state:
		State.WAITING:
			_start_draft()
		State.RESULTS:
			frame += 1
			_prepare_roll()
			net.send_event("prepare", {"frame": frame})
			_start_draft()
		State.MATCH_OVER:
			_new_match()


# ------------------------------------------------------------ Seats

## Local play: people first (from the Play page), then bots.
func _setup_local_seats() -> void:
	var people := clampi(settings.player_count, 1, 4)
	var bot_n := clampi(settings.bot_count, 0, 4 - people)
	player_count = people + bot_n
	seat_kinds = []
	seat_keys = [0, 1, 2, 3]
	for p in 4:
		seat_kinds.append(Seat.LOCAL if p < people else Seat.BOT)
	_make_bots_and_looks()


func _make_bots_and_looks(lobby: Array = []) -> void:
	seat_looks = []
	bots = [null, null, null, null]
	for p in 4:
		if seat_kinds[p] == Seat.BOT:
			bots[p] = MarbleBot.new(p)
			seat_looks.append(MarbleBot.look(p))
		elif p < lobby.size() and not (seat_kinds[p] == Seat.LOCAL and net.active()):
			seat_looks.append(_look_from_ids(lobby[p].get("look", {})))
		else:
			seat_looks.append(profiles.look(profile_of(p) if profile_of(p) >= 0 else p))
	if draft_build:
		draft_build.setup(builder, player_count, player_colors)
	_refresh_colors()


static func _look_from_ids(ids: Dictionary) -> Dictionary:
	var out := {}
	for slot in Cosmetics.SLOTS:
		out[slot] = Cosmetics.find(slot, ids.get(slot, ""))
	if not ids.has("eyes"):
		out.eyes = Cosmetics.EYES[0]
	if not ids.has("color"):
		out.color = Cosmetics.COLORS[0]
	return out


func look_for(p: int) -> Dictionary:
	return seat_looks[p] if p < seat_looks.size() else profiles.look(p)


## Which saved profile a seat's coins go to, or -1 (bots and other
## computers' players don't have one here).
func profile_of(p: int) -> int:
	if p >= seat_kinds.size() or seat_kinds[p] != Seat.LOCAL:
		return -1
	return 0 if net and net.active() else p


func is_bot(p: int) -> bool:
	if p < seat_kinds.size() and seat_kinds[p] == Seat.BOT:
		return true
	# Online clients don't run bots, but still show them as bots.
	return net != null and net.is_client() and p < net.lobby.size() and net.lobby[p].kind == "bot"


## The short name shown for a seat: P1, P2... or BOT.
func seat_name(p: int) -> String:
	if is_bot(p):
		var n := 0
		for q in player_count:
			if is_bot(q):
				n += 1
		return "BOT" if n == 1 else "BOT%d" % (p + 1)
	return "P%d" % (p + 1)


## Seats played at this computer (for the key hints).
func local_seats() -> Array:
	var out := []
	for p in player_count:
		if seat_kinds[p] == Seat.LOCAL:
			out.append(p)
	return out


## Read everyone's input for this frame: keys and controllers, bots, and
## (online, on the host) what other computers sent.
func _poll_seats(delta: float) -> void:
	for p in player_count:
		var list := []
		match seat_kinds[p]:
			Seat.LOCAL:
				for b in NetSession.BUTTONS:
					var action := Controls.action_name(seat_keys[p], b)
					if InputMap.has_action(action) and Input.is_action_just_pressed(action):
						list.append(b)
			Seat.BOT:
				(bots[p] as MarbleBot).think(self, delta)
				list = bots[p].presses
			Seat.REMOTE:
				if net.is_host():
					list = net.remote_presses(p)
					if list.has("roll"):
						request_next()
		_pressed[p] = list
		if list.has("confirm") and state == State.ROLLING:
			_hop_latch[p] = true


func seat_lean(p: int) -> Vector2:
	match seat_kinds[p]:
		Seat.LOCAL:
			return Controls.read_lean(seat_keys[p])
		Seat.BOT:
			return (bots[p] as MarbleBot).lean
		Seat.REMOTE:
			return net.remote_lean(p)
	return Vector2.ZERO


func seat_pressed(p: int, button: String) -> bool:
	return p < _pressed.size() and (_pressed[p] as Array).has(button)


func seat_held(p: int, button: String) -> bool:
	if seat_kinds[p] == Seat.LOCAL:
		return Input.is_action_pressed(Controls.action_name(seat_keys[p], button))
	return false


# ------------------------------------------------------------ Online

func _on_host_requested() -> void:
	net.my_look_ids = profiles.seats[0].equipped.duplicate()
	net.bot_count = settings.bot_count
	if net.host() != OK:
		menu.toast("Couldn't host (is the game already running?)")
		return
	menu.open_lobby(true)


func _on_join_requested(address: String) -> void:
	net.my_look_ids = profiles.seats[0].equipped.duplicate()
	# "address" or "address:port"
	address = address.strip_edges()
	var port := NetSession.DEFAULT_PORT
	if address.count(":") == 1:
		port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	if address == "" or net.join(address, port) != OK:
		menu.toast("Couldn't connect to that address")
		return
	menu.toast("Connecting to %s..." % address)


func _refresh_lobby() -> void:
	var lines := []
	for i in net.lobby.size():
		var s: Dictionary = net.lobby[i]
		var who: String = {"host": "host", "player": "player", "bot": "bot"}.get(s.kind, s.kind)
		var me := "   (you)" if i == net.my_seat and s.kind != "bot" else ""
		lines.append("%s   %s%s" % [s.name, who, me])
	menu.set_lobby_text("\n".join(lines), net.is_host())


## Host: everyone's in, start the match.
func _start_online_match() -> void:
	if not net.is_host():
		return
	net.set_meta("in_match", true)
	frames_per_match = settings.frames_per_match
	marbles_collide = settings.marbles_collide
	_apply_lobby(net.lobby)
	menu.close()
	_new_match(true)


## Turn the lobby into seats. My own seat is played with key set 0.
func _apply_lobby(lobby: Array) -> void:
	player_count = lobby.size()
	seat_kinds = []
	seat_keys = [0, 0, 0, 0]
	for p in 4:
		if p >= lobby.size():
			seat_kinds.append(Seat.LOCAL)
		elif lobby[p].kind == "bot":
			seat_kinds.append(Seat.BOT if net.is_host() else Seat.REMOTE)
		elif p == net.my_seat:
			seat_kinds.append(Seat.LOCAL)
		else:
			seat_kinds.append(Seat.REMOTE)
	_make_bots_and_looks(lobby)
	if not net.is_host():
		bots = [null, null, null, null]  # bots only think on the host


func _on_net_left(reason: String) -> void:
	_setup_local_seats()
	_new_match()
	show_title()
	menu.toast(reason)


## Host: what clients need every tick to draw the game.
func _make_snapshot() -> Dictionary:
	var ms := []
	for m in marbles:
		ms.append([m.global_position, m.quaternion, m.arrived, m.out])
	var pins := []
	for pin in rack.pins:
		pins.append([pin.global_position, pin.quaternion])
	var snap := {"ph": _phase_left, "cd": _countdown, "rt": _roll_time, "la": _last_arrival_time,
			"m": ms, "pins": pins, "arr": arrival_order}
	if state == State.DRAFT:
		snap.dp = draft_build.draft_pointer
		snap.tb = draft_build.taken_by
		snap.pk = draft_build.picks
		snap.msg = draft_build.message
	elif state == State.BUILD:
		snap.cp = draft_build.cursor_pos
		snap.ca = draft_build.cursor_angle
		snap.msg = draft_build.message
	return snap


## Client: a game event from the host. Each one does what the host just
## did, so this copy of the game stays in step.
func _on_net_event(name: String, data: Dictionary) -> void:
	if name == "seat_dropped":
		# Host: a player left mid-match; a bot takes over their seat.
		for p in player_count:
			if seat_kinds[p] == Seat.REMOTE and (p >= net.lobby.size() or net.lobby[p].kind == "bot"):
				seat_kinds[p] = Seat.BOT
				bots[p] = MarbleBot.new(p)
		menu.toast("A player left: a bot took their seat")
		return
	if not net.is_client():
		return
	match name:
		"match":
			net.lobby = data.lobby
			frames_per_match = data.frames
			marbles_collide = data.collide
			_apply_lobby(data.lobby)
			menu.close()
			if hub:
				hub.stop()
			_show_hub_world(false)
			frame = 1
			totals.resize(player_count)
			totals.fill(0)
			frame_points.clear()
			last_result = {}
			match_coins = [0, 0, 0, 0]
			builder.clear()
			($Course/Decor as TrackDecor).seed = data.decor
			track.apply_layout(data.layout, data.start)
			_place_deck()
			state = State.WAITING
			_refresh_colors()
			_prepare_roll()
		"prepare":
			frame = data.frame
			_prepare_roll()
		"draft":
			frame = data.frame
			draft_build.mirror_draft(data.crate)
			state = State.DRAFT
		"build":
			draft_build.picks = data.picks
			draft_build.taken_by = data.taken
			draft_build.start_build()
			state = State.BUILD
		"place":
			draft_build.cursor_pos[data.p] = data.pos
			draft_build.cursor_angle[data.p] = data.angle
			draft_build.request_place(data.p)
		"countdown":
			if state == State.BUILD:
				draft_build.end_build()
			_countdown = 3.0
			state = State.COUNTDOWN
		"rolling":
			_roll_time = 0.0
			state = State.ROLLING
		"result":
			last_result = data.result
			totals = data.totals
			frame_points = data.points
			coins_earned = data.coins
			match_coins = data.match_coins
			state = data.state
			if profile_of(net.my_seat) >= 0:
				profiles.add_coins(0, coins_earned[net.my_seat])
				profiles.save_to_disk()
			if data.striker >= 0:
				hud.show_strike(data.striker, player_colors[data.striker])


## Client: each frame, send my input and show the host's newest snapshot.
func _client_process(delta: float) -> void:
	if state != State.MENU and not menu.is_open():
		net.send_input(Controls.read_lean(0), 0)
	elif state != State.MENU:
		net.send_input(Vector2.ZERO, 0)
	if not _snap.is_empty() and state != State.MENU:
		_apply_snapshot(_snap, delta)
	_update_camera()
	hud.refresh(self)


func _apply_snapshot(snap: Dictionary, delta: float) -> void:
	_phase_left = snap.ph
	_countdown = snap.cd
	_roll_time = snap.rt
	_last_arrival_time = snap.la
	arrival_order = snap.arr
	var k := clampf(delta * 18.0, 0.0, 1.0)
	var ms: Array = snap.m
	for i in mini(ms.size(), marbles.size()):
		var m: Marble = marbles[i]
		var d: Array = ms[i]
		if state in [State.COUNTDOWN, State.ROLLING, State.RESULTS, State.MATCH_OVER]:
			m.global_position = m.global_position.lerp(d[0], k)
			m.quaternion = m.quaternion.slerp(d[1], k)
		if d[3] and not m.out:
			_splash(d[0], m.color)
		m.arrived = d[2]
		m.out = d[3]
	var pins: Array = snap.pins
	for i in mini(pins.size(), rack.pins.size()):
		rack.pins[i].global_position = rack.pins[i].global_position.lerp(pins[i][0], k)
		rack.pins[i].quaternion = rack.pins[i].quaternion.slerp(pins[i][1], k)
	if snap.has("dp") and state == State.DRAFT:
		draft_build.draft_pointer = snap.dp
		draft_build.taken_by = snap.tb
		draft_build.picks = snap.pk
		draft_build.message = snap.msg
	if snap.has("cp") and state == State.BUILD:
		for p in mini(player_count, draft_build.cursor_pos.size()):
			if not draft_build.has_placed[p]:
				draft_build.cursor_pos[p] = snap.cp[p]
				draft_build.cursor_angle[p] = snap.ca[p]
		draft_build.message = snap.msg
		draft_build.refresh_visuals()


## Client: marbles and pins are moved by the host's snapshots, not by
## physics here.
func _freeze_if_client() -> void:
	if not net or not net.is_client():
		return
	for pin in rack.pins:
		pin.freeze = true
	for m in marbles:
		m.freeze = true


# ------------------------------------------------------------ Roll

func _update_roll(delta: float) -> void:
	_roll_time += delta

	for m in marbles:
		if not m.out and not m.arrived and m.global_position.y < out_of_bounds_y:
			m.out = true
			m.freeze = true
			_splash(m.global_position, m.color)
		_unstick(m, delta)

	var all_done := true
	for m in marbles:
		if not (m.arrived or m.out):
			all_done = false

	if all_done and not _settling:
		_settling = true
		_settle_left = settle_time
	if _settling:
		_settle_left -= delta

	if _roll_time >= roll_time_limit or (_settling and _settle_left <= 0.0):
		_finish_frame()


func _unstick(m: Marble, delta: float) -> void:
	if m.out or m.arrived or m.freeze:
		m.still_time = 0.0
		return
	if m.linear_velocity.length() < 0.3:
		m.still_time += delta
	else:
		m.still_time = 0.0
	# Wedged for good (stuck in a piece, or rocking in a dip): after a few
	# seconds with no progress down the track, put it back on a bit further.
	var d := track.distance_of(m.global_position)
	if d > m.best_distance + 0.5:
		m.best_distance = d
		m.best_time = _roll_time
	elif _roll_time - m.best_time > rescue_time and d < track.length() - 2.0:
		var to := m.best_distance + 3.0
		for g in track.gaps:
			if to > g[0] - 1.0 and to < g[1] + 1.0:
				to = g[1] + 1.2
		var spot := track.world_frame_at(to)
		m.global_position = spot.origin + spot.basis.y * 0.5
		m.linear_velocity = -spot.basis.z * 3.0
		m.angular_velocity = Vector3.ZERO
		m.best_time = _roll_time
		m.still_time = 0.0
		return
	if m.still_time >= stuck_time:
		m.still_time = 0.0
		# Up, toward the middle of the lane, and on toward the pins.
		var lane := _lane_frame(m.global_position)
		var across := lane.basis.x.dot(m.global_position - lane.origin)
		var side := -signf(across) * _rng.randf_range(1.5, 3.0)
		var hop := lane.basis.x * side + Vector3.UP * 4.0 - lane.basis.z * 3.0
		m.apply_central_impulse(hop * m.mass)


func _finish_frame() -> void:
	var knockouts := []
	for m in marbles:
		m.lean = Vector2.ZERO
		if m.out and m.knocked_out_by != -1 and m.knocked_out_by != m.player_id:
			knockouts.append(m.knocked_out_by)
	last_result = Scoring.score_frame(player_count, arrival_order,
			rack.fallen_credits(), sweep_player, knockouts)
	for i in player_count:
		totals[i] += last_result.points[i]
	frame_points.append(last_result.points.duplicate())
	state = State.MATCH_OVER if frame >= frames_per_match else State.RESULTS
	_award_coins()
	var striker := strike_player()
	if striker >= 0:
		hud.show_strike(striker, player_colors[striker])
	net.send_event("result", {"result": last_result, "totals": totals, "points": frame_points,
			"coins": coins_earned, "match_coins": match_coins, "state": state, "striker": striker})


## The player who knocked down every pin by themselves this frame, or -1
## (pins left standing, or more than one player shared them).
func strike_player() -> int:
	if rack.standing_count() > 0:
		return -1
	var credits := rack.fallen_credits()
	if credits.is_empty() or credits[0] < 0:
		return -1
	for c in credits:
		if c != credits[0]:
			return -1
	return credits[0]


## Coins: one per point each frame. At the end of a match everyone gets a
## bonus for playing and the winner (or winners, on a tie) gets more.
func _award_coins() -> void:
	for i in player_count:
		coins_earned[i] = last_result.points[i]
		if state == State.MATCH_OVER:
			coins_earned[i] += Profiles.COINS_PER_MATCH
			if totals[i] == totals.max():
				coins_earned[i] += Profiles.COINS_FOR_WIN
		match_coins[i] += coins_earned[i]
		# Coins go to the profiles of people at this computer (online,
		# each computer pays its own player).
		if profile_of(i) >= 0:
			profiles.add_coins(profile_of(i), coins_earned[i])
	profiles.save_to_disk()


func _on_arrival_line_body_entered(body: Node) -> void:
	if state != State.ROLLING or net.is_client():
		return
	if body is Marble and not body.arrived and not body.out:
		body.arrived = true
		arrival_order.append(body.player_id)
		_last_arrival_time = _roll_time


func _on_rack_swept(player_id: int) -> void:
	if state == State.ROLLING and not net.is_client():
		sweep_player = player_id


## Track frame (world space) at the point of the track nearest `pos`.
## Past the end of the track (on the pin deck) it's the frame at the end.
func _lane_frame(pos: Vector3) -> Transform3D:
	return track.world_frame_at(track.distance_of(pos))


## A burst of spray where a marble hits the water.
func _splash(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 40
	p.lifetime = 1.1
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.95, 1.0).lerp(color, 0.15)
	mat.roughness = 0.1
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	p.global_position = Vector3(at.x, _water_level(), at.z)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _water_level() -> float:
	var water := get_node_or_null("Course/Water") as Node3D
	return water.global_position.y if water else out_of_bounds_y


# ------------------------------------------------------------ Camera

## Shake the camera for a hard landing or a marble-on-marble crash.
## `full` is the impact speed that gives the biggest shake.
func _on_marble_impact(strength: float, full: float) -> void:
	if state == State.ROLLING:
		camera.shake(clampf((strength - 2.0) / full, 0.0, 0.6) * camera_shake)


## The marbles the rolling camera should keep on screen.
func _camera_marbles() -> Array:
	var active := []
	for m in marbles:
		if not m.out and not m.arrived:
			active.append(m)
	if camera_follow == CameraFollow.ONE_MARBLE:
		for m in active:
			if m.player_id == camera_player:
				return [m]
	return active


func _marbles_center() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for m in marbles:
		if not m.out and not m.arrived:
			sum += m.global_position
			n += 1
	if n == 0:
		return rack.global_position + Vector3(0, 0, 3)
	return sum / n


func _update_camera() -> void:
	camera.frame_points = []
	if state == State.MENU:
		# Title screen: a slow circle around the whole island.
		_menu_time += get_process_delta_time()
		var box := _course_box()
		var size := maxf(box.size.x, box.size.z)
		var a := _menu_time * 0.06
		camera.heading = Vector3(-sin(a), 0, -cos(a))
		camera.follow_offset = Vector3(0, size * 0.32, size * 0.62)
		camera.look_ahead = Vector3(0, -size * 0.05, -size * 0.1)
		# Aim a little to the left of the island's middle so it sits to
		# the right of the menu panel.
		var right := Vector3(cos(a), 0, -sin(a))
		camera.target = box.get_center() - right * size * 0.16
		return
	if state == State.HUB:
		# Practice island: follow the marble from behind and above. With
		# several players, aim at the middle and pull back to keep everyone
		# in view.
		var sum := Vector3.ZERO
		for m in hub.marbles:
			sum += m.global_position
			camera.frame_points.append(m.global_position + Vector3.UP * Hub.TAG_HEIGHT)
		camera.heading = Vector3.FORWARD
		if hub.marbles.size() == 1:
			camera.follow_offset = Vector3(0, 4.2, 6.8)
			camera.look_ahead = Vector3(0, -0.5, -3.5)
		else:
			camera.follow_offset = Vector3(0, 5.5, 8.5)
			camera.look_ahead = Vector3(0, -0.8, -4.5)
		if not hub.marbles.is_empty():
			camera.target = sum / hub.marbles.size()
		# Watching the derby: follow the horses, keeping the bettors in shot.
		if derby_open.has(true) and hub.derby.phase != HorseRace.Phase.OPEN:
			camera.frame_points = []
			var horses := hub.derby.horse_positions()
			var mid := Vector3.ZERO
			for h in horses:
				mid += h
			camera.target = mid / horses.size()
			camera.follow_offset = Vector3(0, 6.0, 9.0)
			camera.frame_points.append_array(horses)
			for m in hub.marbles:
				if derby_open[m.player_id]:
					camera.frame_points.append(m.global_position)
		return
	if state == State.WAITING and not _overhead_camera:
		# Ready screen: up close behind the marbles, looking down the track.
		var gate := track.world_frame_at(1.0)
		camera.heading = -gate.basis.z
		camera.follow_offset = Vector3(0, 2.9, 1.3)
		camera.look_ahead = Vector3(0, -0.4, -1.1)
		camera.target = gate.origin + gate.basis.y * 0.3
		return
	if _overhead_camera or state in [State.WAITING, State.DRAFT]:
		# The whole track from high up.
		var box := _course_box()
		var size := maxf(box.size.x, box.size.z)
		camera.heading = Vector3.FORWARD
		camera.follow_offset = Vector3(0, size * 0.72, size * 0.62)
		camera.look_ahead = Vector3(0, 0, -size * 0.08)
		camera.target = box.get_center()
		return
	if state == State.BUILD:
		# Follow the build cursors, facing down the track where they are.
		# Every player's cursor (and its floating label) stays on screen;
		# the camera pulls back when cursors spread out.
		var cursors := draft_build.cursor_world_positions()
		var box := AABB(cursors[0], Vector3.ZERO)
		for c in cursors:
			box = box.expand(c)
			box = box.expand(c + Vector3.UP * 3.0)
		var center := box.get_center()
		center.y = box.position.y
		var d := track.distance_of(center)
		camera.heading = -track.world_frame_at(d + 2.0).basis.z
		camera.follow_offset = Vector3(0, 10.0, 7.5)
		camera.look_ahead = Vector3(0, 0, -2.0)
		camera.target = center
		var back := track.world_frame_at(d).basis.z
		for c in cursors:
			camera.frame_points.append(c)
			camera.frame_points.append(c + Vector3.UP * 3.0)
			# Room behind the cursor too, so the HUD chips don't cover it.
			camera.frame_points.append(c + back * 2.5)
		return
	var pin_cam := state == State.RESULTS or state == State.MATCH_OVER
	if state == State.ROLLING:
		# Swing to the pins for each impact, then back to anyone still rolling.
		pin_cam = _no_marbles_rolling() or _roll_time - _last_arrival_time < pin_cam_time
	if pin_cam:
		camera.heading = -deck.global_basis.z
		camera.follow_offset = Vector3(0, 3.2, 6.5)
		camera.look_ahead = Vector3(0, -1.0, -3.0)
		camera.target = rack.global_position - camera.heading * 1.0
	else:
		camera.follow_offset = Vector3(0, 7.0, 7.5)
		camera.look_ahead = Vector3(0, -2.0, -9.0)
		# Aim at the middle of the pack (leader to last place), and pull
		# back until every marble is in shot.
		var followed := _camera_marbles()
		if followed.is_empty():
			camera.target = _marbles_center()
		else:
			var box := AABB(followed[0].global_position, Vector3.ZERO)
			for m in followed:
				box = box.expand(m.global_position)
				camera.frame_points.append(m.global_position)
			camera.target = box.get_center()
		var d := track.distance_of(camera.target)
		if d < track.length() - 1.0:
			camera.heading = -track.world_frame_at(d + 4.0).basis.z
		else:
			camera.heading = -deck.global_basis.z


## Box around the track and pin deck (world space), for the overview camera.
func _course_box() -> AABB:
	var box := AABB(deck.global_position, Vector3.ZERO)
	var len := track.length()
	var d := 0.0
	while d <= len:
		box = box.expand(track.world_frame_at(d).origin)
		d += 4.0
	box = box.expand(deck.global_transform * Vector3(0, 0, -20))
	return box


func _no_marbles_rolling() -> bool:
	for m in marbles:
		if not m.out and not m.arrived:
			return false
	return true


# ------------------------------------------------------------ HUD helpers

func time_left() -> float:
	return maxf(0.0, roll_time_limit - _roll_time)


func phase_time_left() -> int:
	return ceili(maxf(0.0, _phase_left))


func countdown_value() -> int:
	return ceili(_countdown)
