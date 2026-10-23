class_name GameUI
extends RefCounted
## Shared palette, pixel font and original synthesized UI/pickup sounds.

const INK := Color("131c2e")
const PANEL := Color("1d2b42")
const EDGE := Color("425774")
const TEXT := Color("edf5ed")
const MUTED := Color("a2b7c8")
const GOLD := Color("ffd268")
const CYAN := Color("69e1d1")
const RED := Color("ff7775")


static func style(color: Color, border: Color = EDGE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(3)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box


static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://ui/shared/press_start_2p.ttf")
	result.default_font_size = 16
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_stylebox("normal", "Button", style(PANEL))
	result.set_stylebox("hover", "Button", style(Color("304562"), CYAN))
	result.set_stylebox("pressed", "Button", style(INK, GOLD))
	result.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD))
	result.set_stylebox("background", "ProgressBar", style(INK))
	result.set_stylebox("fill", "ProgressBar", style(CYAN, CYAN))
	result.set_constant("separation", "VBoxContainer", 20)
	result.set_constant("separation", "HBoxContainer", 24)
	return result


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 64
	result.pressed.connect(action)
	return result


static func chime(high: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	var count := 3308 if high else 1764
	data.resize(count * 2)
	for i in count:
		var t := float(i) / stream.mix_rate
		var frequency := (880.0 if i < count / 2 else 1320.0) if high else 660.0
		var envelope := pow(1.0 - float(i) / count, 2.0)
		var sample := sin(TAU * frequency * t) * envelope * 0.22
		data.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = data
	return stream


static func play_sound(parent: Node, stream: AudioStream) -> void:
	var sound := AudioStreamPlayer.new()
	sound.bus = &"SFX"
	sound.stream = stream
	parent.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
