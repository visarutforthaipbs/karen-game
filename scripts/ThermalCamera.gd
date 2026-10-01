class_name ThermalCamera
extends Node3D

## Ground thermal camera post on the National Park boundary (PRD §8.2, Year 3+).
## Watches a fixed radius; any burning or smoldering cell inside it trips the alarm.

signal heat_detected(camera: ThermalCamera, world_pos: Vector3)

@export var fire_grid: FireGrid
@export var detect_radius: float = 9.0
@export var rearm_seconds: float = 20.0

var active: bool = true
## Each post logs the burn once: after that it has its evidence
var tripped: bool = false
var _cooldown: float = 0.0
var _scan_timer: float = 0.0
var _blink: float = 0.0
var _lamp: OmniLight3D
var _lens_mat: StandardMaterial3D
var _ring: MeshInstance3D

func _ready() -> void:
	var pole = MeshInstance3D.new()
	var pole_mesh = CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 2.6
	pole_mesh.radial_segments = 6
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 1.3, 0)
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.57, 0.6)
	steel.metallic = 0.6
	pole_mesh.material = steel
	add_child(pole)

	var housing = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.35, 0.25, 0.5)
	box.material = steel
	# Pipeline asset V2 (housing only, base at its origin) sits on top of the procedural pole
	housing.mesh = AssetLibrary.mesh_or("V2", box)
	housing.position = Vector3(0, 2.7 if housing.mesh == box else 2.58, 0)
	add_child(housing)

	var lens = MeshInstance3D.new()
	var lens_mesh = SphereMesh.new()
	lens_mesh.radius = 0.09
	lens_mesh.height = 0.18
	_lens_mat = StandardMaterial3D.new()
	_lens_mat.albedo_color = Color(0.2, 0.0, 0.0)
	_lens_mat.emission_enabled = true
	_lens_mat.emission = Color(1.0, 0.1, 0.1)
	lens_mesh.material = _lens_mat
	lens.mesh = lens_mesh
	lens.position = Vector3(0, 2.7, 0.26)
	add_child(lens)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.15, 0.1)
	_lamp.omni_range = 4.0
	_lamp.light_energy = 0.0
	_lamp.position = Vector3(0, 2.9, 0)
	add_child(_lamp)

	# Faint red ring on the ground showing the watched radius
	_ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = detect_radius - 0.12
	torus.outer_radius = detect_radius
	torus.rings = 48
	torus.ring_segments = 4
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.2, 0.15, 0.35)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = ring_mat
	_ring.mesh = torus
	_ring.position = Vector3(0, 0.3, 0)
	add_child(_ring)

func set_active(on: bool) -> void:
	active = on
	set_process(on)
	_lamp.light_energy = 0.0

func _process(delta: float) -> void:
	_blink += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	# Slow standby blink; fast strobe right after a detection
	var rate = 8.0 if _cooldown > rearm_seconds - 3.0 else 1.0
	var on = fmod(_blink * rate, 1.0) < 0.2 or (tripped and _cooldown <= rearm_seconds - 3.0)
	_lamp.light_energy = 2.5 if on else 0.0
	_lens_mat.emission_energy_multiplier = 3.0 if on else 0.6

	_scan_timer += delta
	if _scan_timer < 1.0 or _cooldown > 0.0 or tripped or not fire_grid:
		return
	_scan_timer = 0.0
	var hot = find_heat_in_view()
	if hot != Vector3.INF:
		_cooldown = rearm_seconds
		tripped = true
		heat_detected.emit(self, hot)

## World position of a burning / smoldering cell inside the watched radius, or Vector3.INF
func find_heat_in_view() -> Vector3:
	var center = fire_grid.get_cell_coord_at_world_pos(global_position)
	var r = int(ceil(detect_radius / fire_grid.cell_size))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c = center + Vector2i(dx, dy)
			if not fire_grid.is_valid_coord(c.x, c.y):
				continue
			var t = fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)]
			if t != FireGrid.CellType.BURNING and t != FireGrid.CellType.SMOLDERING:
				continue
			var p = fire_grid.get_cell_world_pos(c.x, c.y)
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() <= detect_radius:
				return p
	return Vector3.INF
