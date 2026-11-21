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
## REPLAY is the slow-motion strike replay (added last so the numbers
## sent between online players stay the same).
enum State { WAITING, DRAFT, BUILD, COUNTDOWN, ROLLING, RESULTS, MATCH_OVER, MENU, HUB, REPLAY }

const PLAYER_COLORS := [
	Color(0.95, 0.3, 0.55),  # pink
	Color(1.0, 0.8, 0.15),   # yellow
	Color(0.7, 0.45, 0.95),  # violet
	Color(0.6, 0.95, 0.3),   # lime
]
## Where each marble starts across the lane, metres from the centre.
## The practice island is its own place, far away from the match island
## (which is hidden while you're there).
const HUB_SCENE := preload("res://scenes/hub.tscn")
const HUB_POSITION := Vector3(0, 60, 3000)
const SPAWN_X := [-1.5, 1.5, -0.5, 0.5]
## Each match's track is a random width between these (metres).
const TRACK_WIDTHS := Vector2(4.2, 6.6)

## Marbles in the match (1 to 4). Each extra player uses the next key set.
@export_range(1, 4) var player_count := 2
## Make a new random track layout at the start of every match. Turn off
## to play on the hand-drawn curve in scenes/course.tscn (Track/Path).
@export var random_track := true
## Which arena (city, caves...) to play in: "random" picks a new one each
## match. Pick one here to see it every time while you work on it.
@export_enum("random", "beach", "city", "caves", "snow", "clouds") var force_theme := "random"
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

var state := State.MENU:
	set(v):
		state = v
		_state_age = 0.0
## Seconds since the state last changed. Space both hops and starts the next
## frame, so a press right after a change is ignored (see seat_pressed).
var _state_age := 0.0

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
## Steam (lobbies, invites, achievements). Works without Steam too.
var steam: SteamService
## Tests set this to a stand-in for the Steam plugin before the game starts.
var steam_backend: Object
## Strikes each seat has got this match (for the Turkey achievement).
var _strikes: Array = [0, 0, 0, 0]
## Records each roll so a strike can be replayed in slow motion.
var replay := StrikeReplay.new()
## Where the game goes once the replay ends (RESULTS or MATCH_OVER), and who struck.
var _after_replay := State.RESULTS
var _replay_striker := -1
## Online island: who's rolled through the PLAY arch (ready for a match),
## seconds left before the match starts once everyone is (-1 = not
## counting), and a short wait so rolling through once doesn't flip twice.
var hub_ready: Array = [false, false, false, false]
var _ready_countdown := -1.0
var _ready_cool: Array = [0.0, 0.0, 0.0, 0.0]
## Island camera: seconds since anyone turned it, and the scroll-wheel zoom.
var _cam_hands_off := 0.0
var _cam_zoom := 1.0
## Screen, sound and match options (saved between sessions).
var settings := GameSettings.new()
var menu: MainMenu
## The practice island (built the first time someone opens it).
var hub: Hub
## The full-screen closet and loot crate screens on the practice island.
## One player uses each at a time.
var closet: Closet
var crate_screen: CrateScreen
## Which casino game each player is sat at: "", "derby", "blackjack" or "bar".
var table_open: Array = ["", "", "", ""]
## The world round the track this match (sky, ground, scenery).
var arena: Arena
## The victory podium, shown when a match ends.
var podium: Podium
var _hub_env: Environment
## The retro screen filter (warm film colours, optional scanlines).
var retro_filter: RetroFilter
var _menu_time := 0.0
## Coins, owned looks and equipped looks for each seat (saved to disk).
var profiles := Profiles.new()
## Each player's marble colour (from the closet).
var player_colors: Array = PLAYER_COLORS.duplicate()
## Coins each player earned in the last frame / match, for the scoreboard.
var coins_earned: Array = [0, 0, 0, 0]
var match_coins: Array = [0, 0, 0, 0]
## Pins and bonus points each player has scored this match, and at the end
## the coins breakdown for the COINS EARNED screen (Scoring.match_coins).
var match_pins: Array = [0, 0, 0, 0]
var match_bonus: Array = [0, 0, 0, 0]
var coin_breakdown: Array = []
var frame := 1
var totals: Array = []
var marbles: Array[Marble] = []
var arrival_order: Array = []
var sweep_player := -1
var last_result: Dictionary = {}
## Points each player scored in each finished frame: frame_points[frame][player].
var frame_points: Array = []

## Pop up the HOW TO PLAY guide before the first match (see
## _maybe_show_how_to_play). Off for headless test runs.
var auto_how_to_play := DisplayServer.get_name() != "headless"

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
@onready var ball_return: BallReturn = $Course/Deck/BallReturn


