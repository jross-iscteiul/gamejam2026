class_name LeaderboardPanel
extends VBoxContainer

var _status: Label
var _rows: Label
var _name: LineEdit
var _refresh: Button
var _submit: Button
var _result: Label
var _client: LeaderboardClient


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_client = GameState.leaderboard
	add_child(GameUI.label("FULL RUN LEADERBOARD", 24, GameUI.GOLD))
	_status = GameUI.label("", 16, GameUI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_rows = GameUI.label("")
	_rows.custom_minimum_size = Vector2(600, 200)
	add_child(_rows)
	_result = GameUI.label("", 16, GameUI.CYAN)
	add_child(_result)
	_name = LineEdit.new()
	_name.placeholder_text = "Public racer name (2-16 characters)"
	_name.max_length = 16
	_name.custom_minimum_size.y = 64
	add_child(_name)
	_refresh = GameUI.button("REFRESH", _client.refresh)
	add_child(_refresh)
	_submit = GameUI.button("SUBMIT MY RUN", func() -> void: _client.submit(_name.text))
	add_child(_submit)
	_client.updated.connect(_update)
	_update()


func _update() -> void:
	_status.text = _client.message
	var lines := PackedStringArray()
	for entry: Dictionary in _client.entries:
		lines.append("%2d  %-16s %s" % [entry.rank, entry.name, RunClock.format_time(entry.time_ms)])
	_rows.text = "\n".join(lines)
	_refresh.disabled = _client.busy or not _client.configured()
	var pending := LeaderboardClient.valid_result(_client.pending_result)
	_submit.visible = pending
	_name.visible = pending
	_result.visible = pending
	if pending:
		_result.text = "YOUR RUN  " + RunClock.format_time(_client.pending_result.elapsed_ms)
	_submit.disabled = _client.busy or not _client.configured()
