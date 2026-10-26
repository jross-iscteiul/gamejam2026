extends Node
# Headless check for JARVIS: spawn, follow, bob, energy tint, spray shooting and paid abilities.
# Run:  godot --headless --path . res://tests/jarvis/test_jarvis.tscn
var _t := 0
var _failed := false
var _bob_min := INF
var _bob_max := -INF
var _home := Vector2.ZERO
var _activated: Array[StringName] = []
var _denied: Array[StringName] = []
var _platform_at := Vector2.ZERO


func _ready() -> void:
	process_physics_priority = -10 # press inputs before JARVIS (priority -1) reads them
	_begin.call_deferred()


func _begin() -> void:
	GameState.reset_run()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")


func _physics_process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s == null:
		return
	_t += 1
	var jarvis := get_tree().get_first_node_in_group("jarvis") as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _t == 2:
		s.get_node("Entities").queue_free() # no pickups/enemies changing token counts
		_check(jarvis != null, "JARVIS spawns in level 1")
		if jarvis == null:
			return _finish()
		_check(not jarvis.get_node("SpeechBubble").visible, "JARVIS spawns quietly (no back-online line)")
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS starts next to the player")
		_home = player.global_position
		var look: Node2D = jarvis.get_node("Body")
		var sprites := look.get_children().filter(func(n: Node) -> bool: return n is Sprite2D)
		_check(sprites.size() == 2 and sprites.all(func(n: Sprite2D) -> bool: return n.texture != null), "JARVIS uses the drone shell and face sprites")
		look.set_face("blink")
		var blink_frame: int = sprites[1].frame
		look.set_face("neutral")
		_check(blink_frame != sprites[1].frame and look.face == "neutral", "set_face switches the face frame")
		jarvis.global_position += Vector2(150, 0)
	if _t == 30:
		_bob_min = INF
		_bob_max = -INF
	if _t > 30 and _t < 90:
		var y: float = jarvis.get_node("Body").position.y
		_bob_min = minf(_bob_min, y)
		_bob_max = maxf(_bob_max, y)
	if _t == 20:
		_check(absf(jarvis.get_node("Body").rotation) > 0.01, "JARVIS tilts while catching up")
	if _t == 90:
		_check(_bob_max - _bob_min > 2.0, "JARVIS bobs up and down")
		_check(jarvis.get_node("Body").scale.x == player.get("facing"), "JARVIS faces the same way as the player")
		player.set("facing", -player.get("facing"))
	if _t == 91:
		_check(jarvis.get_node("Body").scale.x == player.get("facing"), "JARVIS flips with the player")
		player.set("facing", -player.get("facing"))
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS catches up with the player")
		player.global_position += Vector2(1000, 0)
	if _t == 92:
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS snaps to a far-away player")
		GameState.energy = 0.0
		_check(jarvis.get_node("Body").modulate != Color.WHITE, "JARVIS greys out at zero energy")
		GameState.energy = 50.0
		_check(jarvis.get_node("Body").modulate == Color.WHITE, "JARVIS recovers when energy returns")
		player.global_position = _home
	if _t == 100:
		GameState.energy = GameState.MAX_ENERGY
		_check(is_equal_approx(jarvis.fire_rate(), jarvis.max_fire_rate), "full energy fires at max rate")
		GameState.energy = GameState.MAX_ENERGY * 0.5
		_check(is_equal_approx(jarvis.fire_rate(), (jarvis.min_fire_rate + jarvis.max_fire_rate) * 0.5), "half energy fires at half way rate")
		GameState.tokens = 1000
		_check(is_equal_approx(jarvis.fire_rate(), (jarvis.min_fire_rate + jarvis.max_fire_rate) * 0.5), "tokens do not change fire rate")
		_check_spray(jarvis)
		GameState.energy = 0.0
		_clear_bullets()
	if _t == 160:
		_check(get_tree().get_nodes_in_group("player_projectile").is_empty(), "disabled JARVIS fires no bullets")
		GameState.energy = 100.0
	if _t == 190:
		var bullets := get_tree().get_nodes_in_group("player_projectile")
		_check(not bullets.is_empty(), "JARVIS keeps shooting with no enemies around")
		_check(bullets.all(func(b: Node) -> bool: return b.source == jarvis), "JARVIS bullets credit JARVIS for kills")
		jarvis.ability_activated.connect(func(a: StringName) -> void: _activated.append(a))
		jarvis.ability_denied.connect(func(a: StringName) -> void: _denied.append(a))
	if _t >= 200 and _t < 600:
		_abilities(jarvis, player)
	if _t >= 600:
		_talk(jarvis)


