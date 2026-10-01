extends SceneTree

func _initialize() -> void:
	var scene_root := Node3D.new()
	scene_root.position = Vector3(1, 2, 3)
	var colors := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	colors.fill(Color.RED)
	var texture := ImageTexture.create_from_image(colors)
	var textured := StandardMaterial3D.new()
	textured.albedo_texture = texture
	var solid := StandardMaterial3D.new()
	solid.albedo_color = Color.BLUE
	for i in 2:
		var node := MeshInstance3D.new()
		node.mesh = BoxMesh.new()
		node.mesh.material = textured if i == 0 else solid
		node.position = Vector3(i * 2, 0, 0)
		scene_root.add_child(node)
		node.owner = scene_root
	var packed := PackedScene.new()
	assert(packed.pack(scene_root) == OK)
	scene_root.free()
	var flattened := AssetLibrary._flatten(packed)
	assert(flattened.get_surface_count() == 2, "Material surfaces merged destructively")
	assert(flattened.surface_get_material(0).albedo_texture == texture, "Texture erased")
	assert(flattened.surface_get_material(1).albedo_color == Color.BLUE, "Solid material erased")
	assert(flattened.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size() > 0, "UVs lost")
	assert(flattened.get_aabb().position.is_equal_approx(Vector3(0.5, 1.5, 2.5)), "Scene transforms lost")
	assert(flattened.get_aabb().size.is_equal_approx(Vector3(3, 1, 1)), "Bounds changed")
	# A GLTFDocument material can omit the vertex-colour flag despite COLOR_0.
	var vertex_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE])
	vertex_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var vertex_material := StandardMaterial3D.new()
	vertex_material.albedo_texture = texture
	vertex_mesh.surface_set_material(0, vertex_material)
	var instance := MeshInstance3D.new()
	instance.mesh = vertex_mesh
	var colored := ArrayMesh.new()
	assert(AssetLibrary._append_meshes(instance, Transform3D.IDENTITY, colored))
	var retained := colored.surface_get_material(0) as StandardMaterial3D
	assert(retained.vertex_color_use_as_albedo, "Vertex colours rendered as white")
	assert(retained.albedo_texture == texture, "Enabling vertex colours erased the texture")
	assert(not vertex_material.vertex_color_use_as_albedo, "Shared source material was mutated")
	instance.free()
	print("PASS: prop UVs, textures, solid materials, multiple surfaces and scene transforms retained")
	quit(0)
