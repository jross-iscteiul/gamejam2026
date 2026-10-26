class_name RunClock
extends RefCounted
## Active-play time in integer milliseconds for score submissions. No network credentials here.

signal finished(result: Dictionary)

enum State { IDLE, ARMED, RUNNING, FINISHED }
const RECORD_PATH := "user://run_records.cfg"
const RULESET := "full_run_active_v1"

var state: State = State.IDLE
var eligible: bool = false
var deaths: int = 0
var best_msec: int = 0
var level: int = 0
var completed_levels: Array[int] = []
var splits_msec: Array[int] = []
var elapsed_msec: int:
	get:
		return int(floor(_seconds * 1000.0))

var _seconds: float = 0.0
var _last_split: int = 0
var _record_path: String


func _init(path: String = RECORD_PATH) -> void:
	_record_path = path
	load_record()


func reset(full_run: bool = false) -> void:
	state = State.ARMED if full_run else State.IDLE
	eligible = false
	deaths = 0
	level = 0
	_seconds = 0.0
	_last_split = 0
	completed_levels.clear()
	splits_msec.clear()


func enter_level(number: int) -> void:
	if state == State.FINISHED:
		reset()
	if state in [State.IDLE, State.ARMED]:
		eligible = state == State.ARMED and number == 1
		state = State.RUNNING
	elif number != level and number != completed_levels.size() + 1:
		eligible = false
	if number != level and level > 0 and not completed_levels.has(level):
		eligible = false
	level = number


func advance(delta: float, active: bool) -> void:
	if state == State.RUNNING and active and is_finite(delta) and delta > 0:
		_seconds += delta


func record_level(number: int) -> void:
	if state != State.RUNNING:
		return
	if number != level or number != completed_levels.size() + 1:
		eligible = false
		return
	completed_levels.append(number)
	splits_msec.append(elapsed_msec - _last_split)
	_last_split = elapsed_msec


func record_death() -> void:
	if state == State.RUNNING:
		deaths += 1


func finish() -> Dictionary:
	if state != State.RUNNING:
		return {}
	eligible = eligible and level == 4 and completed_levels == [1, 2, 3] and elapsed_msec > 0
	state = State.FINISHED
	var splits := splits_msec.duplicate()
	splits.append(elapsed_msec - _last_split)
	var result := {
		"ruleset": RULESET,
		"elapsed_ms": elapsed_msec,
		"deaths": deaths,
		"splits_ms": splits,
		"eligible": eligible,
	}
	if eligible and (best_msec == 0 or elapsed_msec < best_msec):
		best_msec = elapsed_msec
		var config := ConfigFile.new()
		config.set_value(RULESET, "best_ms", best_msec)
		var error := config.save(_record_path)
		if error != OK:
			push_warning("Could not save personal best: %s" % error_string(error))
	finished.emit(result)
	return result


func load_record() -> void:
	var config := ConfigFile.new()
	best_msec = 0
	if config.load(_record_path) == OK:
		best_msec = maxi(0, int(config.get_value(RULESET, "best_ms", 0)))


static func format_time(milliseconds: int) -> String:
	var value := maxi(milliseconds, 0)
	return "%02d:%02d.%03d" % [value / 60000, (value / 1000) % 60, value % 1000]
