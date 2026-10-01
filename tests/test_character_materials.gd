extends SceneTree
## Regression: imported UV textures must survive the procedural character animator.
func _initialize() -> void:
	var animator = ChibiAnimator.new()
	var empty = MeshInstance3D.new()
	animator._apply_toon_vertex_material(empty)
	empty.free()
	var textured = MeshInstance3D.new()
	var textured_mesh = BoxMesh.new()
	var imported = StandardMaterial3D.new()
	var pixels = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.RED)
	imported.albedo_texture = ImageTexture.create_from_image(pixels)
	textured_mesh.material = imported
	textured.mesh = textured_mesh
	animator._apply_toon_vertex_material(textured)
	if textured.get_active_material(0) != imported:
		push_error("Animator replaced imported UV material")
		quit(1)
		return
	var solid = MeshInstance3D.new()
	solid.mesh = BoxMesh.new()
	var hair = StandardMaterial3D.new()
	hair.albedo_color = Color(0.02, 0.02, 0.02)
	solid.mesh.material = hair
	animator._apply_toon_vertex_material(solid)
	if solid.get_active_material(0) != hair:
		push_error("Animator erased a solid imported material")
		quit(1)
		return
	solid.free()
	var vertex_mesh = MeshInstance3D.new()
	var arrays = BoxMesh.new().surface_get_arrays(0)
	var colors = PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(Color.BLUE)
	arrays[Mesh.ARRAY_COLOR] = colors
	var legacy = ArrayMesh.new()
	legacy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	legacy.surface_set_material(0, StandardMaterial3D.new())
	vertex_mesh.mesh = legacy
	animator._apply_toon_vertex_material(vertex_mesh)
	var applied = vertex_mesh.get_active_material(0) as StandardMaterial3D
	if applied == null or not applied.vertex_color_use_as_albedo:
		push_error("Legacy vertex-colour material no longer works")
		quit(1)
		return
	textured.free()
	vertex_mesh.free()
	animator.free()
	print("PASS: textured and solid materials preserved; legacy vertex colours retained")
	quit(0)
