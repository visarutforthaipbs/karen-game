class_name FireGrid
extends Node3D

## Signals
signal grid_updated()
signal fire_escaped_to_forest()
signal rice_yield_changed(new_yield_pct: float)
signal hotspot_count_changed(count: int)
signal bamboo_exploded(cell_coord: Vector2i, world_pos: Vector3, landing_coord: Vector2i)
signal ember_jumped(from_coord: Vector2i, landing_coord: Vector2i)
## A spark caught in the protected forest: douse it before it becomes an escape
signal spot_fire_started(coord: Vector2i)

enum CellType {
	VEGETATION,      # Unburned upland brush
	BAMBOO,          # Bamboo clump (explosive culms under steam pressure)
	FIREBREAK,       # Cleared mineral soil barrier (stops ground fire)
	BURNING,         # Active flame (heat = 100)
	SMOLDERING,      # Glowing embers / hot stumps (heat = 45, satellite detectable)
	ASH,             # Cooled mineral ash (heat = 10, safe, gives rice points)
	FOREST_BORDER    # Surrounding protected conservation forest
}

# Grid Dimensions
@export var grid_width: int = 40
@export var grid_height: int = 40
@export var cell_size: float = 1.5

# Simulation Parameters
@export var simulation_tick_rate: float = 0.5
@export var base_spread_chance: float = 0.07
@export var wind_direction: Vector2 = Vector2(0.707, -0.707).normalized()
@export var wind_speed_multiplier: float = 1.3
@export var slope_intensity: float = 1.5
@export var bamboo_ratio: float = 0.22
## Regional drought (PRD §8.2): multiplies every spread roll
@export var spread_multiplier: float = 1.0
## Fuel dryness over the afternoon (dryness_at_minute); MainController updates it
var fuel_dryness: float = 1.0

## Ticks a smoldering root collar stays hot before it cools to ash on its own.
## 480 ticks = 240 real s = 2h40m in-game, so anything that burns after ~17:15
## is still a satellite hotspot at 20:00 unless someone douses it.
@export var smolder_duration_ticks: int = 480

# Procedural hillside (set from the plot config before generate())
var terrain_style: int = PlotGenerator.TerrainStyle.GENTLE
var terrain_seed: int = 1
var border_depth: Dictionary = {"north": 2, "east": 2, "south": 2, "west": 2}

# Atmospheric Inversion flag
var is_inversion_active: bool = false

# Time spent burning before collapsing to smoldering embers
const BURN_DURATION_TICKS: int = 12
const SMOLDER_START_HEAT: float = 45.0
const SMOLDER_END_HEAT: float = 35.0

# Terrain geometry
const TERRAIN_BASE_Y: float = -4.0  # Every ground column extends down to this depth
const GROUND_TOP_OFFSET: float = 0.1 # Ground surface sits slightly above cell elevation

# Slope physics (PRD §4.2): fire pre-heats fuel uphill, up to 2.5x; downhill is
# suppressed to 0.4x. Factor = 1 + grade * gain, where grade = rise / run.
const SLOPE_GRADE_GAIN: float = 7.0
const MIN_SLOPE_FACTOR: float = 0.4
const MAX_SLOPE_FACTOR: float = 2.5

# Ember jumping (PRD §4.2): high wind throws embers across a 1-cell firebreak
const EMBER_JUMP_WIND: float = 1.5
const EMBER_JUMP_DISTANCE: float = 2.0

# Fire behaviour balance (checked with a headless strategy simulation):
# a plot takes roughly an hour to burn through, steered by wind, slope and
# torch lines, and sparks in the park are spot fires that can still be caught.
const BAMBOO_BURST_CHANCE: float = 0.3   # Not every culm bursts
const BORDER_CATCH_CHANCE: float = 0.5   # Green forest edge resists flying embers
const BORDER_SPREAD_FACTOR: float = 0.5  # ...and creeping ground fire
const BORDER_BURN_TICKS: int = 30        # Forest burns longer than brush
const ESCAPE_TICKS: int = 16             # 8 s real to douse a spot fire before it is an escape
const ESCAPE_SPREAD_CELLS: int = 6       # ...or once this many separate spots are alight

## Afternoon fuel dryness: dew-damp at 14:00, driest 15:30-17:00, evening dew
## and the inversion damp it again. Multiplies every spread and spark roll.
static func dryness_at_minute(minute: float) -> float:
	var keys = [[14 * 60, 0.35], [15 * 60, 0.7], [15 * 60 + 30, 0.95], [16 * 60 + 30, 1.0], [17 * 60 + 30, 0.85], [18 * 60 + 30, 0.55], [20 * 60, 0.4]]
	if minute <= keys[0][0]:
		return keys[0][1]
	for i in keys.size() - 1:
		if minute <= keys[i + 1][0]:
			return lerpf(keys[i][1], keys[i + 1][1], (minute - keys[i][0]) / float(keys[i + 1][0] - keys[i][0]))
	return keys[keys.size() - 1][1]

# Grid Data Structures
var cell_types: Array = []
var cell_heat: Array = []
var cell_timers: Array = []
var cell_was_bamboo: Array = []
var cell_elevation: Array = []
var max_elevation: float = 8.5

# Cells kept clear of props (e.g. the field hut yard)
var excluded_prop_cells: Dictionary = {}
# Mu-naw's Thermal Eye: cell index -> highlight expiry (seconds)
var highlight_until: Dictionary = {}

