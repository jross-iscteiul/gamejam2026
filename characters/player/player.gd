class_name Player
extends CharacterBody2D
## Player controller: run, jump, mouse-aimed gun; keys 1-6 switch character.
## Implements the team Player API (README): dash(direction), set_shield(active), boost_jump().
## Dash, the double jump (boost_jump) and shield are sold by JARVIS (Package 2): it reads that input,
## pays tokens and calls the API.
## Pits call respawn(); checkpoints move respawn_point.

signal skin_changed(skin: PlayerSkin)

const SKINS := [
	preload("res://characters/player/biker.tres"),
	preload("res://characters/player/bot_wheel.tres"),
	preload("res://characters/player/penguin.tres"),
	preload("res://characters/player/free_soldier.tres"),
	preload("res://characters/player/robot.tres"),
	preload("res://characters/player/gas_mask.tres"),
]
const BULLET_SCENE: PackedScene = preload("res://characters/player/bullet.tscn")
const SHIELD_BUBBLE: GDScript = preload("res://characters/player/shield_bubble.gd")
## Feet sit this far below the origin (levels place the player at a tile centre). Matches Body's y in player.tscn.
const FEET_Y: float = 16.0

## Last character picked with the number keys; carries over between levels.
static var selected_skin: int = -1

@export_enum("Biker", "Bot Wheel", "Penguin", "Free Soldier", "Robot", "Gas Mask") var skin_index: int = 0:
	set(value):
		skin_index = value
		if is_node_ready():
			_apply_skin()

@export_group("Movement")
@export var move_speed: float = 160.0
@export var ground_acceleration: float = 1400.0
@export var air_acceleration: float = 900.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 1000.0

@export_group("Dash")
@export var dash_speed: float = 420.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.35

@export_group("Death")
@export_range(30.0, 110.0) var death_fall_angle_degrees: float = 82.0
@export var death_fall_duration: float = 0.35

@export_group("Jump")
@export var jump_velocity: float = 480.0
@export var double_jump_velocity: float = 400.0
@export var air_jumps: int = 0 # free air jumps; the double jump is bought from JARVIS
## Upward speed is multiplied by this when jump is released early (1 = fixed-height jumps).
@export_range(0.0, 1.0) var jump_cut: float = 1.0

@export_group("Gun")
## Shots per second while shoot is held.
@export var fire_rate: float = 6.0
@export var bullet_damage: float = 1.0

var facing: int = 1
var respawn_point: Vector2
var shielded: bool = false

var _skin: PlayerSkin
var _move_direction: int = 1
var _air_jumps_left: int = 0
var _can_air_dash: bool = true
var _aim_direction: Vector2 = Vector2.RIGHT
var _fire_cooldown: float = 0.0
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _knockback_left: float = 0.0
var _is_dead: bool = false
var _death_tween: Tween
var _touch_active: bool = false
var _touch_aim := Vector2.RIGHT
var _touch_shooting: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _body: Node2D = $Body
@onready var _sprite: AnimatedSprite2D = $Body/AnimatedSprite2D
@onready var _gun_pivot: Node2D = $GunPivot
@onready var _gun: Sprite2D = $GunPivot/Gun
@onready var _muzzle: Marker2D = $GunPivot/Muzzle
@onready var _jump_sound: AudioStreamPlayer = $JumpSound
@onready var _step_sound: AudioStreamPlayer = $StepSound
@onready var _shoot_sound: AudioStreamPlayer = $ShootSound
@onready var _health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _camera: Camera2D = $Camera2D
@onready var _shield_bubble: Node2D = SHIELD_BUBBLE.new()


