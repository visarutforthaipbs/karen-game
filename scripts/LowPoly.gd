class_name LowPoly
extends RefCounted

## Procedural flat-shaded low-poly props (PRD §9.1: faceted, un-smoothed normals,
## bold silhouettes). Each prop is one ArrayMesh with per-part vertex colours, so
## a whole bamboo clump or pine is a single MultiMesh instance / draw call.

const COLOR_BARK = Color(0.36, 0.25, 0.16)
const COLOR_PINE_DARK = Color(0.10, 0.25, 0.15)
const COLOR_PINE_MID = Color(0.14, 0.32, 0.18)
const COLOR_PINE_LIGHT = Color(0.19, 0.40, 0.21)
const COLOR_BAMBOO = Color(0.62, 0.70, 0.30)
const COLOR_BAMBOO_DRY = Color(0.74, 0.68, 0.36)
const COLOR_BAMBOO_LEAF = Color(0.36, 0.52, 0.20)
const COLOR_BRUSH_A = Color(0.30, 0.46, 0.20)
const COLOR_BRUSH_B = Color(0.40, 0.50, 0.22)
const COLOR_BRUSH_DRY = Color(0.55, 0.52, 0.28)
const COLOR_THATCH = Color(0.78, 0.66, 0.38)
const COLOR_BAMBOO_WALL = Color(0.70, 0.58, 0.36)
const COLOR_POST = Color(0.42, 0.30, 0.20)
const COLOR_BARREL = Color(0.22, 0.36, 0.55)

static var _cache: Dictionary = {}

## Build one flat-shaded mesh from [[PrimitiveMesh, Transform3D, Color], ...]
static func compose(parts: Array) -> ArrayMesh:
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	for part in parts:
		var mesh: Mesh = part[0]
		var xf: Transform3D = part[1]
		var col: Color = part[2]
		var arrays = mesh.get_mesh_arrays()
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tri_count = idx.size() / 3 if idx.size() > 0 else src_v.size() / 3
		for t in tri_count:
			var i0 = idx[t * 3] if idx.size() > 0 else t * 3
			var i1 = idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
			var i2 = idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
			var a = xf * src_v[i0]
			var b = xf * src_v[i1]
			var c = xf * src_v[i2]
			var n = (c - a).cross(b - a)
			if n.length_squared() < 1e-12:
				continue
			n = n.normalized()
			# Keep the primitive's own facing (works for any winding convention)
			var ref = xf.basis * (src_n[i0] + src_n[i1] + src_n[i2])
			if n.dot(ref) < 0.0:
				n = -n
			for v in [a, b, c]:
				verts.append(v)
				normals.append(n)
				colors.append(col)
	var out = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	var mesh_out = ArrayMesh.new()
	mesh_out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh_out

## Vertex-coloured material shared by the props
static func vertex_color_material(roughness: float = 0.85) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat

static func _cyl(top: float, bottom: float, height: float, segments: int = 6) -> CylinderMesh:
	var m = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

static func _ball(radius: float, height: float, segments: int = 6, rings: int = 3) -> SphereMesh:
	var m = SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = segments
	m.rings = rings
	return m

static func _box(size: Vector3) -> BoxMesh:
	var m = BoxMesh.new()
	m.size = size
	return m

static func _at(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)

