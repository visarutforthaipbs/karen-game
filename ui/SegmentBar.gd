class_name SegmentBar
extends Control

## Meter made of slanted low-poly segments, with optional threshold markers.

@export var segments: int = 20
@export var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
@export var max_value: float = 100.0
@export var fill_color: Color = UITheme.EMERALD:
	set(v):
		fill_color = v
		queue_redraw()
@export var empty_color: Color = Color(1, 1, 1, 0.09)
@export var slant: float = 4.0
@export var gap: float = 2.0
## Per-segment fill colours (overrides fill_color when set), e.g. the phase timeline
var segment_colors: PackedColorArray = PackedColorArray()
## [{"at": value, "color": Color}] tick marks above and below the bar
var markers: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(60, 12)

func set_markers(list: Array) -> void:
	markers = list
	queue_redraw()

func _draw() -> void:
	var n = maxi(1, segments)
	var w = (size.x - slant - gap * (n - 1)) / float(n)
	var h = size.y
	var filled = clampf(value / max_value, 0.0, 1.0) * n
	for i in n:
		var x = i * (w + gap)
		var quad = PackedVector2Array([
			Vector2(x + slant, 0), Vector2(x + slant + w, 0), Vector2(x + w, h), Vector2(x, h),
		])
		draw_colored_polygon(quad, empty_color)
		var amount = clampf(filled - i, 0.0, 1.0)
		if amount <= 0.0:
			continue
		var col = segment_colors[i] if i < segment_colors.size() else fill_color
		var fw = w * amount
		var part = PackedVector2Array([
			Vector2(x + slant, 0), Vector2(x + slant + fw, 0), Vector2(x + fw, h), Vector2(x, h),
		])
		draw_colored_polygon(part, col)
		# Lit upper facet
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + slant, 0), Vector2(x + slant + fw, 0), Vector2(x + slant * 0.5 + fw, h * 0.45), Vector2(x + slant * 0.5, h * 0.45),
		]), Color(1, 1, 1, 0.16))
	for m in markers:
		var mx = clampf(m.at / max_value, 0.0, 1.0) * (size.x - slant) + slant * 0.5
		var c: Color = m.color
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 4, -6), Vector2(mx + 4, -6), Vector2(mx, -1)]), c)
		draw_line(Vector2(mx, -1), Vector2(mx, h + 2), c, 2.0)
