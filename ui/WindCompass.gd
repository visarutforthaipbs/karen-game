class_name WindCompass
extends Control

## Octagonal compass whose arrow is drawn in screen space, so it points the
## way the wind actually blows across the isometric hillside.

var wind: Vector2 = Vector2.RIGHT
var strong: bool = false
## The burn camera; the arrow turns with it. Without one, the default isometric view.
var camera: Camera3D
var _last_yaw: float = 0.0

## Grid (+x east, +y south, world X/Z) to screen direction for the current camera.
## Default view looks down the world -X/-Z diagonal: right = (x - y), down = (x + y).
func grid_to_screen(v: Vector2) -> Vector2:
	if camera:
		var b = camera.global_basis
		var right = Vector2(b.x.x, b.x.z)
		var down = Vector2(b.z.x, b.z.z)
		if right.length() > 0.01 and down.length() > 0.01:
			return Vector2(v.dot(right.normalized()), v.dot(down.normalized())).normalized()
	return Vector2(v.x - v.y, v.x + v.y).normalized()

func _process(_delta: float) -> void:
	if camera:
		var yaw = camera.global_rotation.y
		if absf(angle_difference(yaw, _last_yaw)) > 0.002:
			_last_yaw = yaw
			queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(46, 46)

func set_wind(dir: Vector2, is_strong: bool) -> void:
	wind = dir
	strong = is_strong
	queue_redraw()

func _draw() -> void:
	var c = size * 0.5
	var r = minf(size.x, size.y) * 0.5 - 1.0
	var ring = PackedVector2Array()
	var inner = PackedVector2Array()
	for i in 8:
		var a = TAU * (i + 0.5) / 8.0
		ring.append(c + Vector2.from_angle(a) * r)
		inner.append(c + Vector2.from_angle(a) * (r - 4.0))
	draw_colored_polygon(ring, UITheme.PANEL_HI.lightened(0.1))
	draw_colored_polygon(inner, UITheme.INK)

	# North tick (straw) so the player can relate the arrow to the radio forecast
	var north = grid_to_screen(Vector2(0, -1))
	var tip = c + north * (r - 1.0)
	var side = north.orthogonal() * 3.5
	draw_colored_polygon(PackedVector2Array([tip, c + north * (r - 9.0) + side, c + north * (r - 9.0) - side]), UITheme.STRAW)

	if wind.length() < 0.01:
		return
	var d = grid_to_screen(wind)
	var n = d.orthogonal()
	var col = UITheme.EMBER if strong else UITheme.CREAM
	var head = c + d * (r - 6.0)
	var tail = c - d * (r - 9.0)
	var neck = c + d * (r * 0.2)
	# Two-tone arrow: lit and shaded halves
	draw_colored_polygon(PackedVector2Array([head, neck + n * 8.0, neck + n * 2.5, tail + n * 2.5, tail]), col.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([head, tail, tail - n * 2.5, neck - n * 2.5, neck - n * 8.0]), col.darkened(0.25))
