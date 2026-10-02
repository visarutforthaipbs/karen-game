class_name SatelliteStreak
extends Control

## A cold-white satellite crossing the dusk sky with a fading trail: the
## state's eye passing overhead on the title screen.

const PERIOD: float = 14.0
var _t: float = 3.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t = fmod(_t + delta, PERIOD)
	queue_redraw()

func _point(u: float) -> Vector2:
	# Shallow arc from the upper left to the upper right
	return Vector2(lerpf(-0.05, 1.05, u) * size.x, (0.2 - 0.12 * sin(u * PI)) * size.y)

func _draw() -> void:
	var u = _t / (PERIOD * 0.6)
	if u > 1.1:
		return
	var head = _point(clampf(u, 0.0, 1.0))
	for i in 24:
		var a = _point(clampf(u - i * 0.006, 0.0, 1.0))
		var b = _point(clampf(u - (i + 1) * 0.006, 0.0, 1.0))
		draw_line(a, b, Color(0.85, 0.95, 1.0, 0.5 * (1.0 - i / 24.0)), 2.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(0, -4), head + Vector2(4, 0), head + Vector2(0, 4), head + Vector2(-4, 0)]), Color(0.9, 0.98, 1.0))
	# Soft scan halo
	draw_circle(head, 10.0, Color(UITheme.STATE, 0.12))
