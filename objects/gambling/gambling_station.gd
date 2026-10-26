class_name GamblingStation
extends Node2D
## Gambling station. Owned by Package 6.
##
## Walk up, press E, the wheel opens (game pauses). Each spin costs a fixed
## number of tokens depending on the level. Limited spins per station.
## Origin is at the station's feet: place it on the floor.

signal spun(outcome: int)

const WHEEL_SCENE := preload("res://objects/gambling/wheel_ui.tscn")

@export var odds: GamblingOdds
## Minimum stake per spin, indexed by level (0 = tests, 1-4 = levels).
## The player can bet anything from this up to all their tokens.
@export var cost_per_level: Array[int] = [2, 2, 3, 4, 5]
## Paid spins per station.
@export var max_spins: int = 3
## Free spins per station, used before the paid ones. Rewards are still based on
## the level's cost (a free OVERCLOCK pays 5x cost); a ROLLBACK refunds nothing.
@export var free_spins: int = 1
## Use this level instead of GameState.current_level (-1 = use GameState).
@export var level_override: int = -1

@export_group("Rewards")
@export var jackpot_multiplier: int = 5
@export var double_multiplier: int = 2
## JARVIS energy (GameState.energy, 0-100) gained or lost.
@export var energy_boost: float = 20.0
## Energy outcomes scale with stake / minimum stake, up to this many times.
## Keeps an all-in MALWARE from wiping JARVIS (or RECHARGE from always filling him).
@export var max_energy_scale: float = 3.0
## REPAIR heals the player this many HP (scaled by stake like energy, same cap).
@export var heal_amount: float = 3.0
@export var token_multiplier: int = 2
@export var token_multiplier_seconds: float = 60.0
## GOD MODE (1% chance): Package 3's god mode for this long.
@export var god_mode_seconds: float = 20.0

@export_group("Higher or lower")
## Pot multiplier per correct guess, indexed by level. Ties lose (house rule).
@export var cards_step_multiplier: Array[float] = [1.5, 1.5, 1.4, 1.35, 1.3]
## After this many correct guesses the pot is cashed out automatically.
@export var cards_max_streak: int = 8

@export_group("Penalties")
## TAX takes this many times the cost on top of the bet.
@export var tax_multiplier: int = 1
@export var energy_drain: float = 15.0
@export var jarvis_raise: int = 1

## Total spins left (free + paid).
var spins_left: int
var free_spins_left: int

## True while the current spin was a free one.
var _spin_was_free := false
## Stake of the current spin. Rewards and penalties scale with it.
var _stake := 0

var _loss_streak := 0
var _rng := RandomNumberGenerator.new()
var _wheel: WheelUI

@onready var _interactable: Interactable = $Interactable
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	if odds == null:
		odds = GamblingOdds.new()
	_rng.randomize()
	_interactable.interacted.connect(_on_interacted)
	# Cost depends on the current level, so refresh the prompt on approach.
	_interactable.player_entered.connect(func(_p: Node2D) -> void: _update_prompt())
	reset_spins()


func get_level() -> int:
	return level_override if level_override >= 0 else GameState.current_level


func is_next_spin_free() -> bool:
	return free_spins_left > 0


## Smallest stake allowed on this level.
func get_min_stake() -> int:
	return get_cost()


## Biggest stake allowed right now (all-in). A free spin is always min stake.
func get_max_stake() -> int:
	if is_next_spin_free():
		return get_min_stake()
	return maxi(GameState.tokens, get_min_stake())


func clamp_stake(stake: int) -> int:
	return clampi(stake, get_min_stake(), get_max_stake())


## Level minimum stake (kept for older callers).
func get_cost() -> int:
	if cost_per_level.is_empty():
		return 0
	return cost_per_level[clampi(get_level(), 0, cost_per_level.size() - 1)]


func reset_spins() -> void:
	free_spins_left = free_spins
	spins_left = max_spins + free_spins
	_update_prompt()


## Called by the wheel. Pays [param stake] and rolls. Returns the outcome, or
## -1 if the spin was refused (no spins left, not enough tokens). A free spin
## bets the minimum stake without paying it.
func try_spin(stake: int = -1) -> int:
	if spins_left <= 0:
		Dialogue.say("gambling_out_of_spins")
		return -1
	_spin_was_free = free_spins_left > 0
	_stake = get_min_stake() if (_spin_was_free or stake < 0) else clamp_stake(stake)
	if _spin_was_free:
		free_spins_left -= 1
	elif not GameState.spend_tokens(_stake):
		Dialogue.say("gambling_broke")
		return -1
	spins_left -= 1
	_update_prompt()
	var all_in := not _spin_was_free and GameState.tokens == 0 and _stake > get_min_stake()
	Dialogue.say("gambling_all_in" if all_in else "gambling_spin")
	return _roll()


