extends Node
## One-shot level generator: builds levels/shared/tileset.tres and levels/level_XX/level_XX.tscn from the ASCII maps below.
## Run:  godot --headless --path . res://levels/build_levels.tscn
## WARNING: re-running overwrites the level scenes (and any edits made to them in the editor).
##
## Legend:  # solid   . empty   P player   D exit door   L lever
##          G gate (closed, 3 tall)   O gate (open, closes on boss trigger)   T boss trigger   K boss spawn
##          H..h moving platform, horizontal (H = centre of the 3-tile platform, h = where it travels to)
##          V/v  moving platform, vertical (V = start centre, v = end, same column)
##          F..f / E/e  same as H..h / V/v but fast (harder to ride)
##          ~ pit bottom (instant respawn at last checkpoint, drawn as harmless lava)   C checkpoint
##          Hazards (objects/hazards/, scaled by the level's "difficulty"):
##          R lava (instant death)   W toxic waste (1 HP while inside); a run of cells = one pool
##          Z..z laser between two emitters (same row or column)   M swinging hammer (pivot cell)
##          B fixed spinning blade   S..s blade sliding between S and s (same row or column)
##          Y lava pool with a geyser erupting up to the ceiling at random intervals
##          X giant rolling ball (start centre of its 3x3 tiles); chases right and stops at the O gate
## Per level: "background" = city_skyline | neon_night | neon_street (+ optional "background_tint");
##            all levels play MUSIC on the Music bus.

const TILE := 32
const TILESET_PATH := "res://levels/shared/tileset.tres"
# source id -> [texture, layout ("full" = 6x4 sheet, "nine" = 3x3 sheet), has collision]
const SOURCES := [
	["res://assets/art/industrial_tileset/tiles/1_Industrial_Tileset_1.png", "full", true],
	["res://assets/art/industrial_tileset/tiles/1_Industrial_Tileset_1B.png", "full", true],
	["res://assets/art/industrial_tileset/tiles/1_Industrial_Tileset_1C.png", "nine", true],
]

const LEVELS := [
	{ # Level 1 - the docks: long run with steps, dips and an optional upper route.
		"fg": 0, "sky": Color(0.835, 0.902, 0.961), "difficulty": 1.0,
		"background": "city_skyline",
		"map": [
			"##################################################################################################################################",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################.....................H.......h............#",
			"#..................................................................####################..........................................#",
			"#..................................................................####################..............####........................#",
			"#..................................................................####################..............####.......#######..........#",
			"#..................................................................####################...######.....####........................#",
			"#........................################.......#############......####################..........########........................#",
			"#........................################.......#############....................................########...................D....#",
			"#............####........################.......#############...C................................##########RRR####################",
			"#............####........################.......###########################....###################################################",
			"#..P.........####S...s...################.......###########################....###################################################",
			"#########################################.......###########################....###################################################",
			"#########################################.......###########################....###################################################",
			"#########################################.......###########################....###################################################",
			"#########################################~~~~~~~###########################~~~~###################################################",
		],
	},
	{ # Level 2 - the shaft: climb zig-zag platforms, cross the top, then a long drop (future fall damage) to the door.
		"fg": 1, "sky": Color(0.835, 0.902, 0.961), "difficulty": 1.2,
		"background": "neon_night",
		# zoom out + look down over the descent so the next platform is always on screen
		"camera_zones": [Rect2i(30, 1, 39, 50)],
		"map": [
			"######################################################################",
			"#....................................................................#",
			"#....................................................................#",
			"#....................................................................#",
			"#....................................................................#",
			"#....................................................................#",
			"#....................................................................#",
			"#....................................................................#",
			"#..............................C.....................................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#...............###########..########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..F............f..#",
			"#..##########................########.......#######..................#",
			"#............................########.......#######..................#",
			"#Z..........................z########.......#######Z................z#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#...............###########..########.......#######..................#",
			"#............................########.......#######..f............F..#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#..##########.v..............########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######........E.........#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######........e.........#",
			"#.............V.###########..########.......#######..................#",
			"#............................########.......#######..F............f..#",
			"#Z..........................z########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######Z................z#",
			"#..##########................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..f............F..#",
			"#............................########.......#######..................#",
			"#...............###########..########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#............................########.......#######..................#",
			"#...P........................########.......#######.............D....#",
			"#######################WWWWW#########.......##########################",
			"#####################################~~~~~~~##########################",
		],
	},
	{ # Level 3 - control room: climb to the upper deck lever, drop down, pass the opened gate to the door.
		"fg": 1, "sky": Color(0.75, 0.82, 0.9), "difficulty": 1.45,
		"background": "neon_street",
		"map": [
			"##############################################################################################################",
			"#...................................................................................................#........#",
			"#...................................................................................................#........#",
			"#...................................................................................................#........#",
			"#..........................................###.............................###......................#........#",
			"#...........................................M...............................M.......................#........#",
			"#...................................................................................................#........#",
			"#...................................................................................................#........#",
			"#........................................C....................................L.....................#........#",
			"#.......................................#############.H..........h.##############...................#........#",
			"#...................................................................................................#........#",
			"#..............................######...............................................................#........#",
			"#............................Z......................................................................#........#",
			"#...................................................................................................#........#",
			"#...................................................................................................#........#",
			"#............................z......................................................................#........#",
			"#.....................######........................................................................#........#",
			"#...................Z...............................................................................#........#",
			"#.......................................................####........................................G........#",
			"#.......................................................####..........####..........................G........#",
			"#..P................z...................................####S........s####..........................G....D...#",
			"#####################...#######################WWWW###########WWWWW#################..........################",
			"####################################################################################..........################",
			"####################################################################################~~~~~~~~~~################",
		],
	},
	{ # Level 4 - boss arena: outrun the rolling ball past two lava geysers, then the gate shuts and the camera locks.
		"fg": 2, "sky": Color(0.24, 0.18, 0.35), "difficulty": 1.0,
		"background": "city_skyline", "background_tint": Color(0.55, 0.45, 0.75),
		"map": [
			"################################################",
			"###########################....................#",
			"###########################....................#",
			"###########################....................#",
			"###########################....................#",
			"###########################..####........####..#",
			"###########################....................#",
			"#.........................#....................#",
			"#....P....................O......######........#",
			"#.X.......................O....................#",
			"#.........................O...T...........K....#",
			"############Y#######Y###########################",
			"################################################",
		],
	},
]

