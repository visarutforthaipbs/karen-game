extends Control
class_name ForestFireArrows

## Points at fire that has escaped into the national-park ring (reviewer request
## 0.3.6: "อยากรู้ว่าไฟลามเข้าป่าตรงไหน บางทีลามไกลไม่เห็น"). Off-screen fires get an
## edge arrow with the distance; fires already on screen get a pulsing ring.
## Shown even when the panels are hidden: it is a warning, not a panel.

const MAX_ARROWS := 3
const MIN_SEPARATION := deg_to_rad(40.0)   # one arrow per direction
const REFRESH := 0.2

var fire_grid: FireGrid
var camera: Camera3D
var player: Node3D
var targets: Array = []                    # [{world, screen, offscreen, angle, dist}]
var _refresh_left: float = 0.0
var _pulse: float = 0.0
var _font: Font
var _touch: Node = null
## HUD decides when the arrows may draw (not over pause / report / after the pass)
var is_shown: Callable = func() -> bool: return true
## HUD supplies the free field between its cards; the safe area is the fallback
var bounds_provider: Callable = Callable()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = UITheme.font("semibold")

func setup(grid: FireGrid, cam: Camera3D, who: Node3D) -> void:
	fire_grid = grid
	camera = cam
	player = who

func _process(delta: float) -> void:
	var allowed: bool = is_shown.call()
	if visible != allowed:
		visible = allowed
	if not allowed or fire_grid == null or camera == null or not is_instance_valid(camera):
		return
	_pulse = fmod(_pulse + delta * 1.4, 1.0)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_update_targets()
	queue_redraw()

## Burning cells in the park ring, nearest first, at most one per direction
func park_fire_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for idx in fire_grid.active_burning_indices:
		var c := Vector2i(idx % fire_grid.grid_width, idx / fire_grid.grid_width)
		if fire_grid.is_border_coord(c.x, c.y) and fire_grid.cell_types[idx] == FireGrid.CellType.BURNING:
			out.append(c)
	return out

func _bounds() -> Rect2:
	var safe := UITheme.safe_area_rect()
	var area := Rect2(safe.position + Vector2(64, 96), safe.size - Vector2(128, 216))
	if bounds_provider.is_valid():
		area = bounds_provider.call()
	# Phones: stay left of the right-hand action buttons
	if UITheme.is_mobile():
		if _touch == null or not is_instance_valid(_touch):
			var scene := get_tree().current_scene
			_touch = scene.find_child("TouchControls", true, false) if scene else null
		if _touch and _touch.has_method("get_stack_rect"):
			var stack: Rect2 = _touch.get_stack_rect()
			if stack.size.x > 0.0 and area.end.x > stack.position.x - 48.0:
				area.size.x = maxf(80.0, stack.position.x - 48.0 - area.position.x)
	return area

func _update_targets() -> void:
	targets.clear()
	var cells := park_fire_cells()
	if cells.is_empty():
		return
	var origin: Vector3 = player.global_position if player and is_instance_valid(player) else camera.global_position
	cells.sort_custom(func(a, b):
		return fire_grid.get_cell_world_pos(a.x, a.y).distance_squared_to(origin) < fire_grid.get_cell_world_pos(b.x, b.y).distance_squared_to(origin))
	var bounds := _bounds()
	var centre := bounds.get_center()
	for c in cells:
		var world := fire_grid.get_cell_world_pos(c.x, c.y) + Vector3.UP * 0.6
		var behind := camera.is_position_behind(world)
		var screen := camera.unproject_position(world)
		if behind:
			screen = centre - (screen - centre)
		var offscreen := behind or not bounds.has_point(screen)
		var angle := (screen - centre).angle()
		var clash := false
		for t in targets:
			if absf(angle_difference(angle, t.angle)) < MIN_SEPARATION:
				clash = true
				break
		if clash:
			continue
		targets.append({"world": world, "screen": screen, "offscreen": offscreen, "angle": angle,
			"dist": Vector2(world.x - origin.x, world.z - origin.z).length()})
		if targets.size() >= MAX_ARROWS:
			break

## Clamp a direction from the centre onto the bounds rectangle
func _edge_point(bounds: Rect2, angle: float) -> Vector2:
	var c := bounds.get_center()
	var d := Vector2.from_angle(angle)
	var half := bounds.size * 0.5
	var tx := INF if absf(d.x) < 0.0001 else half.x / absf(d.x)
	var ty := INF if absf(d.y) < 0.0001 else half.y / absf(d.y)
	return c + d * minf(tx, ty)

func _draw() -> void:
	if targets.is_empty():
		return
	var bounds := _bounds()
	var glow := 0.55 + 0.45 * sin(_pulse * TAU)
	var size_px := float(UITheme.fs(15))
	for t in targets:
		if not t.offscreen:
			var r := (14.0 + 16.0 * _pulse) * UITheme.text_scale()
			draw_arc(t.screen, r, 0.0, TAU, 32, Color(ForestFireColors.RING, 1.0 - _pulse), 3.0, true)
			draw_arc(t.screen, 10.0, 0.0, TAU, 24, Color(ForestFireColors.RING, 0.9), 2.0, true)
			continue
		var tip := _edge_point(bounds, t.angle)
		var dir := Vector2.from_angle(t.angle)
		var side := dir.orthogonal()
		var s := UITheme.text_scale()          # bigger on phones, like the text
		var length := 34.0 * s
		var arrow := PackedVector2Array([tip, tip - dir * length + side * 18.0 * s, tip - dir * (length * 0.62), tip - dir * length - side * 18.0 * s])
		draw_colored_polygon(arrow, Color(ForestFireColors.ARROW, 0.6 + 0.4 * glow))
		draw_polyline(arrow + PackedVector2Array([tip]), Color(1, 0.94, 0.82, 0.85), 2.0, true)
		var text := UITheme.keep_units(L10n.format("ไฟเข้าป่า %d ม.", roundi(t.dist)))
		var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px))
		var label_pos := tip - dir * (length + 14.0) - text_size * 0.5 + Vector2(0, text_size.y * 0.75)
		label_pos.x = clampf(label_pos.x, bounds.position.x - 40.0, bounds.end.x + 40.0 - text_size.x)
		draw_string_outline(_font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px), 6, Color(0, 0, 0, 0.85))
		draw_string(_font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size_px), Color(1, 0.9, 0.78))

class ForestFireColors:
	const ARROW := Color(0.95, 0.24, 0.1)
	const RING := Color(1.0, 0.32, 0.12)