## Stake of the last spin (what the rewards were computed from).
func get_last_stake() -> int:
	return _stake


## Energy rewards/penalties scale with how many minimum stakes were bet.
func get_energy_amount(base: float) -> float:
	var ratio := minf(float(_stake) / maxf(1.0, float(get_min_stake())), max_energy_scale)
	return minf(base * ratio, GameState.MAX_ENERGY)


func _roll() -> int:
	var outcome := odds.roll(get_level(), _loss_streak, _rng)
	_loss_streak = 0 if GamblingOdds.is_win(outcome) else _loss_streak + 1
	return outcome


## Called by the wheel once the animation has finished.
func apply_outcome(outcome: int) -> void:
	var cost := _stake
	match outcome:
		GamblingOdds.Outcome.JACKPOT:
			GameState.add_tokens(cost * jackpot_multiplier)
			Dialogue.say("gambling_jackpot")
		GamblingOdds.Outcome.DOUBLE:
			GameState.add_tokens(cost * double_multiplier)
			Dialogue.say("gambling_win")
		GamblingOdds.Outcome.ENERGY_BOOST:
			GameState.add_energy(get_energy_amount(energy_boost))
			Dialogue.say("gambling_win")
		GamblingOdds.Outcome.REFUND:
			if not _spin_was_free:
				GameState.add_tokens(cost)
			Dialogue.say("gambling_neutral")
		GamblingOdds.Outcome.NOTHING, GamblingOdds.Outcome.RESPIN_TROLL:
			Dialogue.say("gambling_lose")
		GamblingOdds.Outcome.TAX:
			_take_tokens(cost * tax_multiplier)
			Dialogue.say("gambling_troll")
		GamblingOdds.Outcome.ENERGY_DRAIN:
			GameState.add_energy(-get_energy_amount(energy_drain))
			Dialogue.say("gambling_troll")
		GamblingOdds.Outcome.JARVIS_RAISE:
			_take_tokens(jarvis_raise)
			Dialogue.say("gambling_troll")
		GamblingOdds.Outcome.FAKE_JACKPOT:
			Dialogue.say("gambling_fake_jackpot")
		GamblingOdds.Outcome.HEAL:
			_heal_player(get_energy_amount(heal_amount))
			Dialogue.say("gambling_win")
		GamblingOdds.Outcome.TOKEN_MULTIPLIER:
			GamblingBuffs.get_instance(get_tree()).start_token_multiplier(token_multiplier, token_multiplier_seconds)
			Dialogue.say("gambling_win")
		GamblingOdds.Outcome.GOD_MODE:
			GamblingBuffs.get_instance(get_tree()).start_god_mode(god_mode_seconds)
			Dialogue.say("gambling_god_mode")
	spun.emit(outcome)


