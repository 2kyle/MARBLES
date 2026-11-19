class_name Blackjack
extends Node3D
## BLACKJACK at the casino: up to four players at one table, each playing
## their own hand against the dealer (a marble in shady sunglasses).
##
## How a hand goes:
##   - set your wager (up / down, 10 coins a step) and press your place key
##     to deal. You get two cards, the dealer gets two (one face down).
##   - place key: HIT (take a card). Turn key: STAND (keep what you have).
##     Go over 21 and you bust (lose your wager).
##   - when you stand, the dealer turns their card over and must take cards
##     until they have 17 or more. Closest to 21 without going over wins.
##   - win: double your wager back. Blackjack (21 with your first two
##     cards): 2.5x back. A tie ("push"): your wager back.
## Cards: 2-10 are worth their number, J Q K are 10, an Ace is 11 or 1.
##
## Like the derby, this never reads the keyboard: main.gd calls the
## request_* functions. The cards also show on the felt in front of each
## seat, so people watching can follow along.

enum Phase { BETTING, PLAYING, DEALER, DONE }

const WAGER_STEP := 10
const MIN_WAGER := 10
## Seconds between the dealer's cards, so you can watch them land.
const DEALER_PACE := 0.7
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
## Suits: 0 spades, 1 hearts, 2 diamonds, 3 clubs.
const SUIT_LETTERS := ["S", "H", "D", "C"]

## Where each seat's cards lie on the felt (this node's own space), and
## where the dealer's go.
const SEAT_SPOTS := [Vector3(-1.4, 0, 1.0), Vector3(-0.5, 0, 1.45), Vector3(0.5, 0, 1.45), Vector3(1.4, 0, 1.0)]
const DEALER_SPOT := Vector3(0, 0, -0.7)
const CARD_SIZE := Vector2(0.34, 0.48)
const TABLE_TOP := 1.02

var profiles: Profiles
## One hand per seat: {phase, wager, cards: [[rank, suit]...],
## dealer: [[rank, suit]...], hidden (dealer's 2nd card face down),
## message, timer}.
var seats: Array = []
## Which of the four stools each player sat down at (their cards go there).
var seat_of: Array = [0, 1, 2, 3]

var _rng := RandomNumberGenerator.new()
var _card_nodes: Array = [[], [], [], []]


func _ready() -> void:
	_rng.randomize()
	for p in 4:
		seats.append({"phase": Phase.BETTING, "wager": 20, "cards": [], "dealer": [], "hidden": true,
				"message": "", "timer": 0.0})


# ------------------------------------------------------------ Requests

func request_wager(p: int, step: int) -> void:
	var s: Dictionary = seats[p]
	if s.phase != Phase.BETTING and s.phase != Phase.DONE:
		return
	var most := maxi(profiles.coins(p) if profiles else MIN_WAGER, MIN_WAGER)
	s.wager = clampi(s.wager + step * WAGER_STEP, MIN_WAGER, most)
	if s.phase == Phase.DONE:
		_clear(p)


## Place key: deal a new hand, or hit.
func request_confirm(p: int) -> void:
	var s: Dictionary = seats[p]
	match s.phase:
		Phase.BETTING, Phase.DONE:
			_deal(p)
		Phase.PLAYING:
			s.cards.append(_draw())
			var v := value(s.cards)
			if v > 21:
				_finish(p, "BUST! -%d" % s.wager, 0)
			elif v == 21:
				_stand(p)
	_show_cards(p)


## Turn key: stand. Returns false if there's no hand going (so the turn
## key can mean "leave the table" instead).
func request_stand(p: int) -> bool:
	if seats[p].phase != Phase.PLAYING:
		return false
	_stand(p)
	_show_cards(p)
	return true


## True while a hand is being played (you can't walk away mid-hand).
func busy(p: int) -> bool:
	return seats[p].phase == Phase.PLAYING or seats[p].phase == Phase.DEALER


## Walked away from the table: tidy up the felt.
func leave(p: int) -> void:
	if not busy(p):
		_clear(p)


# ------------------------------------------------------------ Rules

