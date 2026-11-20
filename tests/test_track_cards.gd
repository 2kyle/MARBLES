extends SceneTree
## Checks every track-altering (TA) card: its preview builds, it can be
## dropped somewhere on a fresh track, and dropping it really changes the
## track (longer, walls off, or a gap/narrow stretch where expected).
##   godot --headless --script res://tests/test_track_cards.gd

var game: Node
var _t := 0
var _fails := 0


func _initialize() -> void:
	Achievements.save_path = "user://test_achievements.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_d: float) -> bool:
	_t += 1
	if game.state == game.State.MENU:
		game._on_play_requested()
	if _t < 5:
		return false
	var b: CourseBuilder = game.builder
	var track: Track = game.track
	var start_layout: Array = track.layout.duplicate(true)
	var start_xz: Vector2 = track.start_xz
	for id in PieceCatalog.ids():
		if not PieceCatalog.is_track(id):
			continue
		for left in [0.0, 180.0]:
			if left == 180.0 and not PieceCatalog.turns(id):
				continue
			track.apply_layout(start_layout.duplicate(true), start_xz)
			b.clear()
			var old_len := track.length()
			# The track is random, so look all the way down it for a spot.
			var spot = null
			var z := -16.0
			while spot == null and z > b.bottom_z():
				spot = b.nearest_free(id, Vector2(0, z), left)
				z -= 6.0
			if spot == null:
				print("  (skip %s %s: doesn't fit anywhere on this random track)" % [id, left])
				continue
			var mesh := b.reshape_preview(id, spot, left)
			if mesh == null or mesh.get_surface_count() == 0:
				_fail("%s: preview mesh is empty" % id)
			if not b.place(id, spot, left, 0):
				_fail("%s: place() refused a spot can_place() allowed" % id)
				continue
			var grew := track.length() - old_len
			var seg: String = PieceCatalog.info(id).segment
			match seg:
				"open":
					if track.open_edges.is_empty():
						_fail("%s: no walls came off" % id)
				"narrow":
					if track.narrows.is_empty() or grew < 5.0:
						_fail("%s: no narrow stretch (grew %.1f m)" % [id, grew])
					var mid: float = (track.narrows[0][0] + track.narrows[0][1]) / 2.0
					if absf(track.half_width_at(mid) - Track.NARROW_WIDTH / 2.0) > 0.01:
						_fail("%s: plank is %.2f m wide" % [id, track.half_width_at(mid) * 2.0])
					if b.can_place("bumper_post", Vector2(0, -mid), 0.0):
						_fail("%s: pieces can sit on the plank" % id)
				"gap":
					if track.gaps.size() <= TrackGen.gap_ranges(start_layout).size():
						_fail("%s: no new gap" % id)
				_:
					if grew < 2.0:
						_fail("%s: track only grew %.1f m" % [id, grew])
			print("  ok %-14s %s at %.1f m, track %+.1f m" % [id, "right" if left == 180.0 else "left ", -spot.y, grew])
	# A preview that doesn't fit still draws (in red) instead of vanishing.
	track.apply_layout(start_layout.duplicate(true), start_xz)
	var red := 0
	for z in range(-6, -60, -2):
		var plan = b.ta_plan("track_hairpin", Vector2(0, z), 0.0)
		if plan != null and not plan.fits:
			red += 1
			if b.reshape_preview("track_hairpin", Vector2(0, z), 0.0) == null:
				_fail("hairpin: no preview where it won't fit")
	print("  hairpin spots that won't fit (drawn red): ", red)
	print("FAILS: ", _fails) if _fails else print("ALL PASS")
	return true


func _fail(msg: String) -> void:
	_fails += 1
	print("  FAIL ", msg)
