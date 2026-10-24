class_name ControlSettings
extends VBoxContainer
## Shared, saved preference; loaded lazily for both direct level runs and the main menu.

enum TouchMode { AUTO, ON, OFF }
const SETTINGS_PATH := "user://control_settings.cfg"
static var _touch_mode: int = -1


static func get_touch_mode() -> int:
	if _touch_mode < 0:
		var config := ConfigFile.new()
		config.load(SETTINGS_PATH)
		_touch_mode = clampi(int(config.get_value("controls", "touch_mode", TouchMode.AUTO)), TouchMode.AUTO, TouchMode.OFF)
	return _touch_mode


static func touch_enabled() -> bool:
	match get_touch_mode():
		TouchMode.ON:
			return true
		TouchMode.OFF:
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


static func set_touch_mode(mode: int) -> void:
	_touch_mode = clampi(mode, TouchMode.AUTO, TouchMode.OFF)
	var config := ConfigFile.new()
	config.set_value("controls", "touch_mode", _touch_mode)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save touch controls: %s" % error_string(error))
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group("touch_controls", "apply_preferences")


func _ready() -> void:
	add_child(GameUI.label("CONTROLS", 24, GameUI.GOLD))
	var row := HBoxContainer.new()
	var caption := GameUI.label("TOUCH CONTROLS")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(192, 64)
	choice.get_popup().add_theme_font_size_override("font_size", 24)
	choice.get_popup().add_theme_constant_override("v_separation", 96)
	for option: String in ["AUTO", "ON", "OFF"]:
		choice.add_item(option)
	choice.select(get_touch_mode())
	choice.item_selected.connect(set_touch_mode)
	row.add_child(choice)
	add_child(row)
	add_child(GameUI.label("Auto detects touch devices.\nPlay in landscape for more room.", 16, GameUI.MUTED))
