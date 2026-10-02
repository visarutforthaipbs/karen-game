class_name RangerPatrol
extends Node3D

## Year 3+ forest ranger on foot (PRD_UPDATE_v1.1 P1-2, approved 2026-10-02).
## Walks a loop through the forest belt just outside the plot from 15:30 to
## 18:30, scanning the plot with a 70° x 12 m vision cone drawn on the ground.
## Sees open flames, and crew standing beside open flames (not under bamboo).
## Thick smoke between ranger and target blocks the view. Logs at most one
## sighting per lap; never enters the plot and never attacks.

signal spotted(world_pos: Vector3, is_flame: bool)
signal lap_completed()

const SPEED: float = 1.6            # m/s, an unhurried patrol walk
const OFFSET: float = 4.5           # Loop distance outside the plot edge
const VIEW_RANGE: float = 12.0
const VIEW_HALF_ANGLE: float = deg_to_rad(35.0)
const LOOK_INWARD: float = deg_to_rad(55.0) # Face partly toward the plot while walking
const SMOKE_BLOCK: float = 0.6
const RADIO_SECONDS: float = 3.0    # Stops to radio a sighting in

var fire_grid: FireGrid
var landscape: Landscape
var crew: Array[Node3D] = []
var direction: int = 1              # 1 = anticlockwise, -1 = clockwise
var slate: bool = false             # Second ranger wears the slate uniform
var start_fraction: float = 0.0     # Where on the loop this ranger starts (0..1)
var active: bool = false

var figure: Node3D
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _s: float = 0.0                 # Distance travelled along the loop
var _lap_logged: bool = false
var _radio_left: float = 0.0
var _scan_timer: float = 0.0
var _loop_len: float = 1.0
var _half: float = 34.5

func _ready() -> void:
	visible = false
	figure = RangerFigure.create(true, slate)
	add_child(figure)
	_build_cone()
	if fire_grid:
		_half = fire_grid.grid_width * fire_grid.cell_size * 0.5 + OFFSET
	_loop_len = _half * 8.0
	_s = start_fraction * _loop_len

func _build_cone() -> void:
	var verts = PackedVector3Array()
	var steps = 10
	for i in steps:
		var a0 = lerpf(-VIEW_HALF_ANGLE, VIEW_HALF_ANGLE, float(i) / steps)
		var a1 = lerpf(-VIEW_HALF_ANGLE, VIEW_HALF_ANGLE, float(i + 1) / steps)
		verts.append_array([Vector3.ZERO, Vector3(sin(a1), 0, cos(a1)) * VIEW_RANGE, Vector3(sin(a0), 0, cos(a0)) * VIEW_RANGE])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.albedo_color = Color(RangerFigure.REFLECTIVE, 0.13)
	# Drawn through the forest canopy: the player must always see where a ranger looks
	_cone_mat.no_depth_test = true
	_cone_mat.render_priority = 1
	mesh.surface_set_material(0, _cone_mat)
	_cone = MeshInstance3D.new()
	_cone.mesh = mesh
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cone)
	# Cold-white marker above the ranger, visible through the trees
	var marker = MeshInstance3D.new()
	var gem = PrismMesh.new()
	gem.size = Vector3(0.6, 0.7, 0.6)
	var mm = StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(RangerFigure.REFLECTIVE, 0.9)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.no_depth_test = true
	mm.render_priority = 2
	gem.material = mm
	marker.mesh = gem
	marker.rotation_degrees = Vector3(180, 0, 0) # Points down at the ranger
	marker.position = Vector3(0, 3.4, 0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)

func start() -> void:
	active = true
	visible = true
	_lap_logged = false
	_place(0.0)

func stop() -> void:
	active = false
	visible = false

## Point on the square loop around the plot for a distance along it
func loop_point(s: float) -> Vector2:
	var side = _half * 2.0
	s = fposmod(s, _loop_len)
	if s < side:
		return Vector2(-_half + s, _half)
	s -= side
	if s < side:
		return Vector2(_half, _half - s)
	s -= side
	if s < side:
		return Vector2(_half - s, -_half)
	s -= side
	return Vector2(-_half, -_half + s)

