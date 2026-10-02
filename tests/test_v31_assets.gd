extends SceneTree
## All installed v3.1 exports retain geometry, textures, weighted skins and clips.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var counts := {"Khanae":14394,"Tapoh":19900,"Munaw":13957,"Maelu":19900}
	for name in counts:
		var actor = load("res://scenes/characters/"+name+"Chibi.tscn").instantiate()
		root.add_child(actor)
		actor.set_process(false)
		await process_frame
		var triangles := 0
		check(actor.skeleton.get_bone_count() == (21 if name in ["Munaw","Maelu"] else 19),name+": calibrated bone count")
		for clip in ["Idle","Walk","Run","ToolUse"]:
			check(actor.animation_player.has_animation(clip),name+": missing "+clip)
		if name == "Maelu":
			for clip in ["Talk","Granary"]: check(actor.animation_player.has_animation(clip),"Mae-Lu missing village gesture")
		for mesh in actor.find_children("*","MeshInstance3D",true,false):
			if mesh.skin == null: continue
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				triangles += arrays[Mesh.ARRAY_INDEX].size()/3
				check(weights.size() == vertices.size()*4,name+": four skin influences")
				for i in vertices.size():
					var total := 0.0
					for j in 4: total += weights[4*i+j]
					check(absf(total-1)<.0001,name+": normalized exported weights")
				var material: BaseMaterial3D = mesh.get_active_material(surface)
				check(material.albedo_texture != null,name+": preserved texture")
				check(arrays[Mesh.ARRAY_TEX_UV].size() == vertices.size(),name+": preserved UVs")
		check(triangles == counts[name],name+": geometry unchanged by rigging")
		if name == "Munaw":
			check(actor._carried_tool != null and actor._hose != null,"Mu-naw has independent suppression equipment")
		print("Checked ",name," triangles=",triangles)
		actor.queue_free()
		await process_frame
	print("V31 ASSETS: ",failures," failures")
	quit(1 if failures else 0)
