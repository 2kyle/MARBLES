class_name NetSession
extends Node
## Online play: over Steam (friends-only lobbies, see steam_service.gd) or
## by address over the internet or a home network (Godot's ENet). Both give
## Godot a "multiplayer peer", and everything below works the same on either.
##
## The host runs the whole game, exactly like local play: physics, pins,
## scoring, bots. Everyone else is a "client": it sends its player's input
## to the host (stick and button presses, nothing else) and shows what the
## host sends back. So nobody can cheat by changing their own copy, and
## everyone sees the same pins fall.
##
## What travels:
##   client -> host   input every physics tick (unreliable, newest wins)
##   host -> clients  a snapshot ~30 times a second: marbles, pins, timers,
##                    draft pointers and build cursors (unreliable)
##   host -> clients  game events: match start, draft, build, every piece
##                    placed, roll, frame results (reliable, in order)
##
## main.gd owns this node, asks it to host or join, and handles the events.

signal lobby_changed
## We're hosting and the lobby is open (straight away by address; once
## Steam has made the lobby over Steam).
signal hosted
signal joined
signal failed(reason: String)
signal left(reason: String)
signal event_received(name: String, data: Dictionary)
## Host: a guest changed their look (closet or loot crate on their computer).
signal look_changed(seat: int)
signal snapshot_received(data: Dictionary)

const DEFAULT_PORT := 24680
const MAX_PLAYERS := 4
## Buttons whose presses are sent to the host (as running counts, so a
## press is never lost even if a packet is).
const BUTTONS := ["confirm", "rotate", "cancel", "left", "right", "forward", "back", "roll"]

enum Role { OFFLINE, HOST, CLIENT }

var role := Role.OFFLINE
## Lobby, kept by the host and copied to everyone:
## [{kind: "host"/"player"/"bot", peer: id, name: "P1", look: {slot: id}}]
var lobby: Array = []
var bot_count := 1
## Which seat this computer plays once the match starts.
var my_seat := 0
## My equipped look ids, sent to the host when joining.
var my_look_ids := {}
## My Steam name ("" without Steam), shown in the lobby.
var my_nick := ""
## True while the game is over Steam rather than by address.
var over_steam := false

## Host side: newest input from each remote seat.
var _inputs := {}        # seat -> {lean: Vector2, counts: Array}
var _seen := {}          # seat -> Array (counts already used)
## Client side: running press counts for my seat.
var _counts: Array = []
var _snap_wait := 0.0


func _ready() -> void:
	_counts.resize(BUTTONS.size())
	_counts.fill(0)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Couldn't reach the host"))
	multiplayer.server_disconnected.connect(func(): _drop("The host left the game"))
	var steam := SteamService.instance
	if steam:
		steam.lobby_hosted.connect(func(_id): _start_host(steam.make_peer(true)))
		steam.lobby_entered.connect(func(_id): _start_client(steam.make_peer(false)))
		steam.lobby_failed.connect(_fail)


func active() -> bool:
	return role != Role.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


# ------------------------------------------------------------ Host / join