func _ready() -> void:
	respawn_point = global_position
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_hurtbox.health = _health
	_health.died.connect(_on_died)
	_health.damaged.connect(_on_damaged)
	_shield_bubble.visible = shielded
	add_child(_shield_bubble)
	if selected_skin >= 0:
		skin_index = selected_skin
	_apply_skin()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode >= KEY_1 and key.keycode < KEY_1 + SKINS.size():
		selected_skin = key.keycode - KEY_1
		skin_index = selected_skin


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
		return
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_move(delta)
	_aim()
	_shoot(delta)
	_animate()


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_air_jumps_left = maxi(_air_jumps_left, air_jumps) # keeps an unused boost_jump()
		_can_air_dash = true

	var input_x := Input.get_axis("move_left", "move_right")
	if _dash_time_left > 0.0: # straight horizontal burst, gravity paused
		_dash_time_left -= delta
		velocity = Vector2(facing * dash_speed, 0.0)
	else:
		if not on_floor:
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		if Input.is_action_just_pressed("jump"):
			if on_floor:
				velocity.y = -jump_velocity
				_play(_jump_sound)
			elif _air_jumps_left > 0:
				_air_jumps_left -= 1
				velocity.y = -double_jump_velocity
				_play(_jump_sound)
		elif Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= jump_cut

		var acceleration := ground_acceleration if on_floor else air_acceleration
		if _knockback_left > 0.0: # let a hazard push play out before steering resumes
			_knockback_left -= delta
		else:
			# Clamp first so dash speed doesn't carry over once the dash ends.
			var speed_x := clampf(velocity.x, -move_speed, move_speed)
			velocity.x = move_toward(speed_x, input_x * move_speed, acceleration * delta)
		if input_x != 0.0:
			facing = 1 if input_x > 0.0 else -1
			_move_direction = facing
		elif absf(velocity.x) <= 5.0:
			var mouse_delta_x := _touch_aim.x if _touch_active else get_global_mouse_position().x - global_position.x
			if absf(mouse_delta_x) > (0.05 if _touch_active else 1.0):
				facing = 1 if mouse_delta_x > 0.0 else -1
	_body.scale.x = facing

	move_and_slide()


## Player API: short horizontal burst, one per airtime. Only the x sign of direction is used.
func dash(direction: Vector2) -> void:
	if _is_dead or _dash_cooldown_left > 0.0 or not (is_on_floor() or _can_air_dash):
		return
	if direction.x != 0.0:
		facing = 1 if direction.x > 0.0 else -1
		_move_direction = facing
	_body.scale.x = facing
	_dash_time_left = dash_duration
	_health.grant_invulnerability(dash_duration)
	_dash_cooldown_left = dash_cooldown
	_can_air_dash = is_on_floor()


## Hazard API: push the player (e.g. hammer hits). Ignored while dead.
func apply_knockback(impulse: Vector2) -> void:
	if _is_dead:
		return
	velocity = impulse
	_dash_time_left = 0.0
	_knockback_left = 0.2


## Player API: true when dash() would start a dash right now (JARVIS checks before charging).
func can_dash() -> bool:
	return not _is_dead and _dash_cooldown_left <= 0.0 and (is_on_floor() or _can_air_dash)


## Player API: last horizontal direction the player moved in (-1 or 1); the dash key dashes this way.
func move_direction() -> int:
	return _move_direction


## Player API: true when a jump press would jump right now without buying a boost_jump().
func can_jump() -> bool:
	return not _is_dead and (is_on_floor() or _air_jumps_left > 0)


## Player API: one extra air jump, kept until used.
func boost_jump() -> void:
	_air_jumps_left += 1


## Player API: blocks damage while active.
func set_shield(active: bool) -> void:
	shielded = active
	_health.invulnerable = active
	_shield_bubble.visible = active


## HUD adapter: avoid turning movement-pad touches into emulated mouse shots.
func set_touch_input(active: bool, aim_direction: Vector2, shooting: bool) -> void:
	_touch_active = active
	if not aim_direction.is_zero_approx():
		_touch_aim = aim_direction.normalized()
	_touch_shooting = active and shooting


func respawn() -> void:
	if _death_tween and _death_tween.is_running():
		_death_tween.kill()
	if not _is_dead:
		GameState.player_died.emit()
	_is_dead = false
	_health.restore()
	_health.grant_invulnerability(1.0)
	set_shield(false)
	collision_layer = 2
	_hurtbox.set_deferred("monitoring", true)
	_hurtbox.set_deferred("monitorable", true)
	_body.rotation = 0.0
	_body.position = Vector2(0.0, FEET_Y)
	_gun_pivot.visible = true
	_sprite.play(&"idle")
	global_position = respawn_point
	velocity = Vector2.ZERO
	_dash_time_left = 0.0
	_dash_cooldown_left = 0.0
	_knockback_left = 0.0
	_air_jumps_left = air_jumps
	_can_air_dash = true
	_camera.reset_smoothing()
	GameState.player_respawned.emit()