var door_scene: PackedScene = load("res://levels/shared/door.tscn")
var lever_scene: PackedScene = load("res://levels/shared/lever.tscn")
var gate_scene: PackedScene = load("res://levels/shared/gate.tscn")
var trigger_scene: PackedScene = load("res://levels/shared/boss_trigger.tscn")
var player_scene: PackedScene = load("res://characters/player/player.tscn")
var platform_scene: PackedScene = load("res://objects/platforms/moving_platform.tscn")
var checkpoint_scene: PackedScene = load("res://levels/shared/checkpoint.tscn")
var lava_scene: PackedScene = load("res://objects/hazards/lava.tscn")
var toxic_scene: PackedScene = load("res://objects/hazards/toxic.tscn")
var laser_scene: PackedScene = load("res://objects/hazards/laser.tscn")
var hammer_scene: PackedScene = load("res://objects/hazards/hammer.tscn")
var blade_scene: PackedScene = load("res://objects/hazards/blade.tscn")
var geyser_scene: PackedScene = load("res://objects/hazards/geyser.tscn")
var boulder_scene: PackedScene = load("res://objects/hazards/boulder.tscn")
const MUSIC := "res://assets/audio/music/cyberpunk_street.ogg"


func _ready() -> void:
	if ResourceSaver.save(_make_tileset(), TILESET_PATH) != OK:
		push_error("failed to save tileset")
	var tileset: TileSet = load(TILESET_PATH)
	for i in LEVELS.size():
		_build_level(i, tileset)
	get_tree().quit()


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var h := TILE / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for id in SOURCES.size():
		var src := TileSetAtlasSource.new()
		src.texture = load(SOURCES[id][0])
		src.texture_region_size = Vector2i(TILE, TILE)
		ts.add_source(src, id)
		var grid := src.get_atlas_grid_size()
		for y in grid.y:
			for x in grid.x:
				src.create_tile(Vector2i(x, y))
				if SOURCES[id][2]:
					var data := src.get_tile_data(Vector2i(x, y), 0)
					data.add_collision_polygon(0)
					data.set_collision_polygon_points(0, 0, square)
	return ts


## Pick the atlas tile for cell p from its 4 neighbours (simple 9-slice autotile).
func _atlas(cells: Dictionary, p: Vector2i, layout: String) -> Vector2i:
	var n := cells.has(p + Vector2i.UP)
	var s := cells.has(p + Vector2i.DOWN)
	var w := cells.has(p + Vector2i.LEFT)
	var e := cells.has(p + Vector2i.RIGHT)
	if layout == "nine":
		return Vector2i(0 if not w else 2 if not e else 1, 0 if not n else 2 if not s else 1)
	var row := 0 if not (n or s) else 1 if not n else 3 if not s else 2
	var col := 3 if not (w or e) else 0 if not w else 2 if not e else 1
	if row == 2 and col == 1: # interior: tile the 2x4 filler block
		return Vector2i(4 + posmod(p.x, 2), posmod(p.y, 4))
	return Vector2i(col, row)