# Visual MultiMeshes for High-Fidelity Low-Poly Rendering
var ground_multimesh_instance: MultiMeshInstance3D
# Prop layers: one MultiMesh per mesh variant (pipeline assets can supply several per ID)
var pine_layers: Array[MultiMeshInstance3D] = []
var bamboo_layers: Array[MultiMeshInstance3D] = []
var brush_layers: Array[MultiMeshInstance3D] = []
var ember_bamboo_layers: Array[MultiMeshInstance3D] = []
var ember_brush_layers: Array[MultiMeshInstance3D] = []
var ash_bamboo_layers: Array[MultiMeshInstance3D] = []
var ash_brush_layers: Array[MultiMeshInstance3D] = []
var eye_marker_multimesh_instance: MultiMeshInstance3D
var mountain_pedestal: MeshInstance3D
var ground_material: StandardMaterial3D
var smoke_particles: CPUParticles3D
var flame_particles: CPUParticles3D

# Per-cell prop placement (random yaw / scale baked once per hillside)
var prop_transforms: Array[Transform3D] = []

var tick_accumulator: float = 0.0
var simulation_paused: bool = false
var has_escaped: bool = false
## Park cells alight right now (spot fires)
var burning_border_cells: int = 0
## Spot fires this burn, and how many were caught in time (playtest stats)
var spot_fires_started: int = 0
var spot_fires_doused: int = 0
var thermal_view: bool = false
## A moving satellite footprint (title screen / pass cinematic): cells inside it
## show thermal colours and lose their props, as if seen by the satellite.
## Rotated rectangle in world x/z: centre, half extents, heading (radians about Y).
var scan_active: bool = false
var scan_center: Vector2 = Vector2.ZERO
var scan_half: Vector2 = Vector2(8.0, 2.6)
var scan_heading: float = 0.0
var thermal_threshold: float = 35.0

# Stats
var total_cultivable_cells: int = 0
var cooled_ash_cells: int = 0
var active_hotspot_count: int = 0

# Rich Stylized Low-Poly Color Palette
const COLOR_TERRACE_GRASS = Color(0.28, 0.48, 0.22)    # Lush terrace grass
const COLOR_BAMBOO_FLOOR = Color(0.35, 0.50, 0.22)     # Leaf litter under bamboo
const COLOR_FIREBREAK_CLAY = Color(0.58, 0.38, 0.24)   # Exposed red mountain clay
const COLOR_FLAME_ORANGE = Color(1.0, 0.42, 0.05)      # Brilliant flame
const COLOR_EMBER_RED = Color(0.85, 0.15, 0.08)        # Glowing ruby embers
const COLOR_CHARCOAL_ASH = Color(0.14, 0.14, 0.15)     # Black mineral ash bed
const COLOR_FOREST_DEEP = Color(0.12, 0.24, 0.15)      # Deep national park border soil
const COLOR_THERMAL_EYE = Color(1.0, 0.35, 0.85)       # Mu-naw's highlighted embers

# Particle / Light Pool for Active Flames
var fire_lights: Array[OmniLight3D] = []
var active_burning_indices: Array[int] = []

func _ready() -> void:
	_setup_mountain_pedestal()
	_setup_terrain_multimesh()
	_setup_vegetation_multimeshes()
	_setup_particles()
	_setup_fire_lights()
	generate()

## Applies a plot's hillside shape, fuel and climate, then rebuilds the grid
func configure_plot(cfg: PlotGenerator.PlotConfig) -> void:
	slope_intensity = cfg.slope_intensity
	bamboo_ratio = cfg.bamboo_ratio
	terrain_style = cfg.terrain_style
	terrain_seed = cfg.terrain_seed
	border_depth = cfg.border_depth.duplicate()
	spread_multiplier = cfg.rules.spread_mult if cfg.rules else 1.0
	generate()

## Re-roll the hillside and cell contents with the current settings
func generate() -> void:
	excluded_prop_cells.clear()
	highlight_until.clear()
	_initialize_grid()
	_layout_terrain()
	_update_visuals()

## Kept for callers of the old API
func regenerate() -> void:
	generate()

func _initialize_grid() -> void:
	var total_cells = grid_width * grid_height
	cell_types.resize(total_cells)
	cell_heat.resize(total_cells)
	cell_timers.resize(total_cells)
	cell_elevation.resize(total_cells)
	cell_was_bamboo.resize(total_cells)

	total_cultivable_cells = 0
	cooled_ash_cells = 0
	active_hotspot_count = 0
	has_escaped = false

	_generate_elevation()

	var clump_noise = FastNoiseLite.new()
	clump_noise.seed = terrain_seed + 977
	clump_noise.frequency = 0.16

	for y in range(grid_height):
		for x in range(grid_width):
			var idx = _coord_to_index(x, y)
			cell_timers[idx] = 0
			cell_was_bamboo[idx] = false
			cell_heat[idx] = 0.0

			# Protected national park border (depth per side comes from the plot)
			if is_border_coord(x, y):
				cell_types[idx] = CellType.FOREST_BORDER
			else:
				# Bamboo grows in clumps: noise modulates the plot's density
				var clump = (clump_noise.get_noise_2d(x, y) + 1.0) * 0.5
				if randf() < bamboo_ratio * (0.3 + 1.4 * clump):
					cell_types[idx] = CellType.BAMBOO
					cell_was_bamboo[idx] = true
				else:
					cell_types[idx] = CellType.VEGETATION
				total_cultivable_cells += 1

