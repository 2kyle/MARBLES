class_name CrateScreen
extends CanvasLayer
## The loot crate screen, opened from the LOOT CRATES machine in the
## casino. One player at a time pays coins, the crate pops open and a long
## strip of prizes spins past a gold marker, slowing down until it stops on
## what you won (the rarer the colour under it, the better). Then the prize
## card pops up. The odds live in loot_crates.gd and are shown on screen.
##
## The prize is decided BEFORE the strip spins (LootCrates.open); the strip
## is just a show, filled with random picks at the real odds.
##
## Like the closet, it never reads the keyboard: main.gd calls
## request_confirm() with the player's input.

const TITLE_FONT := preload("res://fonts/Righteous-Regular.ttf")
const GOLD := Color(1.0, 0.82, 0.3)
## How long the strip spins, how many prizes are on it, and which one it
## stops on.
const SPIN_TIME := 6.0
const REEL_COUNT := 48
const REEL_WIN := 41
const TILE := Vector2(170, 200)
const TILE_GAP := 8.0

enum Step { IDLE, SPINNING, REVEAL }

## Fired when someone wins the Golden Marble Trophy.
signal trophy_won(player: int)

var player := -1
var profiles: Profiles
var step := Step.IDLE
var prize: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _ui: Control
var _coins: Label
var _prompt: Label
var _odds: Control   # the "what's inside" list, hidden while the reel spins
var _hint: Label
var _crate: Node3D
var _lid: Node3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _reveal: Control
var _aura: TextureRect
var _rays: Rays
var _confetti: CPUParticles2D
var _t := 0.0
var _reel: Control        # the window the strip shows through
var _strip: Control       # the long row of prize tiles
var _marker: Control
var _reel_from := 0.0
var _reel_to := 0.0
var _reel_tick := -1
var _box: SubViewportContainer


func _ready() -> void:
	layer = 10
	visible = false
	_rng.randomize()


func is_open() -> bool:
	return player >= 0


## While the strip is spinning the player can't leave (so you always see
## what you paid for).
func busy() -> bool:
	return step == Step.SPINNING


func open(p: int, p_profiles: Profiles) -> void:
	player = p
	profiles = p_profiles
	_build()
	visible = true
	_reset_crate()


func close() -> void:
	player = -1
	visible = false
	if _ui:
		_ui.queue_free()
		_ui = null


func request_confirm() -> void:
	if not is_open():
		return
	match step:
		Step.IDLE:
			var won := LootCrates.open(profiles, player, _rng)
			if won.is_empty():
				_shake_label(_prompt)
				_prompt.text = "NOT ENOUGH COINS: NEED %d" % LootCrates.PRICE
				return
			prize = won
			profiles.save_to_disk()
			step = Step.SPINNING
			_t = 0.0
			_coins.text = str(profiles.coins(player) - _coins_back())
			_prompt.text = ""
			_odds.visible = false
			_hint.visible = false
			_start_reel()
		Step.REVEAL:
			_reset_crate()


## Coins this prize paid out (shown after the reveal, not before).
func _coins_back() -> int:
	if prize.kind == "coins":
		return prize.amount
	return prize.get("coins_back", 0)


func _process(delta: float) -> void:
	if not is_open():
		return
	_t += delta
	match step:
		Step.IDLE:
			_crate.rotation.y = sin(_t * 0.8) * 0.25
			_crate.position.y = sin(_t * 2.0) * 0.04
		Step.SPINNING:
			_spin_reel()
			if _t >= SPIN_TIME + 0.6:
				_show_prize()
		Step.REVEAL:
			if _rays:
				_rays.rotation += delta * 0.4


func _reset_crate() -> void:
	step = Step.IDLE
	_odds.visible = true
	_hint.visible = true
	_t = 0.0
	prize = {}
	_reveal.visible = false
	_reel.visible = false
	_box.modulate = Color.WHITE
	_confetti.emitting = false
	_crate.visible = true
	_crate.rotation = Vector3.ZERO
	_crate.scale = Vector3.ONE * 0.3
	_lid.position = Vector3.ZERO
	_lid.rotation = Vector3.ZERO
	_glow_mat.emission = Color(1, 0.95, 0.8)
	_glow_mat.emission_energy_multiplier = 1.0
	_light.light_energy = 0.0
	_aura.modulate = Color(1, 1, 1, 0)
	var tw := _crate.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_crate, "scale", Vector3.ONE, 0.35)
	_coins.text = str(profiles.coins(player))
	if profiles.coins(player) >= LootCrates.PRICE:
		_prompt.text = "%s  OPEN FOR %d COINS" % [Hud._key_names(player).confirm, LootCrates.PRICE]
		_prompt.add_theme_color_override("font_color", Color.WHITE)
	else:
		_prompt.text = "NEED %d COINS: WIN MORE IN MATCHES OR THE DERBY" % LootCrates.PRICE
		_prompt.add_theme_color_override("font_color", Color(1, 0.6, 0.55))