## Dash, double jump and shield: paid with JARVIS's energy, applied through the Player API.
## Costs come from jarvis.energy_costs so retuning them doesn't break the test.
## Input.action_press() during a physics frame reads as "just pressed" on the next one, so
## each check runs two frames after its press.
func _abilities(jarvis: Node2D, p: Player) -> void:
	var dash: float = jarvis.energy_costs[&"dash"]
	var boost: float = jarvis.energy_costs[&"boost_jump"]
	var shield: float = jarvis.energy_costs[&"shield"]
	match _t:
		200:
			p.global_position = _home
			p.velocity = Vector2.ZERO
			GameState.tokens = 0
			GameState.energy = dash - 1.0 # online, but can't afford a dash
		230: Input.action_press("dash")
		232:
			Input.action_release("dash")
			_check(_denied.has(&"dash") and p._dash_time_left <= 0.0 and is_equal_approx(GameState.energy, dash - 1.0),
				"dash without enough energy is denied and does nothing")
			GameState.energy = 100.0
		240: Input.action_press("dash")
		242:
			Input.action_release("dash")
			_check(p._dash_time_left > 0.0 and is_equal_approx(GameState.energy, 100.0 - dash), "dash key costs energy")
			var behind := (jarvis.global_position.x - p.global_position.x) * p.facing
			_check(jarvis.assist == &"dash" and behind < -8.0 and absf(jarvis.global_position.y - p.global_position.y) < 8.0,
				"JARVIS pushes the dash from behind the player")
			_check(jarvis.assist_fx.kind == &"dash" and absf(absf(jarvis.body.rotation) - PI / 2.0) < 0.01, "dash pose turns JARVIS's thruster backwards")
		270: Input.action_press("move_right")
		272: Input.action_release("move_right")
		276: Input.action_press("move_right")
		278:
			_check(p._dash_time_left > 0.0 and is_equal_approx(GameState.energy, 100.0 - 2.0 * dash), "double-tap right buys a dash")
			_check(GameState.tokens == 0, "abilities never spend tokens")
		280:
			Input.action_release("move_right")
			p.global_position = _home
			p.velocity = Vector2.ZERO
		310:
			GameState.energy = 100.0
			Input.action_press("jump")
		312: Input.action_release("jump")
		325: Input.action_press("jump")
		327:
			Input.action_release("jump")
			_check(is_equal_approx(GameState.energy, 100.0 - boost) and p.velocity.y < 0.0 and _activated.has(&"boost_jump"),
				"ground jump is free, double jump costs energy")
			_check(jarvis.assist == &"boost" and jarvis.global_position.y > p.global_position.y + 10.0, "JARVIS is under the player for the double jump")
			_check(jarvis.assist_fx.kind == &"boost", "JARVIS projects a platform for the double jump")
			_platform_at = jarvis.assist_fx._platform_world
			var forward: float = (_platform_at.x - p.global_position.x) * p.facing
			_check(is_equal_approx(forward, jarvis.boost_forward_shift), "platform is shifted forward under the character drawing")
		340: Input.action_press("jump")
		360:
			_check(jarvis.assist == &"" and jarvis.assist_fx.kind == &"boost" and jarvis.assist_fx._platform_world == _platform_at,
				"platform lingers in place after JARVIS leaves")
		372:
			_check(jarvis.assist_fx.kind == &"", "platform disappears 0.2 s after JARVIS's pose")
		342:
			_check(is_equal_approx(GameState.energy, 100.0 - boost) and _activated.count(&"boost_jump") == 1, "only one double jump per airtime")
			Input.action_release("jump")
		380:
			p.global_position = _home
			p.velocity = Vector2.ZERO
			GameState.energy = boost - 1.0
		400: Input.action_press("jump")
		402: Input.action_release("jump")
		412: Input.action_press("jump")
		414:
			Input.action_release("jump")
			_check(_denied.has(&"boost_jump") and p.velocity.y > -350.0, "double jump without enough energy is denied")
		440:
			p.global_position = _home
			p.velocity = Vector2.ZERO
			GameState.energy = 2.0 * shield + 1.0 # pays two seconds, then runs short while still online
			Input.action_press("shield")
		442:
			_check(p.shielded and p._shield_bubble.visible and is_equal_approx(GameState.energy, shield + 1.0),
				"holding shield pays the first second and shows the bubble")
		506:
			_check(p.shielded and is_equal_approx(GameState.energy, 1.0), "held shield is billed again each second")
			_check(jarvis.assist == &"shield" and absf(jarvis.global_position.x - p.global_position.x) < 3.0 \
				and jarvis.global_position.y < p.global_position.y - 30.0 and jarvis.assist_fx.kind == &"shield",
				"JARVIS hovers over the player projecting the shield")
		565:
			_check(not p.shielded and not p._shield_bubble.visible and GameState.jarvis_enabled,
				"shield drops when the next second can't be paid")
			_check(jarvis.assist == &"" and jarvis.assist_fx.kind == &"", "JARVIS leaves the shield pose when it drops")
		566:
			_check(is_equal_approx(GameState.energy, 1.0), "unpaid shield does not retry every frame")
			Input.action_release("shield")
		580:
			GameState.energy = 100.0
			Input.action_press("shield")
		582:
			_check(p.shielded, "shield comes back on a new press")
			GameState.energy = 0.0
		583:
			_check(not p.shielded, "shield drops when JARVIS goes offline")
			Input.action_release("shield")
			GameState.energy = 100.0