func take_damage(amount: float, source: Node = null) -> void:
	_health.take_damage(amount, source)


func _on_died(_source: Node) -> void:
	_is_dead = true
	velocity.x = 0.0
	collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	_gun_pivot.visible = false
	_sprite.stop()
	var fall_tween := create_tween()
	_death_tween = fall_tween
	fall_tween.set_parallel(true)
	fall_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(
		_body,
		"rotation",
		deg_to_rad(death_fall_angle_degrees * facing),
		death_fall_duration
	)
	fall_tween.tween_property(_body, "position:x", 3.0 * facing, death_fall_duration)
	fall_tween.chain().tween_callback(respawn)
	GameState.player_died.emit()


func _on_damaged(_amount: float, _source: Node) -> void:
	var flash := create_tween()
	flash.tween_property(_body, "modulate", Color(2.0, 0.5, 0.5), 0.04)
	flash.tween_property(_body, "modulate", Color.WHITE, 0.15)


func _aim() -> void:
	_gun_pivot.position = Vector2(_skin.shoulder.x * facing, _skin.shoulder.y + FEET_Y)
	var to_mouse := _touch_aim if _touch_active else get_global_mouse_position() - _gun_pivot.global_position
	if _touch_active or to_mouse.length_squared() > 1.0:
		_aim_direction = to_mouse.normalized()
	_gun_pivot.rotation = _aim_direction.angle()
	# Mirror instead of rotating upside down when aiming left.
	_gun_pivot.scale.y = -1.0 if _aim_direction.x < 0.0 else 1.0


func _shoot(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if not _touch_shooting and get_viewport().gui_get_hovered_control() != null:
		return
	var shooting := _touch_shooting if _touch_active else Input.is_action_pressed("shoot")
	if not shooting or _fire_cooldown > 0.0:
		return
	_fire_cooldown = 1.0 / fire_rate

	var bullet: PlayerBullet = BULLET_SCENE.instantiate()
	bullet.direction = _aim_direction
	bullet.damage = bullet_damage
	bullet.source = self
	bullet.texture = _skin.bullet_texture
	bullet.texture_scale = _skin.bullet_scale
	bullet.texture_filter = _sprite.texture_filter
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = _muzzle.global_position
	_play(_shoot_sound)


func _on_sprite_frame_changed() -> void:
	if _sprite.animation == &"run" and is_on_floor() and _sprite.frame in _skin.step_frames:
		_play(_step_sound)


func _play(player: AudioStreamPlayer) -> void:
	if player.stream:
		player.play()


func _animate() -> void:
	var animation := &"idle"
	if not is_on_floor():
		animation = &"jump" if velocity.y < 0.0 else &"fall"
	elif absf(velocity.x) > 5.0:
		animation = &"run"
	if _sprite.animation != animation:
		_sprite.play(animation)


func _apply_skin() -> void:
	_skin = SKINS[skin_index] as PlayerSkin

	_sprite.sprite_frames = _skin.sprite_frames
	_sprite.offset = _skin.sprite_offset
	_sprite.scale = Vector2.ONE * _skin.sprite_scale
	_sprite.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if _skin.smooth_filter
		else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	)
	_sprite.play(&"idle")

	_gun.texture = _skin.gun_texture
	_gun.offset = _skin.gun_offset
	_gun.position = Vector2(_skin.gun_distance, 0.0)
	_muzzle.position = _skin.muzzle + _gun.position

	_jump_sound.stream = _skin.jump_sound
	_step_sound.stream = _skin.step_sound
	_shoot_sound.stream = _skin.shoot_sound

	var shape := RectangleShape2D.new()
	shape.size = _skin.body_size
	_collision.shape = shape
	_collision.position = Vector2(0.0, FEET_Y - _skin.body_size.y / 2.0)
	skin_changed.emit(_skin)
