class_name Landscape
extends Node3D

## The mountain around the burn plot, so it reads as one field in a rotational
## farming landscape rather than a block in a void:
## - flat-shaded terrain that continues the plot's slope, then rises into
##   mountains to the north and falls to a valley to the south;
## - a mosaic of neighbouring swiddens at different stages (just burned,
##   slashed and drying, young to old fallow) inside evergreen and dry-season
##   deciduous forest, with the national park forest beyond the north edge;
## - instanced trees and bamboo, field huts, a ridge-top village and smoke
##   from neighbours' burns;
## - layered ridge silhouettes and valley mist, tinted from the live fog colour
##   so they follow the afternoon -> blue hour cycle.
## The 20:00 satellite view swaps all of it for cold dark ground.

const EXTENT: float = 1100.0        # Terrain half-size (m)
const PLOT_HALF: float = 30.0       # The burn plot is 60 x 60 m around the origin
const BLEND: float = 70.0           # Distance over which the plot edge eases into the mountain
const EDGE_DROP: float = 0.3        # Surrounding ground sits just under the plot's edge cells
const FARM_RADIUS: float = 300.0    # Swidden mosaic out to here, forest beyond

const C_BURNED = Color(0.17, 0.15, 0.14)
const C_SLASHED = Color(0.62, 0.50, 0.32)
const C_FALLOW_YOUNG = Color(0.76, 0.68, 0.42)
const C_FALLOW_MID = Color(0.50, 0.58, 0.30)
const C_FALLOW_OLD = Color(0.31, 0.48, 0.27)
const C_FOREST = Color(0.15, 0.31, 0.19)
const C_FOREST_DRY = Color(0.52, 0.43, 0.27)  # Dry-season deciduous dipterocarp
const C_PEAK = Color(0.20, 0.30, 0.28)
const C_THERMAL_COLD = Color(0.04, 0.06, 0.2)

enum Patch { BURNED, SLASHED, FALLOW_YOUNG, FALLOW_MID, FALLOW_OLD, FOREST, FOREST_DRY }

var fire_grid: FireGrid
var world_environment: WorldEnvironment
var seed_value: int = 1

var terrain: MeshInstance3D
var _thermal_mat: StandardMaterial3D
var _decor: Array[Node3D] = []      # Hidden in the thermal view
var _ridge_mats: Array[StandardMaterial3D] = []
var _mist_mats: Array[StandardMaterial3D] = []

var _relief: FastNoiseLite
var _detail: FastNoiseLite
var _patches: FastNoiseLite
var _dry: FastNoiseLite
var _slope: float = 0.1
var _plot_mid: float = 3.0
var _rng := RandomNumberGenerator.new()
# The built terrain grid, so props sit on the faceted surface rather than the smooth formula
var _xs: PackedFloat32Array
var _heights: PackedFloat32Array

func _ready() -> void:
	if fire_grid:
		seed_value = fire_grid.terrain_seed
		_slope = fire_grid.max_elevation / (PLOT_HALF * 2.0)
		_plot_mid = fire_grid.max_elevation * 0.5
		if fire_grid.mountain_pedestal:
			fire_grid.mountain_pedestal.visible = false
	_rng.seed = seed_value * 7907 + 13
	_make_noise()
	_build_terrain()
	_build_vegetation()
	_build_settlements()
	_build_smoke()
	_build_ridges()
	if GameSettings.landscape_detail != "low":
		_build_mist()
	_thermal_mat = StandardMaterial3D.new()
	_thermal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_thermal_mat.albedo_color = C_THERMAL_COLD
	_thermal_mat.disable_fog = true