static func _cached(key: String, builder: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var mesh: ArrayMesh = builder.call()
		mesh.surface_set_material(0, vertex_color_material())
		_cache[key] = mesh
	return _cache[key]

## Layered evergreen pine for the conservation forest (base at y = 0, ~4.2 m tall)
static func pine() -> ArrayMesh:
	return _cached("pine", func():
		return compose([
			[_cyl(0.12, 0.18, 0.9), _at(Vector3(0, 0.45, 0)), COLOR_BARK],
			[_cyl(0.05, 1.35, 1.8, 7), _at(Vector3(0, 1.6, 0)), COLOR_PINE_DARK],
			[_cyl(0.05, 1.05, 1.5, 7), _at(Vector3(0, 2.5, 0), Vector3(0, 0.4, 0)), COLOR_PINE_MID],
			[_cyl(0.02, 0.70, 1.3, 7), _at(Vector3(0, 3.35, 0), Vector3(0, 0.8, 0)), COLOR_PINE_LIGHT],
		]))

## Clump of leaning bamboo culms with leaf tufts (base at y = 0, ~3.3 m tall)
static func bamboo_clump() -> ArrayMesh:
	return _cached("bamboo", func():
		var parts = []
		var culms = [
			[Vector3(0.0, 0, 0.0), 3.3, Vector3(0.05, 0, 0.02), COLOR_BAMBOO],
			[Vector3(0.28, 0, 0.12), 2.8, Vector3(-0.04, 0, -0.16), COLOR_BAMBOO],
			[Vector3(-0.25, 0, 0.18), 3.0, Vector3(0.12, 0, 0.10), COLOR_BAMBOO_DRY],
			[Vector3(0.10, 0, -0.30), 2.5, Vector3(0.18, 0, -0.06), COLOR_BAMBOO],
			[Vector3(-0.18, 0, -0.16), 2.2, Vector3(-0.15, 0, 0.12), COLOR_BAMBOO_DRY],
		]
		for c in culms:
			var base: Vector3 = c[0]
			var h: float = c[1]
			var tilt: Vector3 = c[2]
			var basis = Basis.from_euler(tilt)
			var mid = base + basis * Vector3(0, h * 0.5, 0)
			parts.append([_cyl(0.06, 0.085, h, 5), Transform3D(basis, mid), c[3]])
			# Node rings
			for k in [0.3, 0.55, 0.8]:
				parts.append([_cyl(0.095, 0.095, 0.05, 5), Transform3D(basis, base + basis * Vector3(0, h * k, 0)), COLOR_BAMBOO_DRY])
			# Leaf tuft at the culm tip
			var tip = base + basis * Vector3(0, h, 0)
			parts.append([_ball(0.35, 0.28, 5, 2), _at(tip, Vector3(0.3, 0.5, 0)), COLOR_BAMBOO_LEAF])
		return compose(parts))

## Faceted mountain brush mound (base at y = 0, ~0.8 m tall)
static func brush() -> ArrayMesh:
	return _cached("brush", func():
		return compose([
			[_ball(0.45, 0.65, 6, 3), _at(Vector3(0, 0.3, 0)), COLOR_BRUSH_A],
			[_ball(0.32, 0.5, 5, 3), _at(Vector3(0.3, 0.22, 0.12), Vector3(0, 0.6, 0)), COLOR_BRUSH_B],
			[_ball(0.28, 0.42, 5, 3), _at(Vector3(-0.25, 0.2, -0.18), Vector3(0, 1.2, 0)), COLOR_BRUSH_DRY],
		]))

## Burnt root collar / stump; tinted by its material (ember glow or charcoal)
static func stump() -> ArrayMesh:
	return _cached("stump", func():
		return compose([
			[_cyl(0.13, 0.2, 0.35, 6), _at(Vector3(0, 0.17, 0)), Color.WHITE],
			[_box(Vector3(0.45, 0.08, 0.1)), _at(Vector3(0.12, 0.04, 0.05), Vector3(0, 0.5, 0)), Color.WHITE],
			[_box(Vector3(0.1, 0.08, 0.4)), _at(Vector3(-0.08, 0.04, -0.1), Vector3(0, 0.3, 0)), Color.WHITE],
		]))

## Karen upland field hut on stilts with a thatched roof (base at y = 0)
static func field_hut() -> ArrayMesh:
	return _cached("hut", func():
		var parts = []
		for p in [Vector3(-1.1, 0, -0.9), Vector3(1.1, 0, -0.9), Vector3(-1.1, 0, 0.9), Vector3(1.1, 0, 0.9)]:
			parts.append([_cyl(0.08, 0.1, 1.9, 5), _at(p + Vector3(0, 0.95, 0)), COLOR_POST])
		parts.append([_box(Vector3(2.6, 0.12, 2.2)), _at(Vector3(0, 1.0, 0)), COLOR_POST])
		parts.append([_box(Vector3(2.4, 0.9, 0.06)), _at(Vector3(0, 1.5, -1.0)), COLOR_BAMBOO_WALL])
		parts.append([_box(Vector3(0.06, 0.9, 2.0)), _at(Vector3(-1.2, 1.5, 0)), COLOR_BAMBOO_WALL])
		parts.append([_box(Vector3(0.06, 0.9, 2.0)), _at(Vector3(1.2, 1.5, 0)), COLOR_BAMBOO_WALL])
		# Steep gable roof: a 3-sided prism
		var roof = PrismMesh.new()
		roof.size = Vector3(3.4, 1.4, 2.9)
		parts.append([roof, _at(Vector3(0, 2.65, 0)), COLOR_THATCH])
		# Ladder
		parts.append([_box(Vector3(0.06, 1.2, 0.06)), _at(Vector3(-0.3, 0.55, 1.35), Vector3(-0.35, 0, 0)), COLOR_POST])
		parts.append([_box(Vector3(0.06, 1.2, 0.06)), _at(Vector3(0.3, 0.55, 1.35), Vector3(-0.35, 0, 0)), COLOR_POST])
		for k in 3:
			parts.append([_box(Vector3(0.6, 0.05, 0.06)), _at(Vector3(0, 0.25 + k * 0.32, 1.48 - k * 0.11)), COLOR_POST])
		return compose(parts))

## Water barrels beside the hut: the sprayer refill point
static func water_barrels() -> ArrayMesh:
	return _cached("barrels", func():
		return compose([
			[_cyl(0.32, 0.32, 0.9, 8), _at(Vector3(0, 0.45, 0)), COLOR_BARREL],
			[_cyl(0.28, 0.28, 0.75, 8), _at(Vector3(0.7, 0.38, 0.15)), COLOR_BARREL],
			[_cyl(0.34, 0.34, 0.08, 8), _at(Vector3(0, 0.92, 0)), Color(0.15, 0.2, 0.3)],
		]))

## Hand tools carried by the player (origin = grip)
static func tool_mesh(tool_name: String) -> ArrayMesh:
	var key = "tool_" + tool_name
	if _cache.has(key):
		return _cache[key]
	var parts = []
	if tool_name == "torch":
		parts = [
			[_cyl(0.025, 0.025, 0.9, 5), _at(Vector3(0, 0.3, 0)), COLOR_POST],
			[_cyl(0.07, 0.06, 0.18, 6), _at(Vector3(0, 0.78, 0)), Color(0.55, 0.55, 0.5)],
			[_ball(0.08, 0.16, 5, 2), _at(Vector3(0, 0.92, 0)), Color(1.0, 0.55, 0.1)],
		]
	elif tool_name == "rake":
		var steel = Color(0.5, 0.5, 0.52)
		parts = [
			[_cyl(0.025, 0.025, 1.4, 5), _at(Vector3(0, 0.45, 0)), COLOR_POST],
			[_box(Vector3(0.5, 0.06, 0.06)), _at(Vector3(0, 1.15, 0)), steel],
			[_box(Vector3(0.04, 0.16, 0.04)), _at(Vector3(-0.2, 1.06, 0)), steel],
			[_box(Vector3(0.04, 0.16, 0.04)), _at(Vector3(0.0, 1.06, 0)), steel],
			[_box(Vector3(0.04, 0.16, 0.04)), _at(Vector3(0.2, 1.06, 0)), steel],
		]
	else:
		# Sprayer wand
		parts = [
			[_cyl(0.02, 0.02, 0.8, 5), _at(Vector3(0, 0.25, 0)), Color(0.3, 0.32, 0.3)],
			[_cyl(0.035, 0.02, 0.1, 5), _at(Vector3(0, 0.68, 0)), Color(0.75, 0.75, 0.2)],
		]
	var mesh = compose(parts)
	mesh.surface_set_material(0, vertex_color_material())
	_cache[key] = mesh
	return mesh

## Backpack sprayer tank (worn on the back)
static func sprayer_tank() -> ArrayMesh:
	return _cached("tank", func():
		return compose([
			[_box(Vector3(0.34, 0.46, 0.2)), _at(Vector3(0, 0, 0)), Color(0.72, 0.66, 0.28)],
			[_cyl(0.05, 0.05, 0.08, 6), _at(Vector3(0, 0.27, 0)), Color(0.2, 0.2, 0.2)],
		]))
