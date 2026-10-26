extends Node2D
# Headless check of each hazard on its own in a generated test room.
# Run:  godot --headless --path . res://tests/hazard_test/test_hazards.tscn

const PLAYER := preload("res://characters/player/player.tscn")
const LAVA := preload("res://objects/hazards/lava.tscn")
const TOXIC := preload("res://objects/hazards/toxic.tscn")
const LASER := preload("res://objects/hazards/laser.tscn")
const HAMMER := preload("res://objects/hazards/hammer.tscn")
const BLADE := preload("res://objects/hazards/blade.tscn")
const GEYSER := preload("res://objects/hazards/geyser.tscn")
const BOULDER := preload("res://objects/hazards/boulder.tscn")
const GATE := preload("res://levels/shared/gate.tscn")
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
var stun_seen := false
var boulder: Node2D
var hammer: Node2D


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
	player.stunned = false
	stun_seen = false


## The handle is solid: the player's shape can't move through its middle from either side.
func _check_hammer_handle() -> void:
	var handle := hammer.get_node_or_null("Handle") as AnimatableBody2D
	_check(handle != null and handle.collision_layer == 1, "hammer: handle is a solid world body")
	if handle == null:
		return
	var arm: Node2D = hammer.get_node("Arm")
	# Check the physics server, not the node: a body under a rotating parent looks right but stays put.
	var physics_xf := PhysicsServer2D.body_get_state(handle.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D
	_check(absf(angle_difference(physics_xf.get_rotation(), arm.global_rotation)) < 0.05 and absf(arm.rotation) > 0.05,
		"hammer: handle's physics body swings with the arm (body %.1f, arm %.1f deg)" % [rad_to_deg(physics_xf.get_rotation()), rad_to_deg(arm.global_rotation)])
	var middle: Vector2 = hammer.to_global(Vector2(0, hammer.length * 0.5).rotated(arm.rotation))
	var saved := player.global_transform
	var blocked_from_left := player.test_move(Transform2D(0.0, middle + Vector2(-30, 0)), Vector2(60, 0))
	var blocked_from_right := player.test_move(Transform2D(0.0, middle + Vector2(30, 0)), Vector2(-60, 0))
	var free_away := not player.test_move(Transform2D(0.0, middle + Vector2(-30, 0)), Vector2(-20, 0))
	player.global_transform = saved
	_check(blocked_from_left and blocked_from_right and free_away, "hammer: can't pass through the handle")


func _check(ok: bool, msg: String) -> void:
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + msg)