func _make_noise() -> void:
	_relief = FastNoiseLite.new()
	_relief.seed = seed_value
	_relief.frequency = 0.0032
	_relief.fractal_octaves = 4
	_detail = FastNoiseLite.new()
	_detail.seed = seed_value + 1
	_detail.frequency = 0.02
	_patches = FastNoiseLite.new()
	_patches.seed = seed_value + 2
	_patches.noise_type = FastNoiseLite.TYPE_CELLULAR
	_patches.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_patches.frequency = 0.013   # Fields roughly 60-90 m across
	_patches.fractal_type = FastNoiseLite.FRACTAL_NONE
	_patches.domain_warp_enabled = true
	_patches.domain_warp_amplitude = 18.0
	_dry = FastNoiseLite.new()
	_dry.seed = seed_value + 3
	_dry.frequency = 0.006

# ---------------------------------------------------------------------------
# Height and land use
# ---------------------------------------------------------------------------

func _outside(x: float, z: float) -> float:
	var dx = maxf(absf(x) - PLOT_HALF, 0.0)
	var dz = maxf(absf(z) - PLOT_HALF, 0.0)
	return sqrt(dx * dx + dz * dz)

func _edge_height(x: float, z: float) -> float:
	if not fire_grid:
		return 0.0
	var p = Vector3(clampf(x, -PLOT_HALF + 0.2, PLOT_HALF - 0.2), 0.0, clampf(z, -PLOT_HALF + 0.2, PLOT_HALF - 0.2))
	return fire_grid.get_ground_height_at_world_pos(p) - EDGE_DROP

func height_at(x: float, z: float) -> float:
	var d = _outside(x, z)
	var north = -z
	var r = Vector2(x, z).length()
	# The plot's hillside keeps climbing north and falls away south into the valley
	var base = _plot_mid + north * _slope
	if north < -PLOT_HALF:
		var past = -north - PLOT_HALF
		base -= past * 0.32 * smoothstep(0.0, 220.0, past)
	if north > PLOT_HALF:
		base += smoothstep(80.0, 700.0, north) * 70.0
	var relief = _relief.get_noise_2d(x, z) * 0.5 + 0.5
	var mountains = pow(relief, 1.6) * 170.0 * smoothstep(70.0, 600.0, r)
	var hills = _detail.get_noise_2d(x, z) * 6.0 * smoothstep(0.0, 50.0, d)
	var natural = base + mountains + hills
	if d <= 0.0:
		return _edge_height(x, z)
	return lerpf(_edge_height(x, z), natural, smoothstep(0.0, BLEND, d))

## Irregular forest belt around the plot: the swidden reads as a clearing cut
## into the forest, and the plot's border pines merge into real woods
func _belt_width(x: float, z: float) -> float:
	return 16.0 + 18.0 * (_dry.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5)

func patch_at(x: float, z: float, steep: float) -> int:
	var r = Vector2(x, z).length()
	if _outside(x, z) < _belt_width(x, z):
		return Patch.FOREST_DRY if _dry.get_noise_2d(x, z) > 0.4 else Patch.FOREST
	var farm = 1.0 - smoothstep(FARM_RADIUS * 0.55, FARM_RADIUS, r)
	# The national park continues past the plot's protected north edge
	if z < -PLOT_HALF and z > -200.0 and absf(x) < 150.0:
		farm *= 0.1
	farm *= 1.0 - smoothstep(0.55, 1.0, steep) * 0.7
	var v = _patches.get_noise_2d(x, z) * 0.5 + 0.5
	if v < farm:
		var q = v / maxf(farm, 0.001)
		if q < 0.13: return Patch.BURNED
		if q < 0.3: return Patch.SLASHED
		if q < 0.52: return Patch.FALLOW_YOUNG
		if q < 0.76: return Patch.FALLOW_MID
		return Patch.FALLOW_OLD
	return Patch.FOREST_DRY if _dry.get_noise_2d(x, z) > 0.28 else Patch.FOREST