## Hillside height field: rises northwards, shaped per plot style
func _generate_elevation() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.frequency = 0.07
	var rise = 4.0 + 2.5 * slope_intensity
	var cx = (grid_width - 1) * 0.5
	var min_e = INF

	for y in range(grid_height):
		for x in range(grid_width):
			var t = float(grid_height - 1 - y) / float(grid_height - 1) # 0 south .. 1 north
			var n = noise.get_noise_2d(x, y)
			var ridge = 1.0 - absf(x - cx) / cx
			var e = t * rise
			match terrain_style:
				PlotGenerator.TerrainStyle.GENTLE:
					e += n * 0.5
				PlotGenerator.TerrainStyle.GROVE:
					e += n * 0.8
				PlotGenerator.TerrainStyle.RIDGE:
					# A spine runs up the middle of the plot; flanks fall away
					e = t * rise * 0.85 + ridge * rise * 0.35 + n * 0.5
				PlotGenerator.TerrainStyle.PARK_EDGE:
					e += n * 0.6
				PlotGenerator.TerrainStyle.TERRACE:
					# Hand-cut terraces: flat benches with steep risers
					var steps = 10.0
					e = floorf(t * steps) / steps * rise + n * 0.2
				_:
					e = t * rise + ridge * rise * 0.25 + n * 0.9
			cell_elevation[_coord_to_index(x, y)] = e
			min_e = minf(min_e, e)

	max_elevation = 0.0
	for i in cell_elevation.size():
		cell_elevation[i] -= min_e
		max_elevation = maxf(max_elevation, cell_elevation[i])

## Bedrock Mountain Foundation Pedestal
func _setup_mountain_pedestal() -> void:
	mountain_pedestal = MeshInstance3D.new()
	var box = BoxMesh.new()
	var total_w = grid_width * cell_size + 16.0
	var total_d = grid_height * cell_size + 16.0
	box.size = Vector3(total_w, 18.0, total_d)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.21, 0.18) # Mountain bedrock brown
	mat.roughness = 0.95
	box.material = mat
	mountain_pedestal.mesh = box

	# Sits entirely below the terrain columns: its top face is the terrain base
	mountain_pedestal.position = Vector3(0, TERRAIN_BASE_Y - box.size.y * 0.5, 0)
	add_child(mountain_pedestal)

## Solid Continuous Terraced Ground MultiMesh
func _setup_terrain_multimesh() -> void:
	ground_multimesh_instance = MultiMeshInstance3D.new()
	add_child(ground_multimesh_instance)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = grid_width * grid_height

	# Unit-height columns, scaled per cell so each runs from the terrain base up to its surface
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(cell_size * 0.99, 1.0, cell_size * 0.99)

	ground_material = StandardMaterial3D.new()
	ground_material.vertex_color_use_as_albedo = true
	ground_material.roughness = 0.88
	box_mesh.material = ground_material
	mm.mesh = box_mesh

	ground_multimesh_instance.multimesh = mm

## Positions every ground column and bakes per-cell prop transforms for this hillside
func _layout_terrain() -> void:
	var mm = ground_multimesh_instance.multimesh
	var rng = RandomNumberGenerator.new()
	rng.seed = terrain_seed * 31 + 7
	prop_transforms.resize(grid_width * grid_height)

	for y in range(grid_height):
		for x in range(grid_width):
			var idx = _coord_to_index(x, y)
			var world_pos = get_cell_world_pos(x, y)

			var top = world_pos.y + GROUND_TOP_OFFSET
			var column_height = top - TERRAIN_BASE_Y
			var t = Transform3D(Basis().scaled(Vector3(1.0, column_height, 1.0)), Vector3(world_pos.x, TERRAIN_BASE_Y + column_height * 0.5, world_pos.z))
			mm.set_instance_transform(idx, t)

			# Organic variation: random yaw, size and a small offset inside the cell
			var yaw = rng.randf_range(0.0, TAU)
			var s = rng.randf_range(0.85, 1.15)
			var jitter = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
			prop_transforms[idx] = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(world_pos.x, top, world_pos.z) + jitter)

## 3D Low-Poly Vegetation: Pines, Bamboo Clumps, Mountain Brush, Burnt Stumps.
## Pipeline assets (assets/props, IDs from ASSETS.md) replace the procedural meshes when present.
func _setup_vegetation_multimeshes() -> void:
	pine_layers = _make_prop_layers(AssetLibrary.variants_or("E1", LowPoly.pine()))
	bamboo_layers = _make_prop_layers(AssetLibrary.variants_or("E2", LowPoly.bamboo_clump()))
	brush_layers = _make_prop_layers(AssetLibrary.variants_or("E3", LowPoly.brush()))
	
	# Glowing root collars (burning / smoldering) and charred, cooled stumps on the ash bed.
	# Bamboo cells use the charred culm stump (E4), brush cells the root collar (E5).
	var ember_mat = StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.25, 0.06, 0.03)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.28, 0.06)
	ember_mat.emission_energy_multiplier = 1.2
	var ash_mat = StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.09, 0.08, 0.08)
	ash_mat.roughness = 1.0
	var bamboo_stumps = AssetLibrary.variants_or("E4", LowPoly.stump())
	var brush_stumps = AssetLibrary.variants_or("E5", LowPoly.stump())
	ember_bamboo_layers = _make_prop_layers(bamboo_stumps, ember_mat)
	ember_brush_layers = _make_prop_layers(brush_stumps, ember_mat)
	ash_bamboo_layers = _make_prop_layers(bamboo_stumps, ash_mat)
	ash_brush_layers = _make_prop_layers(brush_stumps, ash_mat)
	
	# Thermal Eye markers: tall glowing pillars that read through smoke
	var pillar = BoxMesh.new()
	pillar.size = Vector3(0.18, 3.0, 0.18)
	eye_marker_multimesh_instance = _make_prop_layers([pillar])[0]
	var eye_mat = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(COLOR_THERMAL_EYE, 0.75)
	eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	eye_marker_multimesh_instance.material_override = eye_mat

func _make_prop_layers(meshes: Array, material: Material = null) -> Array[MultiMeshInstance3D]:
	var layers: Array[MultiMeshInstance3D] = []
	for mesh in meshes:
		var inst = MultiMeshInstance3D.new()
		add_child(inst)
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = grid_width * grid_height
		inst.multimesh = mm
		if material:
			inst.material_override = material
		layers.append(inst)
	return layers

