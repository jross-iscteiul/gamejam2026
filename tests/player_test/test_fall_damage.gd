extends Node2D
# Headless check of player fall damage: safe drops are free, damage grows faster than the drop,
# settings are respected, and normal jumping on flat ground never hurts.
# Run:  godot --headless --path . res://tests/player_test/test_fall_damage.tscn
const PLAYER := preload("res://characters/player/player.tscn")
const FLOOR_Y := 0.0
# [label, drop in tiles relative to the default safe height (feet to floor), settings to apply]
const CASES := [
	["drop 2 tiles below the safe height is free", -2, {}],
	["drop 1 tile over the safe height hurts a little", 1, {}],
	["drop 5 tiles over hurts a lot more", 5, {}],
	["fall damage can be disabled", 5, {"fall_damage_enabled": false}],
	["fall damage can be capped", 5, {"fall_damage_max": 2.0}],
	["safe height is configurable", 5, {"safe_fall_height": 1000.0}],
]

var player: Player
var PLAYER_DEFAULT_SAFE: float = 0.0
var _defaults := {}
var _case := 0
var _t := 0
var _damage: Array[float] = []
var _failed := false


func _ready() -> void:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = Hazard.rect(Vector2(4000, 64))
	shape.position = Vector2(0, FLOOR_Y + 32)
	floor_body.add_child(shape)
	add_child(floor_body)
	player = PLAYER.instantiate()
	player.position = Vector2(0, FLOOR_Y - 16)
	add_child(player)
	PLAYER_DEFAULT_SAFE = player.safe_fall_height
	for key in ["fall_damage_enabled", "fall_damage_max", "safe_fall_height"]:
		_defaults[key] = player.get(key)


func _physics_process(_delta: float) -> void:
	_t += 1
	if _case >= CASES.size():
		return _jump_check()
	var k: Array = CASES[_case]
	if _t == 1:
		player.respawn()
		for key in k[2]:
			player.set(key, k[2][key])
		# Origin is 16 px above the feet; drop the feet from the default safe height + k[1] tiles.
		var drop: float = PLAYER_DEFAULT_SAFE + k[1] * 32.0
		player.global_position = Vector2(0, FLOOR_Y - 16 - drop)
		player.velocity = Vector2.ZERO
		player.get_node("Health").restore()
	if _t == 120:
		var health: Health = player.get_node("Health")
		_damage.append(health.max_health - health.current)
		_report(k)
		for key in k[2]: # back to defaults
			player.set(key, _defaults[key])
		_case += 1
		_t = 0


func _report(k: Array) -> void:
	var d: float = _damage.back()
	match _case:
		0: _check(d == 0.0, "%s (took %d)" % [k[0], d])
		1: _check(d >= 1.0 and d < 4.0, "%s (took %d)" % [k[0], d])
		2: _check(d > _damage[1] * 2.0, "%s (took %d vs %d for 1 tile over)" % [k[0], d, _damage[1]])
		3: _check(d == 0.0, "%s (took %d)" % [k[0], d])
		4: _check(d == 2.0, "%s (took %d)" % [k[0], d])
		5: _check(d == 0.0, "%s (took %d)" % [k[0], d])


## Ground jump plus a full-height air jump on flat ground stays under the safe height.
func _jump_check() -> void:
	match _t:
		1:
			player.respawn()
			player.global_position = Vector2(0, FLOOR_Y - 16)
			player.get_node("Health").restore()
			player.boost_jump() # the double jump JARVIS would sell
		10: Input.action_press("jump")
		12: Input.action_release("jump")
		40: Input.action_press("jump")
		42: Input.action_release("jump")
		160:
			var health: Health = player.get_node("Health")
			_check(health.current == health.max_health and player.last_fall_height > 150.0,
				"double jump on flat ground never hurts (fell %d px)" % player.last_fall_height)
			var expected := ceilf(player.fall_damage_scale * pow(6.0, player.fall_damage_exponent))
			_check(player.fall_damage_for(player.safe_fall_height) == 0.0 and player.fall_damage_for(player.safe_fall_height + 6.0 * player.fall_damage_step) == expected,
				"damage curve follows scale * steps ^ exponent (6 tiles over = %d HP)" % expected)
			get_tree().quit(1 if _failed else 0)


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	_failed = _failed or not ok