## Speech bubble: shows GameState lines (HUD stays quiet), types out, wraps, hides,
## and JARVIS's own triggers pick the right mood.
func _talk(jarvis: Node2D) -> void:
	var bubble: Node2D = jarvis.get_node("SpeechBubble")
	var hud := get_tree().get_first_node_in_group("game_hud")
	match _t:
		600:
			GameState.jarvis_say.emit("Test line.", "smug")
		601:
			_check(bubble.visible and bubble.text == "Test line." and bubble.mood == "happy", "jarvis_say shows in JARVIS's bubble, smug maps to happy")
			_check(bubble.is_typing(), "bubble text types out")
			_check(hud == null or not hud._speech.visible, "HUD leaves JARVIS lines to the bubble")
		640:
			_check(bubble.visible and not bubble.is_typing(), "bubble finishes typing and holds the line")
		800:
			_check(not bubble.visible, "bubble hides after its hold time")
			bubble.say("This is a much longer line that has to wrap over several rows inside the bubble.")
			var widest := 0.0
			for line: String in bubble._lines:
				widest = maxf(widest, bubble.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, bubble.font_size).x)
			_check(bubble._lines.size() > 1 and widest <= bubble.max_text_width, "long lines wrap inside max_text_width")
			jarvis._denied_cooldown_left = 0.0
			jarvis.ability_denied.emit(&"dash")
		801:
			_check(bubble.mood == "annoyed" and Dialogue._lines["ability_denied"].has(bubble.text), "denied ability gets an annoyed line")
			jarvis.ability_denied.emit(&"dash")
			bubble.say("marker")
			jarvis.ability_denied.emit(&"dash")
		802:
			_check(bubble.text == "marker", "denied lines have a cooldown")
			GameState.energy = jarvis.low_energy_threshold - 1.0
		803:
			_check(bubble.mood == "annoyed" and Dialogue._lines["low_energy"].has(bubble.text), "dropping below the low-energy threshold complains")
			bubble.say("marker")
			GameState.energy = jarvis.low_energy_threshold - 2.0
		804:
			_check(bubble.text == "marker", "low-energy complaint fires once per drop")
			GameState.energy = 0.0
		805:
			_check(bubble.mood == "offline" and Dialogue._lines["offline"].has(bubble.text), "going offline says a last line")
			GameState.energy = 50.0
		806:
			_check(bubble.mood == "happy" and Dialogue._lines["back_online"].has(bubble.text), "coming back online says so")
			bubble.clear()
			jarvis._idle_left = 0.0
		808:
			_check(bubble.visible and Dialogue._lines["idle"].has(bubble.text), "quiet JARVIS says an idle line")
			_check(jarvis.mood == "neutral" and _eye(jarvis) == "neutral", "idle line keeps a normal eye")
		810:
			_set_energy_quietly(jarvis, 90.0)
		811:
			_check(jarvis.mood == "happy" and _eye(jarvis) == "happy", "high energy makes JARVIS happy (green eye)")
			_set_energy_quietly(jarvis, 50.0)
		812:
			_check(jarvis.mood == "neutral" and _eye(jarvis) == "neutral", "mid energy is normal (cyan eye)")
			_set_energy_quietly(jarvis, 30.0)
		813:
			_check(jarvis.mood == "annoyed" and _eye(jarvis) == "annoyed", "low energy annoys JARVIS (orange eye)")
			_set_energy_quietly(jarvis, 10.0)
		814:
			_check(jarvis.mood == "furious" and _eye(jarvis) == "furious", "very low energy makes JARVIS furious (red eye)")
			jarvis._denied_cooldown_left = 0.0
			jarvis.ability_denied.emit(&"dash")
		815:
			_check(bubble.mood == "furious" and bubble.get("mood_colors")["furious"] == Color("ff2a2a"), "refusals while low are furious, bubble border matches the eye")
			GameState.jarvis_say.emit("Got one.", "smug")
		816:
			_check(jarvis.mood == "happy" and _eye(jarvis) == "happy", "a happy line overrides the resting mood while talking")
			bubble.clear()
		817:
			_check(jarvis.mood == "furious", "after talking JARVIS returns to his resting mood")
			_check(jarvis.normalize_mood("sad") == "annoyed" and jarvis.normalize_mood("weird") == "neutral", "unknown and legacy mood names are mapped")
			_set_energy_quietly(jarvis, 0.0)
		830:
			_check(jarvis.power > 0.0 and jarvis.power < 1.0, "powering down is gradual")
		910:
			_check(jarvis.power == 0.0 and _eye(jarvis) == "off", "offline JARVIS powers down with a dark screen")
			var shell: Sprite2D = _sprites(jarvis)[0]
			_check(shell.frame == shell.hframes - 1, "offline rotor stops and the thruster goes out")
			var p := get_tree().get_first_node_in_group("player") as Node2D
			var normal_y: float = p.global_position.y + jarvis.follow_offset.y
			_check(jarvis.global_position.y > normal_y + jarvis.offline_sink * 0.8, "offline JARVIS sinks toward the player")
			var droop: float = jarvis.body.rotation * jarvis.facing
			_check(droop > deg_to_rad(jarvis.offline_droop_degrees * 0.6), "offline JARVIS droops nose-down")
			_set_energy_quietly(jarvis, 50.0)
		960:
			var shell: Sprite2D = _sprites(jarvis)[0]
			_check(jarvis.power == 1.0 and _eye(jarvis) != "off" and shell.frame < shell.hframes - 1, "feeding powers JARVIS back up")
			GameState.energy = 100.0
			_finish()


