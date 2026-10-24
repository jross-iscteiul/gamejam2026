extends Node
# Headless check: every level has a 3-layer parallax city background and starts the looping
# soundtrack on the Music bus, which keeps playing (not restarted) across a level change.
# Run:  godot --headless --path . res://tests/level_test/test_level_backgrounds.tscn

const ART := {1: "city_skyline", 2: "neon_night", 3: "neon_street", 4: "city_skyline"}

var level := 1
var t := 0
var failures := 0
var _running := false
var _music_before: AudioStreamPlayer


func _ready() -> void:
	_begin.call_deferred()


func _begin() -> void:
	get_tree().current_scene = null
	_running = true
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if not _running or s == null:
		return
	t += 1
	if t < 10:
		return
	var bg: CanvasLayer = s.get_node("CityBackground")
	var layers := bg.get_children().filter(func(n: Node) -> bool: return n is TextureRect)
	_check(bg.art == ART[level] and layers.size() == 3 and layers.all(func(r: TextureRect) -> bool: return r.texture != null),
		"L%d background %s has 3 textured layers" % [level, bg.art])
	var music := get_tree().root.get_node_or_null("LevelMusic") as AudioStreamPlayer
	_check(music != null and music.playing and music.bus == &"Music" and music.stream.loop,
		"L%d soundtrack loops on the Music bus" % level)
	if level > 1:
		_check(music == _music_before, "L%d music continues from the previous level (same player)" % level)
	_music_before = music
	level += 1
	t = 0
	if level > 4:
		print("%d failures" % failures)
		get_tree().quit(failures)
		return
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [level, level])


func _check(ok: bool, msg: String) -> void:
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + msg)
