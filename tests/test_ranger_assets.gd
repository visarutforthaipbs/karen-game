extends SceneTree
## C5 delivery contract consumed by RangerFigure; no patrol rules are modified.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var expected:={"Idle":2.4,"Walk":.8,"Run":2.0/3.0,"Scan":3.2,"Photograph":2.0,"Point":1.6,"RadioTalk":2.4,"Escort":28.0/30.0}
	for name in ["RangerChibi","RangerSlateChibi"]:
		var actor=load("res://scenes/characters/"+name+".tscn").instantiate()
		root.add_child(actor)
		await process_frame
		assert(actor.skeleton.get_bone_count()==19)
		assert(actor._tablet.mesh!=null and actor._flashlight.mesh!=null)
		var triangles:=0
		for node in actor.find_children("*","MeshInstance3D",true,false):
			if node.skin==null: continue
			for surface in node.mesh.get_surface_count():
				triangles+=node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
				assert(node.get_active_material(surface).albedo_texture!=null)
		assert(triangles==18522)
		for clip in expected:
			assert(actor.animation_player.has_animation(clip))
			assert(absf(actor.animation_player.get_animation(clip).length-expected[clip])<.0001,"Variant retimed "+clip)
		actor.update_animation(.016,Vector3(0,0,1.2))
		assert(actor.animation_player.current_animation=="Walk")
		actor.play_clip("Photograph",0)
		assert(actor._tablet.visible and not actor._flashlight.visible)
		actor.update_animation(.016,Vector3.ZERO)
		assert(actor.animation_player.current_animation=="Photograph")
		actor.play_clip("Idle",0)
		assert(not actor._tablet.visible and actor._flashlight.visible)
		print(name,": 19 bones, 18,522 triangles, 8 timed clips, locomotion API and equipment passed")
		actor.queue_free()
		await process_frame
	assert(RangerFigure.has_model())
	var patrol_model:=RangerFigure.create(true)
	root.add_child(patrol_model)
	await process_frame
	var beam: SpotLight3D=patrol_model.find_children("Flashlight","SpotLight3D",true,false)[0]
	assert(beam.get_parent()==patrol_model._flashlight,"Patrol beam must follow the held flashlight")
	patrol_model.queue_free()
	await process_frame
	for character in ["khanae","tapoh","munaw","maelu","ranger"]:
		var portrait:=(load("res://assets/ui/portraits/"+character+"_256.png") as Texture2D).get_image()
		assert(portrait.get_size()==Vector2i(256,256) and portrait.detect_alpha()!=Image.ALPHA_NONE)
	assert((load("res://assets/ui/title/satellite_shadow_blue_hour_1920x1080.png") as Texture2D).get_image().get_size()==Vector2i(1920,1080))
	print("C5/U3/U6 asset contract passed")
	quit()