func _ready() -> void:
	Controls.setup()
	var facing := LabelFacing.new()
	facing.name = "LabelFacing"
	add_child(facing)
	steam = SteamService.new(steam_backend)
	steam.name = "Steam"
	add_child(steam)
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
	menu = MainMenu.new()
	menu.settings = settings
	add_child(menu)
	menu.play_requested.connect(_on_play_requested)
	menu.resume_requested.connect(_resume)
	menu.restart_frame_requested.connect(_on_restart_frame_requested)
	menu.quit_to_menu_requested.connect(_on_quit_to_menu)
	menu.quit_requested.connect(func(): get_tree().quit())
	retro_filter = RetroFilter.new()
	retro_filter.name = "RetroFilter"
	add_child(retro_filter)
	retro_filter.set_look(settings.retro_look)
	menu.settings_changed.connect(func():
		camera_shake = settings.camera_shake
		retro_filter.set_look(settings.retro_look))
	menu.practice_requested.connect(_enter_hub)
	closet = Closet.new()
	add_child(closet)
	crate_screen = CrateScreen.new()
	add_child(crate_screen)
	crate_screen.trophy_won.connect(func(_p): hub.refresh_trophies(profiles, settings.player_count))
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	net.my_nick = steam.my_name()
	net.hosted.connect(_enter_online_hub)
	# Steam shows its own pop-up for real achievements; ours covers playing
	# without Steam (and the test App ID, which doesn't have ours).
	Achievements.on_unlocked = func(a: Dictionary):
		if not (steam.available and SteamConfig.APP_ID != 480):
			hud.show_achievement(a)
	steam.invite_accepted.connect(_join_steam_lobby)
	menu.steam = steam
	menu.steam_host_requested.connect(_on_steam_host_requested)
	menu.invite_requested.connect(steam.invite_friends)
	net.event_received.connect(_on_net_event)
	net.snapshot_received.connect(func(d): _snap = d)
	net.lobby_changed.connect(_refresh_lobby)
	net.lobby_changed.connect(_on_lobby_changed_in_hub)
	net.joined.connect(func(): menu.toast("Joined! Heading to the island..."))
	net.look_changed.connect(_on_remote_look)
	net.failed.connect(func(reason): menu.toast(reason); menu.back_to_online())
	net.left.connect(_on_net_left)
	draft_build.placed.connect(func(p, pos, angle):
		net.send_event("place", {"p": p, "pos": pos, "angle": angle}))
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	menu.lobby_leave_requested.connect(func(): show_title(); menu.back_to_online())
	menu.lobby_start_requested.connect(_start_online_match)
	menu.lobby_bots_changed.connect(func(n): net.set_bots(n))
	_setup_local_seats()
	_new_match()
	show_title()
	if steam.pending_lobby:
		# Started by accepting a Steam invite: go straight to that game.
		_join_steam_lobby.call_deferred(steam.pending_lobby)


func _exit_tree() -> void:
	# The pop-up hook points at this game; let go of it before it's freed.
	Achievements.on_unlocked = Callable()


# ------------------------------------------------------------ Menus

## Back to the title screen, with the camera circling the island.
func show_title() -> void:
	get_tree().paused = false
	if steam:
		steam.presence("In the menus")
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
	_maybe_show_how_to_play()


## The first time anyone starts a match on this computer, show the HOW TO
## PLAY guide over the READY? screen. It's skippable and only shows once.
## Test runs (headless) skip it unless `auto_how_to_play` is turned on.
func _maybe_show_how_to_play() -> void:
	if settings.seen_how_to_play or not auto_how_to_play:
		return
	settings.seen_how_to_play = true
	settings.save_to_disk()
	menu.open_how_to_play()


## PRACTICE ISLAND: put everyone's marble on the floating hub island.
## Only people go to the island: bots join when a match starts.
func _enter_hub() -> void:
	menu.close()
	_setup_local_seats()
	player_count = clampi(settings.player_count, 1, 4)
	camera_shake = settings.camera_shake
	steam.presence("At the hub")
	_ensure_hub()
	hub.mirror = false
	_close_screens()
	table_open = ["", "", "", ""]
	hub.start(player_count, seat_looks, marble_scene)
	hub.refresh_trophies(profiles, settings.player_count)
	_arrive_on_hub()
	_refresh_gems()


## Show which secret gems everyone here has already found (they come back
## as faint ghosts), and hand out the gem crown to anyone who has all six
## (for saves from before it existed).
func _refresh_gems() -> void:
	var found_by_all := range(Jungle.GEM_COUNT)
	for p in player_count:
		var prof := profile_of(p)
		if prof < 0:
			continue
		var mine: Array = profiles.seats[prof].secrets
		found_by_all = found_by_all.filter(func(id): return mine.has(id))
		_check_gem_reward(prof)
	hub.jungle.reset(found_by_all)


## All six gems found: the Jungle Gem Crown and the Treasure Hunter
## achievement. Returns true the first time.
func _check_gem_reward(prof: int) -> bool:
	if profiles.secrets_found(prof) < Jungle.GEM_COUNT:
		return false
	Achievements.unlock("GEM_HUNTER")
	if not profiles.grant(prof, "hat", "gem_crown"):
		return false
	profiles.save_to_disk()
	return true


func _ensure_hub() -> void:
	if hub != null:
		return
	hub = HUB_SCENE.instantiate()
	hub.position = HUB_POSITION
	add_child(hub)
	hub.customize_requested.connect(_on_hub_customize)
	hub.play_requested.connect(_on_hub_play)
	hub.table_requested.connect(_on_hub_table)
	hub.crates_requested.connect(_on_hub_crates)
	hub.secret_found.connect(_on_secret_found)
	if not hub.built:
		hub._build()
	hub.sports.goal_scored.connect(_on_goal_scored)
	hub.sports.basket_made.connect(_on_basket_made)
	hub.sports.skee.game_over.connect(_on_skee_game_over)


## The island's world, state and camera, once its marbles are placed.
func _arrive_on_hub() -> void:
	hub.casino.profiles = profiles
	_show_hub_world(true)
	state = State.HUB
	_refresh_colors()
	camera.orbit = true
	camera.orbit_yaw = 0.0
	camera.orbit_pitch = 0.38
	_cam_zoom = 1.0
	var mine := hub.spawn_point(0)
	for m in hub.marbles:
		if profile_of(m.player_id) >= 0:
			mine = m.global_position
			break
	camera.snap_to(mine)


