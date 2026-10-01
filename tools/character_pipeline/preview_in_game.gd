extends SceneTree
## Show the installed characters in the real game scene. Space resumes normal play.
## godot --path . --script tools/character_pipeline/preview_in_game.gd

var game: Node3D
var camera: Camera3D
var original_transform: Transform3D
var original_fov: float
var previewing := true
var caption: CanvasLayer
var model_rotations: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 8:
		await process_frame
	paused = true
	camera = game.get_node("Camera3D")
	original_transform = camera.global_transform
	original_fov = camera.fov
	var elder: Node3D = game.get_node("Elder")
	var youth: Node3D = game.get_node("Youth")
	var player: Node3D = game.get_node("Player")
	var center := (elder.global_position + youth.global_position) * 0.5 + Vector3(0, 0.8, 0)
	camera.global_position = center + Vector3(0.0, 2.6, -6.0)
	camera.fov = 60.0
	camera.look_at(center)
	# Pose only the preview toward the camera; restore the gameplay facing on resume.
	for actor in [elder, player, youth]:
		var model: Node3D = actor.animator
		model_rotations[model] = model.rotation
		model.rotation.y = PI
	# The player's tools normally follow facing during physics; this view is paused.
	var tools: Node3D = player._tool_rig
	model_rotations[tools] = tools.rotation
	tools.rotation.y = PI
	game.get_node("HUD").hide()
	caption = CanvasLayer.new()
	root.add_child(caption)
	var label := Label.new()
	label.text = "KHA-NAE + TA-POH + MU-NAW  |  Installed models in the hillside scene\nSPACE: resume gameplay and normal camera"
	label.position = Vector2(24, 22)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	caption.add_child(label)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://artifacts/character_expansion_20261001/deliverables/in_game.png"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	var error := root.get_texture().get_image().save_png(output)
	print("In-game character preview saved: ", output, " error=", error)

func _process(_delta: float) -> bool:
	if previewing and camera != null and Input.is_physical_key_pressed(KEY_SPACE):
		camera.global_transform = original_transform
		camera.fov = original_fov
		for model in model_rotations:
			model.rotation = model_rotations[model]
		game.get_node("HUD").show()
		caption.queue_free()
		paused = false
		previewing = false
	return false
