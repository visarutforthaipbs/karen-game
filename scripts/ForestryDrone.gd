class_name ForestryDrone
extends Node3D

signal drone_spotted_target(world_pos: Vector3, is_flame: bool)
signal drone_patrol_started()
signal drone_patrol_ended()
## Battery-limited sweeps: over the plot for a while, then away to swap batteries
signal sweep_started(drone: ForestryDrone)
signal sweep_ended(drone: ForestryDrone)

const SWEEP_SECONDS: float = 45.0
const AWAY_SECONDS_MIN: float = 50.0
const AWAY_SECONDS_MAX: float = 70.0
## Over the plot right now (between battery swaps it is away and blind)
var on_station: bool = false
var _phase_left: float = 0.0
## One photo per sweep: the drone hovers, shoots, then finishes its pass
var _photo_taken: bool = false

@export var flight_altitude: float = 12.0
@export var patrol_speed: float = 7.0
@export var search_radius: float = 6.5
@export var fire_grid: FireGrid
@export var player: Node3D
## Everyone the camera can photograph (player + companions)
var crew: Array[Node3D] = []

## 0 = original diagonal sweep, 1 = mirrored sweep (second drone in Year 3+)
var route_variant: int = 0
var speed_multiplier: float = 1.0

var is_active_patrol: bool = false
var waypoints: Array[Vector3] = []
var current_waypoint_idx: int = 0

var detection_cooldown: float = 0.0
var is_hovering: bool = false
var hover_timer: float = 0.0

# Visuals
var searchlight_mesh: MeshInstance3D
var drone_body: MeshInstance3D
var _rotors: Array[MeshInstance3D] = []

func _ready() -> void:
	visible = false
	_build_drone_visuals()
	_generate_patrol_route()

## Fly high enough to clear this hillside, at this year's speed, on this route
func configure(altitude: float, speed_mult: float, variant: int) -> void:
	flight_altitude = altitude
	speed_multiplier = speed_mult
	route_variant = variant
	_generate_patrol_route()
	if searchlight_mesh:
		var cyl = searchlight_mesh.mesh as CylinderMesh
		cyl.height = flight_altitude
		searchlight_mesh.position = Vector3(0, -flight_altitude * 0.5, 0)

func _build_drone_visuals() -> void:
	# Quadcopter body (faceted dark olive/white box with rotor arms)
	drone_body = MeshInstance3D.new()
	var body_box = BoxMesh.new()
	body_box.size = Vector3(1.2, 0.25, 1.2)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.9, 0.9, 0.95) # High-tech cool white
	body_mat.metallic = 0.8
	body_box.material = body_mat
	# Pipeline asset V1 (body only, 1.2 m wide) replaces the box; rotor discs stay procedural
	drone_body.mesh = AssetLibrary.mesh_or("V1", body_box)
	var has_pipeline_body: bool = drone_body.mesh != body_box
	if has_pipeline_body:
		drone_body.position = Vector3(0, -0.15, 0)
	add_child(drone_body)

	# Four spinning rotor discs at the arm tips
	var rotor_mat = StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.15, 0.15, 0.18, 0.6)
	rotor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# V1's 1.2 m body has motor centers at +/-0.48 m. Keep discs attached
	# to those motors; the legacy box used wider, floating rotor positions.
	var rotor_span := 0.48 if has_pipeline_body else 0.8
	var rotor_height: float = drone_body.mesh.get_aabb().end.y + 0.015 if has_pipeline_body else 0.15
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var offset := Vector3(corner.x * rotor_span, rotor_height, corner.y * rotor_span)
		var rotor = MeshInstance3D.new()
		var disc = CylinderMesh.new()
		disc.top_radius = 0.30 if has_pipeline_body else 0.45
		disc.bottom_radius = disc.top_radius
		disc.height = 0.03
		disc.radial_segments = 3
		disc.material = rotor_mat
		rotor.mesh = disc
		rotor.position = offset
		drone_body.add_child(rotor)
		_rotors.append(rotor)

	# Quadcopter searchlight cone projecting onto ground (harsh cold white)
	searchlight_mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = search_radius
	cylinder.height = flight_altitude

	var light_mat = StandardMaterial3D.new()
	light_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.16)
	light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder.material = light_mat

	searchlight_mesh.mesh = cylinder
	searchlight_mesh.position = Vector3(0, -flight_altitude * 0.5, 0)
	add_child(searchlight_mesh)

func _generate_patrol_route() -> void:
	# Diagonal sweeps across the 60m x 60m hillside
	var route = [
		Vector2(-25, -25),
		Vector2(25, 15),
		Vector2(-15, 25),
		Vector2(25, -20),
		Vector2(0, 0),
	]
	waypoints.clear()
	for p in route:
		var q = p if route_variant == 0 else Vector2(-p.y, p.x) # rotated 90 degrees
		waypoints.append(Vector3(q.x, flight_altitude, q.y))