func _paint(layer: TileMapLayer, cells: Dictionary, source: int) -> void:
	for p in cells:
		layer.set_cell(p, source, _atlas(cells, p, SOURCES[source][1]))


func _build_level(index: int, tileset: TileSet) -> void:
	var def: Dictionary = LEVELS[index]
	var map: Array = def.map
	var difficulty: float = def.get("difficulty", 1.0)
	var root := Node2D.new()
	root.name = "Level%d" % (index + 1)
	root.set_script(load("res://levels/shared/level.gd"))
	root.set("number", index + 1)
	root.set("sky", def.sky)
	root.set("music", load(MUSIC))

	var background := CanvasLayer.new()
	background.name = "CityBackground"
	background.set_script(load("res://levels/shared/level_background.gd"))
	background.set("art", def.get("background", "city_skyline"))
	background.set("tint", def.get("background_tint", Color.WHITE))

	var fg := TileMapLayer.new()
	fg.name = "Tiles"
	fg.tile_set = tileset
	_add(root, background)
	_add(root, fg)

	var solid := {}
	var gates := {}
	var nodes := {}
	for y in map.size():
		assert(map[y].length() == map[0].length(), "level %d row %d has wrong width" % [index + 1, y])
		for x in map[y].length():
			var ch: String = map[y][x]
			var p := Vector2i(x, y)
			var at := Vector2(p * TILE) + Vector2(TILE, TILE) / 2.0
			match ch:
				"#": solid[p] = true
				"G", "O":
					if map[y - 1][x] != ch: # only the top cell of each gate column
						var gate = _add(root, gate_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
						gate.closed = ch == "G"
						gates[ch] = gate
				"P": nodes.player = _add(root, player_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
				"D":
					var door = _add(root, door_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
					door.next_level = "res://levels/level_%02d/level_%02d.tscn" % [index + 2, index + 2]
				"C": _add(root, checkpoint_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
				"~":
					if map[y][x - 1] != "~": # one trigger per run of pit cells
						_add_area(root, "Pit", "res://objects/hazards/pit.gd", Rect2i(x, y, _run(map, p), 1))
						var glow = _add(root, lava_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector2(p * TILE))
						glow.size = Vector2(_run(map, p) * TILE, TILE)
						glow.damaging = false # the Pit trigger handles it (instant reset, bypasses shields)
				"R", "W", "Y":
					if map[y][x - 1] != ch: # one pool per run of cells
						var pool = _add(root, (toxic_scene if ch == "W" else lava_scene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector2(p * TILE))
						pool.size = Vector2(_run(map, p) * TILE, TILE)
						pool.difficulty = difficulty
						if ch == "Y":
							var geyser = _add(root, geyser_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector2(p * TILE))
							geyser.width = pool.size.x
							var up := 1
							while map[y - up][x] != "#":
								up += 1
							geyser.height = (up - 1) * TILE
				"X": nodes.boulder = _add(root, boulder_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
				"Z":
					var end := _pair_end(map, p, "z")
					var first := Vector2i(mini(p.x, end.x), mini(p.y, end.y))
					var laser = _add(root, laser_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector2(first * TILE) + Vector2(TILE, TILE) / 2.0)
					laser.vertical = end.x == p.x
					laser.length = float(absi(end.x - p.x) + absi(end.y - p.y)) * TILE
					laser.phase = snappedf(x * 0.08, 0.01) # rows of lasers fire as a wave along the run
					laser.difficulty = difficulty
				"M":
					var hammer = _add(root, hammer_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), Vector2(p * TILE) + Vector2(TILE / 2.0, 0))
					hammer.phase = snappedf(x * 0.37, 0.01) # neighbouring hammers swing out of step
					hammer.difficulty = difficulty
				"B", "S":
					var blade = _add(root, blade_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
					if ch == "S":
						blade.travel = Vector2((_pair_end(map, p, "s") - p) * TILE)
					blade.difficulty = difficulty
				"L": nodes.lever = _add(root, lever_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
				"T":
					nodes.trigger = _add(root, trigger_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
					nodes.trigger_x = x
				"H", "V", "F", "E":
					var fast := ch in "FE"
					var end := _find_end(map, p, ch.to_lower(), ch in "HF")
					var mover = _add(root, platform_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), at)
					mover.travel = Vector2((end - p) * TILE)
					var tiles := (end - p).length()
					mover.seconds_one_way = maxf(1.0, roundi(tiles * 2) / 10.0) if fast else maxf(2.0, snappedf(tiles * 0.4, 0.5))
					if fast:
						mover.pause = 0.4
					mover.texture = load(SOURCES[def.fg][0])
				"K":
					var boss := Marker2D.new()
					boss.name = "BossSpawn"
					var label := Label.new()
					label.name = "Label"
					label.text = "BOSS\n(placeholder)"
					label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					label.add_theme_font_size_override("font_size", 8)
					label.position = Vector2(-32, -32)
					label.size = Vector2(64, 24)
					_add(root, boss, at)
					_add(boss, label)

	for rect: Rect2i in def.get("camera_zones", []):
		_add_area(root, "CameraZone", "res://levels/shared/camera_zone.gd", rect)

	_paint(fg, solid, def.fg)

	# Player last so it draws in front of doors/levers.
	root.move_child(nodes.player, -1)
	if nodes.has("lever"):
		nodes.lever.gate = gates["G"]
	if nodes.has("boulder"): # roll until the ball touches the O gate
		nodes.boulder.gate = gates["O"]
		nodes.boulder.distance = gates["O"].position.x - TILE / 2.0 - nodes.boulder.position.x - nodes.boulder.RADIUS
	if nodes.has("trigger"):
		var gate_x: int = floori(gates["O"].position.x / TILE)
		nodes.trigger.gate = gates["O"]
		nodes.trigger.arena = Rect2(gate_x * TILE, 0, (map[0].length() - gate_x) * TILE, map.size() * TILE)

	# Package 3 owns entity placements; preserve the instance when regenerating level geometry.
	var entities_path := "res://levels/level_%02d/level_%02d_entities.tscn" % [index + 1, index + 1]
	if ResourceLoader.exists(entities_path):
		var entities: Node = (load(entities_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		entities.name = "Entities"
		_add(root, entities)

	# Package 6 owns extras (gambling stations, roasts, side quests, secrets).
	var extras_path := "res://levels/level_%02d/level_%02d_extras.tscn" % [index + 1, index + 1]
	if ResourceLoader.exists(extras_path):
		var extras: Node = (load(extras_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		extras.name = "Extras"
		_add(root, extras)

	var scene := PackedScene.new()
	scene.pack(root)
	var path := "res://levels/level_%02d/level_%02d.tscn" % [index + 1, index + 1]
	if ResourceSaver.save(scene, path) != OK:
		push_error("failed to save " + path)
	print("built ", path)
	root.free()


## Scripted Area2D covering a rectangle of tiles (camera zones, pits).
func _add_area(root: Node, area_name: String, script: String, rect: Rect2i) -> void:
	var area := Area2D.new()
	area.name = area_name
	area.set_script(load(script))
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(rect.size * TILE)
	_add(root, area, Vector2(rect.position * TILE))
	_add(area, shape, Vector2(rect.size * TILE) / 2.0)


## Length of the horizontal run of identical cells starting at p.
func _run(map: Array, p: Vector2i) -> int:
	var run := 1
	while map[p.y][p.x + run] == map[p.y][p.x]:
		run += 1
	return run


## Nearest end marker on the same row, else on the same column (lasers, sliding blades).
func _pair_end(map: Array, from: Vector2i, marker: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	for x in map[from.y].length():
		if map[from.y][x] == marker and (best.x < 0 or absi(x - from.x) < absi(best.x - from.x)):
			best = Vector2i(x, from.y)
	if best.x >= 0:
		return best
	for y in map.size():
		if map[y][from.x] == marker and (best.x < 0 or absi(y - from.y) < absi(best.y - from.y)):
			best = Vector2i(from.x, y)
	if best.x < 0:
		push_error("no end marker '%s' for %s" % [marker, from])
		return from
	return best


## Find the lowercase end marker for a moving platform on the same row or column (either direction).
func _find_end(map: Array, from: Vector2i, marker: String, horizontal: bool) -> Vector2i:
	if horizontal and map[from.y].find(marker) != -1:
		return Vector2i(map[from.y].find(marker), from.y)
	for y in map.size():
		if not horizontal and map[y][from.x] == marker:
			return Vector2i(from.x, y)
	push_error("no end marker '%s' for platform at %s" % [marker, from])
	return from


func _add(parent: Node, node: Node, at := Vector2.ZERO) -> Node:
	parent.add_child(node, true) # readable unique names: Door, MovingPlatform2, ...
	node.owner = parent if parent.owner == null else parent.owner
	if node is Node2D:
		node.position = at
	return node
