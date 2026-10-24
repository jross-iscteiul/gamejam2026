class_name LeaderboardClient
extends Node
## Self-hosted API. Run tokens stay in memory; no shared API secret is shipped to browsers.

signal updated
var api_url: String = "https://leaderboard-gamejam2026.suricata-lab.com"
var enabled: bool = false
var busy: bool = false
var message: String = "Online leaderboard is not available yet."
var entries: Array[Dictionary] = []
var pending_result: Dictionary = {}
var transport: Callable # Offline contract tests inject a fake HTTP transport.
var _run_token: String = ""
var _generation: int = 0
var _checkpoints: Array[int] = []
var _syncing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load("res://leaderboard.cfg") == OK:
		enabled = bool(config.get_value("server", "enabled", false))
		api_url = str(config.get_value("server", "api_url", api_url)).strip_edges().trim_suffix("/")
	if configured():
		message = "Fastest full runs. Refresh to load times."


func configured() -> bool:
	return enabled and api_url.begins_with("https://")


func abandon_run() -> void:
	_generation += 1
	busy = false
	_run_token = ""
	_checkpoints.clear()
	_syncing = false
	pending_result.clear()
	updated.emit()


func start_run() -> void:
	if not configured():
		return
	var generation := _generation
	var response := await _request("/v1/runs", HTTPClient.METHOD_POST, {"ruleset": RunClock.RULESET}, false)
	if generation != _generation:
		return
	if response.ok and response.data.get("run_token") is String:
		_run_token = response.data.run_token
		await _sync_checkpoints()
	updated.emit()


func checkpoint(level: int) -> void:
	if level in range(1, 4) and not _checkpoints.has(level):
		_checkpoints.append(level)
		await _sync_checkpoints()


func _sync_checkpoints() -> void:
	if _syncing or _run_token.is_empty():
		return
	_syncing = true
	var generation := _generation
	while not _checkpoints.is_empty():
		var response := await _request("/v1/checkpoints", HTTPClient.METHOD_POST, {"level": _checkpoints[0]})
		if generation != _generation:
			return
		if not response.ok:
			break
		_checkpoints.pop_front()
	_syncing = false


func offer_result(result: Dictionary) -> void:
	if valid_result(result):
		pending_result = result.duplicate(true)
		updated.emit()


static func valid_result(result: Dictionary) -> bool:
	if result.get("eligible") != true or result.get("ruleset") != RunClock.RULESET:
		return false
	var score: Variant = result.get("elapsed_ms", 0)
	var splits: Variant = result.get("splits_ms", [])
	if not score is int or score <= 0 or not splits is Array or splits.size() != 4:
		return false
	var total: int = 0
	for split: Variant in splits:
		if not split is int or split < 0:
			return false
		total += split
	var deaths: Variant = result.get("deaths", -1)
	return total == score and deaths is int and deaths >= 0


static func valid_name(player_name: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9 _-]{2,16}$")
	return regex.search(player_name.strip_edges()) != null


func refresh() -> void:
	if busy or not configured():
		updated.emit()
		return
	busy = true
	message = "Loading times..."
	updated.emit()
	await _load_scores()
	busy = false
	updated.emit()


func submit(player_name: String) -> void:
	player_name = player_name.strip_edges()
	if busy or not configured() or not valid_result(pending_result):
		return
	if not valid_name(player_name):
		message = "Use 2-16 letters, numbers, spaces, _ or -."
		updated.emit()
		return
	if _run_token.is_empty():
		message = "Online timing was unavailable. Start a new run to submit."
		updated.emit()
		return
	busy = true
	message = "Submitting your time..."
	updated.emit()
	var generation := _generation
	while _syncing and generation == _generation:
		await get_tree().process_frame
	await _sync_checkpoints()
	if generation != _generation:
		return
	if _checkpoints.is_empty() and not _syncing:
		var score: int = pending_result.elapsed_ms
		var payload := {"name": player_name, "time_ms": score, "ruleset": RunClock.RULESET, "splits_ms": pending_result.splits_ms, "deaths": pending_result.deaths}
		var response := await _request("/v1/scores", HTTPClient.METHOD_POST, payload)
		if generation != _generation:
			return
		if response.ok:
			pending_result.clear()
			await _load_scores()
			message = "Time submitted: " + RunClock.format_time(score)
	busy = false
	updated.emit()


func _load_scores() -> void:
	var response := await _request("/v1/leaderboard?ruleset=" + RunClock.RULESET, HTTPClient.METHOD_GET, {}, false)
	if not response.ok:
		return
	var items: Variant = response.data.get("items")
	if not items is Array:
		message = "Could not load times. Try again."
		return
	entries.clear()
	for item: Variant in items.slice(0, 10):
		if not item is Dictionary:
			continue
		var time: Variant = item.get("time_ms")
		if not time is float and not time is int:
			continue
		if time > 0:
			entries.append({"rank": int(item.get("rank", entries.size() + 1)), "name": str(item.get("name", "RACER")).replace("\n", " ").replace("\r", " ").left(16), "time_ms": int(time)})
	message = "Fastest full runs" if not entries.is_empty() else "No times yet. Be the first!"


func _request(path: String, method: HTTPClient.Method, body: Dictionary = {}, authenticated: bool = true) -> Dictionary:
	if transport.is_valid():
		return await transport.call(path, method, body, authenticated)
	var request := HTTPRequest.new()
	request.timeout = 12.0
	request.body_size_limit = 262144
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated:
		headers.append("Authorization: Bearer " + _run_token)
	var error := request.request(api_url + path, headers, method, JSON.stringify(body) if method != HTTPClient.METHOD_GET else "")
	if error != OK:
		request.queue_free()
		message = "Can't reach the leaderboard. Try again."
		return {"ok": false, "data": {}}
	var response: Array = await request.request_completed
	request.queue_free()
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] < 200 or response[1] >= 300 or not parsed is Dictionary:
		message = "Leaderboard request failed. Please try again."
		return {"ok": false, "data": {}}
	return {"ok": true, "data": parsed}