func _patch_color(p: int, h: float) -> Color:
	match p:
		Patch.BURNED: return C_BURNED
		Patch.SLASHED: return C_SLASHED
		Patch.FALLOW_YOUNG: return C_FALLOW_YOUNG
		Patch.FALLOW_MID: return C_FALLOW_MID
		Patch.FALLOW_OLD: return C_FALLOW_OLD
		Patch.FOREST_DRY: return C_FOREST_DRY
	return C_FOREST.lerp(C_PEAK, smoothstep(60.0, 180.0, h))

# ---------------------------------------------------------------------------
# Terrain mesh: a tensor grid that is fine next to the plot and coarse far out
# ---------------------------------------------------------------------------

func _axis() -> PackedFloat32Array:
	var half = PackedFloat32Array([PLOT_HALF])
	var x = PLOT_HALF
	var step = 3.0
	while x < EXTENT:
		x = minf(x + step, EXTENT)
		half.append(x)
		step = minf(step * 1.06, 40.0)
	var out = PackedFloat32Array()
	for i in range(half.size() - 1, -1, -1):
		out.append(-half[i])
	for v in half:
		out.append(v)
	return out

func _build_terrain() -> void:
	var xs = _axis()
	var n = xs.size()
	var heights = PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(xs[i], xs[j])
	_xs = xs
	_heights = heights

	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	for j in n - 1:
		for i in n - 1:
			var cx = (xs[i] + xs[i + 1]) * 0.5
			var cz = (xs[j] + xs[j + 1]) * 0.5
			if absf(cx) < PLOT_HALF and absf(cz) < PLOT_HALF:
				continue # Under the burn plot
			var a = Vector3(xs[i], heights[j * n + i], xs[j])
			var b = Vector3(xs[i + 1], heights[j * n + i + 1], xs[j])
			var c = Vector3(xs[i], heights[(j + 1) * n + i], xs[j + 1])
			var d = Vector3(xs[i + 1], heights[(j + 1) * n + i + 1], xs[j + 1])
			var tris = [[a, d, b], [a, c, d]] if (i + j) % 2 == 0 else [[a, c, b], [b, c, d]]
			for t in tris:
				# Godot's front faces wind clockwise seen from above: right-hand normal points down
				var cross = (t[1] - t[0]).cross(t[2] - t[0])
				if cross.y > 0.0:
					t = [t[0], t[2], t[1]]
					cross = -cross
				var nrm = -cross.normalized()
				var centre = (t[0] + t[1] + t[2]) / 3.0
				var col = _patch_color(patch_at(centre.x, centre.z, 1.0 - nrm.y), centre.y)
				var shade = _rng.randf_range(-0.045, 0.045)
				col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
				for v in t:
					verts.append(v)
					normals.append(nrm)
					colors.append(col)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # Colours above are authored in sRGB
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	terrain = MeshInstance3D.new()
	terrain.mesh = mesh
	add_child(terrain)

## Height of the built (faceted) terrain, using the same diagonal split as the mesh
func surface_at(x: float, z: float) -> float:
	if _xs.is_empty():
		return height_at(x, z)
	var n = _xs.size()
	var i = clampi(_xs.bsearch(x) - 1, 0, n - 2)
	var j = clampi(_xs.bsearch(z) - 1, 0, n - 2)
	var u = clampf((x - _xs[i]) / (_xs[i + 1] - _xs[i]), 0.0, 1.0)
	var v = clampf((z - _xs[j]) / (_xs[j + 1] - _xs[j]), 0.0, 1.0)
	var ha = _heights[j * n + i]
	var hb = _heights[j * n + i + 1]
	var hc = _heights[(j + 1) * n + i]
	var hd = _heights[(j + 1) * n + i + 1]
	if (i + j) % 2 == 0:
		# Split a-d: triangles (a, d, b) above the diagonal and (a, c, d) below
		return ha + (hb - ha) * u + (hd - hb) * v if u >= v else ha + (hc - ha) * v + (hd - hc) * u
	# Split b-c: triangles (a, c, b) and (b, c, d)
	return ha + (hb - ha) * u + (hc - ha) * v if u + v <= 1.0 else hd + (hc - hd) * (1.0 - u) + (hb - hd) * (1.0 - v)

