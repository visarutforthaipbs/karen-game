extends SceneTree
## Installed Kha-nae, actual player tools and terrain. Captures a deterministic demo.
## godot --path . --script tools/character_pipeline/preview_rig_in_game.gd -- output_dir
var game: Node3D
var hero: Node3D
var label: Label
var output: String
var viewport: SubViewport

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "res://artifacts/khanae_rigging/demo"
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	game = load("res://scenes/Main.tscn").instantiate()
	viewport.add_child(game)
	for i in 8:
		await process_frame
	paused = true
	hero = game.get_node("Player").animator
	hero.rotation.y = 0
	var player: AnimationPlayer = hero.animation_player
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	game.get_node("HUD").hide()
	var camera: Camera3D = game.get_node("Camera3D")
	var center: Vector3 = hero.global_position + Vector3(0, 0.8, 0)
	camera.position = center + Vector3(1.9, 1.0, 3.5)
	camera.fov = 42
	camera.look_at(center)
	var canvas := CanvasLayer.new()
	viewport.add_child(canvas)
	label = Label.new()
	label.position = Vector2(25, 20)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	var clips := ["Idle", "Walk", "ToolUse"]
	for part in 3:
		var clip: String = clips[part]
		label.text = "KHA-NAE  |  " + clip + "  |  19-bone rig + hand-attached tool"
		player.play(clip, 0)
		for frame in 48:
			var duration: float = player.get_animation(clip).length
			player.seek(fmod(float(frame) / 24.0, duration), true)
			hero.skeleton.force_update_all_bone_transforms()
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot := viewport.get_texture().get_image()
			var path := output.path_join("frame_%04d.png" % (part * 48 + frame))
			if screenshot.save_png(path) != OK:
				quit(1)
				return
	print("Rig demo frames: ", output)
	viewport.queue_free()
	paused = false
	for i in 3:
		await process_frame
	quit(0)
