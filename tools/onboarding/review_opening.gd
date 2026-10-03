extends SceneTree

## Native-renderer review of every teaching state, with isolated player settings.
## godot --path . --script res://tools/onboarding/review_opening.gd
var output := "res://artifacts/opening_20261003/review"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var old_dir = GameSettings.dir
	GameSettings.dir = "user://opening_visual_review/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameSettings.dir))
	GameSettings.load_settings()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var film = OpeningFilm.new()
	viewport.add_child(film)
	await process_frame
	film.toggle_pause()
	for locale in ["th", "en"]:
		root.get_node("Localization").set_language(locale)
		for frame in [[0, 0.5], [1, 0.8], [2, 0.5], [3, 0.6], [4, 0.5], [5, 0.6], [6, 0.55], [7, 0.8]]:
			film._start_cue(int(frame[0]))
			film._transition.modulate.a = 0
			film.diorama.set_frame(int(frame[0]), float(frame[1]), 0.1)
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output.path_join("%s_%02d.png" % [locale, frame[0]]))
	film._finish()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("en_summary.png"))
	# Steam Deck-sized logical viewport at maximum text scaling.
	viewport.size = Vector2i(985, 554)
	film._fit_layout()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("en_compact_summary.png"))
	film.close()
	await process_frame
	viewport.queue_free()
	GameSettings.dir = old_dir
	GameSettings.load_settings()
	root.get_node("Localization").set_language(GameSettings.locale)
	root.get_node("AudioManager").stop_all_loops()
	await process_frame
	print("Opening review frames: ", ProjectSettings.globalize_path(output))
	quit()
