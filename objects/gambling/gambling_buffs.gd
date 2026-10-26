class_name GamblingBuffs
extends Node
## Timed prizes from the gambling machines. Owned by Package 6.
##
## One instance lives under the scene tree root (like Package 5's LevelMusic),
## so buffs survive closing the machine and changing level. Timers only run
## during gameplay (paused while the game is paused).
##
## - Token multiplier: every token picked up (GameState.token_collected) is
##   worth `multiplier` times as much until it runs out.
## - God mode: switches on Package 3's GameState god mode (infinite tokens and
##   energy) for a while, then switches it off again.

signal changed

const NODE_NAME := "GamblingBuffs"

var token_multiplier: int = 1
var token_multiplier_left: float = 0.0
var god_mode_left: float = 0.0


static func get_instance(tree: SceneTree) -> GamblingBuffs:
	var buffs := tree.root.get_node_or_null(NODE_NAME) as GamblingBuffs
	if buffs == null:
		buffs = GamblingBuffs.new()
		buffs.name = NODE_NAME
		tree.root.add_child(buffs)
	return buffs


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	GameState.token_collected.connect(_on_token_collected)


func start_token_multiplier(multiplier: int, seconds: float) -> void:
	token_multiplier = maxi(token_multiplier, multiplier)
	token_multiplier_left = maxf(token_multiplier_left, 0.0) + seconds
	_notify("TOKENS x%d FOR %dS" % [token_multiplier, ceili(token_multiplier_left)])
	changed.emit()


func start_god_mode(seconds: float) -> void:
	god_mode_left += seconds
	GameState.set_god_mode(true)
	_notify("GOD MODE FOR %dS" % ceili(god_mode_left))
	changed.emit()


func _process(delta: float) -> void:
	if token_multiplier_left > 0.0:
		token_multiplier_left -= delta
		if token_multiplier_left <= 0.0:
			token_multiplier_left = 0.0
			token_multiplier = 1
			_notify("TOKEN MULTIPLIER OVER")
			changed.emit()
	if god_mode_left > 0.0:
		god_mode_left -= delta
		if god_mode_left <= 0.0:
			god_mode_left = 0.0
			GameState.set_god_mode(false)
			_notify("GOD MODE OVER")
			changed.emit()


func _on_token_collected(value: int) -> void:
	# The token already added `value`; add the extra share.
	if token_multiplier_left > 0.0 and token_multiplier > 1:
		GameState.add_tokens(value * (token_multiplier - 1))


func _notify(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("notify"):
		hud.notify(text)
