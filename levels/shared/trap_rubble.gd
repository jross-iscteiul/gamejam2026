extends Node2D
## A few rubble chunks that tumble alongside whoever they're a child of for a moment, then
## free themselves. Spawned on the player by level.gd when GameState.arrived_by_trap is set
## (the player just fell in through the L3 trap door): same look as the trap door's own rubble.

const RUBBLE := Color("30261f")
const LIFETIME := 1.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in 5:
		var seed := float(i) * 1.7
		var y := fposmod(_t * (90.0 + i * 14.0) + seed * 40.0, 60.0) - 40.0
		var x := sin(seed + _t * 2.0) * 10.0
		draw_rect(Rect2(x - 2.0, y, 4.0, 4.0), RUBBLE)
