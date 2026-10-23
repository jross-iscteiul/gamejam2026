extends Node
## Global game state and event bus. Stub owned by Package 3 — keep signal/function signatures stable.

signal tokens_changed(tokens: int)
signal trust_changed(trust: float)
signal enemy_killed(enemy: Node, killer: Node)
signal player_died
signal player_respawned
signal level_completed(level: int)
signal boss_defeated
signal boss_health_changed(current: float, maximum: float)
signal jarvis_say(text: String, mood: String)
signal cutscene_finished

const MAX_TRUST := 100.0

var tokens: int = 0:
	set(value):
		tokens = maxi(value, 0)
		tokens_changed.emit(tokens)

var trust: float = MAX_TRUST:
	set(value):
		trust = clampf(value, 0.0, MAX_TRUST)
		trust_changed.emit(trust)

var current_level: int = 0
var jarvis_hostile: bool = false


func add_tokens(n: int) -> void:
	tokens += n


func spend_tokens(n: int) -> bool:
	if tokens < n:
		return false
	tokens -= n
	return true


func add_trust(n: float) -> void:
	trust += n