## Shows the prop for cell i on one variant layer (stable per cell) and hides it on the rest
func _set_prop(layers: Array[MultiMeshInstance3D], i: int, xf: Transform3D, visible_here: bool, hidden: Transform3D) -> void:
	var pick = (i * 7919 + terrain_seed) % layers.size()
	for k in layers.size():
		layers[k].multimesh.set_instance_transform(i, xf if visible_here and k == pick else hidden)

## Soft round sprite shared by smoke, flames and sparks (no texture assets needed).
## Built as a mipmapped image so distant particles stay round instead of turning into squares.
static var _soft_sprite: ImageTexture

static func soft_sprite() -> ImageTexture:
	if not _soft_sprite:
		var size = 64
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c = (size - 1) * 0.5
		for y in size:
			for x in size:
				var d = Vector2(x - c, y - c).length() / c
				var a = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		img.generate_mipmaps()
		_soft_sprite = ImageTexture.create_from_image(img)
	return _soft_sprite

## Smoke plumes and flame tongues emitted from the burning cells
func _setup_particles() -> void:
	smoke_particles = CPUParticles3D.new()
	smoke_particles.amount = 320
	smoke_particles.lifetime = 7.0
	smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	smoke_particles.direction = Vector3.UP
	smoke_particles.spread = 25.0
	smoke_particles.initial_velocity_min = 0.6
	smoke_particles.initial_velocity_max = 1.4
	smoke_particles.damping_min = 0.1
	smoke_particles.damping_max = 0.3
	smoke_particles.scale_amount_min = 1.2
	smoke_particles.scale_amount_max = 2.4
	var grow = Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	smoke_particles.scale_amount_curve = grow
	var smoke_ramp = Gradient.new()
	smoke_ramp.set_color(0, Color(0.35, 0.33, 0.31, 0.0))
	smoke_ramp.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
	smoke_ramp.add_point(0.2, Color(0.32, 0.30, 0.29, 0.5))
	smoke_particles.color_ramp = smoke_ramp
	var smoke_quad = QuadMesh.new()
	smoke_quad.size = Vector2(1.6, 1.6)
	var smoke_mat = StandardMaterial3D.new()
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.vertex_color_use_as_albedo = true
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.albedo_texture = soft_sprite()
	smoke_quad.material = smoke_mat
	smoke_particles.mesh = smoke_quad
	smoke_particles.emitting = false
	add_child(smoke_particles)

	flame_particles = CPUParticles3D.new()
	flame_particles.amount = 180
	flame_particles.lifetime = 0.8
	flame_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	flame_particles.direction = Vector3.UP
	flame_particles.spread = 15.0
	flame_particles.gravity = Vector3(0, 1.5, 0)
	flame_particles.initial_velocity_min = 1.5
	flame_particles.initial_velocity_max = 3.0
	flame_particles.scale_amount_min = 0.35
	flame_particles.scale_amount_max = 0.8
	var shrink = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.2))
	flame_particles.scale_amount_curve = shrink
	var flame_ramp = Gradient.new()
	flame_ramp.set_color(0, Color(0.9, 0.62, 0.22, 0.55))
	flame_ramp.set_color(1, Color(0.5, 0.08, 0.03, 0.0))
	flame_ramp.add_point(0.4, Color(0.85, 0.32, 0.06, 0.45))
	flame_particles.color_ramp = flame_ramp
	var flame_quad = QuadMesh.new()
	flame_quad.size = Vector2(0.9, 1.2)
	var flame_mat = StandardMaterial3D.new()
	flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_texture = soft_sprite()
	flame_quad.material = flame_mat
	flame_particles.mesh = flame_quad
	flame_particles.emitting = false
	add_child(flame_particles)
	# Painted sprite sheets replace the soft dots when the asset pipeline ships
	# them (ASSET_REQUESTS_v1.2.md X1/X2): flames animate, smoke picks a puff
	apply_sprite_sheet(flame_mat, flame_particles, VFX_FLAME, 4, 4, true)
	apply_sprite_sheet(smoke_mat, smoke_particles, VFX_SMOKE, 2, 2, false)
	_apply_smoke_regime()

const VFX_FLAME = "res://assets/vfx/flame_sheet.png"   # 4x4 frames, greyscale + alpha (flame_ramp colours it)
const VFX_SMOKE = "res://assets/vfx/smoke_sheet.png"   # 2x2 puff variants, white + alpha (game tints)
const VFX_EMBER = "res://assets/vfx/ember.png"         # single spark, white-hot + alpha

## Swap a particle material's soft dot for a sprite sheet if the file exists
static func apply_sprite_sheet(mat: StandardMaterial3D, particles: CPUParticles3D, path: String, h: int, v: int, animated: bool) -> bool:
	if not ResourceLoader.exists(path):
		return false
	mat.albedo_texture = load(path)
	mat.particles_anim_h_frames = h
	mat.particles_anim_v_frames = v
	mat.particles_anim_loop = animated
	particles.anim_speed_min = 1.0 if animated else 0.0
	particles.anim_speed_max = 1.0 if animated else 0.0
	particles.anim_offset_min = 0.0
	particles.anim_offset_max = 1.0
	return true

## Day plumes rise and drift downwind; under the 18:00 inversion they pool at ground level
func _apply_smoke_regime() -> void:
	if not smoke_particles:
		return
	var drift = Vector3(wind_direction.x, 0.0, wind_direction.y) * wind_speed_multiplier * 0.5
	if is_inversion_active:
		smoke_particles.gravity = drift + Vector3(0, -0.03, 0)
		smoke_particles.initial_velocity_min = 0.2
		smoke_particles.initial_velocity_max = 0.5
		smoke_particles.spread = 80.0
		smoke_particles.lifetime = 11.0
		smoke_particles.color_ramp.set_color(1, Color(0.62, 0.5, 0.36, 0.0))
	else:
		smoke_particles.gravity = drift + Vector3(0, 0.35, 0)
		smoke_particles.initial_velocity_min = 0.6
		smoke_particles.initial_velocity_max = 1.4
		smoke_particles.spread = 25.0
		smoke_particles.lifetime = 7.0
		smoke_particles.color_ramp.set_color(1, Color(0.6, 0.58, 0.55, 0.0))