# ---------------------------------------------------------------------------
# Trees, bamboo and scrub
# ---------------------------------------------------------------------------

# Lean versions of the plot props (20-40 triangles each): thousands are instanced
# across the mountain, so they trade detail for count while keeping the style.

static var _lean: Dictionary = {}

static func _cone(radius: float, height: float, segments: int, top: float = 0.0) -> CylinderMesh:
	var c = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = segments
	c.rings = 0
	c.cap_top = top > 0.0
	c.cap_bottom = false
	return c

static func _blob(radius: float, height: float, segments: int = 5, rings: int = 2) -> SphereMesh:
	var s = SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = segments
	s.rings = rings
	return s

static func _lean_mesh(key: String, parts: Array) -> ArrayMesh:
	if not _lean.has(key):
		var mesh = LowPoly.compose(parts)
		mesh.surface_set_material(0, LowPoly.vertex_color_material())
		_lean[key] = mesh
	return _lean[key]

static func lean_pine() -> ArrayMesh:
	return _lean_mesh("pine", [
		[_cone(0.16, 1.0, 4, 0.1), Transform3D(Basis(), Vector3(0, 0.5, 0)), LowPoly.COLOR_BARK],
		[_cone(1.3, 2.2, 6), Transform3D(Basis(), Vector3(0, 1.9, 0)), LowPoly.COLOR_PINE_DARK],
		[_cone(0.9, 1.7, 6), Transform3D(Basis(Vector3.UP, 0.5), Vector3(0, 3.0, 0)), LowPoly.COLOR_PINE_LIGHT],
	])

static func lean_broadleaf() -> ArrayMesh:
	return _lean_mesh("broadleaf", [
		[_cone(0.18, 1.6, 4, 0.1), Transform3D(Basis(), Vector3(0, 0.8, 0)), LowPoly.COLOR_BARK],
		[_blob(1.5, 2.3, 6, 2), Transform3D(Basis(), Vector3(0, 2.5, 0)), Color(0.22, 0.40, 0.2)],
	])

static func lean_dry_tree() -> ArrayMesh:
	return _lean_mesh("dry", [
		[_cone(0.16, 1.8, 4, 0.09), Transform3D(Basis(), Vector3(0, 0.9, 0)), LowPoly.COLOR_BARK],
		[_blob(1.3, 1.6, 6, 2), Transform3D(Basis(), Vector3(0, 2.4, 0)), Color(0.62, 0.48, 0.26)],
	])

static func lean_bamboo() -> ArrayMesh:
	var parts = []
	for c in [[Vector3(0, 0, 0), 3.2, 0.05], [Vector3(0.3, 0, 0.15), 2.7, -0.12], [Vector3(-0.25, 0, 0.2), 2.9, 0.14]]:
		var basis = Basis.from_euler(Vector3(c[2], 0, c[2] * 0.6))
		parts.append([_cone(0.09, c[1], 3), Transform3D(basis, c[0] + basis * Vector3(0, c[1] * 0.5, 0)), LowPoly.COLOR_BAMBOO])
	parts.append([_blob(0.6, 0.6, 4, 1), Transform3D(Basis(), Vector3(0, 3.0, 0.05)), LowPoly.COLOR_BAMBOO_LEAF])
	return _lean_mesh("bamboo", parts)

static func lean_scrub() -> ArrayMesh:
	return _lean_mesh("scrub", [
		[_blob(0.5, 0.7, 5, 2), Transform3D(Basis(), Vector3(0, 0.3, 0)), LowPoly.COLOR_BRUSH_DRY],
	])

static func lean_stump() -> ArrayMesh:
	return _lean_mesh("stump", [
		[_cone(0.2, 0.35, 4, 0.13), Transform3D(Basis(), Vector3(0, 0.17, 0)), Color.WHITE],
		[_cone(0.07, 1.2, 3, 0.07), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.4, 0.07, 0.1)), Color.WHITE],
	])

