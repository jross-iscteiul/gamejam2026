class_name Player
extends CharacterBody2D
## Player controller: run, variable-height jump, double jump and a mouse-aimed gun.

const SKINS := [
	preload("res://characters/player/biker.tres"),
	preload("res://characters/player/bot_wheel.tres"),
	preload("res://characters/player/penguin.tres"),
	preload("res://characters/player/free_soldier.tres"),
]
const BULLET_SCENE: PackedScene = preload("res://characters/player/bullet.tscn")
const DOUBLE_TAP_WINDOW_MSEC: int = 250

@export_enum("Biker", "Bot Wheel", "Penguin", "Free Soldier") var skin_index: int = 0:
	set(value):
		skin_index = value
		if is_node_ready():
			_apply_skin()

@export_group("Movement")
@export var move_speed: float = 130.0
@export var ground_acceleration: float = 1400.0
@export var air_acceleration: float = 900.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 400.0

@export_group("Dash")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.45

@export_group("Death")
@export_range(30.0, 110.0) var death_fall_angle_degrees: float = 82.0
@export var death_fall_duration: float = 0.35

@export_group("Jump")
@export var jump_velocity: float = 300.0
@export var double_jump_velocity: float = 260.0
@export var air_jumps: int = 1
## Upward speed is multiplied by this when jump is released early.
@export_range(0.0, 1.0) var jump_cut: float = 0.5

@export_group("Gun")
## Shots per second while shoot is held.
@export var fire_rate: float = 6.0
@export var bullet_damage: float = 1.0

var _skin: PlayerSkin
var _facing: int = 1
var _air_jumps_left: int = 0
var _aim_direction: Vector2 = Vector2.RIGHT
var _fire_cooldown: float = 0.0
var _last_tap_direction: int = 0
var _last_tap_time_msec: int = 0
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _is_dead: bool = false

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


func _ready() -> void:
	_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_hurtbox.health = _health
	_health.died.connect(_on_died)
	_apply_skin()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		move_and_slide()
		return
	_handle_dash_input()
	_move(delta)
	_aim()
	_shoot(delta)
	_animate()


func _move(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	var on_floor := is_on_floor()
	if on_floor:
		_air_jumps_left = air_jumps
	else:
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

	var input_x := Input.get_axis("move_left", "move_right")
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)
		velocity.x = signf(velocity.x) * dash_speed
	else:
		var acceleration := ground_acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, input_x * move_speed, acceleration * delta)
	if input_x != 0.0:
		_facing = 1 if input_x > 0.0 else -1
	elif absf(velocity.x) <= 5.0:
		var mouse_delta_x := get_global_mouse_position().x - global_position.x
		if absf(mouse_delta_x) > 1.0:
			_facing = 1 if mouse_delta_x > 0.0 else -1
	_body.scale.x = _facing

	move_and_slide()


func _handle_dash_input() -> void:
	var direction := 0
	if Input.is_action_just_pressed("move_left"):
		direction = -1
	elif Input.is_action_just_pressed("move_right"):
		direction = 1
	if direction == 0:
		return

	var now := Time.get_ticks_msec()
	if direction == _last_tap_direction and now - _last_tap_time_msec <= DOUBLE_TAP_WINDOW_MSEC:
		dash(Vector2(direction, 0.0))
		_last_tap_direction = 0
	else:
		_last_tap_direction = direction
		_last_tap_time_msec = now


func dash(direction: Vector2) -> void:
	if _is_dead or _dash_cooldown_left > 0.0:
		return
	var horizontal_direction := signf(direction.x)
	if horizontal_direction == 0.0:
		horizontal_direction = float(_facing)
	_facing = int(horizontal_direction)
	_body.scale.x = _facing
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	velocity.x = horizontal_direction * dash_speed


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
	fall_tween.set_parallel(true)
	fall_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(
		_body,
		"rotation",
		deg_to_rad(death_fall_angle_degrees * _facing),
		death_fall_duration
	)
	fall_tween.tween_property(_body, "position:x", 3.0 * _facing, death_fall_duration)
	GameState.player_died.emit()


func _aim() -> void:
	_gun_pivot.position = Vector2(_skin.shoulder.x * _facing, _skin.shoulder.y)
	var to_mouse := get_global_mouse_position() - _gun_pivot.global_position
	if to_mouse.length_squared() > 1.0:
		_aim_direction = to_mouse.normalized()
	_gun_pivot.rotation = _aim_direction.angle()
	# Mirror instead of rotating upside down when aiming left.
	_gun_pivot.scale.y = -1.0 if _aim_direction.x < 0.0 else 1.0


func _shoot(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if not Input.is_action_pressed("shoot") or _fire_cooldown > 0.0:
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
	_collision.position = Vector2(0.0, -_skin.body_size.y / 2.0)