func _setup_fire_lights() -> void:
	# Pool of warm flickering OmniLights for active fire
	for i in range(8):
		var l = OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.15)
		l.light_energy = 1.1
		l.omni_range = 8.0
		l.visible = false
		add_child(l)
		fire_lights.append(l)

func _process(delta: float) -> void:
	if simulation_paused:
		return
	tick_accumulator += delta
	if tick_accumulator >= simulation_tick_rate:
		tick_accumulator -= simulation_tick_rate
		_simulation_step()
		_update_visuals()

	# Subtle warm fire flicker
	if not active_burning_indices.is_empty():
		for l in fire_lights:
			if l.visible:
				l.light_energy = randf_range(0.9, 1.3)

func set_wind(new_dir: Vector2, new_speed: float) -> void:
	wind_direction = new_dir.normalized()
	wind_speed_multiplier = new_speed
	_apply_smoke_regime()

func set_inversion_active(active: bool) -> void:
	is_inversion_active = active
	_apply_smoke_regime()

## Cellular Automata Simulation Step
func _simulation_step() -> void:
	var next_types = cell_types.duplicate()
	var next_heat = cell_heat.duplicate()
	var next_timers = cell_timers.duplicate()

	active_hotspot_count = 0
	cooled_ash_cells = 0
	active_burning_indices.clear()
	var border_alight = 0
	var spot_burned_long = false

	for y in range(grid_height):
		for x in range(grid_width):
			var idx = _coord_to_index(x, y)
			var type = cell_types[idx]

			match type:
				CellType.BURNING:
					active_hotspot_count += 1
					next_timers[idx] += 1
					next_heat[idx] = 100.0
					active_burning_indices.append(idx)

					_attempt_spread_to_neighbors(x, y, next_types, next_heat)
					_attempt_ember_jump(x, y, next_types, next_heat)

					if cell_was_bamboo[idx] and next_timers[idx] == 5 and randf() < BAMBOO_BURST_CHANCE * fuel_dryness:
						_trigger_bamboo_explosion(x, y, next_types, next_heat)

					if is_border_coord(x, y):
						border_alight += 1
						if next_timers[idx] >= ESCAPE_TICKS:
							spot_burned_long = true

					if next_timers[idx] >= _burn_duration(x, y):
						next_types[idx] = CellType.SMOLDERING
						next_timers[idx] = 0
						next_heat[idx] = SMOLDER_START_HEAT

				CellType.SMOLDERING:
					active_hotspot_count += 1
					next_timers[idx] += 1
					# Stays above the 35-unit VIIRS threshold until it fully cools
					var cool_frac = float(next_timers[idx]) / float(smolder_duration_ticks)
					next_heat[idx] = lerp(SMOLDER_START_HEAT, SMOLDER_END_HEAT, min(cool_frac, 1.0))

					if next_timers[idx] >= smolder_duration_ticks:
						next_types[idx] = CellType.ASH
						next_heat[idx] = 10.0

				CellType.ASH:
					# Burnt conservation forest is not farmland
					if not is_border_coord(x, y):
						cooled_ash_cells += 1
					next_heat[idx] = 10.0

	cell_types = next_types
	cell_heat = next_heat
	cell_timers = next_timers

	# A spot fire left burning, or spreading through the park, is an escape
	burning_border_cells = border_alight
	if spot_burned_long or border_alight >= ESCAPE_SPREAD_CELLS:
		_notify_escape()

	if total_cultivable_cells > 0:
		var current_yield = (float(cooled_ash_cells) / float(total_cultivable_cells)) * 100.0
		rice_yield_changed.emit(current_yield)

	hotspot_count_changed.emit(active_hotspot_count)
	grid_updated.emit()

func _trigger_bamboo_explosion(from_x: int, from_y: int, next_types: Array, next_heat: Array) -> void:
	var spark_dist = randi_range(2, 4)
	var jitter_angle = randf_range(-0.35, 0.35)
	var spark_vector = wind_direction.rotated(jitter_angle) * float(spark_dist)

	var landing_x = int(round(from_x + spark_vector.x))
	var landing_y = int(round(from_y + spark_vector.y))

	var source_world_pos = get_cell_world_pos(from_x, from_y)
	bamboo_exploded.emit(Vector2i(from_x, from_y), source_world_pos, Vector2i(landing_x, landing_y))
	_spawn_spark_burst(source_world_pos, spark_vector)

	_ignite_landing(landing_x, landing_y, next_types, next_heat)

## High valley wind lifts embers over a 1-cell firebreak
func _attempt_ember_jump(from_x: int, from_y: int, next_types: Array, next_heat: Array) -> void:
	if wind_speed_multiplier <= EMBER_JUMP_WIND:
		return
	if is_border_coord(from_x, from_y) and cell_timers[_coord_to_index(from_x, from_y)] < ESCAPE_TICKS:
		return
	var chance = clampf((wind_speed_multiplier - EMBER_JUMP_WIND) * 0.25, 0.0, 0.12) * spread_multiplier * fuel_dryness
	if randf() >= chance:
		return
	var jump = wind_direction.rotated(randf_range(-0.4, 0.4)) * EMBER_JUMP_DISTANCE
	var landing = Vector2i(int(round(from_x + jump.x)), int(round(from_y + jump.y)))
	if _ignite_landing(landing.x, landing.y, next_types, next_heat):
		ember_jumped.emit(Vector2i(from_x, from_y), landing)

