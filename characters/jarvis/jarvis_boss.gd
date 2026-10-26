class_name JarvisBoss
extends Node
## Final phase of the boss fight: once JARVIS has switched sides (see Jarvis.betray()) this
## controller takes over his drone and fights the player as the last opponent. It is added as a
## child of the Jarvis node and drives its position, face and attacks; the drone's own follow,
## shooting and ability code is disabled while Jarvis.hostile is true.

const SHOT := preload("res://ui/placeholder_enemy/shot.tscn")

@export var max_health: float = 12.0
## Armoured: it is three machines in one, so player shots land at this fraction of their damage.
@export_range(0.0, 1.0) var damage_multiplier: float = 0.5
## Hurtbox/contact radius of the assembled giant, before the drone's own scale.
@export var body_radius: float = 20.0
@export_group("Movement")
@export var hover_distance: float = 110.0 # how far he keeps from the player
@export var hover_height: float = -56.0
@export var move_speed: float = 125.0 # the giant is heavier than the drone was
@export var strafe_amplitude: float = 26.0
@export var strafe_speed: float = 2.2
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 4.0
@export_group("Attacks")
@export var volley_interval: float = 2.1 # seconds between volleys
@export var volley_shots: int = 3
@export var volley_spacing: float = 0.12 # seconds between the shots of one volley
@export var volley_spread_degrees: float = 9.0
@export var charge_every: int = 3 # every Nth volley he swoops through the player instead
@export var charge_speed: float = 420.0
@export var charge_seconds: float = 0.45
@export_group("Mech")
## Piloting the chassis he plays by the player's rules: gravity, running, jumping between the
## islands, a dash and an arm cannon. These mirror the player's own tuning, a bit slower.
@export var mech_run_speed: float = 120.0
@export var mech_acceleration: float = 900.0
@export var mech_gravity: float = 980.0
@export var mech_jump_velocity: float = 470.0
@export var mech_air_jumps: int = 1
@export var mech_preferred_range: float = 120.0 # keeps this much air to the player
@export var mech_range_tolerance: float = 36.0
@export var mech_dash_speed: float = 360.0
@export var mech_dash_seconds: float = 0.2
@export var mech_shot_interval: float = 0.9 # seconds between arm-cannon bursts
@export var mech_burst: int = 2
@export var mech_hop_chance: float = 0.25 # per second: random hops so he is hard to pin down
## Collision box of the walking machine, in chassis units (scaled by the mech's size).
@export var mech_body_size: Vector2 = Vector2(44.0, 92.0)
@export_group("Talk")
@export var taunt_interval_min: float = 7.0
@export var taunt_interval_max: float = 12.0

signal defeated

var _jarvis: Jarvis
var _health: Health
var _hurtbox: Hurtbox
var _contact: Hitbox
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
var _attack_left: float = 1.2
var _taunt_left: float = 4.0
var _volleys: int = 0
var _charge_left: float = 0.0
var _charge_direction := Vector2.RIGHT
var _last_step: float = 0.0 # px/s the machine actually travelled last frame
var _previous_position := Vector2.ZERO
var _dead: bool = false
var _walker: CharacterBody2D # physics body of the mech; JARVIS rides along with it
var _air_jumps_left: int = 0
var _dash_left: float = 0.0
var _dash_direction: float = 1.0
var _home := Vector2.ZERO # safe spot to put him back if he ever falls out of the arena


func _ready() -> void:
	_jarvis = get_parent() as Jarvis
	_rng.randomize()
	_jarvis.add_to_group("enemy")
	_previous_position = _jarvis.global_position
	_build_damage_nodes()
	if _jarvis.mech != null:
		_build_walker()
	GameState.boss_label_changed.emit("JARVIS")
	_health.changed.emit(_health.current, _health.max_health)


