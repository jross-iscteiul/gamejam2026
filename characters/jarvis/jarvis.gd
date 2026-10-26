class_name Jarvis
extends Node2D
## Package 2 sidekick. Follows the player, sprays shots ahead and sells abilities: it reads the
## dash / double jump / shield input, pays with its online % (GameState.trust) and calls the Player API. Later steps add
## speech bubble and sounds. Moods (normal/happy/annoyed/furious) show as the eye colour on the
## drone's screen (see Body) and the bubble border.

@export_group("Follow")
@export var follow_offset: Vector2 = Vector2(-20.0, -28.0) # x is mirrored by player facing
@export var follow_speed: float = 6.0 # lerp weight per second
@export var snap_distance: float = 400.0 # teleport when farther (respawn)

@export_group("Bob")
@export var bob_amplitude: float = 3.0 # pixels
@export var bob_speed: float = 3.0 # radians per second
@export var max_tilt_degrees: float = 15.0
@export var tilt_per_speed: float = 0.1 # degrees per px/s of horizontal speed
@export var tilt_smoothing: float = 10.0

@export_group("Shooting")
@export var bullet_scene: PackedScene = preload("res://characters/player/bullet.tscn")
@export var bullet_texture: Texture2D = preload("res://assets/player/biker/bullet.png")
@export var bullet_tint: Color = Color(0.35, 0.85, 1.0)
@export var bullet_damage: float = 1.0
## Spray sectors as (from_deg, to_deg, weight, peak_deg) for JARVIS facing right; mirrored
## when facing left. 0 deg = straight ahead, negative = up. Inside a sector the chance is a
## triangle that is highest at peak_deg and fades to zero at the edges.
@export var spray_sectors: Array[Vector4] = [
	Vector4(-125.0, -60.0, 10.0, -90.0), # mostly up
	Vector4(-60.0, 20.0, 80.0, 0.0), # front and a bit up, densest straight ahead
	Vector4(20.0, 70.0, 10.0, 25.0), # a bit down, densest near the front
]
@export var min_fire_rate: float = 0.5 # shots per second when trust is almost empty
@export var max_fire_rate: float = 2.5 # shots per second at full trust

@export_group("Abilities")
@export var double_tap_window_msec: int = 250 # double-tap move_left/right to dash
@export var shield_bill_interval: float = 1.0 # seconds paid by each shield charge
## Online % (trust) each ability costs; shield cost is per shield_bill_interval.
@export var trust_costs: Dictionary[StringName, float] = {&"dash": 5.0, &"boost_jump": 8.0, &"shield": 4.0}

@export_group("Talk")
@export var low_trust_threshold: float = 25.0 # complains once when the online bar drops below this
@export var idle_line_min_seconds: float = 20.0
@export var idle_line_max_seconds: float = 40.0
@export var denied_line_cooldown: float = 4.0 # don't nag on every refused press

@export_group("Mood")
## Resting mood follows the online bar: happy above happy_trust, furious below furious_trust,
## annoyed below annoyed_trust, normal in between. While talking, the line's mood wins.
@export var happy_trust: float = 75.0
@export var annoyed_trust: float = 40.0
@export var furious_trust: float = 15.0
## Other mood names (from GameState / Dialogue callers) mapped onto JARVIS's moods.
@export var mood_aliases: Dictionary[String, String] = {
	"normal": "neutral", "smug": "happy", "sad": "annoyed", "angry": "furious"}

@export_group("Offline")
## At trust 0 JARVIS powers down: sinks toward the player's waist, droops nose-down, bobs
## weakly, the rotor spins down and the screen goes dark. Feeding powers him back up.
@export var offline_sink: float = 18.0 # pixels lower than the normal follow height
@export var offline_droop_degrees: float = 25.0
@export var offline_bob_scale: float = 0.25 # bob amplitude/speed multiplier when off
@export var power_down_seconds: float = 1.2
@export var power_up_seconds: float = 0.5

@export_group("Assist")
## JARVIS physically performs the abilities he sells: hovers over the player projecting the
## shield, pushes the dash with his thruster, and projects a blue platform for the double jump.
@export var shield_offset: Vector2 = Vector2(0.0, -40.0) # from the player, while shielded
@export var assist_follow_speed: float = 25.0 # faster follow while getting into a pose
@export var dash_push_offset: Vector2 = Vector2(-16.0, -2.0) # behind the player (x mirrored by dash direction)
@export var dash_pose_extra_seconds: float = 0.12 # keeps the pose a moment after the dash ends
## JARVIS's centre goes this far below the player's origin, so the platform he projects
## (AssistFx.platform_offset above him) sits right under the player's feet.
@export var boost_under_feet: float = 36.0
## Shifts JARVIS and his platform toward the way the player faces, so it sits under the
## character drawing (sprite and gun lean forward of the collision box).
@export var boost_forward_shift: float = 6.0
@export var boost_seconds: float = 0.45
@export var boost_recoil: float = 6.0 # pushed down a little by the jump

