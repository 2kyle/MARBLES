class_name SteamService
extends Node
## Talks to Steam through the GodotSteam plugin (addons/godotsteam).
##
## Everything here is optional: if the plugin isn't installed or Steam isn't
## running, `available` is false and the game plays as normal (local play,
## and online by address still work). Nothing outside this file talks to
## Steam directly, so the plugin can be missing without breaking anything.
##
## What it does:
##   - starts Steam with SteamConfig.APP_ID and keeps its callbacks running
##   - friends-only lobbies for online play (host, join, invite friends)
##   - answers "Join game" from the Steam friends list and invite pop-ups,
##     even when the game was started by accepting an invite
##   - rich presence, so friends see what you're doing
##   - achievements (see achievements.gd)
##
## Online play over Steam uses the plugin's SteamMultiplayerPeer, so the
## rest of the game (net.gd) works exactly as it does over an address: no
## port forwarding, and nobody sees anyone else's IP address.

## A lobby we made is ready (we own it): start hosting in it.
signal lobby_hosted(lobby_id: int)
## We joined someone else's lobby: connect to its owner.
signal lobby_entered(lobby_id: int)
## Creating or joining a lobby didn't work.
signal lobby_failed(reason: String)
## A friend invited us (or we picked "Join game" on a friend): join it.
signal invite_accepted(lobby_id: int)

const LOBBY_FRIENDS_ONLY := 1
const ENTER_SUCCESS := 1

## The one SteamService (made by main.gd); other scripts read it through here.
static var instance: SteamService

## True once Steam started.
var available := false
## Why Steam isn't available (for the menu), or "".
var problem := ""
## The lobby we're in, or 0.
var lobby_id := 0
## A lobby to join as soon as the menus are ready (we were started from an
## invite).
var pending_lobby := 0

## The Steam API object. Normally the plugin's "Steam" singleton; tests swap
## in a stand-in with the same functions (see tests/fake_steam.gd).
var api: Object


func _init(backend: Object = null) -> void:
	instance = self
	api = backend


func _ready() -> void:
	if api == null and Engine.has_singleton("Steam"):
		api = Engine.get_singleton("Steam")
	if api == null:
		problem = "Steam isn't set up in this copy of the game"
		return
	if SteamConfig.RESTART_THROUGH_STEAM and SteamConfig.APP_ID != 480 \
			and api.restartAppIfNecessary(SteamConfig.APP_ID):
		get_tree().quit()
		return
	var started: Dictionary = api.steamInitEx(SteamConfig.APP_ID, false)
	if int(started.get("status", 1)) != 0:
		problem = "Steam isn't running (%s)" % started.get("verbal", "no reason given")
		return
	available = true
	api.lobby_created.connect(_on_lobby_created)
	api.lobby_joined.connect(_on_lobby_joined)
	api.join_requested.connect(func(lobby: int, _friend: int): invite_accepted.emit(lobby))
	api.join_game_requested.connect(func(_friend: int, connect: String):
		var lobby := _lobby_from_text(connect)
		if lobby:
			invite_accepted.emit(lobby))
	if api.has_method("initRelayNetworkAccess"):
		api.initRelayNetworkAccess()
	pending_lobby = _lobby_from_text(" ".join(OS.get_cmdline_args()))
	presence("In the menus")
	# Achievements earned while Steam wasn't running get copied over now.
	var earned := Achievements.unlocked_ids()
	for id in earned:
		api.setAchievement(id)
	if not earned.is_empty():
		api.storeStats()


func _process(_delta: float) -> void:
	if available:
		api.run_callbacks()


func _exit_tree() -> void:
	leave_lobby()
	if instance == self:
		instance = null


## The Steam name of whoever's playing, or "" without Steam.
func my_name() -> String:
	return api.getPersonaName() if available else ""


func my_id() -> int:
	return api.getSteamID() if available else 0


# ------------------------------------------------------------ Lobbies