## Instances are split into chunks so off-screen ones are culled; small props
## also drop out beyond `range_end` metres (0 = always drawn)
const CHUNK: float = 110.0

func _multimesh(mesh: Mesh, xforms: Array, shadows: bool, tint: Variant = null, range_end: float = 0.0) -> void:
	if xforms.is_empty():
		return
	var buckets: Dictionary = {}
	for xf in xforms:
		var key = Vector2i(floori(xf.origin.x / CHUNK), floori(xf.origin.z / CHUNK))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(xf)
	var mat: StandardMaterial3D = null
	if tint != null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 1.0
	for key in buckets:
		var list: Array = buckets[key]
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var inst = MultiMeshInstance3D.new()
		inst.multimesh = mm
		if not shadows:
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mat:
			inst.material_override = mat
		if range_end > 0.0:
			inst.visibility_range_end = range_end
			inst.visibility_range_end_margin = 15.0
		add_child(inst)
		_decor.append(inst)

func _place(x: float, z: float, scale_min: float, scale_max: float) -> Transform3D:
	var s = _rng.randf_range(scale_min, scale_max)
	var y = surface_at(x, z) - 0.15
	return Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.2), s)), Vector3(x, y, z))

func _build_vegetation() -> void:
	var pines: Array = []
	var broad: Array = []
	var dry: Array = []
	var bamboo: Array = []
	var scrub: Array = []
	var charred: Array = []
	var cut: Array = []
	var far_trees: Array = []
	# Forest belt hugging the plot: as dense as the plot's own border pines
	var bx = -PLOT_HALF - 40.0
	while bx <= PLOT_HALF + 40.0:
		var bz = -PLOT_HALF - 40.0
		while bz <= PLOT_HALF + 40.0:
			var px = bx + _rng.randf_range(-1.0, 1.0)
			var pz = bz + _rng.randf_range(-1.0, 1.0)
			bz += 2.6
			var bd = _outside(px, pz)
			if bd < 0.8 or bd >= _belt_width(px, pz):
				continue
			if _rng.randf() < 0.8:
				var dry_here = _dry.get_noise_2d(px, pz) > 0.4
				(dry if dry_here else (pines if _rng.randf() < 0.65 else broad)).append(_place(px, pz, 0.9, 1.5))
		bx += 2.6
	# Near ring: individual trees, bamboo and scrub by land use
	var spacing = 6.0
	var reach = FARM_RADIUS + 40.0
	var x = -reach
	while x <= reach:
		var z = -reach
		while z <= reach:
			var px = x + _rng.randf_range(-2.5, 2.5)
			var pz = z + _rng.randf_range(-2.5, 2.5)
			z += spacing
			var d = _outside(px, pz)
			if d < _belt_width(px, pz) or Vector2(px, pz).length() > reach:
				continue
			var p = patch_at(px, pz, 0.3)
			var roll = _rng.randf()
			match p:
				Patch.FOREST:
					if roll < 0.75:
						(pines if _rng.randf() < 0.45 else broad).append(_place(px, pz, 1.3, 2.1))
				Patch.FOREST_DRY:
					if roll < 0.6:
						dry.append(_place(px, pz, 1.3, 2.0))
				Patch.FALLOW_OLD:
					if roll < 0.45:
						broad.append(_place(px, pz, 0.8, 1.3))
					elif roll < 0.7:
						bamboo.append(_place(px, pz, 1.0, 1.4))
				Patch.FALLOW_MID:
					if roll < 0.45:
						bamboo.append(_place(px, pz, 0.9, 1.3))
					elif roll < 0.65:
						scrub.append(_place(px, pz, 1.0, 1.6))
				Patch.FALLOW_YOUNG:
					if roll < 0.3:
						scrub.append(_place(px, pz, 0.8, 1.3))
				Patch.SLASHED:
					if roll < 0.05:
						dry.append(_place(px, pz, 1.0, 1.4)) # Lone trees left standing
					elif roll < 0.6:
						cut.append(_place(px, pz, 1.2, 2.2)) # Felled brush drying for the burn
				Patch.BURNED:
					if roll < 0.55:
						charred.append(_place(px, pz, 1.2, 2.0))
		x += spacing
	# Far ring: sparse big trees give the forested slopes texture under the haze
	# Low detail (Steam Deck): no far ring and no scrub
	spacing = 16.0 if GameSettings.landscape_detail != "low" else 1e9
	reach = 700.0
	x = -reach
	while x <= reach:
		var z = -reach
		while z <= reach:
			var px = x + _rng.randf_range(-6.0, 6.0)
			var pz = z + _rng.randf_range(-6.0, 6.0)
			z += spacing
			var r = Vector2(px, pz).length()
			if r < FARM_RADIUS + 40.0 or r > reach:
				continue
			if patch_at(px, pz, 0.3) >= Patch.FOREST and _rng.randf() < 0.7:
				far_trees.append(_place(px, pz, 2.6, 3.6))
		x += spacing

	_multimesh(lean_pine(), pines, true)
	_multimesh(lean_broadleaf(), broad, true)
	_multimesh(lean_dry_tree(), dry, true)
	_multimesh(lean_bamboo(), bamboo, true, null, 420.0)
	_multimesh(lean_scrub(), scrub, false, null, 260.0)
	_multimesh(lean_stump(), charred, false, Color(0.1, 0.09, 0.09), 260.0)
	_multimesh(lean_stump(), cut, false, Color(0.55, 0.42, 0.26), 260.0)
	_multimesh(lean_broadleaf(), far_trees, false)
	_scatter_set_dressing()