@export_group("Look")
@export var disabled_color: Color = Color(0.45, 0.45, 0.5)

@export_group("Dormant")
## Lies powered down where placed (intro), ignoring the player, until wake() is called.
@export var dormant: bool = false
@export var dormant_tilt_degrees: float = 90.0

const SpeechBubble := preload("res://characters/jarvis/speech_bubble.gd")

## JARVIS's moods; "neutral" is the normal mood. "offline" is used while disabled.
const MOODS: PackedStringArray = ["neutral", "happy", "annoyed", "furious"]

signal mood_changed(mood: String)
signal ability_activated(ability: StringName)
signal ability_denied(ability: StringName) # not enough online % or JARVIS offline

var player: Player
var mood: String = "neutral"
## Current assist pose: &"", &"dash", &"boost" or &"shield".
var assist: StringName = &""
## 1 = powered, 0 = fully powered down; eases between the two (see Offline settings).
var power: float = 1.0
var facing: int = 1
var _bob_time: float = 0.0
var _fire_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last_tap_direction: int = 0
var _last_tap_time_msec: int = 0
var _shield_paid_left: float = 0.0
var _boosted_this_air: bool = false
var _low_trust_warned: bool = false
var _idle_left: float = 0.0
var _denied_cooldown_left: float = 0.0
var _assist_left: float = 0.0
var _assist_dir: int = 1
var _boost_anchor := Vector2.ZERO

@onready var body: Node2D = $Body
@onready var bubble: SpeechBubble = $SpeechBubble
@onready var assist_fx: Node2D = $AssistFx


func _ready() -> void:
	add_to_group("jarvis")
	# Run before the player each physics frame so a bought boost/dash applies to this frame's input.
	process_physics_priority = -1
	_rng.randomize()
	GameState.jarvis_enabled_changed.connect(_on_enabled_changed)
	GameState.jarvis_say.connect(_on_jarvis_say)
	GameState.trust_changed.connect(_on_trust_changed)
	ability_denied.connect(_on_ability_denied)
	_low_trust_warned = GameState.trust < low_trust_threshold
	_reset_idle()
	power = 1.0 if GameState.jarvis_enabled and not dormant else 0.0
	_find_player()
	if player and not dormant:
		global_position = _target_position()
	_apply_enabled_look(GameState.jarvis_enabled and not dormant)


func _process(delta: float) -> void:
	if dormant:
		_lie_down(delta)
		return
	if not is_instance_valid(player) and not _find_player():
		return
	_tick_power(delta)
	_tick_assist(delta)
	var previous := global_position
	_move(delta)
	var speed_x := (global_position.x - previous.x) / delta if delta > 0.0 else 0.0
	_animate_body(delta, speed_x)
	_pose_body()
	_shoot(delta)
	_tick_talk(delta)
	_update_mood()


func _move(delta: float) -> void:
	match assist:
		&"dash": # glued behind the player for the whole push
			global_position = player.global_position + Vector2(dash_push_offset.x * _assist_dir, dash_push_offset.y)
			return
		&"boost": # stays where the player kicked off, nudged down by the jump
			var t := 1.0 - _assist_left / boost_seconds
			global_position = _boost_anchor + Vector2(0.0, boost_recoil * sin(t * PI))
			return
	var target := _target_position()
	var speed := follow_speed
	if assist == &"shield":
		target = player.global_position + shield_offset
		speed = assist_follow_speed
	if global_position.distance_to(target) > snap_distance:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-speed * delta))


func _lie_down(delta: float) -> void:
	_tick_power(delta)
	body.rotation = deg_to_rad(dormant_tilt_degrees)
	body.position.y = 0.0
	_update_mood()


## Ends dormant: powers up and flies to his follow position next to the player.
func wake() -> void:
	dormant = false
	_apply_enabled_look(GameState.jarvis_enabled)
	_reset_idle()


## Starts a timed assist pose (dash or boost); the shield pose follows player.shielded.
func start_assist(kind: StringName, direction: int = 1) -> void:
	assist = kind
	_assist_dir = 1 if direction >= 0 else -1
	match kind:
		&"dash":
			_assist_left = player.dash_duration + dash_pose_extra_seconds
			global_position = player.global_position + Vector2(dash_push_offset.x * _assist_dir, dash_push_offset.y)
		&"boost":
			_assist_left = boost_seconds
			_boost_anchor = player.global_position + Vector2(boost_forward_shift * player.facing, boost_under_feet)
			global_position = _boost_anchor
	assist_fx.start(kind, _assist_dir)


