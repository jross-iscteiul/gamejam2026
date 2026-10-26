class_name GamblingOdds
extends Resource
## Wheel odds. Owned by Package 6. Tune in the inspector during balancing.
##
## Arrays are indexed by level (0 = tests, 1-4 = levels). Levels past the end
## of an array use its last value.

enum Outcome {
	JACKPOT,
	DOUBLE,
	ENERGY_BOOST,
	REFUND,
	NOTHING,
	TAX,
	ENERGY_DRAIN,
	JARVIS_RAISE,
	RESPIN_TROLL,
	FAKE_JACKPOT,
	HEAL,
	TOKEN_MULTIPLIER,
	GOD_MODE,
}

const WINS: Array[int] = [
	Outcome.JACKPOT, Outcome.DOUBLE, Outcome.ENERGY_BOOST,
	Outcome.HEAL, Outcome.TOKEN_MULTIPLIER, Outcome.GOD_MODE,
]

## Chance of a good outcome per level.
@export var good_chance: Array[float] = [0.55, 0.55, 0.45, 0.35, 0.25]
## Chance of a refund per level. Everything else is a troll outcome.
@export var neutral_chance: Array[float] = [0.15, 0.15, 0.15, 0.15, 0.15]
## Relative weights inside the good bucket.
@export var good_weights: Dictionary = {
	Outcome.JACKPOT: 1.0,
	Outcome.DOUBLE: 3.0,
	Outcome.ENERGY_BOOST: 2.0,
	Outcome.HEAL: 2.0,
	Outcome.TOKEN_MULTIPLIER: 1.5,
}
## Chance of GOD MODE on any spin, checked before everything else (1%).
@export_range(0.0, 1.0) var god_mode_chance: float = 0.01
## Relative weights inside the troll bucket.
@export var troll_weights: Dictionary = {
	Outcome.NOTHING: 4.0,
	Outcome.TAX: 2.0,
	Outcome.ENERGY_DRAIN: 2.0,
	Outcome.JARVIS_RAISE: 1.0,
	Outcome.RESPIN_TROLL: 1.0,
}
## After this many non-wins in a row, the next spin is guaranteed good.
@export var pity_after_losses: int = 3
## Chance that a jackpot gets "nudged" into a fake jackpot.
@export_range(0.0, 1.0) var fake_jackpot_chance: float = 0.1
## Fake jackpots only happen from this level on.
@export var fake_jackpot_min_level: int = 2


static func is_win(outcome: int) -> bool:
	return outcome in WINS


func roll(level: int, loss_streak: int, rng: RandomNumberGenerator) -> int:
	var pity := loss_streak >= pity_after_losses
	var good := _at(good_chance, level)
	var neutral := _at(neutral_chance, level)
	if rng.randf() < god_mode_chance:
		return Outcome.GOD_MODE
	var r := rng.randf()

	var outcome: int
	if pity or r < good:
		outcome = _weighted(good_weights, rng)
	elif r < good + neutral:
		outcome = Outcome.REFUND
	else:
		outcome = _weighted(troll_weights, rng)

	if (
		outcome == Outcome.JACKPOT
		and not pity
		and level >= fake_jackpot_min_level
		and rng.randf() < fake_jackpot_chance
	):
		outcome = Outcome.FAKE_JACKPOT
	return outcome


func _at(values: Array[float], level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 0, values.size() - 1)]


func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w: float in weights.values():
		total += w
	var r := rng.randf() * total
	for key: int in weights:
		r -= weights[key]
		if r <= 0.0:
			return key
	return weights.keys().back()