## Hurtbox so the player can shoot him down, contact hitbox so ramming hurts (enemy layers).
func _build_damage_nodes() -> void:
	_health = Health.new()
	_health.name = "BossHealth"
	_health.max_health = max_health
	_health.invincibility_duration = 0.12
	_jarvis.add_child(_health)
	_health.changed.connect(func(current: float, maximum: float) -> void:
		GameState.boss_health_changed.emit(current, maximum))
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_die)
	var shape: Shape2D
	var centre := Vector2.ZERO
	if _jarvis.mech != null:
		# The machine is the target now, from its feet up to the cockpit cradle.
		var size: float = absf(_jarvis.mech.scale.y)
		var box := RectangleShape2D.new()
		box.size = mech_body_size * size
		centre = _mech_centre()
		shape = box
	else:
		var circle := CircleShape2D.new()
		circle.radius = body_radius
		shape = circle
	_hurtbox = Hurtbox.new()
	_hurtbox.name = "BossHurtbox"
	_hurtbox.health = _health
	_hurtbox.damage_multiplier = damage_multiplier
	_hurtbox.collision_layer = 4
	_hurtbox.collision_mask = 8
	_add_area(_hurtbox, shape, centre)
	_contact = Hitbox.new()
	_contact.name = "BossContact"
	_contact.source = _jarvis
	_contact.continuous = true
	_contact.collision_layer = 16
	_contact.collision_mask = 2
	_add_area(_contact, shape, centre)


func _add_area(area: Area2D, shape: Shape2D, centre: Vector2 = Vector2.ZERO) -> void:
	var collider := CollisionShape2D.new()
	collider.position = centre
	collider.shape = shape
	area.add_child(collider)
	_jarvis.add_child(area)


## The mech's own physics body. It lives in the level (not under JARVIS) so move_and_slide()
## can drive it; JARVIS is snapped onto it every physics frame.
func _build_walker() -> void:
	_walker = CharacterBody2D.new()
	_walker.name = "JarvisMechWalker"
	_walker.collision_layer = 0
	_walker.collision_mask = 1 # world only: he walks on the same islands as the player
	_walker.floor_snap_length = 6.0
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = mech_body_size * absf(_jarvis.mech.scale.y)
	collider.shape = box
	collider.position = _mech_centre()
	_walker.add_child(collider)
	get_tree().current_scene.add_child(_walker)
	_walker.global_position = _jarvis.global_position
	_home = _jarvis.global_position
	_air_jumps_left = mech_air_jumps


## Centre of the machine's box relative to its hips: its feet sit at MechFrame.FEET_Y.
func _mech_centre() -> Vector2:
	var size: float = absf(_jarvis.mech.scale.y)
	return Vector2(0.0, (_jarvis.mech.FEET_Y - mech_body_size.y * 0.5) * size)


func _physics_process(delta: float) -> void:
	if _walker == null or _dead or not is_instance_valid(_jarvis.player):
		return
	_time += delta
	_pilot(delta)
	_walker.move_and_slide()
	if _walker.is_on_floor():
		_air_jumps_left = mech_air_jumps
		if _rng.randf() < 0.02:
			_home = _walker.global_position # remember solid ground as he goes
	if _walker.global_position.y > _home.y + 600.0: # fell into a pit: the arena drops him back in
		_walker.global_position = _home
		_walker.velocity = Vector2.ZERO
	_jarvis.global_position = _walker.global_position
	_attack(delta)
	_taunt(delta)
	_animate(delta)


## The player's moveset, driven by simple reads of where the player is.
func _pilot(delta: float) -> void:
	var player := _jarvis.player
	var gap := player.global_position - _walker.global_position
	var on_floor := _walker.is_on_floor()
	_walker.velocity.y = minf(_walker.velocity.y + mech_gravity * delta, 900.0)
	if _dash_left > 0.0:
		_dash_left -= delta
		_walker.velocity = Vector2(_dash_direction * mech_dash_speed, 0.0)
		return
	var drive := 0.0
	var distance := absf(gap.x)
	if distance > mech_preferred_range + mech_range_tolerance:
		drive = signf(gap.x)
	elif distance < mech_preferred_range - mech_range_tolerance:
		drive = -signf(gap.x)
	elif gap.y < -48.0: # player is up on an island: get under it so he can jump up
		drive = signf(gap.x)
	var accel := mech_acceleration * (1.0 if on_floor else 0.6)
	_walker.velocity.x = move_toward(_walker.velocity.x, drive * mech_run_speed, accel * delta)
	var want_jump := false
	if on_floor:
		if drive != 0.0 and _walker.is_on_wall():
			want_jump = true # step up / over obstacles
		elif drive != 0.0 and not _ground_ahead(drive) and gap.y < 24.0:
			want_jump = true # leap the gap rather than dropping into it
		elif gap.y < -48.0 and distance < 150.0:
			want_jump = true # the player went up a level: follow
		elif _rng.randf() < mech_hop_chance * delta:
			want_jump = true
		if want_jump:
			_walker.velocity.y = -mech_jump_velocity
	elif _air_jumps_left > 0 and _walker.velocity.y > 0.0 and gap.y < -32.0:
		_air_jumps_left -= 1 # double jump at the top of the arc to reach a higher island
		_walker.velocity.y = -mech_jump_velocity * 0.85


