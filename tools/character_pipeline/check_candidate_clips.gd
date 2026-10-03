extends SceneTree
## Real renderer review of every candidate clip, including Talk and both ranger palettes.
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use the project renderer for skin baking")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var report:Dictionary={}
	var failed:=false
	for character in manifest:
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		assert(doc.append_from_file(manifest[character],state)==OK)
		var model:=doc.generate_scene(state, 60.0)
		root.add_child(model)
		var player:AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var mesh_nodes=model.find_children("*","MeshInstance3D",true,false)
		var worst:=1.0
		var clip_reports:Dictionary={}
		var worst_clip:=""
		for clip in player.get_animation_list():
			if clip=="RESET":continue
			var clip_worst:=1.0
			var ground_error:=0.0
			player.play(clip)
			for frame in 13:
				player.seek(player.get_animation(clip).length*frame/12.0,true)
				await process_frame
				var floor_y:=INF
				for mesh in mesh_nodes:
					if mesh.skin==null:continue
					var baked:ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose()
					assert(baked!=null)
					for surface in mesh.mesh.get_surface_count():
						var original:Array=mesh.mesh.surface_get_arrays(surface)
						var base:PackedVector3Array=original[Mesh.ARRAY_VERTEX]
						var posed:PackedVector3Array=baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
						var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX]
						for vertex in posed:
							assert(vertex.is_finite())
							floor_y=minf(floor_y,(mesh.global_transform*vertex).y)
						for tri in range(0,indices.size(),3):
							for edge in 3:
								var a:=indices[tri+edge]
								var b:=indices[tri+(edge+1)%3]
								var length:=base[a].distance_to(base[b])
								if length<=.003:continue
								var ratio:=posed[a].distance_to(posed[b])/length
								clip_worst=maxf(clip_worst,ratio)
								if ratio>worst:
									worst=ratio
									worst_clip=clip
				ground_error=maxf(ground_error,absf(floor_y))
			clip_reports[clip]={"worst_edge_stretch":clip_worst,"passed":clip_worst<=3.5 and ground_error<.002,"max_ground_error_m":ground_error,"seconds":player.get_animation(clip).length}
			failed=failed or ground_error>=.002
		report[character]={"worst_edge_stretch":worst,"clip":worst_clip,"passed":worst<=3.5,"clips":clip_reports}
		for result in clip_reports.values():report[character].passed=report[character].passed and result.passed
		failed=failed or worst>3.5
		model.queue_free()
		await process_frame
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(1 if failed else 0)
