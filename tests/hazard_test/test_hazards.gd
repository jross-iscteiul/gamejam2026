extends Node2D
# Headless check of each hazard on its own in a generated test room.
# Run:  godot --headless --path . res://tests/hazard_test/test_hazards.tscn

const PLAYER := preload("res://characters/player/player.tscn")
const LAVA := preload("res://objects/hazards/lava.tscn")
const TOXIC := preload("res://objects/hazards/toxic.tscn")
const LASER := preload("res://objects/hazards/laser.tscn")
const HAMMER := preload("res://objects/hazards/hammer.tscn")
const BLADE := preload("res://objects/hazards/blade.tscn")
const SPAWN := Vector2(100, -20)

var player: CharacterBody2D
var health: Health
var hits := 0
var died := false
var frame := 0
var step := 0
var failures := 0
var mark := Vector2.ZERO
var hit_at := Vector2.INF


func _ready() -> void:
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = Hazard.rect(Vector2(8000, 32))
	shape.position = Vector2(3000, 16)
	floor_body.add_child(shape)
	add_child(floor_body)
	player = PLAYER.instantiate()
	player.position = SPAWN
	add_child(player)
	player.respawn_point = SPAWN
	health = player.get_node("Health")
	health.damaged.connect(func(_a: float, _s: Node) -> void:
		hits += 1
		if hit_at == Vector2.INF:
			hit_at = player.global_position)
	health.died.connect(func(_s: Node) -> void: died = true)


func _spawn(scene: PackedScene, at: Vector2, props := {}) -> Node2D:
	var node: Node2D = scene.instantiate()
	for k in props:
		node.set(k, props[k])
	node.position = at
	add_child(node)
	return node


func _place(at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	health.restore()
	hits = 0
	hit_at = Vector2.INF


func _check(ok: bool, msg: String) -> void:
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + msg)


func _physics_process(_delta: float) -> void:
	frame += 1
	match [step, frame]:
		[0, 10]: # toxic: standing in it hurts every time invincibility (0.65 s) runs out
			_spawn(TOXIC, Vector2(160, -32), {"size": Vector2(96, 32)})
			_place(Vector2(208, -20))
		[0, 70]:
			_check(hits == 2, "toxic: 2 hits in 1.0 s while standing in it (got %d)" % hits)
			_place(Vector2(600, -20))
		[0, 75]: # overlaps update one physics step after a teleport
			hits = 0
		[0, 135]:
			_check(hits == 0, "toxic: no damage after leaving (got %d)" % hits)
			_next()
		[1, 1]: # laser: off 1.6 s -> warn 0.5 s -> on 1.0 s
			_spawn(LASER, Vector2(960, -12), {"length": 96.0})
			_place(Vector2(1008, -20))
		[1, 110]:
			_check(hits == 0, "laser: harmless while off/warning (got %d)" % hits)
		[1, 160]:
			_check(hits >= 1, "laser: hurts while on (got %d)" % hits)
			_next()
		[2, 1]: # blades
			_spawn(BLADE, Vector2(1400, -14))
			_place(Vector2(1400, -20))
		[2, 15]:
			_check(hits == 1, "fixed blade: 1 HP on contact (got %d)" % hits)
			var b: Node = _spawn(BLADE, Vector2(1600, -200), {"travel": Vector2(128, 0), "seconds_one_way": 1.0, "pause": 0.3})
			_check(b.offset_at(1.3).is_equal_approx(Vector2(128, 0)) and b.offset_at(2.6).is_zero_approx(),
				"track blade reaches both ends of its track")
			_place(Vector2(600, -20))
			_next()
		[3, 1]: # hammer: 1 HP and pushed away from the pivot
			_spawn(HAMMER, Vector2(2000, -120))
			_place(Vector2(2030, -20))
			mark = player.global_position
		[3, 200]:
			_check(hits >= 1, "hammer: hit the player (got %d)" % hits)
			_check(hit_at != Vector2.INF and player.global_position.x - 2000.0 > hit_at.x - 2000.0 + 16.0,
				"hammer: knocked away from the pivot (hit at x=%.0f, now x=%.0f)" % [hit_at.x, player.global_position.x])
			_place(Vector2(600, -20))
			_next()
		[4, 1]: # lava: instant death, then respawn at the checkpoint with full health
			_spawn(LAVA, Vector2(2560, -32), {"size": Vector2(96, 32)})
			player.respawn_point = SPAWN
			_place(Vector2(2608, -60))
			died = false
		[4, 90]:
			_check(died, "lava: kills on touch")
			_check(player.global_position.distance_to(SPAWN) < 40.0 and health.current == health.max_health,
				"lava: respawned at checkpoint with full health (at %s, hp %.0f)" % [player.global_position, health.current])
			print("%d failures" % failures)
			get_tree().quit(failures)


func _next() -> void:
	step += 1
	frame = 0
