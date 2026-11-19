extends Object
## A stand-in for the GodotSteam plugin, for tests on computers without
## Steam. It has the same functions and signals the game uses
## (steam_service.gd), remembers what the game asked for, and makes a
## "lobby" out of a local network connection so two copies of the game on
## one computer can play a match the way two Steam friends would.

signal lobby_created(result: int, lobby_id: int)
signal lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int)
signal join_requested(lobby_id: int, friend_id: int)
signal join_game_requested(friend_id: int, connect: String)

const LOBBY_BASE := 109775240000000000
const PORT := 24691
const HOST_ID := 76561198000000001
const CLIENT_ID := 76561198000000002

var my_id := CLIENT_ID
var nick := "Tester"
## What the game asked Steam to do (for the test to check).
var achievements := {}
var presence := {}
var lobby_data := {}
var joinable := true
var invite_dialogs := 0
var _owned := 0
var _pending: Array = []


func steamInitEx(_app_id: int, _embed: bool) -> Dictionary:
	return {"status": 0, "verbal": "ok"}


func restartAppIfNecessary(_app_id: int) -> bool:
	return false


func initRelayNetworkAccess() -> void:
	pass


func run_callbacks() -> void:
	# Steam answers on a later frame, so these fire one tick later too.
	var now := _pending
	_pending = []
	for c in now:
		c.call()


func getPersonaName() -> String:
	return nick


func getSteamID() -> int:
	return my_id


func getFriendPersonaName(_id: int) -> String:
	return "Friend"


func createLobby(_type: int, _max: int) -> void:
	_owned = LOBBY_BASE + PORT
	_pending.append(func(): lobby_created.emit(1, _owned))


func joinLobby(id: int) -> void:
	_pending.append(func(): lobby_joined.emit(id, 0, false, 1))


func leaveLobby(_id: int) -> void:
	_owned = 0


func getLobbyOwner(id: int) -> int:
	return my_id if id == _owned else HOST_ID


func setLobbyData(_id: int, key: String, value: String) -> bool:
	lobby_data[key] = value
	return true


func getLobbyData(_id: int, key: String) -> String:
	return SteamConfig.GAME_TAG if key == "game" else lobby_data.get(key, "")


func setLobbyJoinable(_id: int, on: bool) -> bool:
	joinable = on
	return true


func activateGameOverlayInviteDialog(_id: int) -> void:
	invite_dialogs += 1


func setRichPresence(key: String, value: String) -> bool:
	presence[key] = value
	return true


func setAchievement(id: String) -> bool:
	achievements[id] = true
	return true


func clearAchievement(id: String) -> bool:
	achievements.erase(id)
	return true


func indicateAchievementProgress(_id: String, _now: int, _goal: int) -> bool:
	return true


func storeStats() -> bool:
	return true


## Instead of SteamMultiplayerPeer: a local connection on PORT.
func make_peer(_lobby_id: int, hosting: bool) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 3) if hosting else peer.create_client("127.0.0.1", PORT)
	return peer if err == OK else null
