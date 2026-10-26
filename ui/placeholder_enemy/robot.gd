extends CharacterBody2D
## Package 3 test enemy, isolated here until Package 4 supplies its own scenes.
## Uses the existing robot art; never instances the player controller.

const SKIN: PlayerSkin = preload("res://characters/player/robot.tres")
const SHOT := preload("res://ui/placeholder_enemy/shot.tscn")
const DROP := preload("res://objects/token/token_small.tscn")

@export var patrol_distance: float = 64.0
@export var speed: float = 24.0
@export var fire_interval: float = 2.0
@export var detection_range: float = 240.0
@export var hit_points: float = 3.0

var _home: float
var _direction: float = -1.0
var _shot_left: float = 1.2
var _dead: bool = false
var _assembled: bool = false # bolted onto the giant: still a live unit, but no longer its own
@onready var _health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_home = position.x
	_health.max_health = hit_points
	_health.restore()
	$Hurtbox.health = _health
	$Contact.source = self
	_health.died.connect(_die)
	_health.damaged.connect(_flash)
	_sprite.sprite_frames = SKIN.sprite_frames
	_sprite.play(&"run")
	_shot_left += fposmod(position.x * 0.01, 1.0)


func _physics_process(delta: float) -> void:
	if _dead or _assembled:
		return
	velocity.y = minf(velocity.y + 980.0 * delta, 800.0)
	if is_on_wall() or absf(position.x - _home) > patrol_distance:
		_direction = signf(_home - position.x)
	var ahead := global_position + Vector2(_direction * 16, 0)
	var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 30), 1)
	if is_on_floor() and get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		_direction *= -1.0
	velocity.x = _direction * speed
	move_and_slide()
	_sprite.flip_h = _direction < 0.0
	_shot_left -= delta
	if _shot_left <= 0.0:
		_try_shoot()


func _try_shoot() -> void:
	_shot_left = fire_interval
	var target := get_tree().get_first_node_in_group("player") as Node2D
	if not target or target.global_position.distance_to(global_position) > detection_range:
		return
	var origin := global_position + Vector2(0, -8)
	var destination := target.global_position + Vector2(0, -8)
	var sight := PhysicsRayQueryParameters2D.create(origin, destination, 1)
	if not get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
		return
	var shot := SHOT.instantiate()
	shot.source = self
	shot.direction = origin.direction_to(destination)
	get_tree().current_scene.add_child(shot)
	shot.global_position = origin + shot.direction * 16


func take_damage(amount: float, source: Node = null) -> void:
	_health.take_damage(amount, source)


func _flash(_amount: float, _source: Node) -> void:
	var tween := create_tween()
	_sprite.modulate = GameUI.RED
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


## Pulled out of the ranks to become a limb of JARVIS's giant form: it stops patrolling and
## shooting on its own and its boxes go quiet, because the giant does the damage from now on.
func conscript() -> void:
	if _assembled:
		return
	_assembled = true
	velocity = Vector2.ZERO
	_disable_areas()
	_sprite.play(&"idle")


## The network went dark (JARVIS shot down): no kill credit, no drop, just a unit falling over.
func shut_down() -> void:
	if _dead:
		return
	_dead = true
	_disable_areas()
	_sprite.pause()
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_sprite, "modulate", Color(0.25, 0.25, 0.3, 0.0), 1.0)
	tween.tween_property(_sprite, "rotation", deg_to_rad(90.0 * _direction), 0.8) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	queue_free()


## A downed unit must be harmless to walk over: the contact hitbox has to stop being monitorable
## too, because the player's hurtbox is the side that watches for it.
func _disable_areas() -> void:
	$Contact.continuous = false
	for area: Area2D in [$Hurtbox, $Contact]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		area.get_node("Shape").set_deferred("disabled", true)


func _die(killer: Node) -> void:
	if _dead:
		return
	_dead = true
	_disable_areas() # a corpse must not damage the player on the frame it dies
	GameState.enemy_killed.emit(self, killer)
	var drop := DROP.instantiate()
	get_parent().add_child.call_deferred(drop)
	drop.set_deferred("global_position", global_position + Vector2(0, -10))
	queue_free()
