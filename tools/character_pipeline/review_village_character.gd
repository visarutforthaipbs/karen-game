extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("GameState").seen_how_to_play = true
	var vp := SubViewport.new()
	vp.size = Vector2i(1440,960)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var village = load("res://scenes/VillageHearth.tscn").instantiate()
	vp.add_child(village)
	for i in 30: await process_frame
	assert(village.maelu_portrait.character != null)
	village.maelu_portrait.granary_gesture()
	assert(village.maelu_portrait.character.animation_player.current_animation == "Granary")
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://artifacts/character_rigs_v31/maelu_granary.png")
	print("PASS: Mae-Lu live granary portrait and gesture")
	vp.queue_free()
	await process_frame
	quit()
