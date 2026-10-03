extends SceneTree
## Validate exported C5 clips with Godot's real skinning, independently of Blender.
const CLIPS := ["Idle","Walk","Run","Scan","Photograph","Point","RadioTalk","Escort"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use the real renderer for skin baking")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var files: Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var reports := {}
	var failed := false
	for path in files:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(path,state)==OK)
		var model:=doc.generate_scene(state, 60.0)
		root.add_child(model)
		var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
		var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		assert(skeleton.get_bone_count()==19)
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var result := {}
		for clip in CLIPS:
			assert(player.has_animation(clip))
			var duration:=player.get_animation(clip).length
			var worst:=1.0
			var floor_error:=0.0
			var floor_min:=INF
			var floor_max:=-INF
			for frame in 13:
				player.play(clip)
				player.seek(duration*float(frame)/12.0,true)
				await process_frame
				var minimum:=INF
				for node in model.find_children("*","MeshInstance3D",true,false):
					var mesh: MeshInstance3D=node
					if mesh.skin==null: continue
					var baked:=mesh.bake_mesh_from_current_skeleton_pose()
					assert(baked!=null)
					for surface in mesh.mesh.get_surface_count():
						var original:Array=mesh.mesh.surface_get_arrays(surface)
						var verts:PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
						var base:PackedVector3Array=original[Mesh.ARRAY_VERTEX]
						var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX]
						for v in verts:
							assert(v.is_finite())
							minimum=minf(minimum,(mesh.global_transform*v).y)
						for tri in range(0,indices.size(),3):
							for edge in 3:
								var a:=indices[tri+edge]
								var b:=indices[tri+(edge+1)%3]
								var length:=base[a].distance_to(base[b])
								if length>.003: worst=maxf(worst,verts[a].distance_to(verts[b])/length)
				floor_error=maxf(floor_error,absf(minimum))
				floor_min=minf(floor_min,minimum)
				floor_max=maxf(floor_max,minimum)
			var passed:=worst<=3.5 and floor_error<.002
			failed=failed or not passed
			result[clip]={"seconds":duration,"samples":13,"max_edge_stretch_over_3mm":worst,"max_ground_error_m":floor_error,"ground_range_m":[floor_min,floor_max],"passed":passed}
			print(path.get_file()," ",clip," ",result[clip])
		reports[path]=result
		model.queue_free()
		await process_frame
	var file:=FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"  "))
	quit(1 if failed else 0)
