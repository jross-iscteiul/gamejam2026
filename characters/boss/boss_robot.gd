class_name BossRobot
extends CharacterBody2D
## Level 4 boss: a scaled-up industrial robot that holds the arena, paces after the player and
## fires volleys. It is only the first half of the fight — at final_phase_at it gives up, hands
## its contract to JARVIS (see Jarvis.betray()) and lets him finish the job as the last opponent.

const SKIN: PlayerSkin = preload("res://characters/player/robot.tres")
const SHOT := preload("res://ui/placeholder_enemy/shot.tscn")
const GRAVITY := 980.0

@export var max_health: float = 10.0
## Fraction of max health at which the robot stops fighting and JARVIS takes over.
@export_range(0.0, 1.0) var final_phase_at: float = 0.4
## Lifted off the spawn marker so the scaled-up feet rest on the arena floor.
@export var spawn_offset: Vector2 = Vector2(0.0, -16.0)
## Where JARVIS settles once he has crossed over, relative to the robot.
@export var handover_anchor: Vector2 = Vector2(0.0, -96.0)

@export_group("Movement")
@export var walk_speed: float = 46.0
@export var preferred_range: float = 150.0 # keeps this much air between him and the player
@export var range_tolerance: float = 40.0
@export var patrol_distance: float = 220.0 # never leaves this far from his spawn

@export_group("Attacks")
@export var volley_interval: float = 2.4
@export var volley_shots: int = 3
@export var volley_spacing: float = 0.14
@export var volley_spread_degrees: float = 7.0
@export var muzzle: Vector2 = Vector2(18.0, -34.0)
## Every Nth volley is a ground slam: he jumps, lands hard and sweeps shots both ways.
@export var slam_every: int = 3
@export var slam_jump_speed: float = 420.0

var _active: bool = false
var _defeated: bool = false
var _final_phase: bool = false
var _home_x: float = 0.0
var _facing: int = -1
var _attack_left: float = 1.5
var _volleys: int = 0
var _slamming: bool = false
var _rng := RandomNumberGenerator.new()
@onready var _health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _trigger: Area2D = get_node("../../BossTrigger")


func _ready() -> void:
	_rng.randomize()
	var spawn := get_node("../../BossSpawn") as Marker2D
	global_position = spawn.global_position + spawn_offset
	spawn.get_node("Label").hide()
	_home_x = global_position.x
	_sprite.sprite_frames = SKIN.sprite_frames
	_sprite.play(&"idle")
	_health.max_health = max_health
	_health.restore()
	$Hurtbox.health = _health
	$Contact.source = self
	_health.changed.connect(_health_changed)
	_health.damaged.connect(_flash)
	_health.died.connect(_die)
	_health.invulnerable = true
	_trigger.body_entered.connect(_activate)
	modulate.a = 0.35


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 800.0)
	if _active and not _final_phase and not _defeated:
		_fight(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 4.0 * delta)
	move_and_slide()
	_animate()


func _activate(body: Node2D) -> void:
	if _active or _defeated or not body.is_in_group("player"):
		return
	_active = true
	_health.invulnerable = false
	modulate.a = 1.0
	_health_changed(_health.current, _health.max_health)
	GameState.boss_label_changed.emit("FOREMAN UNIT")
	get_tree().call_group("minion_door", "set_active", true)


