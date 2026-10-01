class_name SatelliteOverpass
extends Node

## 20:00 Suomi-NPP / NOAA-20 VIIRS overpass (PRD §3.1 Phase 5, §6.1).
## The detection is instantaneous at 20:00; the sweep animation then reveals it
## on a false-colour thermal view, dropping a marker on each logged hotspot.

signal sweep_completed(detected_hotspots: int, scrutiny_increase: int)

@export var fire_grid: FireGrid
@export var main_camera: Camera3D

var is_sweeping: bool = false
var sweep_progress: float = 0.0
var sweep_duration: float = 4.0 # Seconds for the satellite orbital line to cross the plot
var detected_hotspots: int = 0

## VIIRS detection threshold in thermal units; lowered to 25 from Year 3
var thermal_threshold: float = 35.0
var hotspot_penalty: int = 15

# Snapshot at 20:00: detected cells and their heat
var detected_cells: Array[Vector2i] = []
var detected_heat: Array[float] = []

var _scan_line: MeshInstance3D
var _markers_shown: int = 0
var _marker_mesh: Mesh

## A VIIRS pixel (~375 m) is wider than the whole plot, so the satellite logs a
## detection, not a count of embers: the base penalty for being seen, a little
## more for every extra hot cell (stronger signal), capped at twice the base.
static func scrutiny_for(hot_cells: int, penalty: int) -> int:
	if hot_cells <= 0:
		return 0
	return mini(penalty * 2, penalty + hot_cells - 1)

func trigger_orbital_pass() -> void:
	if is_sweeping: return
	is_sweeping = true
	sweep_progress = 0.0
	_markers_shown = 0

	detected_cells.clear()
	detected_heat.clear()
	if fire_grid:
		detected_cells = fire_grid.get_hotspot_cells(thermal_threshold)
		# Reveal order follows the scan line (north -> south)
		detected_cells.sort_custom(func(a, b): return a.y < b.y)
		for c in detected_cells:
			detected_heat.append(fire_grid.cell_heat[fire_grid._coord_to_index(c.x, c.y)])
		fire_grid.set_thermal_view(true, thermal_threshold)
		_build_scan_line()
	detected_hotspots = detected_cells.size()

	# Smoothly transition camera to high top-down orbital perspective
	if main_camera:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(main_camera, "global_position", Vector3(0, 70, 0.01), 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(main_camera, "rotation_degrees", Vector3(-90, 0, 0), 1.8)

func _build_scan_line() -> void:
	_scan_line = MeshInstance3D.new()
	var bar = BoxMesh.new()
	bar.size = Vector3(fire_grid.grid_width * fire_grid.cell_size + 6.0, 0.2, 0.35)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.75, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bar.material = mat
	_scan_line.mesh = bar
	fire_grid.add_child(_scan_line)

	var ring = TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.68
	ring.rings = 16
	ring.ring_segments = 4
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.1, 0.1)
	ring.material = ring_mat
	_marker_mesh = ring

func _process(delta: float) -> void:
	if not is_sweeping:
		return

	sweep_progress += delta / sweep_duration
	_advance_scan_line()

	if sweep_progress >= 1.0:
		is_sweeping = false
		if _scan_line:
			_scan_line.queue_free()
			_scan_line = null
		sweep_completed.emit(detected_hotspots, scrutiny_for(detected_hotspots, hotspot_penalty))

func _advance_scan_line() -> void:
	if not fire_grid or not _scan_line:
		return
	var half = fire_grid.grid_height * fire_grid.cell_size * 0.5
	var z = lerpf(-half - 2.0, half + 2.0, clampf(sweep_progress, 0.0, 1.0))
	_scan_line.position = Vector3(0, fire_grid.max_elevation + 1.5, z)

	# Drop a red anomaly ring on every hotspot the line has passed
	while _markers_shown < detected_cells.size():
		var c = detected_cells[_markers_shown]
		var p = fire_grid.get_cell_world_pos(c.x, c.y)
		if p.z > z:
			break
		var marker = MeshInstance3D.new()
		marker.mesh = _marker_mesh
		fire_grid.add_child(marker)
		marker.global_position = p + Vector3(0, 0.6, 0)
		_markers_shown += 1
		if AudioManager.instance and _markers_shown <= 12:
			AudioManager.instance.play_countdown_beep()
