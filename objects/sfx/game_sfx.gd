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

const MISSILE_SCRIPT := "res://characters/jarvis/missile.gd"
const POOL_SCRIPT := "res://objects/hazards/pool.gd"
const RATE := 22050

## Minimum seconds between two hurt sounds (toxic waste hits repeatedly).
@export var hurt_cooldown: float = 0.2

var _streams := {}
var _last_hurt := -INF
var _boss_played := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound: String in ["hurt", "lava", "toxic", "clank", "missile", "boss"]:
		_streams[sound] = _make(sound)
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.boss_defeated.connect(_on_boss_defeated)
	get_tree().node_added.connect(_on_node_added)
	_hook_player.call_deferred()
	for node in get_tree().get_nodes_in_group("boss"):
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
	if is_instance_valid(enemy) and (enemy.is_in_group("boss") or enemy.is_in_group("jarvis")):
		return
	play("clank", -2.0, randf_range(0.9, 1.1))


func _on_boss_defeated() -> void:
	if not _boss_played:
		_boss_played = true
		play("boss", 2.0)


func _on_node_added(node: Node) -> void:
	var script: Script = node.get_script()
	if script != null and script.resource_path == MISSILE_SCRIPT:
		node.tree_exiting.connect(_on_missile_exiting.bind(node))
	elif node.is_in_group("boss") and node.has_signal("defeated") \
			and not node.is_connected("defeated", _on_boss_defeated):
		node.connect("defeated", _on_boss_defeated)


func _on_missile_exiting(missile: Node) -> void:
	# Only when it actually blew up (not when the level unloads).
	if missile.get("_done") == true:
		play("missile", 0.0, randf_range(0.9, 1.1))


# --- Synthesis -------------------------------------------------------------------

func _make(sound: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sound)
	var seconds: float = {"hurt": 0.18, "lava": 0.6, "toxic": 0.45, "clank": 0.35, "missile": 0.55, "boss": 2.2}[sound]
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
		data.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
