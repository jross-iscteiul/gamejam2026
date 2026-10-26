class_name RoastDirector
extends Node
## Watches how the player plays and makes JARVIS roast them. Owned by Package 6.
##
## Put one in each level_XX_extras.tscn. It only needs the player to be a
## CharacterBody2D in the "player" group, and reads the shared input actions,
## so it doesn't depend on the player's code.
##
## Speaks through Dialogue.say(), so the lines go out on GameState.jarvis_say.
## Cooldowns keep JARVIS from talking all the time. Only active while
## GameState.gameplay_active and JARVIS is enabled (energy > 0, not hostile).
##
## GameState already says a generic "death" line the moment the player dies,
## so death roasts here are delivered on respawn, as a follow-up.

signal roasted(category: String)

@export var enabled: bool = true
## Minimum seconds between any two roasts.
@export var global_cooldown: float = 8.0
## Minimum seconds before the same kind of roast can happen again.
@export var category_cooldown: float = 30.0
## Chance to actually speak when a trigger fires (deaths always speak).
@export_range(0.0, 1.0) var chance: float = 0.7

@export_group("Shooting")
## The player auto-fires while shoot is held; shots are estimated from the
## player's fire_rate (or this fallback) while the button is down.
@export var fallback_fire_rate: float = 6.0
## This many shots within spam_window = trigger-happy roast.
@export var spam_shots: int = 24
@export var spam_window: float = 4.0
## This many shots without the player killing anything = bad aim roast.
@export var miss_shots: int = 30

@export_group("Jumping")
@export var spam_jumps: int = 6
@export var jump_window: float = 4.0
## Falling for longer than this = long fall roast. 0.9 s at the player's
## gravity is about 12 tiles (32 px), more than a screen height.
@export var long_fall_time: float = 0.9

@export_group("Moving")
@export var idle_time: float = 10.0
@export var wall_push_time: float = 1.2
@export var direction_changes: int = 8
@export var direction_window: float = 3.0

@export_group("Deaths")
## Dying this soon after respawning = quick death roast.
@export var quick_death_time: float = 5.0
## Dying this close to the previous death = same spot roast.
@export var same_spot_distance: float = 32.0
@export var death_streak: int = 3
@export var death_streak_window: float = 60.0

@export_group("Team KPI")
## Every this many seconds, maybe throw a random jab at team KPI.
@export var kpi_interval: float = 90.0
@export_range(0.0, 1.0) var kpi_chance: float = 0.5

var _time := 0.0
var _last_roast := -INF
var _category_time := {}
var _rng := RandomNumberGenerator.new()

var _shots: Array[float] = []
var _shots_since_kill := 0
var _shot_progress := 1.0
var _pending_death_roast := ""
var _jumps: Array[float] = []
var _air_time := 0.0
var _idle := 0.0
var _wall := 0.0
var _last_dir := 0.0
var _dir_changes: Array[float] = []
var _respawn_time := -INF
var _deaths: Array[float] = []
var _last_death_pos := Vector2.INF
var _kpi_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	GameState.enemy_killed.connect(_on_enemy_killed)
	GameState.player_died.connect(_on_player_died)
	GameState.player_respawned.connect(_on_player_respawned)


func _process(delta: float) -> void:
	_time += delta
	if not enabled or not GameState.gameplay_active or not GameState.jarvis_enabled:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	_check_shooting(player, delta)
	_check_jumping(player, delta)
	_check_moving(player, delta)
	_check_kpi(delta)


## Tries to roast. Returns true if JARVIS actually spoke.
func roast(category: String, force: bool = false) -> bool:
	if _time - _last_roast < global_cooldown:
		return false
	if _time - float(_category_time.get(category, -INF)) < category_cooldown:
		return false
	if not force and _rng.randf() > chance:
		return false
	_last_roast = _time
	_category_time[category] = _time
	Dialogue.say(category)
	roasted.emit(category)
	return true


func _check_shooting(player: CharacterBody2D, delta: float) -> void:
	if not Input.is_action_pressed("shoot"):
		_shot_progress = 1.0  # the first frame of a press fires immediately
		return
	var rate: float = player.get("fire_rate") if player.get("fire_rate") != null else fallback_fire_rate
	_shot_progress += delta * rate
	if _shot_progress < 1.0:
		return
	_shot_progress -= 1.0
	_shots.append(_time)
	_shots_since_kill += 1
	_prune(_shots, spam_window)
	if _shots.size() >= spam_shots:
		_shots.clear()
		roast("roast_shoot_spam")
	elif _shots_since_kill >= miss_shots:
		_shots_since_kill = 0
		roast("roast_shoot_miss")


func _check_jumping(player: CharacterBody2D, delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jumps.append(_time)
		_prune(_jumps, jump_window)
		if _jumps.size() >= spam_jumps:
			_jumps.clear()
			roast("roast_jump_spam")

	if player.is_on_floor():
		if _air_time >= long_fall_time:
			roast("roast_fall")
		_air_time = 0.0
	elif player.velocity.y > 0.0:
		_air_time += delta


func _check_moving(player: CharacterBody2D, delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var busy := dir != 0.0 or Input.is_action_pressed("jump") \
		or Input.is_action_pressed("shoot") or Input.is_action_pressed("shield")
	_idle = 0.0 if busy else _idle + delta
	if _idle >= idle_time:
		_idle = 0.0
		roast("roast_idle")

	var pushing_wall := dir != 0.0 and player.is_on_wall() \
		and signf(player.get_wall_normal().x) == -signf(dir)
	_wall = _wall + delta if pushing_wall else 0.0
	if _wall >= wall_push_time:
		_wall = 0.0
		roast("roast_wall")

	var s := signf(dir)
	if s != 0.0 and _last_dir != 0.0 and s != _last_dir:
		_dir_changes.append(_time)
		_prune(_dir_changes, direction_window)
		if _dir_changes.size() >= direction_changes:
			_dir_changes.clear()
			roast("roast_moonwalk")
	if s != 0.0:
		_last_dir = s


func _check_kpi(delta: float) -> void:
	_kpi_timer += delta
	if _kpi_timer < kpi_interval:
		return
	_kpi_timer = 0.0
	if _rng.randf() < kpi_chance:
		roast("kpi_random", true)


func _on_player_died() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var pos := player.global_position if player else Vector2.INF
	_deaths.append(_time)
	_prune(_deaths, death_streak_window)

	var category := ""
	if _time - _respawn_time <= quick_death_time:
		category = "roast_quick_death"
	elif pos.distance_to(_last_death_pos) <= same_spot_distance:
		category = "roast_same_spot"
	elif _deaths.size() >= death_streak:
		_deaths.clear()
		category = "roast_death_streak"
	_last_death_pos = pos
	_pending_death_roast = category


func _on_player_respawned() -> void:
	if _pending_death_roast != "" and GameState.jarvis_enabled:
		roast(_pending_death_roast, true)
	_pending_death_roast = ""
	_respawn_time = _time
	_air_time = 0.0
	_idle = 0.0


func _on_enemy_killed(_enemy: Node, killer: Node) -> void:
	if not is_instance_valid(killer):
		return
	if killer.is_in_group("player") or killer.is_in_group("player_projectile"):
		_shots_since_kill = 0


func _prune(times: Array[float], window: float) -> void:
	while not times.is_empty() and _time - times[0] > window:
		times.pop_front()