## Ignites an airborne spark's landing cell; returns true if it caught
func _ignite_landing(landing_x: int, landing_y: int, next_types: Array, next_heat: Array) -> bool:
	if not is_valid_coord(landing_x, landing_y):
		return false
	var target_idx = _coord_to_index(landing_x, landing_y)
	var target_type = cell_types[target_idx]

	if target_type == CellType.VEGETATION or target_type == CellType.BAMBOO:
		next_types[target_idx] = CellType.BURNING
		next_heat[target_idx] = 100.0
		return true
	elif target_type == CellType.FOREST_BORDER and randf() < BORDER_CATCH_CHANCE:
		_ignite_border(target_idx, next_types, next_heat)
		return true
	return false

## A forest cell catches: a spot fire the crew can still put out
func _ignite_border(idx: int, next_types: Array, next_heat: Array) -> void:
	next_types[idx] = CellType.BURNING
	next_heat[idx] = 100.0
	if burning_border_cells == 0 and not has_escaped:
		burning_border_cells = 1
		spot_fires_started += 1
		spot_fire_started.emit(_index_to_coord(idx))

func _burn_duration(x: int, y: int) -> int:
	return BORDER_BURN_TICKS if is_border_coord(x, y) else BURN_DURATION_TICKS

func _attempt_spread_to_neighbors(from_x: int, from_y: int, next_types: Array, next_heat: Array) -> void:
	var from_idx = _coord_to_index(from_x, from_y)
	# A spark in the park smoulders before it takes off: it only spreads once established
	if is_border_coord(from_x, from_y) and cell_timers[from_idx] < ESCAPE_TICKS:
		return
	var from_elev = cell_elevation[from_idx]

	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue

			var nx = from_x + dx
			var ny = from_y + dy

			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue

			var n_idx = _coord_to_index(nx, ny)
			var n_type = cell_types[n_idx]

			if n_type != CellType.VEGETATION and n_type != CellType.BAMBOO and n_type != CellType.FOREST_BORDER:
				continue

			var spread_dir = Vector2(dx, dy).normalized()
			var is_orthogonal = (dx == 0 or dy == 0)
			var run = cell_size * (1.0 if is_orthogonal else 1.4142)
			var grade = (cell_elevation[n_idx] - from_elev) / run
			var slope_factor = clampf(1.0 + grade * SLOPE_GRADE_GAIN, MIN_SLOPE_FACTOR, MAX_SLOPE_FACTOR)

			var wind_alignment = spread_dir.dot(wind_direction)
			var wind_factor = max(0.2, 1.0 + (wind_alignment * wind_speed_multiplier))
			var dist_factor = 1.0 if is_orthogonal else 0.707

			var final_chance = base_spread_chance * slope_factor * wind_factor * dist_factor * spread_multiplier * fuel_dryness
			if n_type == CellType.FOREST_BORDER:
				final_chance *= BORDER_SPREAD_FACTOR

			if randf() < final_chance:
				if n_type == CellType.FOREST_BORDER:
					_ignite_border(n_idx, next_types, next_heat)
				else:
					next_types[n_idx] = CellType.BURNING
					next_heat[n_idx] = 100.0

## The escape penalty applies once per burn, not once per forest cell that catches.
## It fires when a spot fire burns too long or spreads, not on the first spark.
func _notify_escape() -> void:
	if has_escaped:
		return
	has_escaped = true
	fire_escaped_to_forest.emit()

## One-shot shower of sparks from an exploding bamboo culm
func _spawn_spark_burst(world_pos: Vector3, direction_2d: Vector2) -> void:
	if thermal_view:
		return
	var burst = CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 40
	burst.lifetime = 1.2
	burst.direction = Vector3(direction_2d.x, 1.6, direction_2d.y).normalized()
	burst.spread = 35.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 8.0
	burst.gravity = Vector3(0, -6.0, 0)
	burst.scale_amount_min = 0.08
	burst.scale_amount_max = 0.16
	var quad = QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat = StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.7, 0.25)
	mat.albedo_texture = load(VFX_EMBER) if ResourceLoader.exists(VFX_EMBER) else soft_sprite()
	quad.material = mat
	burst.mesh = quad
	add_child(burst)
	burst.global_position = world_pos + Vector3(0, 1.5, 0)
	burst.emitting = true
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)