func _ground_ahead(direction: float) -> bool:
	var size: float = absf(_jarvis.mech.scale.y)
	var foot := _walker.global_position + Vector2(direction * mech_body_size.x * 0.6 * size,
		_jarvis.mech.FEET_Y * size)
	var query := PhysicsRayQueryParameters2D.create(foot, foot + Vector2(0.0, 40.0), 1)
	return not _walker.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _process(delta: float) -> void:
	if _walker != null or _dead or not is_instance_valid(_jarvis.player):
		return
	_time += delta
	_last_step = _jarvis.global_position.distance_to(_previous_position) / maxf(delta, 0.0001)
	_previous_position = _jarvis.global_position
	if _charge_left > 0.0:
		_charge(delta)
	else:
		_hover(delta)
		_attack(delta)
	_taunt(delta)
	_animate(delta)


## Mirrors the player: keeps his distance on the side the player is facing away from.
func _hover(delta: float) -> void:
	var player_position := _jarvis.player.global_position
	var side := signf(_jarvis.global_position.x - player_position.x)
	if is_zero_approx(side):
		side = 1.0
	var target := player_position + Vector2(
		side * hover_distance + sin(_time * strafe_speed) * strafe_amplitude, hover_height)
	_jarvis.global_position = _jarvis.global_position.move_toward(target, move_speed * delta)


func _attack(delta: float) -> void:
	_attack_left -= delta
	if _attack_left > 0.0:
		return
	_volleys += 1
	if _walker != null:
		_attack_left = mech_shot_interval
		if _volleys % 4 == 0 and _walker.is_on_floor():
			_start_dash()
		else:
			_burst()
		return
	_attack_left = volley_interval
	if _volleys % charge_every == 0:
		_start_charge()
	else:
		_volley()


func _volley() -> void:
	for i in volley_shots:
		if _dead or not is_instance_valid(_jarvis.player):
			return
		var origin := _muzzle(i)
		var aim := origin.direction_to(_jarvis.player.global_position + Vector2(0, -8))
		var spread := deg_to_rad(_rng.randf_range(-volley_spread_degrees, volley_spread_degrees))
		var shot: Hitbox = SHOT.instantiate()
		shot.source = _jarvis
		shot.direction = aim.rotated(spread)
		get_tree().current_scene.add_child(shot)
		shot.global_position = origin + shot.direction * 12.0
		await get_tree().create_timer(volley_spacing).timeout


## Arm cannon: a short, nearly flat burst like the player's gun, aimed at the player.
func _burst() -> void:
	for i in mech_burst:
		if _dead or not is_instance_valid(_jarvis.player):
			return
		var origin := _muzzle(i)
		var aim := origin.direction_to(_jarvis.player.global_position + Vector2(0, -8))
		var shot: Hitbox = SHOT.instantiate()
		shot.source = _jarvis
		shot.direction = aim.rotated(deg_to_rad(_rng.randf_range(-4.0, 4.0)))
		get_tree().current_scene.add_child(shot)
		shot.global_position = origin
		await get_tree().create_timer(volley_spacing).timeout


## Dash at the player along the ground, like the player's own dash.
func _start_dash() -> void:
	_dash_direction = signf(_jarvis.player.global_position.x - _walker.global_position.x)
	if is_zero_approx(_dash_direction):
		_dash_direction = 1.0
	_dash_left = mech_dash_seconds
	_jarvis.body.set_face("furious")


## The mech fires from its front fist; the bare drone fires from its own shell.
func _muzzle(_index: int) -> Vector2:
	if _jarvis.mech == null:
		return _jarvis.global_position
	return _jarvis.mech.to_global(Vector2(40.0, 12.0))


## Swoop: he lines up and rams straight through the player, trailing the contact hitbox.
func _start_charge() -> void:
	_charge_direction = _jarvis.global_position.direction_to(
		_jarvis.player.global_position + Vector2(0, -8))
	_charge_left = charge_seconds
	_jarvis.body.set_face("furious")


