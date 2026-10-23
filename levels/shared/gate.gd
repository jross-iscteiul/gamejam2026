class_name Gate
extends StaticBody2D
## 3-tile-tall piston barrier. Origin = centre of its top tile.
## Changing `closed` at runtime slides the piston out of / back into the wall above.

const SLIDE_TIME := 0.45
const HEIGHT := 96.0
const REGION := Rect2(96, 32, 32, 96) # piston column in 1_Industrial_Tileset_1B.png

@export var closed := true:
	set(value):
		closed = value
		if is_node_ready():
			_slide()

var amount := 1.0 # 0 = retracted into the wall, 1 = fully down


func _ready() -> void:
	_set_amount(1.0 if closed else 0.0)
	$CollisionShape2D.disabled = not closed


func _slide() -> void:
	if closed: # block straight away so nobody slips under a closing gate
		$CollisionShape2D.set_deferred("disabled", false)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN if closed else Tween.EASE_OUT) # accelerate into the slam
	tween.tween_method(_set_amount, amount, 1.0 if closed else 0.0, SLIDE_TIME)
	if not closed:
		tween.tween_callback($CollisionShape2D.set_deferred.bind("disabled", true))


## Show only the bottom `a` fraction of the piston, hanging from the top edge.
func _set_amount(a: float) -> void:
	amount = a
	var h := HEIGHT * a
	$Sprite2D.visible = h >= 1.0
	$Sprite2D.region_rect = Rect2(REGION.position.x, REGION.end.y - h, REGION.size.x, maxf(h, 1.0))
