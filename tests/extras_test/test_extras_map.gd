extends Node2D
## Package 6 test map: the real Player and HUD, a floor, a wall, a high ledge,
## gambling stations and a RoastDirector. 32x32 tiles.
##
## Player controls are the real ones (A/D, Space/W, mouse, Shift/X, 1-6 skins).
## Debug: [T] +5 tokens, [L] next level (1-4), [R] reset stations, [Y] refill energy,
##        [K] die and respawn, [J] fake kill by the player, [F] fast roasts.

const PLAYER_SCENE := preload("res://characters/player/player.tscn")
const HUD_SCENE := preload("res://ui/hud/hud.tscn")
const TILE := 32

@export var start_tokens: int = 20
@export var start_level: int = 1

var _debug: Label
var _player: Player

@onready var _roasts: RoastDirector = $RoastDirector


func _ready() -> void:
	GameState.reset_run()
	GameState.begin_level(start_level)
	GameState.tokens = start_tokens
	RenderingServer.set_default_clear_color(Color(0.835, 0.902, 0.961))

	_add_block(Rect2i(-10, 0, 50, 6))  # floor
	_add_block(Rect2i(-2, -4, 1, 4))  # wall to walk into
	_add_block(Rect2i(16, -9, 4, 1))  # high ledge, for long falls

	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(TILE, -Player.FEET_Y)
	add_child(_player)
	add_child(HUD_SCENE.instantiate())
	_build_debug()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_T:
			GameState.add_tokens(5)
		KEY_L:
			GameState.current_level = GameState.current_level % 4 + 1
			_reset_stations()
		KEY_R:
			_reset_stations()
		KEY_Y:
			GameState.energy = GameState.MAX_ENERGY
		KEY_K:
			_player.respawn()
		KEY_J:
			GameState.enemy_killed.emit(null, _player)
		KEY_F:
			var fast := _roasts.global_cooldown > 0.0
			_roasts.global_cooldown = 0.0 if fast else 8.0
			_roasts.category_cooldown = 0.0 if fast else 30.0
			_roasts.chance = 1.0 if fast else 0.7
		_:
			return
	_update_debug()


func _reset_stations() -> void:
	for child in get_children():
		if child is GamblingStation:
			child.reset_spins()


func _add_block(tiles: Rect2i) -> void:
	var rect := Rect2(tiles.position * TILE, tiles.size * TILE)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	var fill := Polygon2D.new()
	fill.color = MachineDrawing.STEEL_DARK
	fill.polygon = _rect_points(rect)
	body.add_child(fill)
	var cap := Polygon2D.new()
	cap.color = MachineDrawing.ORANGE
	cap.polygon = _rect_points(Rect2(rect.position, Vector2(rect.size.x, 4)))
	body.add_child(cap)
	add_child(body)


func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _build_debug() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	_debug = Label.new()
	_debug.add_theme_font_override("font", PixelFont.get_font())
	_debug.add_theme_font_size_override("font_size", 16)
	_debug.add_theme_color_override("font_color", Color.BLACK)
	_debug.position = Vector2(24, 1000)
	layer.add_child(_debug)
	add_child(layer)
	_update_debug()


func _update_debug() -> void:
	var fast := "ON" if _roasts.global_cooldown == 0.0 else "off"
	_debug.text = "LEVEL %d  FAST ROASTS %s  |  [T] +5 TKN [L] LEVEL [R] RESET [Y] ENERGY [K] DIE [J] KILL [F] FAST" % [
		GameState.current_level, fast,
	]