## Rocks (E6), fallen logs (E8), grass tufts (E9) and terrace walls (E7) from the
## asset pipeline, when installed (ASSET_REQUESTS_v1.2.md). Each variant gets its
## own chunked MultiMesh. Spec: id, count, patches, scale range, draw range, shadows,
## outer radius. Scaled up from life size so they still read from the game camera
## (30 m+ away), like the landscape's oversized trees.
func _scatter_set_dressing() -> void:
	for spec in [["E6", 700, [Patch.FALLOW_YOUNG, Patch.SLASHED, Patch.BURNED, Patch.FOREST_DRY], 1.1, 2.4, 300.0, true, FARM_RADIUS],
			["E8", 320, [Patch.SLASHED, Patch.FOREST, Patch.FALLOW_OLD], 1.2, 1.7, 300.0, true, FARM_RADIUS],
			["E9", 5000, [Patch.FALLOW_YOUNG, Patch.FALLOW_MID, Patch.SLASHED, Patch.BURNED], 1.5, 2.6, 130.0, false, 150.0]]:
		var variants: Array = AssetLibrary.meshes(spec[0])
		if variants.is_empty() or (spec[0] == "E9" and GameSettings.landscape_detail == "low"):
			continue
		var per_variant: Array = []
		for v in variants:
			per_variant.append([])
		for i in spec[1]:
			var a = _rng.randf() * TAU
			var r = _rng.randf_range(PLOT_HALF + 3.0, spec[7])
			var p = Vector2(cos(a), sin(a)) * r
			if spec[2].has(patch_at(p.x, p.y, 0.3)):
				per_variant[i % variants.size()].append(_place(p.x, p.y, spec[3], spec[4]))
		for k in variants.size():
			_multimesh(variants[k], per_variant[k], spec[6], null, spec[5])
	_scatter_terraces()