# ------------------------------------------------------------ Online island
#
# Online games start on the host's island. Everyone who joins (by Steam
# invite or by address) rolls about on it together; the host's computer runs
# it, like a match. Rolling through the PLAY arch marks you READY, and once
# every person is ready the match starts. After the match everyone comes
# back here. Esc opens the lobby panel: who's here, inviting Steam friends,
# bots and frames (host), and leaving.

## Host: go to (or back to) the island with everyone in the lobby. Guests
## follow when the "hub" event arrives.
func _enter_online_hub() -> void:
	menu.close()
	_close_screens()
	_ensure_hub()
	if net.is_host():
		if net.has_meta("in_match"):
			net.remove_meta("in_match")
		net.drop_left()
		steam.set_joinable(true)
	_apply_lobby(net.lobby)
	player_count = net.humans()
	hub.mirror = net.is_client()
	hub_ready = [false, false, false, false]
	_ready_countdown = -1.0
	table_open = ["", "", "", ""]
	hub.start(player_count, seat_looks, marble_scene, _hub_names())
	hub.refresh_trophies(profiles, 1)
	_arrive_on_hub()
	_refresh_gems()
	steam.presence("On the island with friends")
	menu.toast("Roll through the PLAY arch when you're ready.  Esc: lobby and invites")
	if net.is_host():
		net.send_event("hub", {})


## Names over the marbles: Steam names, or P1, P2...
func _hub_names() -> Array:
	var names := []
	for i in net.lobby.size():
		var s: Dictionary = net.lobby[i]
		var nick: String = s.get("nick", "")
		var text: String = nick if nick != "" else s.name
		if hub_ready[i]:
			text += "  READY"
		names.append(text)
	return names


## Someone joined, left or changed their look while we're on the island.
func _on_lobby_changed_in_hub() -> void:
	if state != State.HUB or not net.active() or net.has_meta("in_match"):
		return
	_apply_lobby(net.lobby)
	player_count = net.humans()
	for i in range(player_count, 4):
		hub_ready[i] = false
	hub.sync_marbles(player_count, seat_looks, marble_scene, _hub_names())
	if net.is_host():
		_check_all_ready()
		net.send_event("hub", {})


## Rolled through the PLAY arch online: ready (or not ready any more).
func _toggle_ready(p: int) -> void:
	if p >= player_count or _ready_cool[p] > 0.0:
		return
	_ready_cool[p] = 1.5
	hub_ready[p] = not hub_ready[p]
	_refresh_ready_tags()
	_check_all_ready()


func _check_all_ready() -> void:
	var all := player_count > 0
	for p in player_count:
		all = all and hub_ready[p]
	if all and _ready_countdown < 0.0:
		_ready_countdown = 3.0
	elif not all:
		_ready_countdown = -1.0


func _refresh_ready_tags() -> void:
	var names := _hub_names()
	for p in mini(names.size(), hub.marbles.size()):
		hub.set_tag(p, names[p], look_for(p).color.color)
	_refresh_lobby()


## Host, every tick on the online island: ready countdown.
func _update_online_hub(delta: float) -> void:
	for p in 4:
		_ready_cool[p] = maxf(_ready_cool[p] - delta, 0.0)
	if _ready_countdown < 0.0:
		return
	var before := ceili(_ready_countdown)
	_ready_countdown -= delta
	if ceili(_ready_countdown) != before and _ready_countdown > 0.0:
		menu.toast("Everyone's ready! Starting in %d..." % ceili(_ready_countdown))
	if _ready_countdown <= 0.0:
		_ready_countdown = -1.0
		_start_online_match()


## A guest finished in their closet or at the crates: wear the new look.
func _on_remote_look(seat: int) -> void:
	if hub and state == State.HUB:
		hub.release_from_plate(seat)


## Someone rolled into one of the jungle's secret gems. The first time a
## player finds each gem they get some coins (saved, so it only pays once).
func _on_secret_found(p: int, id: int, at: Vector3) -> void:
	var text := "SECRET GEM!\n%s" % Jungle.GEM_NAMES[id]
	var prof := profile_of(p)
	if prof >= 0:
		var is_new := profiles.find_secret(prof, id)
		text += "\n%d / %d FOUND" % [profiles.secrets_found(prof), Jungle.GEM_COUNT]
		if is_new:
			profiles.add_coins(prof, Hub.SECRET_COINS)
			profiles.save_to_disk()
			text += "\n+%d COINS" % Hub.SECRET_COINS
			if _check_gem_reward(prof):
				text += "\nALL FOUND! JUNGLE GEM CROWN\nIS IN YOUR CLOSET"
		else:
			text += "\n(ALREADY FOUND)"
	hub.jungle.pop_text(at, text, Jungle.GEM_COLORS[id])


## Goals and baskets: achievements here, and online the host tells
## everyone so they see the GOAL! too.
func _on_goal_scored(team: String) -> void:
	Achievements.unlock("BACK_OF_THE_NET")
	net.send_event("fx", {"kind": "goal", "team": team, "score": hub.sports.score})


## A game of SKEE-JUMP finished: a coin for every 10 points.
func _on_skee_game_over(p: int, score: int) -> void:
	var prof := profile_of(p)
	var coins := score / 10
	if prof >= 0 and coins > 0:
		profiles.add_coins(prof, coins)
		profiles.save_to_disk()


