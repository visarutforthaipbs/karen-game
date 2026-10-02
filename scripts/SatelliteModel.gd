class_name SatelliteModel
extends RefCounted

## Polar-orbiting VIIRS satellite (asset V3). A faceted low-poly placeholder
## built in code; a pipeline model at assets/props/V3_*.glb replaces it through
## AssetLibrary.mesh_or("V3", ...). Staged large (about 16 m wingspan) for the
## title screen and the 20:00 pass: the satellite's shadow made literal.
## Wings span local X, the satellite flies along local +Z, the scanner looks down.

const FOIL = Color(0.86, 0.66, 0.26)
const FOIL_DARK = Color(0.62, 0.44, 0.16)
const PANEL_A = Color(0.12, 0.18, 0.42)
const PANEL_B = Color(0.18, 0.27, 0.55)
const STRUT = Color(0.72, 0.74, 0.78)
const LENS = Color(0.05, 0.06, 0.08)

static var _mesh: ArrayMesh
static var _shadow: ImageTexture

static func mesh() -> Mesh:
	return AssetLibrary.mesh_or("V3", procedural())

## Uniform scale that gives `m` the placeholder's wingspan (about 16 m), so a
## metre-scale V3 asset of any size stages the same as the placeholder
static func fit_scale(m: Mesh) -> float:
	var span = m.get_aabb().size.x if m else 0.0
	return procedural().get_aabb().size.x / span if span > 0.01 else 1.0

static func procedural() -> ArrayMesh:
	if _mesh:
		return _mesh
	var parts = []
	var body = BoxMesh.new()
	body.size = Vector3(2.2, 1.9, 3.0)
	parts.append([body, Transform3D(Basis(), Vector3.ZERO), FOIL])
	var band = BoxMesh.new()
	band.size = Vector3(2.26, 0.35, 3.06)
	parts.append([band, Transform3D(Basis(), Vector3(0, 0.55, 0)), FOIL_DARK])
	# Solar wings: four panels a side on a boom, alternating blues for facets
	var boom = BoxMesh.new()
	boom.size = Vector3(1.4, 0.14, 0.14)
	var panel = BoxMesh.new()
	panel.size = Vector3(1.55, 0.07, 2.3)
	for side in [-1.0, 1.0]:
		parts.append([boom, Transform3D(Basis(), Vector3(side * 1.75, 0.2, 0)), STRUT])
		for k in 4:
			var x = side * (2.5 + k * 1.62 + 0.78)
			parts.append([panel, Transform3D(Basis(Vector3.RIGHT, 0.08 * side), Vector3(x, 0.2, 0)), PANEL_A if k % 2 == 0 else PANEL_B])
	# Dish antenna on top, tilted toward the ground station
	var dish = CylinderMesh.new()
	dish.top_radius = 0.95
	dish.bottom_radius = 0.12
	dish.height = 0.45
	dish.radial_segments = 8
	dish.rings = 0
	parts.append([dish, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 1.35, -0.6)), STRUT])
	var mast = CylinderMesh.new()
	mast.top_radius = 0.06
	mast.bottom_radius = 0.06
	mast.height = 0.6
	mast.radial_segments = 5
	mast.rings = 0
	parts.append([mast, Transform3D(Basis(), Vector3(0, 1.1, -0.6)), STRUT])
	# VIIRS radiometer: the eye, looking straight down
	var scanner = BoxMesh.new()
	scanner.size = Vector3(1.0, 0.7, 1.1)
	parts.append([scanner, Transform3D(Basis(), Vector3(0, -1.25, 0.5)), STRUT])
	var lens = CylinderMesh.new()
	lens.top_radius = 0.32
	lens.bottom_radius = 0.38
	lens.height = 0.2
	lens.radial_segments = 8
	lens.rings = 0
	parts.append([lens, Transform3D(Basis(), Vector3(0, -1.65, 0.5)), LENS])
	_mesh = LowPoly.compose(parts)
	_mesh.surface_set_material(0, LowPoly.vertex_color_material(0.55))
	return _mesh

## Soft-edged top-down silhouette for the ground shadow (a Decal texture).
## U spans the wings (local X), V spans the flight direction (local Z).
static func shadow_texture() -> ImageTexture:
	if _shadow:
		return _shadow
	var w = 64
	var h = 16
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink = Color(0, 0, 0, 1)
	# Body in the middle, wings out to the sides, as seen from the sun
	img.fill_rect(Rect2i(28, 4, 8, 9), ink)
	img.fill_rect(Rect2i(3, 5, 24, 7), ink)
	img.fill_rect(Rect2i(37, 5, 24, 7), ink)
	img.fill_rect(Rect2i(30, 1, 4, 3), ink)
	# Upscale smoothly: soft penumbra edges
	img.resize(w * 4, h * 4, Image.INTERPOLATE_CUBIC)
	_shadow = ImageTexture.create_from_image(img)
	return _shadow