## Old terrace walls (E7) in short runs along the contour of the fallows: each
## segment faces the plot (local +Z inward), runs follow a ring around it.
func _scatter_terraces() -> void:
	var variants: Array = AssetLibrary.meshes("E7")
	if variants.is_empty():
		return
	var per_variant: Array = []
	for v in variants:
		per_variant.append([])
	var s = 1.5 # Same oversize as the other set dressing
	for run in 110:
		var r = _rng.randf_range(PLOT_HALF + 8.0, FARM_RADIUS * 0.6)
		var a = _rng.randf() * TAU
		var step = 1.47 * s / r # Segments are 1.5 m wide before scaling
		for k in _rng.randi_range(4, 9):
			var ak = a + k * step
			var p = Vector2(cos(ak), sin(ak)) * r
			if not [Patch.FALLOW_MID, Patch.FALLOW_OLD, Patch.FALLOW_YOUNG].has(patch_at(p.x, p.y, 0.3)):
				break
			var inward = -Vector3(p.x, 0, p.y).normalized()
			var xf = Transform3D(Basis.looking_at(-inward, Vector3.UP).scaled(Vector3.ONE * s), Vector3(p.x, surface_at(p.x, p.y) - 0.15, p.y))
			per_variant[(run + k) % variants.size()].append(xf)
	for k in variants.size():
		_multimesh(variants[k], per_variant[k], true, null, 220.0)

# ---------------------------------------------------------------------------
# Field huts, a ridge village and neighbours' burns
# ---------------------------------------------------------------------------

func _find_spot(patch_types: Array, r_min: float, r_max: float, tries: int = 300) -> Vector3:
	for _i in tries:
		var a = _rng.randf() * TAU
		var r = _rng.randf_range(r_min, r_max)
		var p = Vector2(cos(a), sin(a)) * r
		if _outside(p.x, p.y) < 12.0:
			continue
		if patch_types.has(patch_at(p.x, p.y, 0.3)):
			return Vector3(p.x, surface_at(p.x, p.y), p.y)
	return Vector3.INF

func _build_settlements() -> void:
	var hut_mesh = AssetLibrary.mesh_or("S1", LowPoly.field_hut())
	var huts: Array = []
	for _i in 7:
		var p = _find_spot([Patch.SLASHED, Patch.BURNED, Patch.FALLOW_YOUNG], 70.0, 260.0)
		if p != Vector3.INF:
			huts.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p - Vector3(0, 0.2, 0)))
	# A small hamlet on open ground further up the valley
	var centre = _find_spot([Patch.FALLOW_YOUNG, Patch.FALLOW_MID, Patch.SLASHED], 200.0, 290.0)
	if centre != Vector3.INF:
		for _k in 7:
			var off = Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-16.0, 16.0))
			var hp = Vector3(centre.x + off.x, 0.0, centre.z + off.y)
			hp.y = surface_at(hp.x, hp.z) - 0.2
			var s = _rng.randf_range(1.2, 1.6)
			huts.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), hp))
	_multimesh(hut_mesh, huts, true)

func _build_smoke() -> void:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.78, 0.76, 0.72, 0.5)
	# Soft round puff instead of a hard-edged quad
	var puff = GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var falloff = Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = falloff
	mat.albedo_texture = puff
	var quad = QuadMesh.new()
	quad.size = Vector2(9, 9)
	quad.material = mat
	var fade = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.55))
	fade.add_point(0.6, Color(1, 1, 1, 0.3))
	var ramp = GradientTexture1D.new()
	ramp.gradient = fade
	var grow = Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.4))
	var grow_tex = CurveTexture.new()
	grow_tex.curve = grow
	for _i in 3:
		var p = _find_spot([Patch.BURNED, Patch.SLASHED], 110.0, 300.0)
		if p == Vector3.INF:
			continue
		var smoke = GPUParticles3D.new()
		smoke.amount = 28
		smoke.lifetime = 16.0
		smoke.preprocess = 16.0
		smoke.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 90, 80))
		var pm = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 5.0
		pm.direction = Vector3(0.25, 1, 0.1)
		pm.spread = 12.0
		pm.initial_velocity_min = 2.5
		pm.initial_velocity_max = 4.0
		pm.gravity = Vector3(0.4, 0.15, 0.0)
		pm.color_ramp = ramp
		pm.scale_curve = grow_tex
		smoke.process_material = pm
		smoke.draw_pass_1 = quad
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(smoke)
		smoke.global_position = p
		_decor.append(smoke)

