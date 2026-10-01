extends SceneTree
## Numerical review of runtime layers, beyond the baked Blender clip checks.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var report := {}
	var failed := false
	for character in ["Khanae", "Tapoh", "Munaw"]:
		var actor = load("res://scenes/characters/" + character + "Chibi.tscn").instantiate()
		root.add_child(actor)
		await process_frame
		var worst := 1.0
		var worst_pose := ""
		var worst_edge := ""
		for action in [&"", &"ignite", &"rake", &"spray"]:
			for speed in [0.0, 6.0]:
				actor.cancel_work()
				actor.set_work(action, action != &"")
				for frame in 24:
					actor.update_animation(1.0/30.0, Vector3(speed, 0, 0), Vector3(0, 0, 1))
					if frame % 6 != 0: continue
					await process_frame
					for mesh in actor.find_children("*", "MeshInstance3D", true, false):
						if mesh.skin == null: continue
						var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
						for surface in mesh.mesh.get_surface_count():
							var original: Array = mesh.mesh.surface_get_arrays(surface)
							var base: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
							var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
							for tri in range(0, indices.size(), 3):
								for edge in 3:
									var a := indices[tri + edge]
									var b := indices[tri + (edge+1)%3]
									var length := base[a].distance_to(base[b])
									if length <= .003: continue
									var ratio := vertices[a].distance_to(vertices[b]) / length
									if ratio > worst:
										worst = ratio
										worst_pose = "%s speed=%s frame=%s" % [action, speed, frame]
										worst_edge = "%s / %s" % [base[a], base[b]]
		failed = failed or worst > 3.5
		report[character] = {"max_edge_stretch_over_3mm":worst, "pose":worst_pose, "edge":worst_edge, "passed":worst <= 3.5}
		actor.queue_free()
		await process_frame
	var output := "res://artifacts/character_motion_20261002/runtime_deformation.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(1 if failed else 0)