func _on_basket_made(p: int) -> void:
	if profile_of(p) >= 0:
		Achievements.unlock("NOTHING_BUT_NET")
	net.send_event("fx", {"kind": "basket", "count": hub.sports.baskets, "seat": p})


## A marble rolled onto the Customize plate: open the closet (one player
## at a time; anyone else is sent back off the plate).
func _on_hub_customize(p: int) -> void:
	if p >= player_count:
		return
	if seat_kinds[p] == Seat.REMOTE and net.is_host():
		# A guest: their own computer opens their closet.
		net.send_event("screen", {"seat": p, "kind": "closet"})
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
	if net.is_client():
		_hide_world(false)
		net.send_look(profiles.seats[0].equipped.duplicate())
		return
	_after_screen(p)


## A marble rolled onto the Loot Crates plate.
func _on_hub_crates(p: int) -> void:
	if p >= player_count:
		return
	if seat_kinds[p] == Seat.REMOTE and net.is_host():
		net.send_event("screen", {"seat": p, "kind": "crates"})
		return
	if seat_kinds[p] != Seat.LOCAL or closet.is_open() or crate_screen.is_open():
		hub.release_from_plate.call_deferred(p)
		return
	crate_screen.open.call_deferred(p, profiles)
	_hide_world(true)


func _close_crates() -> void:
	var p := crate_screen.player
	crate_screen.close()
	if net.is_client():
		_hide_world(false)
		net.send_look(profiles.seats[0].equipped.duplicate())
		return
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
## own sky and sun, and the arena, track and pins hidden.
func _show_hub_world(on: bool) -> void:
	var env: WorldEnvironment = $WorldEnvironment
	if on and _hub_env == null:
		_hub_env = hub.make_environment()
	if podium:
		podium.clear()
	if on:
		env.environment = _hub_env
		Arena.plain_sun($Sun)
	elif arena:
		env.environment = arena.environment()
		arena.light_sun($Sun)
	course.visible = not on
	rack.visible = not on
	for m in marbles:
		m.visible = not on


## A marble rolled onto a casino plate: the derby, a blackjack seat or the bar.
func _on_hub_table(p: int, kind: String) -> void:
	if p < player_count and seat_kinds[p] == Seat.LOCAL:
		table_open[p] = kind
	elif hub:
		hub.release_from_plate.call_deferred(p)
		if seat_kinds[p] == Seat.REMOTE:
			net.send_event("toast", {"seat": p, "text": "The casino games are for players at the host's computer, for now"})


## Someone rolled through the PLAY arch: start a real match (online, it
## marks them ready instead).
func _on_hub_play(p: int) -> void:
	if state != State.HUB:
		return
	if net.active():
		_toggle_ready(p)
		return
	hub.stop.call_deferred()
	_show_hub_world(false)
	_on_play_requested()


func _pause() -> void:
	if net.active() and state == State.HUB:
		menu.open_lobby(net.is_host(), net.over_steam, true)
		return
	# Online, the game keeps going for everyone else.
	get_tree().paused = not net.active()
	menu.open_pause(state != State.HUB)


func _resume() -> void:
	menu.close()
	get_tree().paused = false


func _on_restart_frame_requested() -> void:
	_resume()
	if net.active():
		menu.toast("No retries in online games")
		return
	if state in [State.COUNTDOWN, State.ROLLING, State.RESULTS]:
		_prepare_roll()
		_start_countdown()
	else:
		menu.toast("You can retry once the balls are rolling")


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
	_strikes = [0, 0, 0, 0]
	builder.clear()
	if random_track and (new_track or track.layout.is_empty()):
		_new_track()
	_place_deck()
	state = State.WAITING
	_reset_match_coins()
	_refresh_colors()
	_prepare_roll()
	if net.is_host():
		net.send_event("match", {"layout": track.layout, "start": track.start_xz,
				"decor": ($Course/Decor as TrackDecor).seed, "theme": arena.id, "width": track.lane_width, "lobby": net.lobby,
				"frames": frames_per_match, "collide": marbles_collide})


## A fresh random track, centred in a random arena.
func _new_track() -> void:
	var layout := TrackGen.random_layout(_rng)
	var pts := TrackGen.points(layout)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	($Course/Decor as TrackDecor).seed = _rng.randi()
	var theme: String = force_theme if force_theme != "random" else Arena.random_theme(_rng)
	var width := snappedf(_rng.randf_range(TRACK_WIDTHS.x, TRACK_WIDTHS.y), 0.1)
	_set_arena(theme, layout, -(lo + hi) / 2.0, width)


## Build the track from `layout` inside the arena `theme`: its colours, sky,
## sun and scenery. The decor seed keeps the scenery the same online.
func _set_arena(theme: String, layout: Array, start_xz: Vector2, width: float) -> void:
	if arena == null or arena.id != theme:
		if arena:
			arena.queue_free()
		arena = Arena.create(theme)
		course.add_child(arena)
	track.floor_color = arena.track_floor
	track.wall_color = arena.track_wall
	track.support_color = arena.track_support
	track.lane_width = width
	builder.half_width = width / 2.0 - 0.7   # where pieces may go
	track.apply_layout(layout, start_xz)
	_place_deck()
	arena.build(track, deck, ($Course/Decor as TrackDecor).seed)
	if not (hub and hub.visible):
		_show_hub_world(false)


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
	if arena:
		($Course/Decor as TrackDecor).rebuild(track, deck, arena)
		arena.refit(track, deck)


