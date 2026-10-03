extends SceneTree
## Numerical review of runtime layers, beyond the baked Blender clip checks.
class Ramp extends Node3D:
	func get_ground_height_at_world_pos(point: Vector3) -> float:
		return 0.20*point.z

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this test with the project renderer; headless cannot bake skinned meshes")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var report := {}
	var failed := false
	var args := OS.get_cmdline_user_args()
	var ramp := Ramp.new()
	root.add_child(ramp)
	var candidates: Dictionary = {}
	if args.size() >= 2:
		candidates = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	else:
		for name in ["khanae","tapoh","munaw","maelu"]:
			candidates[name] = ProjectSettings.globalize_path("res://assets/models/"+name+"_rigged.glb")
	assert(not candidates.is_empty(), "No candidates to test")
	for character in candidates:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(candidates[character], state) == OK)
		var actor := Node3D.new()
		actor.set_script(load("res://scripts/SkeletalChibiAnimator.gd"))
		actor.character_profile = character
		actor.separate_equipment = true
		actor.add_child(doc.generate_scene(state, 60.0))
		root.add_child(actor)
		await process_frame
		if args.size() > 2 and args[2] == "slope": actor.set_environment(ramp,true)
		var worst := 1.0
		var worst_pose := ""
		var worst_edge := ""
		var actions: Array = [&"", &"ignite", &"rake", &"spray"]
		if character == "munaw": actions = [&"", &"spray"]
		if character == "tapoh": actions = [&"", &"rake", &"spray"]
		if character == "maelu": actions = [&""]
		for action in actions:
			for velocity in [Vector3.ZERO, Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6)]:
				actor.cancel_work()
				actor.set_work(action, action != &"")
				for frame in 24:
					actor.update_animation(1.0/30.0, velocity, Vector3(0, 0, 1))
					if frame % 6 != 0: continue
					await process_frame
					for mesh in actor.find_children("*", "MeshInstance3D", true, false):
						if mesh.skin == null: continue
						var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
						if baked == null:
							push_error("Could not bake skinned mesh")
							quit(1)
							return
						for surface in mesh.mesh.get_surface_count():
							var original: Array = mesh.mesh.surface_get_arrays(surface)
							var base: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
							var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
							var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
							for vertex in vertices:
								if not vertex.is_finite():
									failed = true
									push_error(character+": non-finite deformed vertex")
							for tri in range(0, indices.size(), 3):
								for edge in 3:
									var a := indices[tri + edge]
									var b := indices[tri + (edge+1)%3]
									var length := base[a].distance_to(base[b])
									if length <= .003: continue
									var ratio := vertices[a].distance_to(vertices[b]) / length
									if ratio > worst:
										worst = ratio
										worst_pose = "%s velocity=%s frame=%s" % [action, velocity, frame]
										worst_edge = "%s / %s" % [base[a], base[b]]
		failed = failed or worst > 3.5
		report[character] = {"max_edge_stretch_over_3mm":worst, "pose":worst_pose, "edge":worst_edge, "passed":worst <= 3.5}
		actor.queue_free()
		await process_frame
	var output: String = args[1] if args.size() >= 2 else "res://artifacts/character_rigs_v31/installed_runtime.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(1 if failed else 0)
