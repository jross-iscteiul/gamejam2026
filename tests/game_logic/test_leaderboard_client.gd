extends Node
## Offline client/API contract tests. Never calls the configured public domain.

var _failures: int = 0
var _calls: Array[Dictionary] = []
var _fail_submit: bool = false


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _fake(path: String, method: HTTPClient.Method, body: Dictionary, authenticated: bool) -> Dictionary:
	_calls.append({"path": path, "method": method, "body": body.duplicate(true), "authenticated": authenticated})
	if path == "/v1/runs":
		return {"ok": true, "data": {"run_token": "a".repeat(64)}}
	if path == "/v1/scores" and _fail_submit:
		return {"ok": false, "data": {}}
	if path.begins_with("/v1/leaderboard"):
		return {"ok": true, "data": {"items": [{"rank": 1, "name": "Racer", "time_ms": 10000}, {"time_ms": "bad"}, null]}}
	return {"ok": true, "data": {"ok": true}}


func _run() -> void:
	var client := LeaderboardClient.new()
	add_child(client)
	client.transport = _fake
	await client.refresh()
	_check(_calls.is_empty(), "disabled integration makes no network calls")
	client.enabled = true
	await client.refresh()
	_check(client.entries.size() == 1 and client.entries[0].time_ms == 10000, "leaderboard parses valid entries and ignores malformed rows")
	_check(not _calls[0].authenticated, "reading the public leaderboard needs no run token")
	var result := {"eligible": true, "ruleset": RunClock.RULESET, "elapsed_ms": 10000, "splits_ms": [2500, 2500, 2500, 2500], "deaths": 1}
	var practice := result.duplicate(true)
	practice.eligible = false
	client.offer_result(practice)
	_check(client.pending_result.is_empty(), "practice results are never offered for submission")
	client.offer_result(result)
	var count := _calls.size()
	await client.submit("Racer")
	_check(_calls.size() == count and not client.pending_result.is_empty(), "an unregistered run cannot mint a token after finishing")
	await client.start_run()
	for level in range(1, 4):
		await client.checkpoint(level)
	var checkpoints := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/checkpoints")
	_check(checkpoints.size() == 3 and checkpoints[0].body.level == 1 and checkpoints[2].body.level == 3, "client sends ordered authenticated checkpoints")
	count = _calls.size()
	await client.submit("<bad>")
	_check(_calls.size() == count, "invalid public names do not send requests")
	_fail_submit = true
	await client.submit("Racer")
	_check(not client.pending_result.is_empty() and not client.busy, "failed submission keeps the result available for retry")
	_fail_submit = false
	await client.submit("Racer")
	var submissions := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/scores")
	_check(submissions[-1].body.time_ms == 10000 and submissions[-1].body.splits_ms.size() == 4 and submissions[-1].authenticated, "submission sends milliseconds, splits and run authentication")
	_check(client.pending_result.is_empty() and not client.busy, "successful submission consumes its pending result")
	count = _calls.size()
	await client.submit("Racer")
	_check(_calls.size() == count, "repeat submission cannot upload the same result again")
	client.abandon_run()
	_check(client._run_token.is_empty() and client._checkpoints.is_empty(), "new/practice runs discard previous online timing credentials")
	var invalid := result.duplicate(true)
	invalid.splits_ms = [1, 2, 3, 4]
	_check(not LeaderboardClient.valid_result(invalid), "mismatched split totals cannot be submitted")
	var previous_entries := GameState.leaderboard.entries.duplicate(true)
	GameState.leaderboard.entries = [{"rank": 1, "name": "Racer", "time_ms": 10000}]
	var panel := LeaderboardPanel.new()
	panel.theme = GameUI.theme()
	add_child(panel)
	_check(panel._rows.text.contains("Racer") and panel._rows.text.contains("00:10.000"), "leaderboard UI formats player names and millisecond times")
	GameState.leaderboard.entries.assign(previous_entries)
	panel.queue_free()
	client.queue_free()
	await get_tree().process_frame
	print("LEADERBOARD CLIENT: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)