## Where the FINAL STANDINGS stage is built: far below the course, in its
## own dark room, so nothing else is in shot.
const PODIUM_STAGE_AT := Vector3(0, -400, 0)

## The match is over: the top three on the podium, fourth in the bin, on
## their own dark stage. The pins and real balls hide meanwhile.
func _show_podium() -> void:
	if podium == null:
		podium = Podium.new()
		podium.name = "Podium"
		podium.top_level = true
		deck.add_child(podium)
	podium.global_transform = Transform3D(Basis(Vector3.UP, deck.global_rotation.y), PODIUM_STAGE_AT)
	var order := range(player_count)
	order.sort_custom(func(a, b): return totals[a] > totals[b] or (totals[a] == totals[b] and a < b))
	var looks := []
	var names := []
	for p in player_count:
		looks.append(look_for(p))
		names.append(seat_name(p))
	podium.show_for(order, looks, player_colors, names, marble_scene)
	($WorldEnvironment as WorldEnvironment).environment = podium.environment()
	($Sun as DirectionalLight3D).light_energy = 0.0
	rack.visible = false
	for m in marbles:
		m.visible = false
	_update_camera()
	camera.snap_to(camera.target)


func _prepare_roll() -> void:
	## Put fresh marbles at the start gate (frozen) and a fresh rack of pins.
	if podium and podium.visible:
		_show_hub_world(false)   # clears it, back to the course's sky and sun
	rack.visible = course.visible   # (hidden while at the hub)
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
	ball_return.reset()
	replay.start(marbles + rack.pins)
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
	_state_age += delta
	if net.is_client():
		_client_process(delta)
		return
	_poll_seats(delta)
	if state == State.DRAFT or state == State.BUILD:
		_gather_build_inputs(delta)
	elif state == State.HUB:
		_gather_hub_inputs()
	elif state == State.REPLAY:
		if not replay.update(delta):
			_end_replay()
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
			replay.record(delta, rack.pins)
			if state != State.REPLAY:
				ball_return.update(marbles, delta)
		State.RESULTS, State.MATCH_OVER:
			ball_return.update(marbles, delta)
		State.HUB:
			hub.physics_update(delta)
			if net.is_host():
				_update_online_hub(delta)


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
	## crate fills the screen, only that player's keys do anything here
	## (online guests on other computers carry on rolling).
	var screen_open := closet.is_open() or crate_screen.is_open()
	if screen_open:
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
	var cam := camera.global_basis
	var flat := Basis(Vector3.UP, atan2(cam.z.x, cam.z.z))
	for m in hub.marbles:
		var p := m.player_id
		if hub.plane.pilot == m:
			# Flying the biplane: steer with the move keys.
			hub.plane.steer = seat_lean(p)
			if seat_pressed(p, "confirm"):
				hub.plane.boost()
			if _leave_pressed(p):
				hub.plane.bail()
			continue
		if seat_kinds[p] == Seat.REMOTE:
			# Guests send their lean already turned to match their own
			# camera (x = east, y = south), so no turning here.
			m.lean = seat_lean(p)
			m.lane_basis = Basis.IDENTITY
			if seat_pressed(p, "confirm"):
				m.request_hop()
			continue
		if screen_open or menu.is_open():
			m.lean = Vector2.ZERO
			continue
		if table_open[p] != "":
			m.lean = Vector2.ZERO
			if _casino_input(p):
				table_open[p] = ""
				hub.release_from_plate(p)
			continue
		m.lean = seat_lean(p)
		m.lane_basis = flat
		if seat_pressed(p, "confirm"):
			m.request_hop()


## Keys for a player sat at a casino game. Returns true when they leave.
func _casino_input(p: int) -> bool:
	var casino := hub.casino
	match table_open[p]:
		"derby":
			# Left/right picks a horse, up/down the wager, place key bets.
			if seat_pressed(p, "left"):
				casino.derby.request_pick(p, -1)
			if seat_pressed(p, "right"):
				casino.derby.request_pick(p, 1)
			if seat_pressed(p, "forward"):
				casino.derby.request_wager(p, 1)
			if seat_pressed(p, "back"):
				casino.derby.request_wager(p, -1)
			if seat_pressed(p, "confirm"):
				casino.derby.request_bet(p)
		"blackjack":
			# Up/down the wager, place key deals or hits, turn key stands.
			var bj := casino.blackjack
			if seat_pressed(p, "forward"):
				bj.request_wager(p, 1)
			if seat_pressed(p, "back"):
				bj.request_wager(p, -1)
			if seat_pressed(p, "confirm"):
				bj.request_confirm(p)
			if seat_pressed(p, "rotate") and bj.request_stand(p):
				return false
			if _leave_pressed(p) and not bj.busy(p):
				bj.leave(p)
				return true
			return false
		"bar":
			# Left/right picks a drink, place key orders it.
			if seat_pressed(p, "left"):
				casino.request_drink_pick(p, -1)
			if seat_pressed(p, "right"):
				casino.request_drink_pick(p, 1)
			if seat_pressed(p, "confirm"):
				casino.request_drink(p, hub.marbles[p])
	return _leave_pressed(p)


## Guest: my closet or loot crate screen, worked by my own keys.
func _client_screens() -> void:
	if closet.is_open():
		closet.request_move(_local_menu_dir())
		if _local_pressed("confirm"):
			closet.request_confirm()
		if _local_pressed("rotate") or _local_pressed("cancel"):
			_close_closet()
	elif crate_screen.is_open():
		if _local_pressed("confirm"):
			crate_screen.request_confirm()
		if (_local_pressed("rotate") or _local_pressed("cancel")) and not crate_screen.busy():
			_close_crates()