## Update Colors and 3D Props per Cell
func _update_visuals() -> void:
	if not ground_multimesh_instance or not ground_multimesh_instance.multimesh or prop_transforms.size() != cell_types.size():
		return

	var mm_ground = ground_multimesh_instance.multimesh
	var mm_eye = eye_marker_multimesh_instance.multimesh

	var zero_transform = Transform3D().scaled(Vector3.ZERO)
	var now = Time.get_ticks_msec() / 1000.0
	var show_props = not thermal_view

	for i in range(cell_types.size()):
		var type = cell_types[i]
		var prop_xf: Transform3D = prop_transforms[i]
		var excluded = excluded_prop_cells.has(i)
		var highlighted = type == CellType.SMOLDERING and highlight_until.get(i, 0.0) > now

		# Ground Color
		var g_color = COLOR_TERRACE_GRASS
		var scanned = scan_active and in_scan(prop_xf.origin.x, prop_xf.origin.z)
		if thermal_view or scanned:
			g_color = _thermal_color(cell_heat[i], cell_elevation[i])
			if scanned and not thermal_view:
				# Lit by the scene's sun, so push the false colour to glow
				g_color = Color(g_color.r * 1.8, g_color.g * 1.8, g_color.b * 1.8)
		else:
			match type:
				CellType.VEGETATION:
					g_color = COLOR_TERRACE_GRASS
				CellType.BAMBOO:
					g_color = COLOR_BAMBOO_FLOOR
				CellType.FIREBREAK:
					g_color = COLOR_FIREBREAK_CLAY
				CellType.BURNING:
					g_color = COLOR_FLAME_ORANGE
				CellType.SMOLDERING:
					g_color = COLOR_THERMAL_EYE if highlighted else COLOR_EMBER_RED
				CellType.ASH:
					g_color = COLOR_CHARCOAL_ASH
				CellType.FOREST_BORDER:
					g_color = COLOR_FOREST_DEEP
		mm_ground.set_instance_color(i, g_color)

		# 3D Vegetation Props
		var visible_props = show_props and not excluded and not scanned
		_set_prop(pine_layers, i, prop_xf, visible_props and type == CellType.FOREST_BORDER, zero_transform)
		_set_prop(bamboo_layers, i, prop_xf, visible_props and type == CellType.BAMBOO, zero_transform)
		_set_prop(brush_layers, i, prop_xf, visible_props and type == CellType.VEGETATION, zero_transform)
		var glowing = visible_props and (type == CellType.BURNING or type == CellType.SMOLDERING)
		var ashen = visible_props and type == CellType.ASH
		var was_bamboo: bool = cell_was_bamboo[i]
		_set_prop(ember_bamboo_layers, i, prop_xf, glowing and was_bamboo, zero_transform)
		_set_prop(ember_brush_layers, i, prop_xf, glowing and not was_bamboo, zero_transform)
		_set_prop(ash_bamboo_layers, i, prop_xf, ashen and was_bamboo, zero_transform)
		_set_prop(ash_brush_layers, i, prop_xf, ashen and not was_bamboo, zero_transform)
		var eye_xf = Transform3D(Basis(), prop_xf.origin + Vector3(0, 1.5, 0))
		mm_eye.set_instance_transform(i, eye_xf if visible_props and highlighted else zero_transform)

	_update_fire_effects()

## Is a world point inside the satellite footprint?
func in_scan(x: float, z: float) -> bool:
	var local = Vector2(x - scan_center.x, z - scan_center.y).rotated(scan_heading)
	return absf(local.x) <= scan_half.x and absf(local.y) <= scan_half.y

## Fire lights and particle emitters follow the current burning / smoldering cells
func _update_fire_effects() -> void:
	var show_fx = not thermal_view
	var burning_points = PackedVector3Array()
	var smoke_points = PackedVector3Array()
	for i in range(cell_types.size()):
		var type = cell_types[i]
		if type == CellType.BURNING or type == CellType.SMOLDERING:
			var p = prop_transforms[i].origin
			smoke_points.append(to_local(p) + Vector3(0, 0.6, 0))
			if type == CellType.BURNING:
				burning_points.append(to_local(p) + Vector3(0, 0.3, 0))

	if smoke_particles:
		smoke_particles.emitting = show_fx and not smoke_points.is_empty()
		smoke_particles.visible = show_fx
		if not smoke_points.is_empty():
			smoke_particles.emission_points = smoke_points
	if flame_particles:
		flame_particles.emitting = show_fx and not burning_points.is_empty()
		flame_particles.visible = show_fx
		if not burning_points.is_empty():
			flame_particles.emission_points = burning_points

	# Position Fire Lights over active flames
	for j in range(fire_lights.size()):
		if show_fx and j < active_burning_indices.size():
			var b_coord = _index_to_coord(active_burning_indices[j])
			fire_lights[j].global_position = get_cell_world_pos(b_coord.x, b_coord.y) + Vector3(0, 2.5, 0)
			fire_lights[j].visible = true
		else:
			fire_lights[j].visible = false

## False-colour infrared palette (PRD §9.1): cold navy -> violet -> orange -> white-hot
func _thermal_color(heat: float, elevation: float) -> Color:
	if heat >= thermal_threshold:
		return Color(1.0, 0.85, 0.2).lerp(Color.WHITE, clampf((heat - thermal_threshold) / 60.0, 0.0, 1.0))
	if heat > 12.0:
		return Color(0.45, 0.05, 0.45).lerp(Color(0.95, 0.35, 0.1), clampf((heat - 12.0) / maxf(thermal_threshold - 12.0, 1.0), 0.0, 1.0))
	var shade = clampf(elevation / maxf(max_elevation, 1.0), 0.0, 1.0) * 0.08
	return Color(0.04 + shade, 0.06 + shade, 0.22 + shade * 2.0)

## Satellite overpass view: false-colour heat map, no props or particles
func set_thermal_view(enabled: bool, threshold: float = 35.0) -> void:
	thermal_view = enabled
	thermal_threshold = threshold
	if ground_material:
		ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if enabled else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_update_visuals()

## Mu-naw's Thermal Eye: make these smoldering cells glow through smoke for a while
func highlight_cells(coords: Array, duration: float) -> void:
	var until = Time.get_ticks_msec() / 1000.0 + duration
	for c in coords:
		highlight_until[_coord_to_index(c.x, c.y)] = until
	_update_visuals()

## Keeps a patch of cells bare and free of props (e.g. the field hut yard)
func reserve_clearing(coords: Array) -> void:
	for c in coords:
		if not is_valid_coord(c.x, c.y):
			continue
		var idx = _coord_to_index(c.x, c.y)
		excluded_prop_cells[idx] = true
		cell_types[idx] = CellType.FIREBREAK
		cell_heat[idx] = 0.0
	_update_visuals()

