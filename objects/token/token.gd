class_name TokenPickup
extends Area2D
## Original 16-pixel industrial coin, drawn at native world scale. Big coins are worth five.

@export_range(1, 100) var value: int = 1
@export var big: bool = false
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_time = position.x * 0.035
	body_entered.connect(collect)
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			collect(area.get_parent())
	)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _collected:
		return
	var y := roundf(sin(_time * 3.5) * 2.0)
	var width := maxf(2.0, roundf(absf(cos(_time * 2.5)) * 7.0))
	var height := 9.0 if big else 7.0
	draw_rect(Rect2(-width, y - height + 2, width * 2, height * 2 - 4), Color("805327"))
	draw_rect(Rect2(-width + 2, y - height, maxf(2, width * 2 - 4), height * 2), Color("805327"))
	draw_rect(Rect2(-width + 1, y - height + 2, maxf(1, width * 2 - 2), height * 2 - 4), GameUI.GOLD)
	draw_rect(Rect2(-width + 2, y - height + 1, maxf(1, width * 2 - 4), 2), Color("fff2b1"))
	if width >= 5:
		draw_rect(Rect2(-1, y - 3, 2, 6), Color("b78036"))
		if big:
			draw_rect(Rect2(-3, y - 1, 6, 2), Color("b78036"))


func collect(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	var health := body.get_node_or_null("Health") as Health
	if health and health.current <= 0.0:
		return
	_collected = true
	GameState.add_tokens(value)
	GameState.token_collected.emit(value)
	# Parent owns the sound so freeing this pickup cannot cut off the chime.
	GameUI.play_sound(get_tree().current_scene, GameUI.chime(true))
	queue_free()
