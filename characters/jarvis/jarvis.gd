class_name Jarvis
extends Node2D
## Package 2 sidekick. Follows the player and sprays shots ahead; later steps add abilities,
## speech bubble, moods and sounds. Visual is a code-drawn placeholder (see Body).

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
@export var max_fire_rate: float = 3.0 # shots per second at full trust

@export_group("Look")
@export var disabled_color: Color = Color(0.45, 0.45, 0.5)

var player: Node2D
var facing: int = 1
var _bob_time: float = 0.0
var _fire_cooldown: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var body: Node2D = $Body


func _ready() -> void:
	add_to_group("jarvis")
	_rng.randomize()
	GameState.jarvis_enabled_changed.connect(_on_enabled_changed)
	_find_player()
	if player:
		global_position = _target_position()
	_on_enabled_changed(GameState.jarvis_enabled)


func _process(delta: float) -> void:
	if not is_instance_valid(player) and not _find_player():
		return
	var previous := global_position
	var target := _target_position()
	if global_position.distance_to(target) > snap_distance:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))
	var speed_x := (global_position.x - previous.x) / delta if delta > 0.0 else 0.0
	_animate_body(delta, speed_x)
	_shoot(delta)


## Shots per second; follows the trust ("online") bar from min_fire_rate to max_fire_rate.
func fire_rate() -> float:
	return lerpf(min_fire_rate, max_fire_rate, clampf(GameState.trust / GameState.MAX_TRUST, 0.0, 1.0))


func _shoot(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _fire_cooldown > 0.0 or not GameState.jarvis_enabled:
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


## Visual-only motion on Body, so the follow position stays exact.
func _animate_body(delta: float, speed_x: float) -> void:
	_bob_time = fmod(_bob_time + delta * bob_speed, TAU)
	body.position.y = sin(_bob_time) * bob_amplitude
	body.scale.x = facing
	var tilt := clampf(speed_x * tilt_per_speed, -max_tilt_degrees, max_tilt_degrees)
	body.rotation = lerp_angle(body.rotation, deg_to_rad(tilt), 1.0 - exp(-tilt_smoothing * delta))


func _find_player() -> bool:
	player = get_tree().get_first_node_in_group("player") as Node2D
	return player != null


func _target_position() -> Vector2:
	var player_facing: Variant = player.get("facing")
	facing = player_facing if player_facing is int else 1
	return player.global_position + Vector2(follow_offset.x * facing, follow_offset.y)


func _on_enabled_changed(enabled: bool) -> void:
	body.modulate = Color.WHITE if enabled else disabled_color
	body.queue_redraw()
