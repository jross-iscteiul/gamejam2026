class_name AudioSettings
extends VBoxContainer

const SETTINGS_PATH := "user://audio_settings.cfg"


static func load_volumes() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name: String in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_volume_linear(index, clampf(config.get_value("audio", bus_name, 1.0), 0.0, 1.0))


func _ready() -> void:
	add_child(GameUI.label("AUDIO SETTINGS", 24, GameUI.GOLD))
	for bus_name: String in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var row := HBoxContainer.new()
		var name_label := GameUI.label(bus_name.to_upper())
		name_label.custom_minimum_size.x = 144
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = AudioServer.get_bus_volume_linear(index) * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(220, 48)
		row.add_child(slider)
		var percent := GameUI.label("%d%%" % slider.value)
		percent.custom_minimum_size.x = 80
		row.add_child(percent)
		slider.value_changed.connect(func(value: float) -> void:
			AudioServer.set_bus_volume_linear(index, value / 100.0)
			percent.text = "%d%%" % value
			_save_volumes()
		)
		add_child(row)


func _save_volumes() -> void:
	var config := ConfigFile.new()
	for bus_name: String in ["Master", "Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			config.set_value("audio", bus_name, AudioServer.get_bus_volume_linear(index))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % error_string(error))