func _local_pressed(button: String) -> bool:
	var action := Controls.action_name(0, button)
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _local_menu_dir() -> Vector2i:
	var d := Vector2i.ZERO
	if _local_pressed("left"): d.x -= 1
	if _local_pressed("right"): d.x += 1
	if _local_pressed("forward"): d.y -= 1
	if _local_pressed("back"): d.y += 1
	return d


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
	if _hub_mouse(event):
		return
	if state == State.MENU or menu.is_open():
		return  # the menu handles its own keys
	if state == State.REPLAY:
		# Any key or button skips the strike replay.
		if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) \
				and event.is_pressed() and not event.is_echo():
			get_viewport().set_input_as_handled()
			replay.finish()
			_end_replay()
		return
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
		# Not the instant the scores appear, or a late hop would skip them.
		if not (state in [State.RESULTS, State.MATCH_OVER] and _state_age < 0.8):
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
			if net.is_host():
				_enter_online_hub()   # everyone back to the island
			else:
				_new_match()


# ------------------------------------------------------------ Seats

func _new_bot(p: int) -> MarbleBot:
	var bot := MarbleBot.new(p)
	bot.level = settings.bot_level
	return bot


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
			bots[p] = _new_bot(p)
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
	if button == "confirm" and _state_age < 0.25:
		return false   # the same press that changed the screen
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


func _on_steam_host_requested() -> void:
	net.my_look_ids = profiles.seats[0].equipped.duplicate()
	net.bot_count = settings.bot_count
	if not net.host_steam():
		menu.toast(steam.problem if steam.problem != "" else "Steam isn't available")
		return
	menu.toast("Making a Steam lobby...")


## Join a friend's Steam lobby (accepted an invite, or "Join game" in the
## Steam friends list). Whatever we were doing stops first.
func _join_steam_lobby(lobby_id: int) -> void:
	if state != State.MENU or net.active():
		show_title()
	net.my_look_ids = profiles.seats[0].equipped.duplicate()
	if net.join_steam(lobby_id):
		menu.back_to_online()
		menu.toast("Joining your friend's game...")


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
		var nick: String = s.get("nick", "")
		var ready := "   READY" if state == State.HUB and i < 4 and hub_ready[i] and s.kind != "bot" else ""
		lines.append("%s   %s%s%s" % [s.name, nick if nick != "" else who, me, ready])
	menu.set_lobby_text("\n".join(lines), net.is_host())


## Host: everyone's in, start the match.
func _start_online_match() -> void:
	if not net.is_host():
		return
	net.set_meta("in_match", true)
	steam.set_joinable(false)
	_ready_countdown = -1.0
	if hub:
		hub.stop()
	_close_screens()
	_show_hub_world(false)
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
	if state == State.HUB:
		var hm := []
		for m in hub.marbles:
			hm.append([m.global_position, m.quaternion])
		var ball := hub.sports.ball()
		return {"hub": hm, "ball": [ball.global_position, ball.quaternion],
				"rd": hub_ready, "rc": _ready_countdown}
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
		if state == State.HUB:
			menu.toast("A player left the island")
			return
		# Host: a player left mid-match; a bot takes over their seat.
		for p in player_count:
			if seat_kinds[p] == Seat.REMOTE and (p >= net.lobby.size() or net.lobby[p].kind == "bot"):
				seat_kinds[p] = Seat.BOT
				bots[p] = _new_bot(p)
		menu.toast("A player left: a bot took their seat")
		return
	if not net.is_client():
		return
	match name:
		"hub":
			if state != State.HUB:
				_enter_online_hub()
			else:
				_on_lobby_changed_in_hub()
		"fx":
			if state == State.HUB and data.kind == "goal":
				hub.sports.show_goal(data.team, data.score)
				Achievements.unlock("BACK_OF_THE_NET")
			elif state == State.HUB and data.kind == "basket":
				hub.sports.show_basket(data.count)
				if data.seat == net.my_seat:
					Achievements.unlock("NOTHING_BUT_NET")
		"screen":
			if data.seat == net.my_seat and state == State.HUB and not closet.is_open() and not crate_screen.is_open():
				if data.kind == "closet":
					closet.open.call_deferred(0, profiles)
				else:
					crate_screen.open.call_deferred(0, profiles)
				_hide_world(true)
		"toast":
			if data.seat == net.my_seat:
				menu.toast(data.text)
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
			_strikes = [0, 0, 0, 0]
			_reset_match_coins()
			builder.clear()
			($Course/Decor as TrackDecor).seed = data.decor
			_set_arena(data.get("theme", "beach"), data.layout, data.start, data.get("width", 5.0))
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
			coin_breakdown = data.get("breakdown", [])
			state = data.state
			if profile_of(net.my_seat) >= 0:
				profiles.add_coins(0, coins_earned[net.my_seat])
				profiles.save_to_disk()
			if data.striker >= 0:
				hud.show_strike(data.striker, player_colors[data.striker])
			_frame_achievements(data.striker)
			if state == State.MATCH_OVER:
				_show_podium()


