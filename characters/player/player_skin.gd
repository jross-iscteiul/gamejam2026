class_name PlayerSkin
extends Resource
## Art and gun placement for one selectable player character.

@export var display_name: String
@export var sprite_frames: SpriteFrames
## Sprite is drawn uncentered; this offset puts the feet on the player origin.
@export var sprite_offset: Vector2
@export var sprite_scale: float = 1.0
## Linear filtering for high-res art that gets scaled down.
@export var smooth_filter: bool = false
@export var body_size: Vector2 = Vector2(12, 30)

@export_group("Gun")
## Gun pivot relative to the feet, when facing right.
@export var shoulder: Vector2 = Vector2(0, -18)
## Leave empty when the gun is already part of the character art.
@export var gun_texture: Texture2D
## Gun sprite is drawn uncentered; this offset puts the grip on the pivot.
@export var gun_offset: Vector2
## Pushes the gun out along the aim direction so it orbits the body instead of spinning in place.
@export var gun_distance: float = 0.0
## Bullet spawn point relative to the gun grip, when aiming right.
@export var muzzle: Vector2 = Vector2(10, 0)
@export var bullet_texture: Texture2D
@export var bullet_scale: float = 1.0

@export_group("Sounds")
@export var jump_sound: AudioStream
@export var step_sound: AudioStream
## Frames of the run animation where a foot hits the ground.
@export var step_frames: PackedInt32Array
@export var shoot_sound: AudioStream