func get_hotspot_cells(threshold: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(cell_heat.size()):
		if cell_heat[i] >= threshold:
			cells.append(_index_to_coord(i))
	return cells

func count_cells_of_type(type: int) -> int:
	return cell_types.count(type)

func get_smoke_density_at_pos(pos: Vector3) -> float:
	var coord = get_cell_coord_at_world_pos(pos)
	if not is_valid_coord(coord.x, coord.y):
		return 0.0

	var density: float = 0.0
	var check_radius = 3

	for dy in range(-check_radius, check_radius + 1):
		for dx in range(-check_radius, check_radius + 1):
			var nx = coord.x + dx
			var ny = coord.y + dy
			if is_valid_coord(nx, ny):
				var idx = _coord_to_index(nx, ny)
				var type = cell_types[idx]
				if type == CellType.BURNING:
					density += 0.35
				elif type == CellType.SMOLDERING:
					density += 0.20

	if is_inversion_active:
		density *= 2.2

	return clamp(density, 0.0, 1.0)

func get_cell_coord_at_world_pos(world_pos: Vector3) -> Vector2i:
	var origin_x = - (grid_width * cell_size) * 0.5
	var origin_z = - (grid_height * cell_size) * 0.5
	# floori so positions just outside the low edge map to -1, not 0
	var gx = floori((world_pos.x - origin_x) / cell_size)
	var gz = floori((world_pos.z - origin_z) / cell_size)
	return Vector2i(gx, gz)

## Height of the walkable ground surface under a world position (clamped to the grid)
func get_ground_height_at_world_pos(world_pos: Vector3) -> float:
	var coord = get_cell_coord_at_world_pos(world_pos)
	coord.x = clampi(coord.x, 0, grid_width - 1)
	coord.y = clampi(coord.y, 0, grid_height - 1)
	return cell_elevation[_coord_to_index(coord.x, coord.y)] + GROUND_TOP_OFFSET

## Keeps a world position inside the hillside footprint
func clamp_to_grid(world_pos: Vector3, margin: float = 0.3) -> Vector3:
	var half_w = grid_width * cell_size * 0.5 - margin
	var half_d = grid_height * cell_size * 0.5 - margin
	return Vector3(clamp(world_pos.x, -half_w, half_w), world_pos.y, clamp(world_pos.z, -half_d, half_d))

## Ray-march against the terraced heightfield; returns the first cell the ray hits or (-1, -1)
func raycast_cell(ray_origin: Vector3, ray_dir: Vector3) -> Vector2i:
	var miss = Vector2i(-1, -1)
	if ray_dir.y >= -0.0001:
		return miss
	# Start where the ray crosses the highest possible ground, stop at the lowest
	var t = max(0.0, (max_elevation + GROUND_TOP_OFFSET - ray_origin.y) / ray_dir.y)
	var t_end = (0.0 - ray_origin.y) / ray_dir.y
	var step = cell_size * 0.1
	while t <= t_end + step:
		var p = ray_origin + ray_dir * t
		var coord = get_cell_coord_at_world_pos(p)
		if is_valid_coord(coord.x, coord.y) and p.y <= cell_elevation[_coord_to_index(coord.x, coord.y)] + GROUND_TOP_OFFSET:
			return coord
		t += step
	return miss

func get_cell_world_pos(gx: int, gy: int) -> Vector3:
	var idx = _coord_to_index(gx, gy)
	var origin_x = - (grid_width * cell_size) * 0.5
	var origin_z = - (grid_height * cell_size) * 0.5
	var wx = origin_x + (gx * cell_size) + (cell_size * 0.5)
	var wz = origin_z + (gy * cell_size) + (cell_size * 0.5)
	var wy = cell_elevation[idx]
	return Vector3(wx, wy, wz)

func is_valid_coord(gx: int, gy: int) -> bool:
	return gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height

func is_border_coord(gx: int, gy: int) -> bool:
	return gx < border_depth.west or gx >= grid_width - border_depth.east or gy < border_depth.north or gy >= grid_height - border_depth.south

func ignite_cell(gx: int, gy: int) -> bool:
	if not is_valid_coord(gx, gy): return false
	var idx = _coord_to_index(gx, gy)
	if cell_types[idx] == CellType.VEGETATION or cell_types[idx] == CellType.BAMBOO:
		cell_types[idx] = CellType.BURNING
		cell_heat[idx] = 100.0
		cell_timers[idx] = 0
		_update_visuals()
		return true
	return false

func clear_firebreak(gx: int, gy: int) -> bool:
	if not is_valid_coord(gx, gy): return false
	var idx = _coord_to_index(gx, gy)
	if cell_types[idx] == CellType.VEGETATION or cell_types[idx] == CellType.BAMBOO:
		cell_types[idx] = CellType.FIREBREAK
		cell_heat[idx] = 0.0
		_update_visuals()
		return true
	return false

## Spraying knocks open flame down to embers (or back to wet unburnt brush if it
## was only just lit, so light-then-douse can't farm free ash); spraying embers
## cools them to ash.
func douse_cell(gx: int, gy: int) -> bool:
	if not is_valid_coord(gx, gy): return false
	var idx = _coord_to_index(gx, gy)
	match cell_types[idx]:
		CellType.BURNING:
			var x = idx % grid_width
			var y = idx / grid_width
			if is_border_coord(x, y) and cell_timers[idx] < ESCAPE_TICKS:
				# Caught in time: the forest is only scorched
				spot_fires_doused += 1
				cell_types[idx] = CellType.FOREST_BORDER
				cell_heat[idx] = 0.0
			elif cell_timers[idx] * 2 < _burn_duration(x, y):
				cell_types[idx] = CellType.BAMBOO if cell_was_bamboo[idx] else CellType.VEGETATION
				cell_heat[idx] = 0.0
			else:
				cell_types[idx] = CellType.SMOLDERING
				cell_heat[idx] = SMOLDER_START_HEAT
		CellType.SMOLDERING:
			cell_types[idx] = CellType.ASH
			cell_heat[idx] = 10.0
		_:
			return false
	cell_timers[idx] = 0
	highlight_until.erase(idx)
	_update_visuals()
	return true

func _coord_to_index(x: int, y: int) -> int:
	return y * grid_width + x

func _index_to_coord(idx: int) -> Vector2i:
	return Vector2i(idx % grid_width, idx / grid_width)
