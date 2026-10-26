extends Node2D
## Temporary leaderboard target. Replace its entity instance when Package 4's boss is ready.

var _active: bool = false
var _defeated: bool = false
@onready var _health: Health = $Health
@onready var _trigger: Area2D = get_node("../../BossTrigger")


func _ready() -> void:
	var spawn := get_node("../../BossSpawn") as Marker2D
	global_position = spawn.global_position
	spawn.get_node("Label").hide()
	$Hurtbox.health = _health
	_health.invulnerable = true
	_health.changed.connect(_health_changed)
	_health.died.connect(_die)
	_trigger.body_entered.connect(_activate)
	modulate.a = 0.35
	queue_redraw()


func _draw() -> void:
	var square := Rect2(-32, -48, 64, 64)
	draw_rect(square, Color("c94d75"))
	draw_rect(square, Color("ffe4a3"), false, 3.0)


func _activate(body: Node2D) -> void:
	if _active or _defeated or not body.is_in_group("player"):
		return
	_active = true
	_health.invulnerable = false
	modulate.a = 1.0
	_health_changed(_health.current, _health.max_health)


func _health_changed(current: float, maximum: float) -> void:
	if _active:
		GameState.boss_health_changed.emit(current, maximum)


func _die(_source: Node) -> void:
	if not _active or _defeated:
		return
	_defeated = true
	_trigger.get_node("Banner").hide()
	hide()
	GameState.boss_defeated.emit()
	queue_free()