## Client: each frame, send my input and show the host's newest snapshot.
func _client_process(delta: float) -> void:
	var busy := menu.is_open() or closet.is_open() or crate_screen.is_open()
	if state == State.HUB:
		_client_screens()
		# Steer relative to my own camera, sent as an island direction.
		var lean := Vector2.ZERO if busy else Controls.read_lean(0)
		var cam := camera.global_basis
		var flat := Basis(Vector3.UP, atan2(cam.z.x, cam.z.z))
		var world := flat * Vector3(lean.x, 0, lean.y)
		net.send_input(Vector2(world.x, world.z), 0)
	elif state != State.MENU and not busy:
		net.send_input(Controls.read_lean(0), 0)
	elif state != State.MENU:
		net.send_input(Vector2.ZERO, 0)
	if not _snap.is_empty() and state != State.MENU:
		_apply_snapshot(_snap, delta)
	_update_camera()
	hud.refresh(self)


func _apply_snapshot(snap: Dictionary, delta: float) -> void:
	if snap.has("hub"):
		if state == State.HUB:
			_apply_hub_snapshot(snap, delta)
		return
	if not snap.has("ph"):
		return
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


## Guest on the island: move everything to where the host has it.
func _apply_hub_snapshot(snap: Dictionary, delta: float) -> void:
	var k := clampf(delta * 18.0, 0.0, 1.0)
	var hm: Array = snap.hub
	for i in mini(hm.size(), hub.marbles.size()):
		var m: Marble = hub.marbles[i]
		m.global_position = m.global_position.lerp(hm[i][0], k)
		m.quaternion = m.quaternion.slerp(hm[i][1], k)
	var ball := hub.sports.ball()
	ball.global_position = ball.global_position.lerp(snap.ball[0], k)
	ball.quaternion = ball.quaternion.slerp(snap.ball[1], k)
	if snap.rd != hub_ready:
		hub_ready = snap.rd.duplicate()
		_refresh_ready_tags()
	var before := ceili(_ready_countdown)
	_ready_countdown = snap.rc
	if _ready_countdown > 0.0 and ceili(_ready_countdown) != before:
		menu.toast("Everyone's ready! Starting in %d..." % ceili(_ready_countdown))


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
	_frame_achievements(striker)
	if striker >= 0 and _start_replay(striker):
		return   # the scores come in once the replay is over
	_show_frame_result(striker)


## The STRIKE! banner, the podium at the end of a match, and the result for
## online players.
func _show_frame_result(striker: int) -> void:
	if striker >= 0:
		hud.show_strike(striker, player_colors[striker])
	if state == State.MATCH_OVER:
		_show_podium()
	net.send_event("result", {"result": last_result, "totals": totals, "points": frame_points,
			"coins": coins_earned, "match_coins": match_coins, "breakdown": coin_breakdown,
			"state": state, "striker": striker})


## Achievements for the people at this computer, once a frame is scored
## (host and online clients both run this for their own players).
func _frame_achievements(striker: int) -> void:
	var max_total: int = totals.max()
	for p in player_count:
		if profile_of(p) < 0:
			continue
		Achievements.unlock("FIRST_FRAME")
		Achievements.add("PINS_500", last_result.pins[p])
		if striker == p:
			Achievements.unlock("STRIKE")
			_strikes[p] += 1
			if _strikes[p] >= 3:
				Achievements.unlock("TURKEY")
		if last_result.race[p] == Scoring.RACE_BONUS[0]:
			Achievements.unlock("PHOTO_FINISH")
		if last_result.knockouts[p] > 0:
			Achievements.unlock("BUMPER_CARS")
		if p < marbles.size() and (marbles[p] as Marble).out:
			Achievements.unlock("SPLASHDOWN")
		if profiles.coins(profile_of(p)) >= 1000:
			Achievements.unlock("PIGGY_BANK")
		if state == State.MATCH_OVER:
			Achievements.unlock("FIRST_MATCH")
			if net.active():
				Achievements.unlock("ONLINE_MATCH")
			if player_count > 1 and totals[p] == max_total and totals.count(max_total) == 1:
				Achievements.unlock("FIRST_WIN")
	if state == State.MATCH_OVER:
		steam.presence("Just finished a match")
	else:
		steam.presence("In a match (frame %d of %d)" % [frame, frames_per_match])


## Strike! Play the last moments back in slow motion from by the pins.
## Not online (everyone would have to watch it together), and not if it's
## switched off in Settings. Returns false if there's no replay to show.
func _start_replay(striker: int) -> bool:
	if net.active() or not settings.strike_replay or not replay.begin():
		return false
	_after_replay = state
	_replay_striker = striker
	state = State.REPLAY
	for m in marbles:
		m.clear_trail()
	_update_camera()
	camera.snap_to(camera.target)
	return true


## The replay finished or was skipped: on to STRIKE! and the scores.
func _end_replay() -> void:
	if state != State.REPLAY:
		return
	for m in marbles:
		m.clear_trail()
	state = _after_replay
	_show_frame_result(_replay_striker)


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


func _reset_match_coins() -> void:
	match_coins = [0, 0, 0, 0]
	match_pins = [0, 0, 0, 0]
	match_bonus = [0, 0, 0, 0]
	coin_breakdown = []


## Coins: one per point each frame (pins and bonuses). At the end of the
## match everyone gets a prize for their place and a little for finishing
## (Scoring.match_coins has the whole breakdown for the coins screen).
func _award_coins() -> void:
	for i in player_count:
		match_pins[i] += last_result.pins[i]
		match_bonus[i] += last_result.points[i] - last_result.pins[i]
		coins_earned[i] = last_result.points[i]
	if state == State.MATCH_OVER:
		coin_breakdown = Scoring.match_coins(match_pins.slice(0, player_count),
				match_bonus.slice(0, player_count), totals)
		for i in player_count:
			coins_earned[i] += coin_breakdown[i].place_coins + coin_breakdown[i].finish
	for i in player_count:
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


