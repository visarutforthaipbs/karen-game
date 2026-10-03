extends SceneTree
## Actual Hearth integration: focused preparation controls and responsive layout.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var scratch = "user://village_presentation_test_%d" % Time.get_ticks_usec()
	SaveGame.dir = scratch
	GameSettings.dir = scratch
	PlaytestLog.dir = scratch
	DirAccess.make_dir_recursive_absolute(scratch)
	GameSettings.load_settings()
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play = true
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var hearth = load("res://scenes/VillageHearth.tscn").instantiate()
	view.add_child(hearth)
	for i in 12: await process_frame
	check(hearth.find_children("*", "VillageDiorama", true, false).is_empty(), "Preparation must not instantiate the decorative village")
	for button in hearth.find_children("*", "Button", true, false):
		check(button.text != "ดูหมู่บ้าน", "Preparation must not expose the removed inspection action")
	var campaign: Dictionary = state.to_dict().duplicate(true)
	var output = OS.get_cmdline_user_args()
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output[0])
	for locale in ["en", "th"]:
		L10n.set_locale(locale)
		for channel in [1, 2, 3]:
			hearth.radio_buttons[channel - 1].pressed.emit()
			check(hearth.current_radio_channel == channel and not hearth.radio_text.text.is_empty(), "Radio channel controls stopped working")
		hearth._tune_radio(1, false)
		for resolution in [Vector2i(1280, 720), Vector2i(960, 720), Vector2i(1280, 600)]:
			view.size = resolution
			hearth.size = resolution
			for i in 12: await process_frame
			check(hearth.launch_button.get_global_rect().end.y <= resolution.y + .5, "Launch action falls below screen")
			check(hearth._card_columns.size.x <= hearth._card_scroll.size.x + .5, "Preparation cards clip horizontally")
			check(hearth.settings_button.get_global_rect().end.x <= resolution.x + .5, "Header actions clip horizontally")
			check(hearth._card_scroll.position.y < 180, "Decorative banner still displaces preparation controls")
			check(hearth.ration_buttons.size() == 3 and hearth.favour_buttons.size() == 3, "Preparation choices are missing")
			if not output.is_empty() and resolution == Vector2i(1280, 720) and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				view.get_texture().get_image().save_png(output[0].path_join("preparation_" + locale + ".png"))
	check(state.to_dict() == campaign, "Browsing preparation changed campaign choices")
	view.queue_free()
	for i in 3: await process_frame
	root.get_node("AudioManager").stop_all_loops()
	for file in DirAccess.get_files_at(scratch):
		DirAccess.remove_absolute(scratch.path_join(file))
	DirAccess.remove_absolute(scratch)
	print("VILLAGE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
