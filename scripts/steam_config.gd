class_name SteamConfig
extends RefCounted
## Steam settings in one place.
##
## APP_ID is the number Steam gives your game when you pay the Steam Direct
## fee. Until then it's 480, Valve's free test app ("Spacewar"): lobbies,
## invites and online play all work with it, and your friends need Steam
## running too. Achievements only show up once you use your own App ID and
## have added them on the Steamworks site (see docs/STEAM.md).

const APP_ID := 480

## Shown on Steam lobbies so we only ever join our own game's lobbies (lots
## of test games share App ID 480).
const GAME_TAG := "marbles4p"

## If true and the game wasn't started from Steam, ask Steam to restart it
## through the Steam client. Turn on for the real release so the overlay
## and invites always work.
const RESTART_THROUGH_STEAM := false
