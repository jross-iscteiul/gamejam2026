class_name GameSfx
extends Node
## Gameplay sound effects that were missing, all synthesized in code (no files).
## Owned by Package 6. One instance per level (in level_XX_extras.tscn).
##
## Listens instead of editing other packages' scripts:
## - player hit:        the player's Health.damaged (liquids get their own sound)
## - clanker killed:    GameState.enemy_killed
## - boss killed:       GameState.boss_defeated and any boss's `defeated` signal
## - missile explosion: missiles (characters/jarvis/missile.gd) leaving the tree after exploding
## - JARVIS explodes:   GameState.enemy_killed with JARVIS once he's hostile (the final fight)
## - level 3 trap exit: the trap door's phase (rattle -> collapse), and the rubble landing in level 4
## - rolling boulder:   a looping rumble whose volume follows the ball's speed

const MISSILE_SCRIPT := "res://characters/jarvis/missile.gd"
const POOL_SCRIPT := "res://objects/hazards/pool.gd"
const JARVIS_BOSS_SCRIPT := "res://characters/jarvis/jarvis_boss.gd"
const DOOR_SCRIPT := "res://levels/shared/door.gd"
const RUBBLE_SCRIPT := "res://levels/shared/trap_rubble.gd"
const BOULDER_SCRIPT := "res://objects/hazards/boulder.gd"
## Boulder speed (px/s) that plays the rumble at full volume.
const BOULDER_FULL_SPEED := 130.0
const RATE := 22050

## Minimum seconds between two hurt sounds (toxic waste hits repeatedly).
@export var hurt_cooldown: float = 0.2

var _streams := {}
var _last_hurt := -INF
var _boss_played := false
var _doors := {} # trap door -> last phase seen
var _boulders := {} # boulder -> [rumble player, last x]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound: String in ["hurt", "lava", "toxic", "clank", "missile", "boss", "jarvis", "rattle", "collapse", "land", "roll"]:
		_streams[sound] = _make(sound)
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.boss_defeated.connect(_on_boss_defeated)
	get_tree().node_added.connect(_on_node_added)
	_hook_player.call_deferred()
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _hook_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var health := player.get_node_or_null("Health") as Health if player else null
	if health != null and not health.damaged.is_connected(_on_player_damaged):
		health.damaged.connect(_on_player_damaged)