func start_patrol() -> void:
	is_active_patrol = true
	drone_patrol_started.emit()
	_begin_sweep()

func end_patrol() -> void:
	is_active_patrol = false
	on_station = false
	visible = false
	drone_patrol_ended.emit()

func _begin_sweep() -> void:
	on_station = true
	visible = true
	global_position = waypoints[0]
	current_waypoint_idx = 1
	_phase_left = SWEEP_SECONDS
	_photo_taken = false
	is_hovering = false
	sweep_started.emit(self)

func _leave_for_battery() -> void:
	on_station = false
	visible = false
	_phase_left = randf_range(AWAY_SECONDS_MIN, AWAY_SECONDS_MAX)
	sweep_ended.emit(self)

## 0..1 loudness of the rotor hum heard by the player
func get_hum_level(listener: Vector3) -> float:
	if not is_active_patrol or not on_station:
		return 0.0
	var d = Vector2(global_position.x - listener.x, global_position.z - listener.z).length()
	return clampf(1.0 - (d - search_radius) / 30.0, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if not is_active_patrol:
		return
	_phase_left -= delta
	if not on_station:
		if _phase_left <= 0.0:
			_begin_sweep()
		return
	if _phase_left <= 0.0 and not is_hovering:
		_leave_for_battery()
		return

	for r in _rotors:
		r.rotation.y += delta * 40.0

	if detection_cooldown > 0.0:
		detection_cooldown -= delta

	if is_hovering:
		hover_timer -= delta
		# Rotor tilt wobble
		drone_body.rotation.y += delta * 5.0
		if hover_timer <= 0.0:
			is_hovering = false
		return

	_move_along_patrol(delta)
	_scan_ground_area()

func _move_along_patrol(delta: float) -> void:
	if waypoints.is_empty(): return

	var target = waypoints[current_waypoint_idx]
	var dist = global_position.distance_to(target)

	if dist <= 2.0:
		current_waypoint_idx = (current_waypoint_idx + 1) % waypoints.size()
	else:
		var dir = (target - global_position).normalized()
		global_position += dir * patrol_speed * speed_multiplier * delta
		look_at(target, Vector3.UP)

func _scan_ground_area() -> void:
	if not fire_grid or detection_cooldown > 0.0 or _photo_taken:
		return

	var ground_pos = Vector3(global_position.x, 0.0, global_position.z)
	var drone_coord = fire_grid.get_cell_coord_at_world_pos(ground_pos)
	var cell_radius = int(ceil(search_radius / fire_grid.cell_size))

	# Check for open flames under search cone
	for dy in range(-cell_radius, cell_radius + 1):
		for dx in range(-cell_radius, cell_radius + 1):
			var nx = drone_coord.x + dx
			var ny = drone_coord.y + dy
			if fire_grid.is_valid_coord(nx, ny):
				var cell_pos = fire_grid.get_cell_world_pos(nx, ny)
				# Horizontal footprint of the search cone, regardless of hill height
				if ground_pos.distance_to(Vector3(cell_pos.x, 0.0, cell_pos.z)) <= search_radius:
					var idx = fire_grid._coord_to_index(nx, ny)
					if fire_grid.cell_types[idx] == FireGrid.CellType.BURNING:
						_trigger_spot(cell_pos, true)
						return

	# Check for uncamouflaged crew in open view
	var watched: Array[Node3D] = crew.duplicate()
	if watched.is_empty() and player:
		watched.append(player)
	for person in watched:
		var p_dist = ground_pos.distance_to(Vector3(person.global_position.x, 0, person.global_position.z))
		if p_dist > search_radius:
			continue
		var p_coord = fire_grid.get_cell_coord_at_world_pos(person.global_position)
		if fire_grid.is_valid_coord(p_coord.x, p_coord.y):
			var p_type = fire_grid.cell_types[fire_grid._coord_to_index(p_coord.x, p_coord.y)]
			# Under a bamboo grove or forest canopy, the crew is camouflaged; farmers
			# in a field are only evidence when caught beside open flames
			if p_type != FireGrid.CellType.BAMBOO and p_type != FireGrid.CellType.FOREST_BORDER and _flames_near(p_coord, 2):
				_trigger_spot(person.global_position, false)
				return

func _flames_near(c: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if fire_grid.is_valid_coord(c.x + dx, c.y + dy) and fire_grid.cell_types[fire_grid._coord_to_index(c.x + dx, c.y + dy)] == FireGrid.CellType.BURNING:
				return true
	return false

func _trigger_spot(spot_pos: Vector3, is_flame: bool) -> void:
	detection_cooldown = 12.0 # Don't spam alert
	_photo_taken = true
	is_hovering = true
	hover_timer = 3.5 # Drone hovers and snaps photos
	drone_spotted_target.emit(spot_pos, is_flame)