func _tick_assist(delta: float) -> void:
	if assist == &"dash" or assist == &"boost":
		_assist_left -= delta
		if _assist_left > 0.0:
			return
		assist = &""
	var shielding := player.shielded and GameState.jarvis_enabled
	if shielding and assist != &"shield":
		assist = &"shield"
		assist_fx.start(&"shield", facing)
	elif not shielding and assist == &"shield":
		assist = &""
	if assist == &"" and assist_fx.kind != &"boost": # the platform lingers on its own timer
		assist_fx.stop()


## Assist poses override the bob/tilt from _animate_body.
func _pose_body() -> void:
	match assist:
		&"dash": # sideways, thruster pointing back at the player's back
			body.scale.x = _assist_dir
			body.rotation = deg_to_rad(90.0) * _assist_dir # rotates the bottom nozzle to face backwards
			body.position.y = 0.0
		&"boost": # level and steady under the platform he projects
			body.rotation = 0.0
			body.position.y = 0.0
		&"shield": # level, steady, projecting down
			body.rotation = lerp_angle(body.rotation, 0.0, 0.3)
			body.scale = Vector2(facing, 1.0)
		_:
			body.scale.y = 1.0


## Resting mood from the online bar (or "offline" while disabled).
func base_mood() -> String:
	if dormant or not GameState.jarvis_enabled:
		return "offline"
	if GameState.trust < furious_trust:
		return "furious"
	if GameState.trust < annoyed_trust:
		return "annoyed"
	if GameState.trust >= happy_trust:
		return "happy"
	return "neutral"


## Maps any mood name onto one of MOODS (or "offline").
func normalize_mood(mood_name: String) -> String:
	var mapped: String = mood_aliases.get(mood_name, mood_name)
	return mapped if mapped == "offline" or MOODS.has(mapped) else "neutral"


func _update_mood() -> void:
	var current := bubble.mood if bubble.is_talking() else base_mood()
	if current == mood:
		return
	mood = current
	body.set_face(mood if MOODS.has(mood) else ("off" if mood == "offline" else "neutral"))
	mood_changed.emit(mood)


## Says a random Dialogue line from `category` for the current level.
func say_line(category: String, line_mood: String = "neutral") -> void:
	bubble.say(Dialogue.get_line(category, GameState.current_level), normalize_mood(line_mood))
	_reset_idle()


func _tick_talk(delta: float) -> void:
	_denied_cooldown_left = maxf(_denied_cooldown_left - delta, 0.0)
	if not GameState.jarvis_enabled or bubble.is_talking():
		return
	_idle_left -= delta
	if _idle_left <= 0.0:
		say_line("idle")


func _reset_idle() -> void:
	_idle_left = _rng.randf_range(idle_line_min_seconds, idle_line_max_seconds)


## GameState already picked the line (kills, deaths); just show it.
func _on_jarvis_say(text: String, line_mood: String) -> void:
	if dormant:
		return
	bubble.say(text, normalize_mood(line_mood))
	_reset_idle()


func _on_ability_denied(_ability: StringName) -> void:
	if _denied_cooldown_left > 0.0 or not GameState.jarvis_enabled:
		return
	_denied_cooldown_left = denied_line_cooldown
	say_line("ability_denied", "furious" if GameState.trust < annoyed_trust else "annoyed")


func _on_trust_changed(trust: float) -> void:
	if trust >= low_trust_threshold:
		_low_trust_warned = false
	elif not _low_trust_warned and GameState.jarvis_enabled:
		_low_trust_warned = true
		say_line("low_trust", "annoyed")


func _physics_process(delta: float) -> void:
	if dormant or (not is_instance_valid(player) and not _find_player()) or player.input_locked:
		return
	_handle_dash_input()
	_handle_boost_jump_input()
	_handle_shield_input(delta)


func _handle_dash_input() -> void:
	var direction := 0
	if Input.is_action_just_pressed("dash"):
		direction = player.move_direction()
	else:
		var tapped := 0
		if Input.is_action_just_pressed("move_left"):
			tapped = -1
		elif Input.is_action_just_pressed("move_right"):
			tapped = 1
		if tapped != 0:
			var now := Time.get_ticks_msec()
			if tapped == _last_tap_direction and now - _last_tap_time_msec <= double_tap_window_msec:
				direction = tapped
				_last_tap_direction = 0
			else:
				_last_tap_direction = tapped
				_last_tap_time_msec = now
	if direction != 0 and player.can_dash() and _buy(&"dash"):
		player.dash(Vector2(direction, 0.0))
		start_assist(&"dash", direction)


## The double jump: a jump press in the air with no jumps left buys one (once per airtime);
## the player's own jump code then uses it this frame.
func _handle_boost_jump_input() -> void:
	if player.is_on_floor():
		_boosted_this_air = false
	if not Input.is_action_just_pressed("jump") or player.can_jump() or player.stunned or _boosted_this_air:
		return
	if _buy(&"boost_jump"):
		_boosted_this_air = true
		player.boost_jump()
		start_assist(&"boost", facing)