## Holds his preferred range: closes in when the player runs, backs off when crowded.
func _fight(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var gap := player.global_position.x - global_position.x
	_facing = -1 if gap < 0.0 else 1
	if _slamming:
		velocity.x = 0.0
	else:
		var distance := absf(gap)
		var drive := 0.0
		if distance > preferred_range + range_tolerance:
			drive = signf(gap)
		elif distance < preferred_range - range_tolerance:
			drive = -signf(gap)
		if absf(global_position.x + drive * 8.0 - _home_x) > patrol_distance:
			drive = 0.0 # stays inside his half of the arena
		velocity.x = drive * walk_speed
	if is_on_floor() and _slamming:
		_land_slam()
	_attack_left -= delta
	if _attack_left <= 0.0:
		_attack_left = volley_interval
		_volleys += 1
		if _volleys % slam_every == 0:
			_start_slam()
		else:
			_volley(player)


func _volley(player: Node2D) -> void:
	for i in volley_shots:
		if _defeated or _final_phase or not is_instance_valid(player):
			return
		var origin := global_position + Vector2(muzzle.x * _facing, muzzle.y)
		var aim := origin.direction_to(player.global_position + Vector2(0, -8))
		var spread := deg_to_rad(_rng.randf_range(-volley_spread_degrees, volley_spread_degrees))
		_fire(origin, aim.rotated(spread))
		await get_tree().create_timer(volley_spacing).timeout


## Ground slam: he hops, and the landing sprays shots along the floor to both sides.
func _start_slam() -> void:
	if not is_on_floor():
		return
	_slamming = true
	velocity.y = -slam_jump_speed


func _land_slam() -> void:
	_slamming = false
	_shake_camera()
	var origin := global_position + Vector2(0, -8)
	for direction in [Vector2.LEFT, Vector2.RIGHT]:
		_fire(origin + direction * 20.0, (direction + Vector2.UP * 0.12).normalized())


func _fire(origin: Vector2, direction: Vector2) -> void:
	var shot: Hitbox = SHOT.instantiate()
	shot.source = self
	shot.direction = direction
	get_tree().current_scene.add_child(shot)
	shot.global_position = origin


func _animate() -> void:
	_sprite.flip_h = _facing < 0
	var animation := &"idle"
	if not is_on_floor():
		animation = &"jump" if velocity.y < 0.0 else &"fall"
	elif absf(velocity.x) > 1.0:
		animation = &"run"
	if _sprite.animation != animation:
		_sprite.play(animation)


func _flash(_amount: float, _source: Node) -> void:
	if _final_phase:
		return
	var tween := create_tween()
	_sprite.modulate = GameUI.RED
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _health_changed(current: float, maximum: float) -> void:
	if not _active:
		return
	GameState.boss_health_changed.emit(current, maximum)
	if not _final_phase and current > 0.0 and current <= maximum * final_phase_at:
		_enter_final_phase()


## The robot powers down and JARVIS takes the fight over. Without a JARVIS in the scene
## (chapter practice runs) the robot simply keeps fighting to the end.
func _enter_final_phase() -> void:
	var jarvis := get_tree().get_first_node_in_group("jarvis") as Jarvis
	if jarvis == null or jarvis.hostile:
		return
	_final_phase = true
	_health.invulnerable = true
	_disable_areas() # kneeling: no more hits taken, and harmless to stand next to
	GameState.boss_label_changed.emit("") # his bar goes away; JARVIS brings up his own
	jarvis.defeated.connect(_finish)
	_power_down()
	jarvis.betray(global_position + handover_anchor)


## He topples over and lies dead on the floor while the contract moves over to JARVIS. His body
## leaves the enemy layer, so the wreck is scenery: shots fly straight through it.
func _power_down() -> void:
	collision_layer = 0
	_sprite.play(&"idle")
	_sprite.speed_scale = 0.0
	var rest := _sprite.position
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "modulate", Color(0.35, 0.33, 0.42, 1.0), 0.8)
	# Fall around his feet (the node origin): the sprite's offset turns with the rotation.
	tween.tween_method(func(angle: float) -> void:
		_sprite.rotation = angle
		_sprite.position = rest.rotated(angle), 0.0, deg_to_rad(-90.0 * _facing), 0.8) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_shake_camera()


## Called when the whole network goes dark (JARVIS shot down), so he collapses with his minions.
func shut_down() -> void:
	_final_phase = true
	_disable_areas()
	_sprite.speed_scale = 0.0
	if collision_layer == 0:
		return # already lying dead on the floor since the handover
	var tween := create_tween().set_parallel()
	tween.tween_property(_sprite, "modulate", Color(0.2, 0.2, 0.25, 0.0), 1.0)
	tween.tween_property(_sprite, "rotation", deg_to_rad(80.0 * _facing), 1.0) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## A downed unit must be harmless to walk over: the contact hitbox has to stop being monitorable
## too, because the player's hurtbox is the side that watches for it.
func _disable_areas() -> void:
	$Contact.continuous = false
	for area: Area2D in [$Hurtbox, $Contact]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		area.get_node("Shape").set_deferred("disabled", true)


func _shake_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := create_tween()
	for i in 5:
		tween.tween_property(camera, "offset", Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-4, 4)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)


func _die(_source: Node) -> void:
	if not _active or _defeated or _final_phase:
		return # in the last phase only JARVIS can end the fight
	_finish()


func _finish() -> void:
	if _defeated:
		return
	_defeated = true
	_trigger.get_node("Banner").hide()
	get_tree().call_group("minion_door", "shut_down")
	hide()
	GameState.boss_defeated.emit()
	queue_free()