func _show_prize() -> void:
	_hint.visible = true
	step = Step.REVEAL
	_t = 0.0
	_reel.create_tween().tween_property(_reel, "modulate:a", 0.0, 0.3)
	var color := Cosmetics.rarity_color(prize.rarity)
	# Fill in the reveal card.
	for c in _reveal.get_node("Card/Box/Icon").get_children():
		c.queue_free()
	var icon: Control
	match prize.kind:
		"coins": icon = ItemIcons.make("coins", {}, Color.WHITE, 220)
		"trophy": icon = ItemIcons.make("trophy", prize.item, Color.WHITE, 220)
		_:
			var base: Color = Cosmetics.find("color", profiles.equipped(player, "color")).color
			icon = ItemIcons.make(prize.slot, prize.item, base, 220)
	_reveal.get_node("Card/Box/Icon").add_child(icon)
	var rarity: Label = _reveal.get_node("Card/Box/Rarity")
	var name: Label = _reveal.get_node("Card/Box/Name")
	var note: Label = _reveal.get_node("Card/Box/Note")
	rarity.text = Cosmetics.rarity_name(prize.rarity).to_upper()
	rarity.add_theme_color_override("font_color", color)
	match prize.kind:
		"coins":
			rarity.text = "COINS"
			rarity.add_theme_color_override("font_color", GOLD)
			name.text = "+%d COINS" % prize.amount
			note.text = ""
		"trophy":
			name.text = prize.item.name.to_upper()
			note.text = "1 IN 100! IT NOW STANDS ON YOUR ISLAND" if not prize.duplicate \
					else "ALREADY YOURS: +%d COINS" % prize.coins_back
		_:
			name.text = prize.item.name.to_upper()
			var slot_name: String = Cosmetics.SLOT_NAMES[prize.slot]
			note.text = ("NEW %s!  WEAR IT IN THE CLOSET" % slot_name.trim_suffix("S")) if not prize.duplicate \
					else "DUPLICATE: +%d COINS" % prize.coins_back
	var card: PanelContainer = _reveal.get_node("Card")
	var cs: StyleBoxFlat = card.get_theme_stylebox("panel")
	cs.border_color = color if prize.kind != "coins" else GOLD
	_rays.color = cs.border_color
	_reveal.visible = true
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2.ONE * 0.2
	card.rotation = -0.3
	var pop := card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "scale", Vector2.ONE, 0.45)
	pop.tween_property(card, "rotation", 0.0, 0.45)
	_rays.modulate.a = 0.0
	_rays.create_tween().tween_property(_rays, "modulate:a", 1.0, 0.3)
	# Coins tick up to the new total.
	var start := int(_coins.text)
	_coins.create_tween().tween_method(func(v: float): _coins.text = str(int(v)),
			float(start), float(profiles.coins(player)), 0.6).set_delay(0.3)
	_confetti.color = cs.border_color
	_confetti.amount = 160 if prize.kind == "trophy" else 70
	_confetti.restart()
	_confetti.emitting = true
	_prompt.text = "%s  AGAIN" % Hud._key_names(player).confirm
	_prompt.add_theme_color_override("font_color", Color.WHITE)
	if prize.kind == "trophy" and not prize.duplicate:
		trophy_won.emit(player)
	Achievements.unlock("FIRST_CRATE")
	if prize.kind == "trophy":
		Achievements.unlock("GOLDEN_MARBLE")
	elif prize.get("rarity", "") == "legendary" and prize.kind == "item":
		Achievements.unlock("LEGENDARY")
	if profiles.coins(player) >= 1000:
		Achievements.unlock("PIGGY_BANK")


func _shake_label(l: Label) -> void:
	l.pivot_offset = l.size / 2.0
	var tw := l.create_tween()
	for k in 4:
		tw.tween_property(l, "position:x", l.position.x + (8 if k % 2 == 0 else -8), 0.04)
	tw.tween_property(l, "position:x", l.position.x, 0.04)