## Make a friends-only lobby. `lobby_hosted` fires when it's ready.
func host_lobby() -> void:
	leave_lobby()
	api.createLobby(LOBBY_FRIENDS_ONLY, NetSession.MAX_PLAYERS)


## Join a friend's lobby. `lobby_entered` fires once we're in.
func join_lobby(id: int) -> void:
	leave_lobby()
	api.joinLobby(id)


func leave_lobby() -> void:
	if available and lobby_id != 0:
		api.leaveLobby(lobby_id)
	lobby_id = 0
	if available:
		api.setRichPresence("connect", "")


## Open the Steam overlay's "invite friends" list for our lobby.
func invite_friends() -> void:
	if available and lobby_id != 0:
		api.activateGameOverlayInviteDialog(lobby_id)


## Stop new people joining once a match starts (and let them in again after).
func set_joinable(joinable: bool) -> void:
	if available and lobby_id != 0:
		api.setLobbyJoinable(lobby_id, joinable)


## A network connection for the lobby: hosting (we own it) or joining.
## Returns null if it couldn't be made.
func make_peer(hosting: bool) -> MultiplayerPeer:
	if api.has_method("make_peer"):
		return api.make_peer(lobby_id, hosting)   # test stand-in
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = peer.host_with_lobby(lobby_id) if hosting else peer.connect_to_lobby(lobby_id)
	return peer if err == OK else null


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1 or id == 0:
		lobby_failed.emit("Steam couldn't make a lobby (error %d)" % result)
		return
	lobby_id = id
	api.setLobbyData(id, "game", SteamConfig.GAME_TAG)
	api.setLobbyData(id, "name", "%s's game" % my_name())
	api.setLobbyJoinable(id, true)
	api.setRichPresence("connect", "+connect_lobby %d" % id)
	lobby_hosted.emit(id)


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if api.getLobbyOwner(id) == my_id():
		return   # our own lobby: handled by _on_lobby_created
	if response != ENTER_SUCCESS:
		lobby_failed.emit(_enter_problem(response))
		return
	if api.getLobbyData(id, "game") != SteamConfig.GAME_TAG:
		api.leaveLobby(id)
		lobby_failed.emit("That lobby is for a different game")
		return
	lobby_id = id
	api.setRichPresence("connect", "+connect_lobby %d" % id)
	lobby_entered.emit(id)


static func _enter_problem(response: int) -> String:
	match response:
		2: return "That lobby doesn't exist any more"
		4: return "That game is full"
		5: return "Steam had a problem joining"
		6: return "You're banned from that lobby"
		7: return "That lobby is limited"
		8: return "Clan-only lobby"
		9: return "Steam has locked your community features"
		10: return "Someone in that lobby has blocked you"
		11: return "You've blocked someone in that lobby"
	return "Couldn't join (Steam said %d)" % response


## Pull a lobby id out of "+connect_lobby 1234..." (or 0).
static func _lobby_from_text(text: String) -> int:
	var at := text.find("+connect_lobby")
	if at < 0:
		return 0
	var rest := text.substr(at + "+connect_lobby".length()).strip_edges()
	return int(rest.get_slice(" ", 0))


# ------------------------------------------------------------ Presence

## What friends see under your name, like "In a match (frame 3/10)".
func presence(text: String) -> void:
	if available:
		api.setRichPresence("status", text)


# ------------------------------------------------------------ Achievements

## Unlock an achievement on Steam (it's saved locally too, by Achievements).
func unlock(api_name: String) -> void:
	if available:
		api.setAchievement(api_name)
		api.storeStats()


## Show "12 / 50" progress on a counting achievement in the overlay.
func progress(api_name: String, now: int, goal: int) -> void:
	if available and now < goal:
		api.indicateAchievementProgress(api_name, now, goal)


## Wipe every achievement on this Steam account (for testing).
func reset_all(names: Array) -> void:
	if available:
		for n in names:
			api.clearAchievement(n)
		api.storeStats()