func _charge(delta: float) -> void:
	_charge_left -= delta
	_jarvis.global_position += _charge_direction * charge_speed * delta
	if _charge_left <= 0.0:
		_jarvis.body.set_face("annoyed")


func _taunt(delta: float) -> void:
	_taunt_left -= delta
	if _taunt_left > 0.0 or _jarvis.bubble.is_talking():
		return
	_taunt_left = _rng.randf_range(taunt_interval_min, taunt_interval_max)
	_jarvis.bubble.say(Dialogue.get_line("hostile_idle", GameState.current_level), "furious")


func _animate(delta: float) -> void:
	var body := _jarvis.body
	var bob := bob_amplitude * (0.3 if _walker != null else 1.0) # a pilot only rocks in his seat
	body.position = _jarvis.seat_offset + Vector2(0.0, sin(_time * bob_speed) * bob)
	_jarvis.facing = -1 if _jarvis.player.global_position.x < _jarvis.global_position.x else 1
	body.scale.x = absf(body.scale.x) * _jarvis.facing
	var tilt := 0.0 if _charge_left <= 0.0 else deg_to_rad(20.0 * _jarvis.facing)
	body.rotation = lerp_angle(body.rotation, tilt, 1.0 - exp(-10.0 * delta))
	var mech := _jarvis.mech
	if mech == null:
		return
	# The chassis turns with him and strides whenever the machine is actually moving.
	mech.scale.x = absf(mech.scale.x) * _jarvis.facing
	mech.walking = absf(_walker.velocity.x) > 8.0 if _walker != null else false
	mech.airborne = _walker != null and not _walker.is_on_floor()
	var lean := 0.0 if _dash_left <= 0.0 else deg_to_rad(10.0 * _jarvis.facing)
	mech.rotation = lerp_angle(mech.rotation, lean, 1.0 - exp(-12.0 * delta))


func _on_damaged(_amount: float, _source: Node) -> void:
	if _dead:
		return
	var tween := _jarvis.create_tween()
	_jarvis.body.modulate = Color.WHITE
	tween.tween_property(_jarvis.body, "modulate", _jarvis.hostile_color, 0.18)
	if not _jarvis.bubble.is_talking() and _rng.randf() < 0.5:
		_jarvis.bubble.say(Dialogue.get_line("hostile_hurt", GameState.current_level), "furious")


## Shot down: the rotor dies, he drops out of the sky and the run's boss is finished.
func _die(killer: Node) -> void:
	if _dead:
		return
	_dead = true
	_contact.continuous = false # stop the per-frame overlap scan before the areas go off
	for area: Area2D in [_hurtbox, _contact]:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false) # the player's hurtbox watches for us, not the reverse
	_jarvis.body.set_face("off")
	_jarvis.body.power = 0.0
	_jarvis.bubble.say(Dialogue.get_line("hostile_defeat", GameState.current_level), "offline")
	GameState.enemy_killed.emit(_jarvis, killer)
	_black_out()
	if _walker != null:
		_walker.queue_free()
		_walker = null
	var tween := _jarvis.create_tween()
	tween.set_parallel()
	tween.tween_property(_jarvis, "global_position",
		_jarvis.global_position + Vector2(_rng.randf_range(-24.0, 24.0), 90.0), 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_jarvis.body, "rotation", _jarvis.body.rotation + TAU * 1.5, 1.1)
	tween.tween_property(_jarvis.body, "modulate", Color(0.2, 0.2, 0.25, 0.0), 1.1)
	if _jarvis.mech != null: # the chassis buckles and drops with its pilot
		tween.tween_property(_jarvis.mech, "rotation",
			_jarvis.mech.rotation + deg_to_rad(70.0 * _jarvis.facing), 1.1) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_jarvis.mech, "modulate", Color(0.2, 0.2, 0.25, 0.0), 1.1)
	await tween.finished
	defeated.emit()
	_jarvis.queue_free()


## He was running the whole floor: once he drops, the hatches seal and every unit still standing
## powers down with him instead of fighting on.
func _black_out() -> void:
	get_tree().call_group("minion_door", "shut_down")
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != _jarvis and enemy.has_method("shut_down"):
			enemy.shut_down()
	get_tree().call_group("game_hud", "notify", "ALL UNITS OFFLINE")