func _heal_player(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var health := player.get_node_or_null("Health") as Health if player else null
	if health == null or health.current <= 0.0:
		return
	health.current = minf(health.current + amount, health.max_health)
	health.changed.emit(health.current, health.max_health)


# --- Higher or lower ("montinho") ---------------------------------------------

## Cards are 1 (ace) to 13 (king).
var cards: Array[int] = []
var cards_streak := 0
var cards_active := false


func get_cards_step() -> float:
	if cards_step_multiplier.is_empty():
		return 1.5
	return cards_step_multiplier[clampi(get_level(), 0, cards_step_multiplier.size() - 1)]


## Current pot: stake grown by every correct guess.
func get_cards_pot() -> int:
	return int(floor(_stake * pow(get_cards_step(), cards_streak)))


## Pays the stake (or uses the free spin) and deals the first card.
## Returns false if refused (no spins, not enough tokens).
func cards_deal(stake: int = -1) -> bool:
	if cards_active or spins_left <= 0:
		if spins_left <= 0:
			Dialogue.say("gambling_out_of_spins")
		return false
	_spin_was_free = free_spins_left > 0
	_stake = get_min_stake() if (_spin_was_free or stake < 0) else clamp_stake(stake)
	if _spin_was_free:
		free_spins_left -= 1
	elif not GameState.spend_tokens(_stake):
		Dialogue.say("gambling_broke")
		return false
	spins_left -= 1
	_update_prompt()
	cards = [_draw_card()]
	cards_streak = 0
	cards_active = true
	Dialogue.say("cards_deal")
	return true


## Draws the next card. Returns true if the guess was right. A wrong guess or a
## tie loses the pot; reaching cards_max_streak cashes out automatically.
func cards_guess(higher: bool) -> bool:
	if not cards_active:
		return false
	var last: int = cards.back()
	var next := _draw_card()
	cards.append(next)
	var correct := (next > last) if higher else (next < last)
	if not correct:
		cards_active = false
		Dialogue.say("cards_lose")
		spun.emit(GamblingOdds.Outcome.NOTHING)
		return false
	cards_streak += 1
	if cards_streak >= cards_max_streak:
		cards_cash_out()
	return true


## Pays the pot. Only allowed after at least one correct guess.
func cards_cash_out() -> int:
	if not cards_active or cards_streak <= 0:
		return 0
	var pot := get_cards_pot()
	GameState.add_tokens(pot)
	cards_active = false
	Dialogue.say("cards_cash_out")
	spun.emit(GamblingOdds.Outcome.DOUBLE)
	return pot


func _draw_card() -> int:
	return _rng.randi_range(1, 13)


## GameState.add_tokens ignores negative amounts, so penalties go through
## spend_tokens, capped at what the player has.
func _take_tokens(amount: int) -> void:
	GameState.spend_tokens(mini(amount, GameState.tokens))


## Short text shown on the wheel after a spin.
func describe_outcome(outcome: int) -> String:
	var cost := _stake
	match outcome:
		GamblingOdds.Outcome.JACKPOT:
			return "OVERCLOCK! +%d TKN" % (cost * jackpot_multiplier)
		GamblingOdds.Outcome.DOUBLE:
			return "x2 BOOST! +%d TKN" % (cost * double_multiplier)
		GamblingOdds.Outcome.ENERGY_BOOST:
			return "RECHARGE. +%d JARVIS ENERGY" % get_energy_amount(energy_boost)
		GamblingOdds.Outcome.REFUND:
			if _spin_was_free:
				return "ROLLBACK. FREE SPIN, NOTHING TO REFUND"
			return "ROLLBACK. +%d TKN REFUNDED" % cost
		GamblingOdds.Outcome.TAX:
			return "CPU TAX! -%d TKN" % (cost * tax_multiplier)
		GamblingOdds.Outcome.ENERGY_DRAIN:
			return "MALWARE DETECTED. -%d JARVIS ENERGY" % get_energy_amount(energy_drain)
		GamblingOdds.Outcome.JARVIS_RAISE:
			return "JARVIS FEE. -%d TKN" % jarvis_raise
		GamblingOdds.Outcome.FAKE_JACKPOT:
			return "ERROR: OVERCLOCK NOT FOUND. NULL."
		GamblingOdds.Outcome.HEAL:
			return "REPAIR. +%d HP" % get_energy_amount(heal_amount)
		GamblingOdds.Outcome.TOKEN_MULTIPLIER:
			return "TOKENS x%d FOR %dS!" % [token_multiplier, token_multiplier_seconds]
		GamblingOdds.Outcome.GOD_MODE:
			return "GOD MODE!!! %dS" % god_mode_seconds
	return "NULL. NOTHING RETURNED."


func _on_interacted(_player: Node2D) -> void:
	if _wheel != null:
		return
	if spins_left <= 0:
		Dialogue.say("gambling_out_of_spins")
		return
	_wheel = WHEEL_SCENE.instantiate()
	_wheel.station = self
	_wheel.closed.connect(_on_wheel_closed)
	add_child(_wheel)
	Dialogue.say("gambling_enter")


func _on_wheel_closed() -> void:
	_wheel = null


func _update_prompt() -> void:
	if _visual != null:
		_visual.offline = spins_left <= 0
	if _interactable == null:
		return
	if spins_left > 0:
		# Touch players press Package 3's USE pad button instead of E.
		var key := "[USE]" if ControlSettings.touch_enabled() else "[E]"
		if is_next_spin_free():
			_interactable.prompt_text = "%s ACCESS ENGINE (FREE SPIN!)" % key
		else:
			_interactable.prompt_text = "%s ACCESS ENGINE (MIN %d TKN)" % [key, get_cost()]
	else:
		_interactable.prompt_text = "OFFLINE"