func _physics_process(_delta: float) -> void:
	frame += 1
	stun_seen = stun_seen or player.stunned
	match [step, frame]:
		[0, 10]: # toxic: standing in it hurts every time invincibility (0.65 s) runs out
			_spawn(TOXIC, Vector2(160, -32), {"size": Vector2(96, 32)})
			_place(Vector2(208, -20))
		[0, 70]:
			_check(hits == 2, "toxic: 2 hits in 1.0 s while standing in it (got %d)" % hits)
			_check(health.max_health - health.current == 4.0, "toxic: 2 damage per hit (lost %d HP)" % (health.max_health - health.current))
			var toxic := get_children().filter(func(n: Node) -> bool: return n.scene_file_path == TOXIC.resource_path)[0] as Node2D
			_check(toxic.z_index > player.z_index, "toxic: drawn in front of the player")
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
			_check(hit_at != Vector2.INF and absf(player.global_position.x - hit_at.x) > 16.0,
				"laser: knocked back (hit at x=%.0f, now x=%.0f)" % [hit_at.x, player.global_position.x])
			_check(stun_seen and not player.stunned, "laser: stunned, then free again after landing")
			_next()
		[2, 1]: # blades
			_spawn(BLADE, Vector2(1400, -14))
			_place(Vector2(1400, -20))
		[2, 15]:
			_check(hits == 1, "fixed blade: 1 HP on contact (got %d)" % hits)
			_check(absf(player.global_position.x - 1400.0) > 16.0 and stun_seen,
				"fixed blade: knocked back and stunned (now x=%.0f)" % player.global_position.x)
			var b: Node = _spawn(BLADE, Vector2(1600, -200), {"travel": Vector2(128, 0), "seconds_one_way": 1.0, "pause": 0.3})
			_check(b.offset_at(1.3).is_equal_approx(Vector2(128, 0)) and b.offset_at(2.6).is_zero_approx(),
				"track blade reaches both ends of its track")
			_place(Vector2(600, -20))
		[2, 60]: # stun: holding right does nothing until the player lands
			_place(Vector2(600, -20))
			player.apply_knockback(Vector2(-200, -200), true)
			Input.action_press("move_right")
			Input.action_press("jump")
		[2, 70]:
			_check(player.stunned and player.velocity.x == -200.0 and not player.can_dash(),
				"stun: no steering or dash in the air (vx=%.0f)" % player.velocity.x)
		[2, 120]:
			_check(not player.stunned and player.velocity.x > 0.0,
				"stun: steering back after landing (vx=%.0f)" % player.velocity.x)
			Input.action_release("move_right")
			Input.action_release("jump")
			_place(Vector2(600, -20))
			_next()
		[3, 1]: # hammer: 1 HP and pushed away from the pivot
			hammer = _spawn(HAMMER, Vector2(2000, -120))
			_place(Vector2(2030, -20))
			mark = player.global_position
		[3, 200]:
			_check(hits >= 1, "hammer: hit the player (got %d)" % hits)
			_check(hit_at != Vector2.INF and player.global_position.x - 2000.0 > hit_at.x - 2000.0 + 16.0,
				"hammer: knocked away from the pivot (hit at x=%.0f, now x=%.0f)" % [hit_at.x, player.global_position.x])
			_check_hammer_handle()
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
			_next()
		[5, 1]: # geyser: idle 0.5 s -> warn 0.5 s (harmless) -> erupt 1.0 s (instant death up the column)
			_spawn(GEYSER, Vector2(3200, -32), {"idle_min": 0.5, "idle_max": 0.5, "warn_time": 0.5})
			_place(Vector2(3216, -20))
			died = false
		[5, 50]:
			_check(not died and hits == 0, "geyser: harmless while idle/warning")
		[5, 80]:
			_check(died, "geyser: eruption kills")
		[5, 110]: # let the death fall play out and respawn the player before the next test
			_next()
		[6, 1]: # boulder: waits 0.5 s, eases to 200 px/s over 0.5 s, stops after 300 px
			boulder = _spawn(BOULDER, Vector2(4000, -48), {"delay": 0.5, "speed": 200.0, "accel_time": 0.5, "distance": 300.0})
			_check(boulder.offset_at(0.4) == 0.0 and is_equal_approx(boulder.offset_at(1.0), 50.0)
				and is_equal_approx(boulder.offset_at(2.0), 250.0) and boulder.offset_at(10.0) == 300.0,
				"boulder: wait, ease up, roll, stop at its distance")
			_place(Vector2(4200, -20))
			died = false
		[6, 20]:
			_check(boulder.position.x == 4000.0, "boulder: still waiting at the start")
		[6, 105]:
			_check(died, "boulder: crushes the player")
		[6, 125]: # the player has respawned by now, which sends the ball back to the start
			_check(boulder.position.x < 4010.0, "boulder: back at the start after the respawn (x=%.0f)" % boulder.position.x)
		[6, 270]:
			_check(boulder.position.x == 4300.0, "boulder: stops at the end of its run (x=%.0f)" % boulder.position.x)
			boulder.gate = _spawn(GATE, Vector2(5000, -80), {"closed": true})
			GameState.player_respawned.emit()
		[6, 275]:
			_check(boulder.position.x == 4300.0, "boulder: stays put on respawn once the gate is closed")
			print("%d failures" % failures)
			get_tree().quit(failures)


func _next() -> void:
	step += 1
	frame = 0
