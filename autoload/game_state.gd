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
## The boss health bar changed owner (boss phases, JARVIS taking over the fight).
signal boss_label_changed(label: String)
## JARVIS finished switching sides in the boss arena and is now the final opponent.
signal jarvis_betrayed
signal jarvis_say(text: String, mood: String)
signal cutscene_finished
signal jarvis_enabled_changed(enabled: bool)
signal level_started(level: int)
signal token_collected(value: int)
signal ability_used(ability: StringName, cost: int)
signal run_finished(result: Dictionary)
signal god_mode_changed(active: bool)

const MAX_ENERGY := 100.0
const ABILITY_COSTS := {&"dash": 1, &"shield": 2, &"boost_jump": 3}
const FEED_COST: int = 3
const FEED_ENERGY: float = 25.0
## On each player death JARVIS comes back with at least this much energy (revived if offline).
const DEATH_ENERGY: float = 75.0
const ENERGY_DRAIN := [0.8, 1.2, 1.6, 2.0] # energy per active gameplay second
const KILL_DOUBT_CHANCE := [0.10, 0.25, 0.40, 0.60]
## Token count shown while god mode is on (spending never lowers it).
const GOD_TOKENS: int = 999

## Practice-only cheat (G): energy locked at max and tokens never run out. Never on in a
## leaderboard-eligible run; reset_run() / prepare_full_run() turn it off.
var god_mode: bool = false
## Energy held at max without touching tokens (the intro). Cleared by reset_run().
var infinite_energy: bool = false:
	set(value):
		infinite_energy = value
		if value:
			energy = MAX_ENERGY
var _tokens_outside_god_mode: int = 0

var tokens: int = 0:
	set(value):
		tokens = GOD_TOKENS if god_mode else maxi(value, 0)
		tokens_changed.emit(tokens)

var energy: float = MAX_ENERGY:
	set(value):
		var was_enabled := jarvis_enabled
		energy = MAX_ENERGY if god_mode or infinite_energy else clampf(value, 0.0, MAX_ENERGY)
		energy_changed.emit(energy)
		if was_enabled != jarvis_enabled:
			jarvis_enabled_changed.emit(jarvis_enabled)

var current_level: int = 0
## Set by the L3 trap door right before the scene change; the next level's level.gd consumes
## it once (spawns a few falling rubble chunks with the player) and clears it back to false.
var arrived_by_trap: bool = false
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
	set_god_mode(false)
	infinite_energy = false
	leaderboard.abandon_run()
	run_clock.reset()
	gameplay_active = false
	jarvis_hostile = false
	current_level = 0
	tokens = 0
	energy = MAX_ENERGY


func begin_level(level: int) -> void:
	run_clock.enter_level(level)
	if run_clock.eligible:
		set_god_mode(false)
	current_level = clampi(level, 1, 4)
	gameplay_active = true
	level_started.emit(current_level)


## New Game arms a full run; chapter select, direct scene runs and restarts stay practice.
func prepare_full_run() -> void:
	set_god_mode(false)
	run_clock.reset(true)
	leaderboard.start_run()


func _on_boss_defeated() -> void:
	run_clock.finish()
	gameplay_active = false


## Practice only: refuses (returns false) to turn on during a leaderboard-eligible run.
func toggle_god_mode() -> bool:
	if not god_mode and (run_clock.eligible or infinite_energy):
		return false
	set_god_mode(not god_mode)
	return true


func set_god_mode(active: bool) -> void:
	if active == god_mode:
		return
	if active:
		_tokens_outside_god_mode = tokens
		god_mode = true
		tokens = GOD_TOKENS
		energy = MAX_ENERGY
	else:
		god_mode = false
		tokens = _tokens_outside_god_mode # the real balance, plus anything picked up meanwhile
	god_mode_changed.emit(god_mode)


func add_tokens(n: int) -> void:
	if n <= 0:
		return
	if god_mode:
		_tokens_outside_god_mode += n
	tokens += n


func spend_tokens(n: int) -> bool:
	if god_mode and n >= 0:
		return true
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
	if not jarvis_hostile and energy < DEATH_ENERGY:
		energy = DEATH_ENERGY