func _ground_y(x: float, z: float) -> float:
	if landscape:
		return landscape.surface_at(x, z)
	return fire_grid.get_ground_height_at_world_pos(Vector3(x, 0, z)) if fire_grid else 0.0

func _process(delta: float) -> void:
	if not active:
		return
	var moving = _radio_left <= 0.0
	if moving:
		var before = floori(_s / _loop_len)
		_s += SPEED * delta * direction
		if floori(_s / _loop_len) != before:
			_lap_logged = false
			lap_completed.emit()
	else:
		_radio_left -= delta
	_place(delta)
	if moving and AudioManager.instance:
		AudioManager.instance.step_at("ranger_%d" % get_instance_id(), global_position)
	var vel = Vector3.ZERO
	if moving:
		var ahead = loop_point(_s + direction)
		var here = loop_point(_s)
		var d = (ahead - here).normalized()
		vel = Vector3(d.x, 0, d.y) * SPEED
	RangerFigure.animate(figure, delta, vel)
	_scan_timer += delta
	if _scan_timer >= 0.25:
		_scan_timer = 0.0
		_scan()

func _place(_delta: float) -> void:
	var p = loop_point(_s)
	global_position = Vector3(p.x, _ground_y(p.x, p.y), p.y)
	var ahead = loop_point(_s + direction * 2.0)
	var walk = (ahead - p).normalized()
	var inward = (-p).normalized()
	# Look ahead along the path, turned toward the plot, with a slow scanning sweep
	var sweep = sin(Time.get_ticks_msec() / 1000.0 * 0.8) * deg_to_rad(20.0)
	var side = sign(walk.x * inward.y - walk.y * inward.x)
	# `side` is the sign of walk x inward: rotating by it turns the gaze toward the plot
	var look = walk.rotated(side * LOOK_INWARD + sweep)
	var yaw = atan2(look.x, look.y)
	figure.rotation.y = yaw
	_cone.rotation.y = yaw
	_cone.position.y = 0.08

## Facing direction on the ground (unit vector, x/z)
func facing() -> Vector2:
	return Vector2(sin(_cone.rotation.y), cos(_cone.rotation.y))

func can_see(target: Vector3) -> bool:
	var to = Vector2(target.x - global_position.x, target.z - global_position.z)
	var dist = to.length()
	if dist > VIEW_RANGE or dist < 0.1:
		return false
	if absf(facing().angle_to(to)) > VIEW_HALF_ANGLE:
		return false
	# Thick smoke halfway along the line of sight hides the target
	var mid = global_position.lerp(target, 0.6)
	return fire_grid.get_smoke_density_at_pos(mid) < SMOKE_BLOCK

func _scan() -> void:
	if not fire_grid or _lap_logged:
		return
	var c = fire_grid.get_cell_coord_at_world_pos(global_position)
	var r = int(ceil(VIEW_RANGE / fire_grid.cell_size))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q = c + Vector2i(dx, dy)
			if not fire_grid.is_valid_coord(q.x, q.y):
				continue
			if fire_grid.cell_types[fire_grid._coord_to_index(q.x, q.y)] != FireGrid.CellType.BURNING:
				continue
			var p = fire_grid.get_cell_world_pos(q.x, q.y)
			if can_see(p):
				_log(p, true)
				return
	for person in crew:
		if not is_instance_valid(person) or not can_see(person.global_position):
			continue
		var pc = fire_grid.get_cell_coord_at_world_pos(person.global_position)
		if not fire_grid.is_valid_coord(pc.x, pc.y):
			continue
		var t = fire_grid.cell_types[fire_grid._coord_to_index(pc.x, pc.y)]
		# Same cover rule as the drone: bamboo or forest canopy hides the crew
		if not FireGrid.is_cover(t) and _flames_near(pc, 2):
			_log(person.global_position, false)
			return

func _flames_near(c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if fire_grid.is_valid_coord(c.x + dx, c.y + dy) and fire_grid.cell_types[fire_grid._coord_to_index(c.x + dx, c.y + dy)] == FireGrid.CellType.BURNING:
				return true
	return false

func _log(pos: Vector3, is_flame: bool) -> void:
	_lap_logged = true
	_radio_left = RADIO_SECONDS
	RangerFigure.gesture(figure, "RadioTalk")
	spotted.emit(pos, is_flame)
