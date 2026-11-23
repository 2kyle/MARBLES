class_name UISfx
extends Node
## The menu and button sounds: the "clink!" of a pickaxe on rock, the
## little "shine" sparkle after it, a tiny tick when you move onto a
## button, and so on. Call UISfx.play("clink") from anywhere.
##
## The sounds are PLACEHOLDERS made in code (no sound files needed), so the
## game has its crunchy feel today. To use your own sounds instead, drop a
## file into res://assets/sounds/ui/ named after the sound:
##
##     clink.wav   shine.wav   hover.wav   back.wav   deny.wav   big.wav
##
## (.ogg and .mp3 work too.) Want a few takes so it never sounds the same
## twice? Name them clink_1.wav, clink_2.wav ... (up to 8) and one is
## picked at random each press. Your file always wins over the made-up
## one, so nothing in the code needs to change. See docs/UI_FEEL.md.

## Every sound the UI can make.
const NAMES := ["clink", "shine", "hover", "back", "deny", "big"]
const FOLDER := "res://assets/sounds/ui/"
const RATE := 44100
## How loud each sound is (dB), on top of the game's VOLUME setting.
const LOUDNESS := {"clink": -7.0, "shine": -13.0, "hover": -17.0,
		"back": -9.0, "deny": -8.0, "big": -6.0}
## The same sound can't stack more often than this (seconds), so holding
## a key or a spinning reel never turns into noise.
const MIN_GAP := 0.035

static var _node: UISfx
## name -> Array of AudioStream (one or more takes).
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}


## Play one of the UI sounds. `pitch` nudges it up or down (1.0 = normal);
## it's also wobbled a little every time so repeats don't sound robotic.
static func play(sound: String, pitch := 1.0) -> void:
	var n := _instance()
	if n:
		n._play(sound, pitch)


## Make (or find) the one sound player. Done by UIFeel.install().
static func ensure(tree: SceneTree) -> void:
	if _node and is_instance_valid(_node):
		return
	_node = UISfx.new()
	_node.name = "UISfx"
	tree.root.add_child.call_deferred(_node)
	_node._load_all()


static func _instance() -> UISfx:
	if _node and is_instance_valid(_node) and _node.is_inside_tree():
		return _node
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _play(sound: String, pitch: float) -> void:
	var takes: Array = _streams.get(sound, [])
	if takes.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < MIN_GAP:
		return
	_last[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = takes[randi() % takes.size()]
	p.volume_db = LOUDNESS.get(sound, -10.0)
	p.pitch_scale = clampf(pitch * randf_range(0.95, 1.06), 0.3, 3.0)
	p.play()


# ------------------------------------------------------------ Loading

func _load_all() -> void:
	for sound in NAMES:
		var files := _custom_files(sound)
		if files.is_empty():
			_streams[sound] = [_make(sound)]
		else:
			_streams[sound] = files


## Kyle's own files for this sound, if he's added any.
func _custom_files(sound: String) -> Array:
	var found := []
	for ext in ["wav", "ogg", "mp3"]:
		var one := "%s%s.%s" % [FOLDER, sound, ext]
		if ResourceLoader.exists(one):
			found.append(load(one))
		for i in range(1, 9):
			var take := "%s%s_%d.%s" % [FOLDER, sound, i, ext]
			if ResourceLoader.exists(take):
				found.append(load(take))
	return found


# ------------------------------------------------------------ Placeholder sounds
# Each sound is built sample by sample: a few sine waves ("partials") that
# ring and die away, plus a short burst of noise for the crunch of rock.
# A metal bar's partials aren't neat multiples of each other, which is
# what makes a clink sound like metal instead of a musical note.

func _make(sound: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	match sound:
		"clink":
			# Pickaxe tip on stone: bright metal ring + gritty crack + thud.
			return _render(0.42, rng, [[2350.0, 1.0, 22.0], [6480.0, 0.55, 40.0],
					[12700.0, 0.25, 70.0], [3910.0, 0.35, 30.0], [180.0, 0.7, 45.0]],
					0.9, 0.012, 0.55)
		"big":
			# A heavier swing: deeper ring, more crunch, longer tail.
			return _render(0.7, rng, [[1560.0, 1.0, 11.0], [4300.0, 0.6, 20.0],
					[8420.0, 0.3, 35.0], [2630.0, 0.45, 16.0], [110.0, 1.0, 26.0]],
					1.0, 0.03, 0.7)
		"back":
			# A softer, lower tap for going back a page.
			return _render(0.3, rng, [[1320.0, 1.0, 30.0], [3640.0, 0.4, 55.0],
					[150.0, 0.6, 50.0]], 0.6, 0.008, 0.6)
		"hover":
			# A tiny pebble tick when you move onto a button.
			return _render(0.07, rng, [[3300.0, 0.6, 90.0], [7100.0, 0.3, 140.0]],
					0.5, 0.004, 0.9)
		"deny":
			# A dull thunk: rock that won't break (locked, not enough coins).
			return _render(0.22, rng, [[95.0, 1.0, 22.0], [210.0, 0.6, 30.0],
					[480.0, 0.25, 45.0]], 0.7, 0.02, 0.2)
		"shine":
			return _shine(rng)
	return _render(0.1, rng, [[1000.0, 1.0, 40.0]], 0.0, 0.0, 0.0)


## partials: [frequency Hz, loudness, how fast it dies]. `crunch`: how loud
## the noise burst is, `crunch_len` how long (s), `brightness` 0..1 how
## hissy the noise is (low = rumbly).
func _render(length: float, rng: RandomNumberGenerator, partials: Array,
		crunch: float, crunch_len: float, brightness: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var phases := []
	for p in partials:
		phases.append(rng.randf() * TAU)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in partials.size():
			var p: Array = partials[k]
			s += sin(TAU * p[0] * t + phases[k]) * p[1] * exp(-t * p[2])
		if t < crunch_len * 4.0:
			# Noise, smoothed a bit (a cheap low-pass) so it crunches.
			var white := rng.randf_range(-1.0, 1.0)
			lp += (white - lp) * (0.15 + 0.8 * brightness)
			s += lp * crunch * exp(-t / maxf(crunch_len, 0.001))
		# A 1 ms fade-in so the start doesn't pop.
		s *= minf(t / 0.001, 1.0)
		out[i] = s
	return _to_wav(out)


## A sparkle: little high "ting"s scattered over half a second, getting
## quieter, like light glinting off a freshly cut gem.
func _shine(rng: RandomNumberGenerator) -> AudioStreamWAV:
	var length := 0.6
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [5274.0, 6272.0, 7040.0, 7902.0, 8372.0, 9397.0]
	var start := 0.0
	for j in 9:
		var f: float = notes[rng.randi() % notes.size()] * rng.randf_range(0.99, 1.01)
		var amp := 0.6 * pow(0.8, j)
		var i0 := int(start * RATE)
		for i in range(i0, mini(i0 + int(0.25 * RATE), n)):
			var t := float(i - i0) / RATE
			out[i] += sin(TAU * f * t) * amp * exp(-t * 26.0) * minf(t / 0.002, 1.0)
		start += rng.randf_range(0.025, 0.06)
	# A soft shimmer underneath (two close notes beating together).
	for i in n:
		var t := float(i) / RATE
		out[i] += (sin(TAU * 4186.0 * t) + sin(TAU * 4200.0 * t)) * 0.06 * exp(-t * 7.0) * minf(t / 0.03, 1.0)
	return _to_wav(out)


## Float samples -> a 16-bit mono sound, scaled so the loudest bit is 90%.
func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.9 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