func _on_player_damaged(_amount: float, source: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hurt < hurt_cooldown:
		return
	_last_hurt = now
	if is_instance_valid(source) and source.get_script() != null and source.get_script().resource_path == POOL_SCRIPT:
		play("lava" if source.get("kind") == 0 else "toxic")
	else:
		play("hurt", 0.0, randf_range(0.92, 1.08))


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	if is_instance_valid(enemy) and enemy.is_in_group("jarvis"):
		if GameState.jarvis_hostile: # the final fight: JARVIS blows up
			play("jarvis", 3.0)
		return
	if is_instance_valid(enemy) and enemy.is_in_group("boss"):
		return
	play("clank", -2.0, randf_range(0.9, 1.1))


func _on_boss_defeated() -> void:
	if not _boss_played:
		_boss_played = true
		play("boss", 2.0)


func _on_node_added(node: Node) -> void:
	var script: Script = node.get_script()
	var path := script.resource_path if script != null else ""
	if path == MISSILE_SCRIPT:
		node.tree_exiting.connect(_on_missile_exiting.bind(node))
	elif path == DOOR_SCRIPT and node.get("trap") == true:
		_doors[node] = "idle"
	elif path == RUBBLE_SCRIPT:
		play("land", 2.0)
	elif path == BOULDER_SCRIPT:
		var rumble := AudioStreamPlayer.new()
		rumble.bus = &"SFX"
		rumble.stream = _streams["roll"]
		rumble.volume_db = -80.0
		rumble.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(rumble)
		rumble.play()
		_boulders[node] = [rumble, (node as Node2D).position.x]
	elif path == JARVIS_BOSS_SCRIPT and node.has_signal("defeated") \
			and not node.is_connected("defeated", _on_boss_defeated):
		node.connect("defeated", _on_boss_defeated)
	elif node.is_in_group("boss") and node.has_signal("defeated") \
			and not node.is_connected("defeated", _on_boss_defeated):
		node.connect("defeated", _on_boss_defeated)


func _process(delta: float) -> void:
	for door: Node in _doors.keys():
		if not is_instance_valid(door):
			_doors.erase(door)
			continue
		var phase: String = door.get("_phase")
		if phase != _doors[door]:
			_doors[door] = phase
			if phase == "rattle":
				play("rattle", 0.0)
			elif phase == "collapse":
				play("collapse", 3.0)


## Boulders move in physics frames, so measure their speed there.
func _physics_process(delta: float) -> void:
	for ball: Node in _boulders.keys():
		var entry: Array = _boulders[ball]
		var rumble: AudioStreamPlayer = entry[0]
		if not is_instance_valid(ball):
			rumble.queue_free()
			_boulders.erase(ball)
			continue
		if get_tree().paused or delta <= 0.0:
			continue
		var x: float = (ball as Node2D).position.x
		var speed := absf(x - float(entry[1])) / delta
		entry[1] = x
		var level := clampf(speed / BOULDER_FULL_SPEED, 0.0, 1.0)
		var target := linear_to_db(maxf(level, 0.0001))
		rumble.volume_db = move_toward(rumble.volume_db, target, 120.0 * delta)
		rumble.pitch_scale = 0.8 + 0.3 * level


func _on_missile_exiting(missile: Node) -> void:
	# Only when it actually blew up (not when the level unloads).
	if missile.get("_done") == true:
		play("missile", 0.0, randf_range(0.9, 1.1))


# --- Synthesis -------------------------------------------------------------------

func _make(sound: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var seconds: float = {"hurt": 0.18, "lava": 0.6, "toxic": 0.45, "clank": 0.35, "missile": 0.55,
		"boss": 2.2, "jarvis": 2.6, "rattle": 1.0, "collapse": 1.8, "land": 0.7, "roll": 1.0}[sound]
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var low := 0.0 # one-pole low-pass state for rumbles
	for i in count:
		var t := float(i) / RATE
		var p := float(i) / count
		var noise := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match sound:
			"hurt": # punchy square thud sliding down
				phase += (220.0 - 140.0 * p) / RATE
				s = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * 0.5 + noise * 0.25
				s *= pow(1.0 - p, 2.0)
			"lava": # hiss + low sizzle
				low += (noise - low) * 0.08
				s = (noise * 0.35 * pow(1.0 - p, 1.5) + low * 0.9) * minf(1.0, p * 20.0)
				s *= pow(1.0 - p, 1.2)
			"toxic": # wet splash + bubbles
				low += (noise - low) * 0.2
				var bubble := sin(TAU * (300.0 + 500.0 * fmod(t * 9.0, 1.0)) * t) * 0.4
				s = (low * 0.8 * pow(1.0 - p, 3.0)) + bubble * (1.0 - p) * 0.6
			"clank": # metallic crunch: inharmonic partials + noise
				s = (sin(TAU * 523.0 * t) + sin(TAU * 1187.0 * t) * 0.7 + sin(TAU * 1913.0 * t) * 0.5) * 0.3
				s = s * pow(1.0 - p, 3.0) + noise * 0.5 * pow(1.0 - p, 6.0)
			"missile": # boom: falling sine + filtered noise
				phase += (110.0 - 70.0 * p) / RATE
				low += (noise - low) * 0.15
				s = sin(TAU * phase) * 0.7 * pow(1.0 - p, 2.0) + low * 1.2 * pow(1.0 - p, 1.5)
			"boss": # several booms rolling into a long rumble
				phase += (70.0 - 40.0 * p) / RATE
				low += (noise - low) * 0.06
				var pulse := 0.6 + 0.4 * absf(sin(t * 7.0))
				s = (sin(TAU * phase) * 0.6 + low * 1.6) * pulse * pow(1.0 - p, 1.3)
			"jarvis": # electric crackle and sparks, then a big boom with a long tail
				phase += (60.0 - 30.0 * p) / RATE
				low += (noise - low) * 0.1
				var crackle := (noise if rng.randf() < 0.06 else 0.0) * (1.0 - p)
				var boom := 0.0 if t < 0.35 else (sin(TAU * phase) * 0.8 + low * 1.8) * pow(1.0 - (t - 0.35) / (seconds - 0.35), 1.4)
				var whine := sin(TAU * (1400.0 - 1200.0 * minf(1.0, t / 0.35)) * t) * 0.25 * (1.0 if t < 0.35 else 0.0)
				s = crackle * 0.8 + boom + whine
			"rattle": # metal door shaking in its frame
				var hit := 1.0 if fmod(t * 18.0, 1.0) < 0.25 else 0.0
				s = (sin(TAU * 740.0 * t) * 0.4 + sin(TAU * 1310.0 * t) * 0.3 + noise * 0.3) * hit * (0.6 + 0.4 * p)
			"collapse": # crash: debris burst + falling rocks + rumble
				low += (noise - low) * 0.07
				var rocks := (noise if rng.randf() < 0.03 * (1.0 - p) else 0.0)
				s = (noise * 0.7 * pow(1.0 - p, 6.0)) + low * 1.5 * pow(1.0 - p, 1.2) + rocks * 0.7
			"land": # heavy thud and settling debris
				phase += (80.0 - 50.0 * p) / RATE
				low += (noise - low) * 0.12
				s = sin(TAU * phase) * 0.9 * pow(1.0 - p, 3.0) + low * 1.0 * pow(1.0 - p, 2.0)
			"roll": # seamless rumble loop (no fade: it loops)
				low += (noise - low) * 0.04
				phase += 45.0 / RATE
				s = low * 2.2 + sin(TAU * phase) * 0.25 * (0.7 + 0.3 * sin(TAU * 3.0 * t))
		data.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if sound == "roll":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
