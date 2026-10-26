extends Node
## Package 3 economy and event bus. Existing team interfaces stay stable.

signal tokens_changed(tokens: int)
signal energy_changed(energy: float)
signal enemy_killed(enemy: Node, killer: Node)
signal player_died
signal player_respawned
signal level_completed(level: int)
signal boss_defeated
signal boss_health_changed(current: float, maximum: float)
signal jarvis_say(text: String, mood: String)
signal cutscene_finished
signal jarvis_enabled_changed(enabled: bool)
signal level_started(level: int)
signal token_collected(value: int)
signal ability_used(ability: StringName, cost: int)
signal run_finished(result: Dictionary)

const MAX_ENERGY := 100.0
const ABILITY_COSTS := {&"dash": 1, &"shield": 2, &"boost_jump": 3}
const FEED_COST: int = 3
const FEED_ENERGY: float = 25.0
const ENERGY_DRAIN := [0.8, 1.2, 1.6, 2.0] # energy per active gameplay second
const KILL_DOUBT_CHANCE := [0.10, 0.25, 0.40, 0.60]

var tokens: int = 0:
	set(value):
		tokens = maxi(value, 0)
		tokens_changed.emit(tokens)

var energy: float = MAX_ENERGY:
	set(value):
		var was_enabled := jarvis_enabled
		energy = clampf(value, 0.0, MAX_ENERGY)
		energy_changed.emit(energy)
		if was_enabled != jarvis_enabled:
			jarvis_enabled_changed.emit(jarvis_enabled)

var current_level: int = 0
var jarvis_hostile: bool = false:
	set(value):
		var was_enabled := jarvis_enabled
		jarvis_hostile = value
		if was_enabled != jarvis_enabled:
			jarvis_enabled_changed.emit(jarvis_enabled)
var jarvis_enabled: bool:
	get:
		return energy > 0.0 and not jarvis_hostile

var gameplay_active: bool = false
var _rng := RandomNumberGenerator.new()
var run_clock := RunClock.new()
var leaderboard := LeaderboardClient.new()


func _ready() -> void:
	add_child(leaderboard)
	run_finished.connect(leaderboard.offer_result)
	_rng.randomize()
	enemy_killed.connect(_on_enemy_killed)
	player_died.connect(_on_player_died)
	level_completed.connect(run_clock.record_level)
	level_completed.connect(leaderboard.checkpoint)
	run_clock.finished.connect(func(result: Dictionary) -> void: run_finished.emit(result))
	boss_defeated.connect(_on_boss_defeated)


func _process(delta: float) -> void:
	run_clock.advance(delta, gameplay_active)
	if gameplay_active and not jarvis_hostile and current_level in range(1, 5):
		add_energy(-ENERGY_DRAIN[current_level - 1] * delta)


func reset_run() -> void:
	leaderboard.abandon_run()
	run_clock.reset()
	gameplay_active = false
	jarvis_hostile = false
	current_level = 0
	tokens = 0
	energy = MAX_ENERGY


func begin_level(level: int) -> void:
	run_clock.enter_level(level)
	current_level = clampi(level, 1, 4)
	gameplay_active = true
	level_started.emit(current_level)


## New Game arms a full run; chapter select, direct scene runs and restarts stay practice.
func prepare_full_run() -> void:
	run_clock.reset(true)
	leaderboard.start_run()


func _on_boss_defeated() -> void:
	run_clock.finish()
	gameplay_active = false


func add_tokens(n: int) -> void:
	if n > 0:
		tokens += n


func spend_tokens(n: int) -> bool:
	if n < 0 or tokens < n:
		return false
	tokens -= n
	return true


func add_energy(n: float) -> void:
	energy += n


func feed_jarvis() -> bool:
	if jarvis_hostile or energy >= MAX_ENERGY or not spend_tokens(FEED_COST):
		return false
	add_energy(FEED_ENERGY)
	return true


## Package 2 can use this before calling the existing Player ability API.
## Shield cost is per second; its controller chooses a billing interval.
func use_ability(ability: StringName) -> bool:
	if not jarvis_enabled or not ABILITY_COSTS.has(ability):
		return false
	var cost: int = ABILITY_COSTS[ability]
	if not spend_tokens(cost):
		return false
	ability_used.emit(ability, cost)
	return true


func kill_doubt_chance(level: int = 0) -> float:
	var chapter := current_level if level == 0 else level
	return KILL_DOUBT_CHANCE[clampi(chapter, 1, 4) - 1]


func _on_enemy_killed(_enemy: Node, killer: Node) -> void:
	if not jarvis_enabled or not is_instance_valid(killer):
		return
	if not killer.is_in_group("player") and not killer.is_in_group("jarvis"):
		return
	var category := "kill_jarvis" if killer.is_in_group("jarvis") else "kill_player"
	if killer.is_in_group("player") and _rng.randf() < kill_doubt_chance():
		category = "kill_doubt"
	GameState.jarvis_say.emit(Dialogue.get_line(category, current_level), "smug")


func _on_player_died() -> void:
	run_clock.record_death()
	if jarvis_enabled:
		jarvis_say.emit(Dialogue.get_line("death", current_level), "smug")