# ---------------------------------------------------------------------------
# Atmosphere: ridge silhouettes on the horizon and mist in the valleys
# ---------------------------------------------------------------------------

func _build_ridges() -> void:
	var layers = [[1350.0, 210.0, 0], [1750.0, 300.0, 1], [2250.0, 380.0, 2]]
	for layer in layers:
		var radius: float = layer[0]
		var peak: float = layer[1]
		var noise = FastNoiseLite.new()
		noise.seed = seed_value * 3 + layer[2]
		noise.frequency = 0.9
		var verts = PackedVector3Array()
		var segs = 140
		for s in segs:
			var a0 = TAU * s / segs
			var a1 = TAU * (s + 1) / segs
			var h0 = peak * (0.45 + 0.55 * (noise.get_noise_1d(s) * 0.5 + 0.5))
			var h1 = peak * (0.45 + 0.55 * (noise.get_noise_1d(s + 1) * 0.5 + 0.5))
			var b0 = Vector3(cos(a0) * radius, -260.0, sin(a0) * radius)
			var b1 = Vector3(cos(a1) * radius, -260.0, sin(a1) * radius)
			var t0 = Vector3(b0.x, h0, b0.z)
			var t1 = Vector3(b1.x, h1, b1.z)
			verts.append_array([b0, t0, t1, b0, t1, b1])
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_fog = true
		mesh.surface_set_material(0, mat)
		var inst = MeshInstance3D.new()
		inst.mesh = mesh
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_decor.append(inst)
		_ridge_mats.append(mat)

func _build_mist() -> void:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 9
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp = Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.set_color(1, Color(1, 1, 1, 1.0))
	ramp.set_offset(0, 0.42)
	tex.color_ramp = ramp
	for sheet in [[-16.0, 0.42, 4.0], [-34.0, 0.6, 2.5]]:
		var plane = PlaneMesh.new()
		plane.size = Vector2(EXTENT * 2.0, EXTENT * 2.0)
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.9, 0.9, 0.92, sheet[1])
		mat.uv1_scale = Vector3(sheet[2], sheet[2], 1.0)
		mat.disable_receive_shadows = true
		plane.material = mat
		var inst = MeshInstance3D.new()
		inst.mesh = plane
		inst.position = Vector3(0, sheet[0], 0)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		_decor.append(inst)
		_mist_mats.append(mat)

func _process(delta: float) -> void:
	var env = world_environment.environment if world_environment else null
	if not env:
		return
	var fog: Color = env.fog_light_color
	var sky = env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	var horizon: Color = sky.sky_horizon_color if sky else fog
	# Nearer ridges darker and bluer, farther ones melt into the horizon haze
	for i in _ridge_mats.size():
		var depth = float(i) / maxf(1.0, _ridge_mats.size() - 1)
		var near = fog.lerp(Color(0.2, 0.28, 0.3), 0.45).darkened(0.12)
		_ridge_mats[i].albedo_color = near.lerp(horizon, 0.25 + 0.55 * depth)
	for i in _mist_mats.size():
		var m = _mist_mats[i]
		m.albedo_color = Color(fog.lightened(0.25), m.albedo_color.a)
		m.uv1_offset += Vector3(0.0025, 0.0012, 0.0) * delta * (1.0 + i)

## 20:00 satellite pass: cold ground everywhere outside the plot
func set_thermal(enabled: bool) -> void:
	terrain.material_override = _thermal_mat if enabled else null
	for n in _decor:
		n.visible = not enabled