## A hand's best total: Aces count 11 unless that would bust.
static func value(cards: Array) -> int:
	var total := 0
	var aces := 0
	for c in cards:
		var r: int = c[0]
		if r == 0:
			aces += 1
			total += 11
		else:
			total += mini(r + 1, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


static func card_name(c: Array) -> String:
	return RANKS[c[0]]


func _draw() -> Array:
	return [_rng.randi() % 13, _rng.randi() % 4]


func _deal(p: int) -> void:
	var s: Dictionary = seats[p]
	if profiles == null or profiles.coins(p) < s.wager:
		s.message = "Not enough coins"
		return
	profiles.add_coins(p, -s.wager)
	profiles.save_to_disk()
	s.cards = [_draw(), _draw()]
	s.dealer = [_draw(), _draw()]
	s.hidden = true
	s.phase = Phase.PLAYING
	s.message = ""
	if value(s.cards) == 21:
		s.hidden = false
		if value(s.dealer) == 21:
			_finish(p, "Both blackjack: push", s.wager)
		else:
			_finish(p, "BLACKJACK! +%d" % roundi(s.wager * 1.5), roundi(s.wager * 2.5))


func _stand(p: int) -> void:
	var s: Dictionary = seats[p]
	s.phase = Phase.DEALER
	s.hidden = false
	s.timer = DEALER_PACE


func _finish(p: int, text: String, pay: int) -> void:
	var s: Dictionary = seats[p]
	s.phase = Phase.DONE
	s.hidden = false
	s.message = text
	if pay > 0 and profiles:
		profiles.add_coins(p, pay)
		profiles.save_to_disk()
		if profiles.coins(p) >= 1000:
			Achievements.unlock("PIGGY_BANK")


func _clear(p: int) -> void:
	var s: Dictionary = seats[p]
	s.phase = Phase.BETTING
	s.cards = []
	s.dealer = []
	s.message = ""
	_show_cards(p)


## Called every physics tick: the dealer plays out their hand.
func update(delta: float) -> void:
	for p in 4:
		var s: Dictionary = seats[p]
		if s.phase != Phase.DEALER:
			continue
		s.timer -= delta
		if s.timer > 0.0:
			continue
		s.timer = DEALER_PACE
		var d := value(s.dealer)
		if d < 17:
			s.dealer.append(_draw())
			_show_cards(p)
			continue
		var me := value(s.cards)
		if d > 21:
			_finish(p, "Dealer busts! +%d" % s.wager, s.wager * 2)
		elif me > d:
			_finish(p, "You win! +%d" % s.wager, s.wager * 2)
		elif me == d:
			_finish(p, "Push: wager back", s.wager)
		else:
			_finish(p, "Dealer wins. -%d" % s.wager, 0)
		_show_cards(p)


# ------------------------------------------------------------ Cards on the felt

## Lay seat p's cards (and the dealer's cards for them) on the table.
func _show_cards(p: int) -> void:
	for n in _card_nodes[p]:
		n.queue_free()
	_card_nodes[p] = []
	var s: Dictionary = seats[p]
	var k: int = seat_of[p]
	var spot: Vector3 = SEAT_SPOTS[k]
	for i in s.cards.size():
		_card_nodes[p].append(_card(s.cards[i], spot + Vector3(i * 0.37 - 0.3, 0, -i * 0.04), false, -spot.x * 0.25))
	# The dealer deals each seat's hand in its own little row.
	var drow := DEALER_SPOT + Vector3((k - 1.5) * 1.15, 0, 0)
	for i in s.dealer.size():
		_card_nodes[p].append(_card(s.dealer[i], drow + Vector3(i * 0.3 - 0.3, 0, 0), i == 1 and s.hidden, 0.0))


func _card(c: Array, at: Vector3, face_down: bool, yaw: float) -> Node3D:
	var card := Node3D.new()
	card.position = at + Vector3(0, TABLE_TOP + 0.01, 0)
	card.rotation.y = yaw
	add_child(card)
	var red: bool = c[1] == 1 or c[1] == 2
	LowPoly.box(card, Vector3(CARD_SIZE.x, 0.012, CARD_SIZE.y), Vector3.ZERO, Color(0.95, 0.15, 0.25) if face_down else Color(0.98, 0.97, 0.94))
	if not face_down:
		var l := LowPoly.label(card, Vector3(0, 0.012, 0), card_name(c) + SUIT_LETTERS[c[1]], 40,
				Color(1, 1, 1, 0), 0.0)
		l.rotation.x = -PI / 2
		l.modulate = Color(0.85, 0.1, 0.15) if red else Color(0.08, 0.08, 0.1)
		l.outline_size = 0
		l.pixel_size = 0.0042
	# Cards land with a little drop.
	card.position.y += 0.3
	card.create_tween().tween_property(card, "position:y", at.y + TABLE_TOP + 0.01, 0.18)
	return card