# ------------------------------------------------------------ Building

func _build() -> void:
	if _ui:
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.texture = Closet._gradient([Color(0.3, 0.2, 0.45), Color(0.08, 0.07, 0.18)], true)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_ui.add_child(bg)
	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.08, 0.07, 0.18)
	dark.show_behind_parent = true
	_ui.add_child(dark)
	_ui.move_child(dark, 0)

	var title := _label("LOOT CRATE", 64, Color.WHITE)
	title.position = Vector2(48, 22)
	_ui.add_child(title)
	var who := _label("PLAYER %d" % (player + 1), 26, Cosmetics.find("color", profiles.equipped(player, "color")).color)
	who.position = Vector2(54, 100)
	_ui.add_child(who)

	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0, 0, 0, 0.35)
	cs.set_corner_radius_all(26)
	cs.content_margin_left = 10
	cs.content_margin_right = 22
	cs.border_color = GOLD
	cs.set_border_width_all(3)
	chip.add_theme_stylebox_override("panel", cs)
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.offset_left = -260
	chip.offset_right = -40
	chip.offset_top = 30
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	chip.add_child(row)
	var coin := ItemIcons.CoinIcon.new()
	coin.custom_minimum_size = Vector2(56, 56)
	row.add_child(coin)
	_coins = _label(str(profiles.coins(player)), 40, GOLD)
	row.add_child(_coins)
	_ui.add_child(chip)

	# A glow behind the crate that grows in the prize's colour as it shakes.
	_aura = TextureRect.new()
	_aura.texture = Closet._gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 0)], true)
	_aura.stretch_mode = TextureRect.STRETCH_SCALE
	_aura.anchor_left = 0.5
	_aura.anchor_right = 0.5
	_aura.anchor_top = 0.42
	_aura.anchor_bottom = 0.42
	_aura.offset_left = -420
	_aura.offset_right = 420
	_aura.offset_top = -420
	_aura.offset_bottom = 420
	_aura.pivot_offset = Vector2(420, 420)
	_aura.modulate = Color(1, 1, 1, 0)
	_ui.add_child(_aura)
	# The crate itself, in its own little 3D world.
	var box := SubViewportContainer.new()
	_box = box
	box.stretch = true
	box.anchor_left = 0.2
	box.anchor_right = 0.8
	box.anchor_top = 0.12
	box.anchor_bottom = 0.84
	_ui.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	ItemIcons._studio(world)
	var cam := Camera3D.new()
	cam.fov = 34.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 4.2), Vector3(0, 0.35, 0))
	_crate = ItemIcons.crate_model()
	world.add_child(_crate)
	_lid = _crate.get_node("Lid")
	_glow_mat = (_crate.get_node("Seam") as MeshInstance3D).material_override
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.3, 0.4)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_crate.add_child(_light)

	_build_reel()

	# Rays + reveal card, over the crate.
	_reveal = Control.new()
	_reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reveal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_reveal)
	_rays = Rays.new()
	_rays.anchor_left = 0.5
	_rays.anchor_right = 0.5
	_rays.anchor_top = 0.47
	_rays.anchor_bottom = 0.47
	_reveal.add_child(_rays)
	var card := PanelContainer.new()
	card.name = "Card"
	var cst := StyleBoxFlat.new()
	cst.bg_color = Color(0.12, 0.12, 0.22, 1.0)
	cst.set_corner_radius_all(24)
	cst.set_border_width_all(6)
	cst.content_margin_left = 30
	cst.content_margin_right = 30
	cst.content_margin_top = 18
	cst.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", cst)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.47
	card.anchor_bottom = 0.47
	card.offset_left = -230
	card.offset_right = 230
	card.offset_top = -230
	card.offset_bottom = 230
	_reveal.add_child(card)
	var col := VBoxContainer.new()
	col.name = "Box"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	for n in [["Rarity", 30], ["Icon", 0], ["Name", 40], ["Note", 20]]:
		var c: Control
		if n[0] == "Icon":
			c = CenterContainer.new()
			c.custom_minimum_size = Vector2(220, 220)
		else:
			c = _label("", n[1], Color.WHITE)
			(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.name = n[0]
		col.add_child(c)
	_confetti = CPUParticles2D.new()
	_confetti.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0, get_viewport().get_visible_rect().size.y * 0.47)
	_confetti.emitting = false
	_confetti.one_shot = true
	_confetti.explosiveness = 0.95
	_confetti.lifetime = 1.6
	_confetti.direction = Vector2(0, -1)
	_confetti.spread = 180.0
	_confetti.initial_velocity_min = 260.0
	_confetti.initial_velocity_max = 620.0
	_confetti.gravity = Vector2(0, 700)
	_confetti.scale_amount_min = 6.0
	_confetti.scale_amount_max = 12.0
	_confetti.angular_velocity_min = -400
	_confetti.angular_velocity_max = 400
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	_confetti.color_ramp = ramp
	_reveal.add_child(_confetti)
	_reveal.visible = false

	# Odds, so nobody has to guess.
	var odds := VBoxContainer.new()
	odds.anchor_left = 1.0
	odds.anchor_right = 1.0
	odds.anchor_top = 0.3
	odds.offset_left = -270
	odds.offset_right = -40
	odds.add_theme_constant_override("separation", 4)
	_ui.add_child(odds)
	_odds = odds
	odds.add_child(_label("WHAT'S INSIDE", 22, Color(1, 1, 1, 0.8)))
	var look_share := 1.0 - LootCrates.TROPHY_CHANCE - LootCrates.COIN_CHANCE
	var total := 0.0
	for w in LootCrates.RARITY_WEIGHTS.values():
		total += w
	for r in LootCrates.RARITY_WEIGHTS:
		var pct: float = LootCrates.RARITY_WEIGHTS[r] / total * look_share * 100.0
		odds.add_child(_label("%s  %.1f%%" % [Cosmetics.rarity_name(r), pct], 20, Cosmetics.rarity_color(r)))
	odds.add_child(_label("Coins  %d%%" % roundi(LootCrates.COIN_CHANCE * 100.0), 20, GOLD))
	odds.add_child(_label("%s  %d%%" % [Cosmetics.TROPHY.name, roundi(LootCrates.TROPHY_CHANCE * 100.0)], 20,
			Cosmetics.rarity_color("ultra")))
	odds.add_child(_label("Duplicates pay coins back", 16, Color(1, 1, 1, 0.55)))

	_prompt = _label("", 32, Color.WHITE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.86
	_ui.add_child(_prompt)
	var k := Hud._key_names(player)
	var hint := _label("%s  Open      %s  Leave" % [k.confirm, k.rotate], 20, Color(1, 1, 1, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_right = 1.0
	hint.anchor_top = 0.94
	_ui.add_child(hint)
	_hint = hint


# ------------------------------------------------------------ The reel

## The strip of prizes and the gold marker in the middle of the screen.
func _build_reel() -> void:
	_reel = Control.new()
	_reel.clip_contents = true
	_reel.anchor_left = 0.0
	_reel.anchor_right = 1.0
	_reel.anchor_top = 0.5
	_reel.anchor_bottom = 0.5
	_reel.offset_top = -TILE.y / 2.0 - 22.0
	_reel.offset_bottom = TILE.y / 2.0 + 22.0
	_reel.visible = false
	_ui.add_child(_reel)
	var back := ColorRect.new()
	back.color = Color(0.03, 0.03, 0.08, 0.85)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reel.add_child(back)
	_strip = Control.new()
	_strip.position = Vector2(0, 22)
	_reel.add_child(_strip)
	# Fade the ends so tiles slide in and out of the dark.
	for side in [0, 1]:
		var fade := TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.03, 0.03, 0.08, 1.0) if side == 0 else Color(0.03, 0.03, 0.08, 0.0))
		g.set_color(1, Color(0.03, 0.03, 0.08, 0.0) if side == 0 else Color(0.03, 0.03, 0.08, 1.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 64
		gt.height = 4
		fade.texture = gt
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.anchor_left = 0.0 if side == 0 else 0.82
		fade.anchor_right = 0.18 if side == 0 else 1.0
		fade.anchor_bottom = 1.0
		_reel.add_child(fade)
	_marker = Marker.new()
	_marker.anchor_left = 0.5
	_marker.anchor_right = 0.5
	_marker.anchor_bottom = 1.0
	_reel.add_child(_marker)


## Fill the strip with random prizes at the real odds, put the real prize
## at REEL_WIN, and work out where the strip has to stop.
func _start_reel() -> void:
	for c in _strip.get_children():
		c.queue_free()
	var fake := RandomNumberGenerator.new()
	fake.randomize()
	var base: Color = Cosmetics.find("color", profiles.equipped(player, "color")).color
	for i in REEL_COUNT:
		var item: Dictionary = prize if i == REEL_WIN else LootCrates.roll(fake)
		var tile := _tile(item, base)
		tile.position = Vector2(i * (TILE.x + TILE_GAP), 0)
		_strip.add_child(tile)
	var width := get_viewport().get_visible_rect().size.x
	var stop := REEL_WIN * (TILE.x + TILE_GAP) + TILE.x * (0.5 + _rng.randf_range(-0.38, 0.38))
	_reel_from = width * 0.15
	_reel_to = width / 2.0 - stop
	_strip.position.x = _reel_from
	_reel_tick = -1
	_reel.modulate = Color.WHITE
	_reel.visible = true
	# The crate pops its lid and steps back to make room.
	var tw := _crate.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lid, "position", Vector3(0.6, 1.6, -0.4), 0.4)
	tw.tween_property(_lid, "rotation", Vector3(-1.2, 0.4, 0.9), 0.4)
	_box.create_tween().tween_property(_box, "modulate:a", 0.25, 0.4)


func _spin_reel() -> void:
	var u := clampf(_t / SPIN_TIME, 0.0, 1.0)
	# Fast at first, then a long slow crawl at the end (ease out).
	var e := 1.0 - pow(1.0 - u, 4.0)
	_strip.position.x = lerpf(_reel_from, _reel_to, e)
	var middle := get_viewport().get_visible_rect().size.x / 2.0 - _strip.position.x
	var under := floori(middle / (TILE.x + TILE_GAP))
	if under != _reel_tick:
		# A little bump of the marker for every tile that passes it.
		_reel_tick = under
		_marker.scale = Vector2(1.25, 1.0)
		_marker.create_tween().tween_property(_marker, "scale", Vector2.ONE, 0.08)
	var col := Cosmetics.rarity_color(prize.rarity) if prize.kind != "coins" else GOLD
	if u >= 1.0 and _strip.get_child_count() > REEL_WIN:
		var win: Control = _strip.get_child(REEL_WIN)
		if win.scale == Vector2.ONE:
			win.pivot_offset = TILE / 2.0
			win.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
					.tween_property(win, "scale", Vector2.ONE * 1.12, 0.25)
			_aura.modulate = Color(col, 0.8)
	_light.light_color = col
	_light.light_energy = u * 3.0


## One prize on the strip: its picture, its name and a stripe of its
## rarity colour.
func _tile(item: Dictionary, base: Color) -> Control:
	var color: Color = GOLD if item.kind == "coins" else Cosmetics.rarity_color(item.rarity)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.13, 0.24).lerp(color, 0.12)
	st.set_corner_radius_all(10)
	st.border_width_bottom = 8
	st.border_color = color
	st.content_margin_top = 8
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = TILE
	panel.size = TILE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(TILE.x, 128)
	col.add_child(holder)
	var icon: Control
	match item.kind:
		"coins": icon = ItemIcons.make("coins", {}, Color.WHITE, 112)
		"trophy": icon = ItemIcons.make("trophy", item.item, Color.WHITE, 112)
		_: icon = ItemIcons.make(item.slot, item.item, base, 112)
	holder.add_child(icon)
	var name := _label("+%d COINS" % item.amount if item.kind == "coins" else String(item.item.name).to_upper(), 15, Color.WHITE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size = Vector2(TILE.x - 10, 0)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name)
	return panel


## The gold line down the middle that the prize stops under.
class Marker extends Control:
	func _draw() -> void:
		var h := size.y
		var gold := Color(1.0, 0.82, 0.3)
		draw_rect(Rect2(-2, 0, 4, h), gold)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(0, 18)]), gold)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, h), Vector2(14, h), Vector2(0, h - 18)]), gold)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12, 0.8))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	return l


## Slowly turning light rays behind the prize card.
class Rays extends Control:
	var color := Color.WHITE:
		set(v):
			color = v
			queue_redraw()

	func _draw() -> void:
		var n := 14
		for i in n:
			var a := i * TAU / n
			var pts := PackedVector2Array([Vector2.ZERO,
					Vector2(cos(a - 0.09), sin(a - 0.09)) * 700.0,
					Vector2(cos(a + 0.09), sin(a + 0.09)) * 700.0])
			draw_colored_polygon(pts, Color(color, 0.18))
		draw_circle(Vector2.ZERO, 300, Color(color, 0.12))
