class_name AssetLibrary
extends RefCounted

## Drop-in props from tools/asset_pipeline. A file named assets/props/<ID>_<name>_<variant>.glb
## (IDs from ASSETS.md) replaces the procedural LowPoly mesh for that ID; several variants
## (_a, _b, ...) are spread across cells. With no file, callers keep the procedural fallback.
## Each GLB is flattened into one vertex-coloured ArrayMesh so it can be MultiMesh-instanced.

const PROPS_DIR = "res://assets/props/"

static var _index: Dictionary = {}  # ID -> sorted Array of resource paths
static var _indexed: bool = false
static var _cache: Dictionary = {}  # ID -> Array of meshes

## All variants for an asset ID (empty if none have been built)
static func meshes(id: String) -> Array:
	if _cache.has(id):
		return _cache[id]
	_build_index()
	var result: Array = []
	for path in _index.get(id, []):
		if not ResourceLoader.exists(path):
			continue
		var scene = load(path) as PackedScene
		if scene:
			var mesh = _flatten(scene)
			if mesh:
				result.append(mesh)
	_cache[id] = result
	return result

## First variant of an asset, or the procedural fallback
static func mesh_or(id: String, fallback: Mesh) -> Mesh:
	var found = meshes(id)
	return found[0] if not found.is_empty() else fallback

## Every variant of an asset, or [fallback]
static func variants_or(id: String, fallback: Mesh) -> Array:
	var found = meshes(id)
	return found if not found.is_empty() else [fallback]

static func has_asset(id: String) -> bool:
	return not meshes(id).is_empty()

## Forget everything (e.g. after the pipeline adds files while the game is running)
static func reload() -> void:
	_index.clear()
	_cache.clear()
	_indexed = false

static func _build_index() -> void:
	if _indexed:
		return
	_indexed = true
	var dir = DirAccess.open(PROPS_DIR)
	if not dir:
		return
	for file in dir.get_files():
		# Exported builds only list the .import remap next to each source file
		var name = file.trim_suffix(".import")
		if not name.ends_with(".glb"):
			continue
		var id = name.get_slice("_", 0)
		var path = PROPS_DIR + name
		if not _index.has(id):
			_index[id] = []
		if not _index[id].has(path):
			_index[id].append(path)
	for id in _index:
		_index[id].sort()

## Merge every MeshInstance3D in the imported scene into a single mesh (node transforms baked in)
static func _flatten(scene: PackedScene) -> ArrayMesh:
	var root = scene.instantiate()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var found = _append_meshes(root, Transform3D.IDENTITY, st)
	root.free()
	if not found:
		return null
	var mesh = st.commit()
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh

static func _append_meshes(node: Node, parent_xf: Transform3D, st: SurfaceTool) -> bool:
	var xf = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	var found = false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			st.append_from(mesh, s, xf)
			found = true
	for child in node.get_children():
		found = _append_meshes(child, xf, st) or found
	return found
