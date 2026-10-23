extends CharacterBody2D
## Placeholder player: run, jump + double jump, dash, and press E (interact) near doors/levers.
## Pits call respawn(); checkpoints move respawn_point.
## Implements the team Player API (README): dash(direction), set_shield(active), boost_jump().

const SPEED := 160.0
const JUMP_VELOCITY := -480.0
const AIR_JUMPS := 1 # extra jumps allowed in the air (1 = double jump)
const AIR_JUMP_VELOCITY := -400.0 # weaker second jump: single ~3.8 tiles up, double ~6
const DASH_SPEED := 420.0
const DASH_TIME := 0.15 # seconds; ~2 tiles
const DASH_COOLDOWN := 0.35
const FPS := 10.0
# name -> [sheet, vframes, frame count]; every sheet is 3 frames wide.
const ANIMS := {
	"idle": [preload("res://assets/art/industrial_tileset/robot/idle.png"), 3, 9],
	"walk": [preload("res://assets/art/industrial_tileset/robot/walk.png"), 2, 6],
	"jump": [preload("res://assets/art/industrial_tileset/robot/jump.png"), 3, 8],
}

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing := 1.0
var air_jumps_left := AIR_JUMPS
var can_air_dash := true # one dash per airtime; refilled on landing
var dash_time_left := 0.0
var dash_cooldown := 0.0
var anim := ""
var respawn_point: Vector2
var shielded := false # no damage system yet; Package 3 / JARVIS will use this
var anim_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	respawn_point = global_position


func respawn() -> void:
	GameState.player_died.emit()
	global_position = respawn_point
	velocity = Vector2.ZERO
	dash_time_left = 0.0
	$Camera2D.reset_smoothing()
	GameState.player_respawned.emit()


## Player API: short horizontal burst. Only the x sign of direction is used.
func dash(direction: Vector2) -> void:
	if dash_cooldown > 0.0 or not (is_on_floor() or can_air_dash):
		return
	if direction.x:
		facing = signf(direction.x)
		sprite.flip_h = facing < 0
	dash_time_left = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	can_air_dash = is_on_floor()


## Player API: one extra air jump, kept until used (JARVIS sells this for tokens).
func boost_jump() -> void:
	air_jumps_left += 1


## Player API: placeholder until the damage system exists.
func set_shield(active: bool) -> void:
	shielded = active


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		air_jumps_left = maxi(air_jumps_left, AIR_JUMPS) # keeps an unused boost_jump()
		can_air_dash = true

	var dir := Input.get_axis("move_left", "move_right")
	if dir:
		facing = signf(dir)
		sprite.flip_h = facing < 0

	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("dash"): # keyboard shortcut; JARVIS will also call dash()
		dash(Vector2(facing, 0.0))

	if dash_time_left > 0.0: # straight horizontal burst, gravity paused
		dash_time_left -= delta
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		if not on_floor:
			velocity.y += gravity * delta
		if Input.is_action_just_pressed("jump"):
			if on_floor:
				velocity.y = JUMP_VELOCITY
			elif air_jumps_left > 0:
				air_jumps_left -= 1
				velocity.y = AIR_JUMP_VELOCITY
				anim = "" # restart the jump animation
		velocity.x = dir * SPEED
	move_and_slide()

	sprite.modulate = Color(1.8, 1.8, 1.8) if dash_time_left > 0.0 else Color.WHITE
	_animate("walk" if dash_time_left > 0.0 else "jump" if not is_on_floor() else "walk" if dir else "idle", delta)


func _animate(name: String, delta: float) -> void:
	if name != anim:
		anim = name
		anim_time = 0.0
		sprite.texture = ANIMS[name][0]
		sprite.vframes = ANIMS[name][1]
	anim_time += delta
	var count: int = ANIMS[name][2]
	var f := int(anim_time * FPS)
	sprite.frame = mini(f, count - 1) if name == "jump" else f % count