## A splash (or puff of dust, snow, sparkles...) where a marble falls off
## the track and hits the arena's ground.
func _splash(at: Vector3, color: Color) -> void:
	arena.fall_burst(self, at, color)


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


## Practice island: a free third-person camera around your marble. Turn it
## with the mouse (hold the right button and move), the right stick, or
## Z / X; scroll to zoom. Left alone, it slowly swings round behind the way
## you're rolling. With several players at this computer it aims at the
## middle and pulls back to keep everyone in view.
func _update_hub_camera(delta: float) -> void:
	var mine: Array = []
	for m in hub.marbles:
		if profile_of(m.player_id) >= 0:
			mine.append(m)
	if mine.is_empty():
		mine = hub.marbles
	if mine.is_empty():
		return
	var sum := Vector3.ZERO
	var vel := Vector3.ZERO
	for m in mine:
		sum += m.global_position
		vel += (m as Marble).seen_velocity()
		camera.frame_points.append(m.global_position + Vector3.UP * Hub.TAG_HEIGHT)
	camera.target = sum / mine.size()
	vel /= mine.size()
	camera.orbit_distance = (6.0 if mine.size() == 1 else 7.5) * _cam_zoom
	# Turning by hand.
	var turn := Input.get_axis("cam_left", "cam_right")
	var tilt := 0.0
	for pad in Input.get_connected_joypads():
		var rx := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(rx) > 0.2:
			turn += rx
		if absf(ry) > 0.2:
			tilt += ry
	if menu.is_open() or closet.is_open() or crate_screen.is_open():
		turn = 0.0
		tilt = 0.0
	camera.orbit_yaw -= turn * 2.6 * delta
	camera.orbit_pitch = clampf(camera.orbit_pitch + tilt * 1.6 * delta, 0.08, 1.2)
	if absf(turn) > 0.01 or absf(tilt) > 0.01:
		_cam_hands_off = 0.0
	else:
		_cam_hands_off += delta
	# Left alone for a moment: drift round behind the way we're rolling,
	# but never spin right round when rolling back toward the camera.
	var flat := Vector2(vel.x, vel.z)
	if _cam_hands_off > 1.0 and flat.length() > 1.5 and not table_open.has("derby"):
		var behind := atan2(-vel.x, -vel.z)
		if absf(angle_difference(camera.orbit_yaw, behind)) < 2.0:
			var k := 1.0 - exp(-1.1 * delta * clampf(flat.length() / 5.0, 0.3, 1.0))
			camera.orbit_yaw = lerp_angle(camera.orbit_yaw, behind, k)
	# Watching the derby: look at the horses, keeping the bettors in shot.
	if table_open.has("derby") and hub.derby.phase != HorseRace.Phase.OPEN:
		camera.frame_points = []
		var horses := hub.derby.horse_positions()
		var mid := Vector3.ZERO
		for h in horses:
			mid += h
		camera.target = mid / horses.size()
		camera.frame_points.append_array(horses)
		for m in hub.marbles:
			if table_open[m.player_id] == "derby":
				camera.frame_points.append(m.global_position)


## Hold the right mouse button and move to turn the island camera; the
## wheel zooms.
func _hub_mouse(event: InputEvent) -> bool:
	if state != State.HUB or menu.is_open() or closet.is_open() or crate_screen.is_open():
		return false
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		camera.orbit_yaw -= event.relative.x * 0.006
		camera.orbit_pitch = clampf(camera.orbit_pitch + event.relative.y * 0.004, 0.08, 1.2)
		_cam_hands_off = 0.0
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom = clampf(_cam_zoom - 0.1, 0.5, 2.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom = clampf(_cam_zoom + 0.1, 0.5, 2.0)
		else:
			return false
		return true
	return false


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
	camera.orbit = state == State.HUB
	if state == State.HUB:
		_update_hub_camera(get_process_delta_time())
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
	if state == State.REPLAY:
		# Strike replay: low down beside the front pins, looking up the
		# lane at an angle so the marble comes crashing in.
		var lane := -deck.global_basis.z
		camera.heading = lane.rotated(Vector3.UP, 0.4)
		camera.follow_offset = Vector3(0, 0.9, 3.6)
		camera.look_ahead = Vector3(0, 0.2, -2.6)
		camera.target = rack.global_position
		var depth := rack.rows * rack.spacing * sqrt(3.0) / 2.0
		var wide := rack.rows * rack.spacing * 0.5
		for corner in [Vector3(0, 1.0, 0.4), Vector3(-wide, 0.2, -depth), Vector3(wide, 0.2, -depth)]:
			camera.frame_points.append(rack.to_global(corner))
		return
	var pin_cam := state == State.RESULTS or state == State.MATCH_OVER
	if state == State.ROLLING:
		# Swing to the pins for each impact, then back to anyone still rolling.
		pin_cam = _no_marbles_rolling() or _roll_time - _last_arrival_time < pin_cam_time
	if state == State.MATCH_OVER and podium and podium.visible:
		camera.heading = -podium.global_basis.z
		camera.follow_offset = Vector3(0, 1.6, 4.6)
		camera.look_ahead = Vector3(0, -0.1, -3.0)
		camera.target = podium.to_global(Vector3(0.6, 0.9, 0))
		camera.frame_points = podium.frame_points()
	elif pin_cam:
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
