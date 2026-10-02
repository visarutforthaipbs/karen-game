extends SceneTree
## Real Godot surface renders, identical cameras, lighting and material for each candidate.
## godot --path . --script tools/character_pipeline_v2/render_benchmark.gd -- manifest.json output.png
var panels: Array[SubViewport] = []
var output: String
var tile = 320
const LABEL = 32
var columns = 4

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() > 3:
		push_error("Expected manifest.json output.png [tile_pixels]")
		quit(1)
		return
	output = args[1]
	if args.size() == 3:
		tile = clampi(int(args[2]), 128, 1024)
	var records = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not records is Array:
		quit(1)
		return
	var sheet = SubViewport.new()
	sheet.size = Vector2i(tile * columns, (tile + LABEL) * records.size())
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var base = Control.new()
	sheet.add_child(base)
	var bg = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10)
	bg.size = Vector2(sheet.size)
	base.add_child(bg)
	for row in records.size():
		var record = records[row]
		for col in columns:
			var container = SubViewportContainer.new()
			container.position = Vector2(col * tile, row * (tile + LABEL) + LABEL)
			base.add_child(container)
			var vp = SubViewport.new()
			vp.size = Vector2i(tile, tile)
			vp.own_world_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.msaa_3d = Viewport.MSAA_4X
			container.add_child(vp)
			panels.append(vp)
			var world = Node3D.new()
			vp.add_child(world)
			var doc = GLTFDocument.new()
			var state = GLTFState.new()
			if doc.append_from_file(record.path, state) != OK:
				push_error("Cannot import " + record.path)
				quit(1)
				return
			var model = doc.generate_scene(state)
			if record.get("ranger_equipment",false):
				var ranger := Node3D.new()
				ranger.set_script(load("res://scenes/characters/RangerRig.gd"))
				ranger.autoplay_idle=false
				ranger.add_child(model)
				model=ranger
			if record.get("runtime", false):
				var actor := Node3D.new()
				actor.set_script(load("res://scripts/SkeletalChibiAnimator.gd"))
				actor.character_profile = record.character
				actor.separate_equipment = true
				actor.base_scale = 1.0
				actor.add_child(model)
				world.add_child(actor)
				if record.character == "khanae":
					var tool := MeshInstance3D.new()
					tool.mesh = AssetLibrary.mesh_or("T3",LowPoly.tool_mesh("rake"))
					actor.get_hand_socket().add_child(tool)
				actor.set_work(StringName(record.get("work", "")), record.get("work", "") != "")
				for step in 24:
					actor.update_animation(1.0/30.0, Vector3(0,0,float(record.get("speed",0))), Vector3.FORWARD*-1)
				await process_frame
				actor.update_animation(0, Vector3.ZERO, Vector3.FORWARD*-1)
			else:
				world.add_child(model)
			if record.has("animation"):
				var players = model.find_children("*", "AnimationPlayer", true, false)
				if players.is_empty() or not players[0].has_animation(record.animation):
					push_error("Missing preview animation: " + str(record.animation))
					quit(1)
					return
				var player: AnimationPlayer = players[0]
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				if model.has_method("play_clip"): model.play_clip(record.animation,0)
				player.play(record.animation)
				player.seek(float(record.get("time", 0.0)), true)
			if record.get("vertex_material", true):
				apply_material(model)
			if record.get("silhouette", false):
				apply_silhouette(model)
			var env_node = WorldEnvironment.new()
			var env = Environment.new()
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.10, 0.12, 0.15)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color.WHITE
			env.ambient_light_energy = 0.65
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env_node.environment = env
			world.add_child(env_node)
			var light = DirectionalLight3D.new()
			light.rotation_degrees = Vector3(-40, -35, 0)
			light.light_energy = 0.8
			world.add_child(light)
			var camera = Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = float(record.get("camera_size", 1.65))
			world.add_child(camera)
			var angle = deg_to_rad([0.0, 45.0, 90.0, 180.0][col])
			var target_y = float(record.get("target_y", 0.6))
			camera.position = Vector3(sin(angle) * 3.0, target_y + 0.12, cos(angle) * 3.0)
			camera.look_at(Vector3(0, target_y, 0))
			var title = Label.new()
			title.text = "%s | %s" % [record.label, ["Front (+Z)", "45 degrees", "Side", "Back (-Z)"][col]]
			title.position = Vector2(col * tile + 8, row * (tile + LABEL) + 5)
			title.size = Vector2(tile - 16, LABEL - 6)
			title.clip_text = true
			title.add_theme_font_size_override("font_size", 15)
			base.add_child(title)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img = sheet.get_texture().get_image()
	var result = img.save_png(output)
	print("Benchmark image: ", output, " error=", result)
	quit(0 if result == OK else 1)

func apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.85
		for s in node.mesh.get_surface_count():
			node.set_surface_override_material(s, mat)
	for child in node.get_children():
		apply_material(child)

func apply_silhouette(node: Node) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.8, 0.8, 0.8)
		node.material_override = mat
	for child in node.get_children():
		apply_silhouette(child)
