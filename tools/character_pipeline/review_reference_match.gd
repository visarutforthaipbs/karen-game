extends SceneTree
## Compare a locked design with exported models at identical cameras/lighting.
## Args: [{label,reference} or {label,path,animation?}], output.png
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var sheet := SubViewport.new()
	sheet.size = Vector2i(512*rows.size(), 960)
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var references: Array = []
	var base := Control.new()
	sheet.add_child(base)
	var background := ColorRect.new()
	background.color = Color(.10,.12,.15)
	background.size = Vector2(sheet.size)
	base.add_child(background)
	for column in rows.size():
		var row: Dictionary = rows[column]
		var label := Label.new()
		label.text = row.label
		label.position = Vector2(column*512+12,8)
		label.add_theme_font_size_override("font_size",20)
		base.add_child(label)
		for closeup in 2:
			var origin := Vector2(column*512,40 if closeup==0 else 564)
			var dimensions := Vector2i(512,512 if closeup==0 else 384)
			if row.has("reference"):
				var texture := ImageTexture.create_from_image(Image.load_from_file(row.reference))
				var picture := TextureRect.new()
				if closeup==1:
					var crop := AtlasTexture.new()
					crop.atlas=texture
					crop.region=Rect2(335,135,355,260)
					picture.texture=crop
				else: picture.texture=texture
				picture.position=origin
				picture.size=Vector2(dimensions)
				picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				base.add_child(picture)
				references.append({"node":picture,"origin":origin,"dimensions":dimensions})
				continue
			var container := SubViewportContainer.new()
			container.position=origin
			base.add_child(container)
			var view := SubViewport.new()
			view.size=dimensions
			view.own_world_3d=true
			view.msaa_3d=Viewport.MSAA_4X
			view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			container.add_child(view)
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			assert(doc.append_from_file(row.path,state)==OK)
			var model := doc.generate_scene(state)
			view.add_child(model)
			if row.has("animation"):
				var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
				player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				player.play(row.animation)
				player.seek(0,true)
			var environment := WorldEnvironment.new()
			environment.environment=Environment.new()
			environment.environment.background_mode=Environment.BG_COLOR
			environment.environment.background_color=background.color
			environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color=Color.WHITE
			environment.environment.ambient_light_energy=.65
			view.add_child(environment)
			var light := DirectionalLight3D.new()
			light.rotation_degrees=Vector3(-30,-25,0)
			light.light_energy=.85
			view.add_child(light)
			var camera := Camera3D.new()
			camera.projection=Camera3D.PROJECTION_ORTHOGONAL
			camera.size=1.30 if closeup==0 else .46
			view.add_child(camera)
			var target := Vector3(0,.6 if closeup==0 else .91,0)
			camera.position=target+Vector3(0,0,3)
			camera.look_at(target)
	for i in 3: await process_frame
	for reference in references:
		reference.node.position=reference.origin
		reference.node.size=Vector2(reference.dimensions)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	assert(sheet.get_texture().get_image().save_png(args[1])==OK)
	quit()