## Held shield is paid up front for each shield_bill_interval. A failed payment drops it until
## the button is pressed again, so holding it with no tokens doesn't retry every frame.
func _handle_shield_input(delta: float) -> void:
	var active := false
	if Input.is_action_pressed("shield"):
		_shield_paid_left -= delta
		if _shield_paid_left <= 0.0 and (Input.is_action_just_pressed("shield") or player.shielded):
			_shield_paid_left = shield_bill_interval if _buy(&"shield") else 0.0
		active = _shield_paid_left > 0.0 and GameState.jarvis_enabled
	if not active:
		_shield_paid_left = 0.0
	if active != player.shielded:
		player.set_shield(active)


## Pays the ability's trust cost. Allowed while online with at least that much trust, so the
## last purchase can take JARVIS to exactly 0 (offline).
func _buy(ability: StringName) -> bool:
	var cost: float = trust_costs.get(ability, 0.0)
	if not GameState.jarvis_enabled or GameState.trust < cost:
		ability_denied.emit(ability)
		return false
	GameState.add_trust(-cost)
	GameState.ability_used.emit(ability, ceili(cost))
	ability_activated.emit(ability)
	return true


## Shots per second; follows the trust ("online") bar from min_fire_rate to max_fire_rate.
func fire_rate() -> float:
	return lerpf(min_fire_rate, max_fire_rate, clampf(GameState.trust / GameState.MAX_TRUST, 0.0, 1.0))


func _shoot(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _fire_cooldown > 0.0 or not GameState.jarvis_enabled or player.input_locked:
		return
	_fire_cooldown = 1.0 / fire_rate()
	var bullet: PlayerBullet = bullet_scene.instantiate()
	bullet.direction = spray_direction()
	bullet.damage = bullet_damage
	bullet.source = self
	bullet.texture = bullet_texture
	bullet.modulate = bullet_tint
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position


## Random shot direction from spray_sectors, mirrored by facing.
func spray_direction() -> Vector2:
	var total := 0.0
	for sector in spray_sectors:
		total += sector.z
	if total <= 0.0:
		return Vector2(facing, 0.0)
	var pick := _rng.randf() * total
	var chosen: Vector4 = spray_sectors.back()
	for sector in spray_sectors:
		pick -= sector.z
		if pick < 0.0:
			chosen = sector
			break
	var angle := deg_to_rad(_triangular(chosen.x, chosen.y, clampf(chosen.w, chosen.x, chosen.y)))
	return Vector2(cos(angle) * facing, sin(angle))


## Inverse-CDF sample of a triangular distribution on [low, high] peaking at mode.
func _triangular(low: float, high: float, mode: float) -> float:
	var u := _rng.randf()
	var width := high - low
	if width <= 0.0:
		return low
	var split := (mode - low) / width
	if u < split:
		return low + sqrt(u * width * (mode - low))
	return high - sqrt((1.0 - u) * width * (high - mode))


func _tick_power(delta: float) -> void:
	var target := 1.0 if GameState.jarvis_enabled and not dormant else 0.0
	var seconds := power_up_seconds if target > power else power_down_seconds
	power = move_toward(power, target, delta / maxf(seconds, 0.01))
	body.power = power


## Visual-only motion on Body, so the follow position stays exact.
func _animate_body(delta: float, speed_x: float) -> void:
	var bob_scale := lerpf(offline_bob_scale, 1.0, power)
	_bob_time = fmod(_bob_time + delta * bob_speed * bob_scale, TAU)
	body.position.y = sin(_bob_time) * bob_amplitude * bob_scale
	body.scale.x = facing
	var tilt := clampf(speed_x * tilt_per_speed, -max_tilt_degrees, max_tilt_degrees)
	tilt += offline_droop_degrees * facing * (1.0 - power) # nose-down when powered off
	body.rotation = lerp_angle(body.rotation, deg_to_rad(tilt), 1.0 - exp(-tilt_smoothing * delta))


func _find_player() -> bool:
	player = get_tree().get_first_node_in_group("player") as Player
	return player != null


func _target_position() -> Vector2:
	facing = player.facing
	var sink := offline_sink * (1.0 - power)
	return player.global_position + Vector2(follow_offset.x * facing, follow_offset.y + sink)


func _apply_enabled_look(enabled: bool) -> void:
	body.modulate = Color.WHITE if enabled else disabled_color


## Only real changes speak; spawning (see _ready) applies the look silently.
func _on_enabled_changed(enabled: bool) -> void:
	_apply_enabled_look(enabled)
	if enabled:
		say_line("back_online", "happy")
	elif not GameState.jarvis_hostile:
		say_line("offline", "offline")
