class_name Interactable
extends Area2D
## "Press E" zone. Owned by Package 6, reusable by anyone.
##
## Add as a child of any object, give it a CollisionShape2D, and connect
## [signal interacted]. Shows a prompt above itself while the player is inside.
## Collision is set in code: layer 6 (pickups), mask 2 (player).

signal interacted(player: Node2D)
signal player_entered(player: Node2D)
signal player_exited(player: Node2D)

const LAYER_PICKUPS := 1 << 5
const LAYER_PLAYER := 1 << 1

@export var prompt_text: String = "[E] Interact":
	set(value):
		prompt_text = value
		_update_prompt()
@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_prompt()
## Where the prompt's center sits, relative to this node.
@export var prompt_offset: Vector2 = Vector2(0, -72)
## World-space size (the camera zooms 3x, so 8 reads as 24 px on a 1080p screen).
@export var prompt_font_size: int = 8
## The prompt is rendered this many times bigger and scaled back down, so the
## zoomed camera shows it at full resolution instead of blurry/broken.
@export var prompt_render_scale: float = 3.0

var _player: Node2D
var _prompt: Label


func _ready() -> void:
	collision_layer = LAYER_PICKUPS
	collision_mask = LAYER_PLAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_prompt()


func is_player_in_range() -> bool:
	return _player != null


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not enabled:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interacted.emit(_player)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_update_prompt()
		player_entered.emit(body)


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		_update_prompt()
		player_exited.emit(body)


func _create_prompt() -> void:
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var k := prompt_render_scale
	_prompt.add_theme_font_override("font", PixelFont.SOURCE)
	_prompt.add_theme_font_size_override("font_size", int(prompt_font_size * k))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", int(3 * k))
	_prompt.size = Vector2(320, prompt_font_size + 6) * k
	_prompt.scale = Vector2.ONE / k
	_prompt.position = prompt_offset - _prompt.size / k / 2.0
	add_child(_prompt)
	_update_prompt()


func _update_prompt() -> void:
	if _prompt == null:
		return
	_prompt.text = prompt_text
	_prompt.visible = enabled and _player != null