## Changes energy and silences any line it triggers, so only the resting mood is tested.
func _set_energy_quietly(jarvis: Node2D, value: float) -> void:
	GameState.energy = value
	jarvis.get_node("SpeechBubble").clear()
	jarvis._idle_left = 999.0


## Name of the face currently shown on JARVIS's screen.
func _eye(jarvis: Node2D) -> String:
	var look: Node2D = jarvis.get_node("Body")
	var face_sprite: Sprite2D = _sprites(jarvis)[1]
	return look.face_names[face_sprite.frame]


## [shell, face] sprites under JARVIS's Body.
func _sprites(jarvis: Node2D) -> Array:
	return jarvis.get_node("Body").get_children().filter(func(n: Node) -> bool: return n is Sprite2D)


func _clear_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("player_projectile"):
		bullet.free()


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	_failed = _failed or not ok


## Samples the spray: each slice gets its weight share, nothing lands outside the slices,
## and facing left mirrors it. Reads spray_sectors so tuning the values never breaks the test.
func _check_spray(jarvis: Node2D) -> void:
	var samples := 6000
	var sectors: Array[Vector4] = jarvis.spray_sectors
	var total := 0.0
	for sector in sectors:
		total += sector.z
	for side in [1, -1]:
		jarvis.facing = side
		var counts: Array[int] = []
		counts.resize(sectors.size())
		counts.fill(0)
		var outside := 0
		for i in samples:
			var d: Vector2 = jarvis.spray_direction()
			var deg := rad_to_deg(Vector2(d.x * side, d.y).angle())
			var hit := false
			for k in sectors.size():
				if deg >= sectors[k].x - 0.5 and deg <= sectors[k].y + 0.5:
					counts[k] += 1
					hit = true
					break
			if not hit:
				outside += 1
		var ok := outside == 0
		var shares: Array[String] = []
		for k in sectors.size():
			var share := counts[k] / float(samples)
			ok = ok and absf(share - sectors[k].z / total) < 0.03
			shares.append("%.0f%%" % (share * 100.0))
		_check(ok, "spray facing %d matches slice weights: %s, outside %d / %d" % [side, ", ".join(shares), outside, samples])
	jarvis.facing = 1


func _finish() -> void:
	set_physics_process(false)
	get_tree().quit(1 if _failed else 0)
