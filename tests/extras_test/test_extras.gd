extends Control
## Package 6 test scene. Browse JARVIS lines without the full game.
##
## Controls:
##   Up / Down    : change category
##   Left / Right : change level (0-4)
##   Space / E    : roll a new line
##   H            : toggle GameState.jarvis_hostile
##   Enter        : print every category for the current level to the Output panel

var _categories: Array = []
var _index := 0
var _level := 1

@onready var _label: Label = $Label


func _ready() -> void:
	_categories = Dialogue.get_categories()
	_categories.sort()
	GameState.jarvis_say.connect(_on_jarvis_say)
	_roll()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP:
			_index = posmod(_index - 1, _categories.size())
		KEY_DOWN:
			_index = posmod(_index + 1, _categories.size())
		KEY_LEFT:
			_level = clampi(_level - 1, 0, 4)
		KEY_RIGHT:
			_level = clampi(_level + 1, 0, 4)
		KEY_H:
			GameState.jarvis_hostile = not GameState.jarvis_hostile
		KEY_ENTER, KEY_KP_ENTER:
			_dump_all()
			return
		KEY_SPACE, KEY_E:
			pass
		_:
			return
	_roll()


func _roll() -> void:
	GameState.current_level = _level
	Dialogue.say(_categories[_index])


func _on_jarvis_say(text: String, mood: String) -> void:
	_label.text = "Category: %s   Level: %d   Hostile: %s\nMood: %s\n\n%s\n\n[Up/Down] category  [Left/Right] level  [Space] reroll  [H] hostile  [Enter] dump all" % [
		_categories[_index], _level, GameState.jarvis_hostile, mood, text,
	]


func _dump_all() -> void:
	for category: String in _categories:
		var entry := Dialogue.get_entry(category, _level)
		print("[%s | %s] %s" % [category, entry.mood, entry.text])
