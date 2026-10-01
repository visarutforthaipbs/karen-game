class_name HearthBackdrop
extends Control

## Night over the hamlet as flat-shaded polygons: banded dusk sky, stars,
## three faceted ridge lines and the hearth's ember glow along the bottom.

const SKY = [Color("0b1020"), Color("121a30"), Color("1d2240"), Color("3a2a3f"), Color("5c3a3a")]
const RIDGES = [Color("1c2438"), Color("141b2a"), Color("0d121c")]

var _time: float = 0.0
var _rng_seed: int = 4242

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_time += delta
	# The ember glow breathes slowly; no need to redraw every frame
	if Engine.get_process_frames() % 6 == 0:
		queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var rng = RandomNumberGenerator.new()
	rng.seed = _rng_seed

	# Flat dusk sky bands
	var bands = SKY.size()
	for i in bands:
		var y0 = h * 0.62 * float(i) / bands
		var y1 = h * 0.62 * float(i + 1) / bands + 1.0
		draw_rect(Rect2(0, y0, w, y1 - y0), SKY[i])
	if bands > 0:
		draw_rect(Rect2(0, h * 0.62, w, h * 0.38), SKY[bands - 1])

	# Stars: tiny diamonds
	for i in 70:
		var p = Vector2(rng.randf() * w, rng.randf() * h * 0.45)
		var r = rng.randf_range(0.8, 2.0)
		var a = 0.35 + 0.35 * sin(_time * rng.randf_range(0.5, 1.5) + i)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), Color(1, 0.95, 0.85, a))

	# Faceted ridges, back to front
	for layer in RIDGES.size():
		var base_y = h * (0.42 + 0.14 * layer)
		var amp = h * (0.16 - 0.035 * layer)
		var steps = 9 + layer * 3
		var pts: Array[Vector2] = []
		for s in steps + 1:
			var x = w * float(s) / steps
			var y = base_y - amp * (0.35 + 0.65 * absf(sin(s * 1.7 + layer * 2.3 + rng.randf() * 0.6)))
			pts.append(Vector2(x, y))
		var col: Color = RIDGES[layer]
		for s in steps:
			var a = pts[s]
			var b = pts[s + 1]
			var mid = Vector2((a.x + b.x) * 0.5, maxf(a.y, b.y) + amp * 0.4)
			# Lit and shaded halves of each mountain face
			draw_colored_polygon(PackedVector2Array([a, b, mid]), col.lightened(0.06 if a.y < b.y else 0.0))
			draw_colored_polygon(PackedVector2Array([a, mid, Vector2(mid.x, h), Vector2(a.x, h)]), col.darkened(0.08 * (s % 2)))
			draw_colored_polygon(PackedVector2Array([mid, b, Vector2(b.x, h), Vector2(mid.x, h)]), col.lightened(0.03 * ((s + 1) % 2)))

	# Hearth glow: stacked translucent ember triangles along the bottom
	var pulse = 0.5 + 0.5 * sin(_time * 1.3)
	for k in 3:
		var gh = h * (0.18 - 0.05 * k) * (0.9 + 0.1 * pulse)
		var col = Color(UITheme.EMBER, 0.06 + 0.03 * k)
		draw_colored_polygon(PackedVector2Array([Vector2(w * (0.18 + 0.08 * k), h), Vector2(w * 0.5, h - gh), Vector2(w * (0.82 - 0.08 * k), h)]), col)
