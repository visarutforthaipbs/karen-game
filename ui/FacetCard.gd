class_name FacetCard
extends PanelContainer

## A panel drawn as a triangulated low-poly slab: jittered facets with a soft
## top-lit gradient, chamfered corners, an accent ridge and a hard drop shadow.

@export var base_color: Color = UITheme.PANEL:
	set(v):
		base_color = v
		_rebuild()
@export var accent: Color = UITheme.STRAW:
	set(v):
		accent = v
		queue_redraw()
@export var chamfer: float = 12.0
@export var facet_size: float = 64.0
@export var contrast: float = 0.045
@export var seed_value: int = 1
@export var padding: Vector4 = Vector4(16, 12, 16, 14) # left, top, right, bottom

var _polys: Array[PackedVector2Array] = []
var _colors: PackedColorArray = PackedColorArray()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var sb = StyleBoxEmpty.new()
	sb.content_margin_left = padding.x
	sb.content_margin_top = padding.y
	sb.content_margin_right = padding.z
	sb.content_margin_bottom = padding.w
	add_theme_stylebox_override("panel", sb)
	resized.connect(_rebuild)
	_rebuild()

func _outline(offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var w = size.x
	var h = size.y
	var c = minf(chamfer, minf(w, h) * 0.5)
	var pts = PackedVector2Array()
	for p in [Vector2(c, 0), Vector2(w - c, 0), Vector2(w, c), Vector2(w, h - c),
			Vector2(w - c, h), Vector2(c, h), Vector2(0, h - c), Vector2(0, c)]:
		pts.append(p + offset)
	return pts

func _axis(length: float) -> PackedFloat32Array:
	var n = maxi(1, roundi(length / facet_size))
	var a = PackedFloat32Array()
	for i in n + 1:
		a.append(length * float(i) / float(n))
	return a

## Jittered grid of facets over the whole rect; only the four corner cells are
## clipped to the chamfer, so there is no thin rim of odd-looking slivers.
func _rebuild() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var xs = _axis(size.x)
	var ys = _axis(size.y)
	var cols = xs.size()
	var rows = ys.size()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + int(size.x) * 31 + int(size.y)

	var pts = PackedVector2Array()
	for j in rows:
		for i in cols:
			var p = Vector2(xs[i], ys[j])
			if i > 0 and i < cols - 1 and j > 0 and j < rows - 1:
				p += Vector2(rng.randf_range(-0.2, 0.2) * (xs[1] - xs[0]), rng.randf_range(-0.2, 0.2) * (ys[1] - ys[0]))
			pts.append(p)

	var outline = _outline()
	_polys.clear()
	_colors = PackedColorArray()
	for j in rows - 1:
		for i in cols - 1:
			var a = j * cols + i
			var b = a + 1
			var d = a + cols
			var e = d + 1
			var corner = (i == 0 or i == cols - 2) and (j == 0 or j == rows - 2)
			var halves = [[a, b, e], [a, e, d]] if (i + j) % 2 == 0 else [[a, b, d], [b, e, d]]
			for t in halves:
				var tri = PackedVector2Array([pts[t[0]], pts[t[1]], pts[t[2]]])
				var centre = (tri[0] + tri[1] + tri[2]) / 3.0
				# Light from the upper left, plus a little per-facet noise
				var shade = 0.05 * (1.0 - centre.y / size.y) + 0.03 * (1.0 - centre.x / size.x) + rng.randf_range(-contrast, contrast)
				var col = base_color.lightened(shade) if shade >= 0.0 else base_color.darkened(-shade)
				col.a = base_color.a
				var pieces = Geometry2D.intersect_polygons(tri, outline) if corner else [tri]
				for piece in pieces:
					_polys.append(piece)
					_colors.append(col)
	queue_redraw()

func _draw() -> void:
	if _polys.is_empty():
		return
	draw_colored_polygon(_outline(Vector2(0, 5)), Color(0, 0, 0, 0.42))
	for k in _polys.size():
		draw_colored_polygon(_polys[k], _colors[k])
	var rim = _outline()
	rim.append(rim[0])
	draw_polyline(rim, Color(base_color.lightened(0.25), 0.55 * base_color.a + 0.2), 1.0, true)
	# Accent ridge along the top edge, with a facet notch on the left
	var c = minf(chamfer, size.y * 0.5)
	draw_line(Vector2(c, 1.0), Vector2(size.x - c, 1.0), accent, 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(c, 0), Vector2(c + 34, 0), Vector2(c + 28, 5), Vector2(c - 3, 5)]), accent)