## Host by address: friends join with this computer's address.
func host(port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	_start_host(peer)
	return OK


## Join by address ("192.168.1.20" and a port).
func join(address: String, port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_start_client(peer)
	return OK


## Host over Steam: make a friends-only lobby, then invite friends from the
## Steam overlay. `hosted` fires when it's ready.
func host_steam() -> bool:
	var steam := SteamService.instance
	if steam == null or not steam.available:
		return false
	leave()
	over_steam = true
	steam.host_lobby()
	return true


## Join a friend's Steam lobby (from an invite or the friends list).
func join_steam(lobby_id: int) -> bool:
	var steam := SteamService.instance
	if steam == null or not steam.available or lobby_id == 0:
		return false
	leave()
	over_steam = true
	steam.join_lobby(lobby_id)
	return true


func _start_host(peer: MultiplayerPeer) -> void:
	if peer == null:
		_fail("Couldn't start hosting")
		return
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	my_seat = 0
	lobby = [{"kind": "host", "peer": 1, "name": "P1", "look": my_look_ids, "nick": my_nick}]
	_rebuild_lobby()
	hosted.emit()


func _start_client(peer: MultiplayerPeer) -> void:
	if peer == null:
		_fail("Couldn't connect to the host")
		return
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	lobby = []


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if over_steam and SteamService.instance:
		SteamService.instance.leave_lobby()
	over_steam = false
	role = Role.OFFLINE
	lobby = []
	_inputs.clear()
	_seen.clear()
	_counts.fill(0)


func set_bots(n: int) -> void:
	bot_count = n
	if is_host():
		_rebuild_lobby()


## How many people (not bots) are in the lobby.
func humans() -> int:
	var n := 0
	for s in lobby:
		if s.kind != "bot":
			n += 1
	return n


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	if humans() >= MAX_PLAYERS:
		_kick.rpc_id(id, "The game is full")
		return


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	for i in lobby.size():
		if lobby[i].peer == id:
			# Mid-match their seat is taken over by a bot (see main.gd);
			# in the lobby they just leave.
			lobby[i].kind = "bot"
			lobby[i].peer = 0
			lobby[i].left = true
	if not has_meta("in_match"):
		lobby = lobby.filter(func(s): return not s.get("left", false))
		_rebuild_lobby()
	lobby_changed.emit()
	event_received.emit("seat_dropped", {"peer": id})


func _on_connected() -> void:
	_hello.rpc_id(1, my_look_ids, my_nick)
	joined.emit()


## Keep humans first, then bots, and number the seats.
func _rebuild_lobby() -> void:
	var people := lobby.filter(func(s): return s.kind != "bot")
	var want_bots := clampi(bot_count, 0, MAX_PLAYERS - people.size())
	lobby = people
	for i in want_bots:
		lobby.append({"kind": "bot", "peer": 0, "look": {}})
	for i in lobby.size():
		lobby[i].name = ("BOT%d" % (i + 1)) if lobby[i].kind == "bot" else "P%d" % (i + 1)
	_lobby_update.rpc(lobby)
	lobby_changed.emit()


func _fail(reason: String) -> void:
	leave()
	failed.emit(reason)


func _drop(reason: String) -> void:
	leave()
	left.emit(reason)


# ------------------------------------------------------------ RPCs

@rpc("any_peer", "reliable")
func _hello(look_ids: Dictionary, nick: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if has_meta("in_match"):
		_kick.rpc_id(id, "That game has already started")
		return
	lobby.insert(humans(), {"kind": "player", "peer": id, "look": look_ids, "nick": nick.left(24)})
	_rebuild_lobby()


@rpc("authority", "reliable")
func _lobby_update(new_lobby: Array) -> void:
	lobby = new_lobby
	for i in lobby.size():
		if lobby[i].peer == multiplayer.get_unique_id():
			my_seat = i
	lobby_changed.emit()


@rpc("authority", "reliable")
func _kick(reason: String) -> void:
	_drop(reason)


## Host: forget people who left during the match (bots took their seats).
func drop_left() -> void:
	if not is_host():
		return
	var before := lobby.size()
	lobby = lobby.filter(func(s): return not s.get("left", false))
	if lobby.size() != before:
		_rebuild_lobby()


## Guest: I changed my look; tell the host so everyone sees it.
func send_look(look_ids: Dictionary) -> void:
	my_look_ids = look_ids
	if is_client():
		_set_look.rpc_id(1, look_ids)


@rpc("any_peer", "reliable")
func _set_look(look_ids: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	for i in lobby.size():
		if lobby[i].peer == id:
			lobby[i].look = look_ids
			_rebuild_lobby()
			look_changed.emit(i)
			return


## Host -> everyone: a game event (see main.gd `_on_net_event`).
func send_event(name: String, data: Dictionary) -> void:
	if is_host():
		_event.rpc(name, data)


@rpc("authority", "reliable")
func _event(name: String, data: Dictionary) -> void:
	event_received.emit(name, data)


## Host: send a snapshot if it's time (about 30 a second).
func send_snapshot(delta: float, make: Callable) -> void:
	if not is_host() or multiplayer.get_peers().is_empty():
		return
	_snap_wait -= delta
	if _snap_wait > 0.0:
		return
	_snap_wait = 1.0 / 30.0
	_snapshot.rpc(make.call())


@rpc("authority", "unreliable_ordered")
func _snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)


# ------------------------------------------------------------ Input

## Client: send my stick and button presses to the host. `key_set` is
## which local key set / controller this computer plays with.
func send_input(lean: Vector2, key_set: int) -> void:
	if not is_client():
		return
	for i in BUTTONS.size():
		var b: String = BUTTONS[i]
		var action := "roll" if b == "roll" else Controls.action_name(key_set, b)
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			_counts[i] += 1
	_send_input.rpc_id(1, lean, _counts)


@rpc("any_peer", "unreliable_ordered")
func _send_input(lean: Vector2, counts: Array) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	for i in lobby.size():
		if lobby[i].peer == id:
			_inputs[i] = {"lean": lean, "counts": counts}


## Host: the newest stick position from a remote seat.
func remote_lean(seat: int) -> Vector2:
	return _inputs.get(seat, {}).get("lean", Vector2.ZERO)


## Host: buttons a remote seat pressed since the last call. Call once per
## frame per seat.
func remote_presses(seat: int) -> Array:
	var out := []
	if not _inputs.has(seat):
		return out
	var counts: Array = _inputs[seat].counts
	var seen: Array = _seen.get(seat, [])
	if seen.size() != counts.size():
		seen = counts.duplicate()  # first packet: don't replay old presses
	for i in counts.size():
		if counts[i] > seen[i]:
			out.append(BUTTONS[i])
	_seen[seat] = counts.duplicate()
	return out
