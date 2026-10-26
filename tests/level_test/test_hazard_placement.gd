extends Node
# Headless check of hazard placement in levels 1-4 (spec rules) and hazard counts per level.
# Run:  godot --headless --path . res://tests/level_test/test_hazard_placement.tscn

const T := 32
const EXPECTED := { # hazard counts per level (pit-bottom lava included)
	1: {"Lava": 3, "Blade": 1},
	2: {"Lava": 1, "Toxic": 1, "Laser": 4},
	3: {"Lava": 1, "Toxic": 2, "Laser": 2, "Hammer": 2, "Blade": 1},
	4: {"Lava": 2, "Geyser": 2, "Boulder": 1},
}

var failures := 0


func _ready() -> void:
	for n in range(1, 5):
		_check_level(n)
	print("%d failures" % failures)
	get_tree().quit(failures)


func _check_level(n: int) -> void:
	var level: Node = load("res://levels/level_%02d/level_%02d.tscn" % [n, n]).instantiate()
	var tokens: Array[Vector2i] = []
	var robots: Array[Vector2i] = []
	var checkpoints: Array[Vector2i] = []
	for node in level.get_node("Entities").get_children():
		if "robot" in node.scene_file_path:
			robots.append(_cell(node.position))
		elif "token" in node.scene_file_path:
			tokens.append(_cell(node.position))
	var counts := {}
	for node in level.get_children():
		if "checkpoint" in node.scene_file_path:
			checkpoints.append(_cell(node.position))
		if not node is Hazard:
			continue
		var kind: String = node.scene_file_path.get_file().get_basename().capitalize()
		counts[kind] = counts.get(kind, 0) + 1
		var cells := _cells(node)
		var grounded: bool = kind != "Laser" # robots walk on the ground; lasers are in the air
		_far(n, kind, cells, tokens, 2, "token")
		_far(n, kind, cells, checkpoints, 2, "checkpoint")
		if grounded:
			_far(n, kind, cells, robots, 3, "robot spawn")
	var ok: bool = counts == EXPECTED[n]
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + "L%d hazard counts %s" % [n, counts])
	level.free()


## Static cells a hazard occupies: pool cells, laser beam cells, hammer pivot, blade start cell.
func _cells(h: Node) -> Array[Vector2i]:
	var start := _cell(h.position)
	var out: Array[Vector2i] = [start]
	if "size" in h:
		for i in int(h.size.x / T):
			out.append(start + Vector2i(i, 0))
	elif "length" in h and "vertical" in h:
		for i in int(h.length / T) + 1:
			out.append(start + (Vector2i(0, i) if h.vertical else Vector2i(i, 0)))
	return out


func _far(n: int, kind: String, cells: Array[Vector2i], others: Array[Vector2i], min_dist: int, what: String) -> void:
	for c in cells:
		for o in others:
			var d := maxi(absi(c.x - o.x), absi(c.y - o.y))
			if d < min_dist:
				failures += 1
				print("FAIL L%d %s at %s is %d tile(s) from %s at %s (min %d)" % [n, kind, c, d, what, o, min_dist])
				return
	print("PASS L%d %s at %s keeps >= %d tiles from every %s" % [n, kind, cells[0], min_dist, what])


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))
