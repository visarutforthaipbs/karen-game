extends SceneTree
## Native game screenshots at 1280×720 with isolated saves and staged state.
## These are layout review fixtures, not player performance evidence.
var vp: SubViewport
var output: String
var findings: Array = []
var current: Node
var thai_re := RegEx.new()

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 8) -> void:
	for i in count:
		await process_frame

func clear() -> void:
	if is_instance_valid(current):
		current.queue_free()
	await frames(3)

func inspect(node: Node, screen: String) -> void:
	if node is Label or node is Button:
		if node.is_visible_in_tree() and not node.text.is_empty():
			var rendered: String = node.tr(node.text)
			if TranslationServer.get_locale() == "en" and thai_re.search(rendered):
				findings.append({"screen": screen, "source": node.text, "rendered": rendered})
	for child in node.get_children():
		inspect(child, screen)

func snap(name: String, settle_frames: int = 12) -> void:
	await frames(settle_frames)
	inspect(current, name)
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(output.path_join(name + ".png"))
	print("CAPTURE ", name)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "res://artifacts/localization_20261003"
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	SaveGame.dir = output.path_join("capture_save")
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	GameSettings.load_settings()
	GameSettings.ui_scale = 1.0
	GameSettings.online_board = false
	GameSettings.player_name = "Kha-nae"
	thai_re.compile("[\\x{0E00}-\\x{0E7F}]")
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	var gs = root.get_node("GameState")
	var audio = root.get_node("AudioManager")
	for locale in ["en", "th"]:
		L10n.set_locale(locale)
		GameSettings.locale = locale
		gs.reset_campaign()
		gs.seen_how_to_play = true
		current = load("res://scenes/Title.tscn").instantiate()
		vp.add_child(current)
		await snap("title_" + locale)
		await clear()
		current = load("res://ui/HowToPlay.gd").new()
		vp.add_child(current)
		await snap("guide_" + locale)
		await clear()
		current = load("res://scenes/VillageHearth.tscn").instantiate()
		vp.add_child(current)
		current._tune_radio(2, false)
		await snap("village_" + locale)
		current._show_harvest({"year": 7, "next_year": 8, "yields": [75.0, 76.0, 81.0, 79.0, 78.0], "average": 77.8, "rice_delta": 10.0, "scrutiny_relief": 45, "next_rules": Escalation.rules_for_year(8).headlines()})
		await snap("harvest_" + locale)
		await clear()
		gs.reset_campaign()
		current = load("res://scenes/Main.tscn").instantiate()
		vp.add_child(current)
		await frames(15)
		current.game_clock.is_running = false
		current.game_clock.current_sim_time_seconds = 16 * 3600 + 20 * 60
		current._on_clock_ticked("16:20", 16, 20)
		Input.warp_mouse(Vector2(900, 360))
		current.hud.set_process(false)
		for panel in current.hud._fade_targets:
			panel.modulate.a = 1.0
		await snap("gameplay_" + locale)
		var caption = load("res://scripts/VoiceSubtitles.gd").new()
		audio.add_child(caption)
		# Reuse the production caption Controls in this offscreen viewport.
		# Moving the surface avoids a CanvasLayer custom-viewport engine quirk.
		var caption_surface: Control = caption.get_child(0)
		caption_surface.reparent(vp)
		caption_surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		caption_surface.size = Vector2(vp.size)
		audio.stop_all_loops()
		# A staged, exact recording transcript for deterministic layout review.
		var line: Dictionary = audio.voice_captions["radio_ch1_01.wav"]
		caption._caption_changed(line.speaker, line.th, 4.0)
		await snap("subtitles_" + locale, 2)
		caption_surface.queue_free()
		caption.queue_free()
		audio.stop_all_loops()
		current.hud.show_resolution_report(72.0, 3, false, gs, 15,
			PackedStringArray(["#01 18.72000°N 98.40000°E 40 TU"]))
		await snap("report_" + locale)
		await clear()
		audio.stop_all_loops()
	var report = FileAccess.open(output.path_join("translation_review.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"untranslated_visible_text": findings}, "\t"))
	print("Translation review: ", findings.size(), " unresolved visible strings")
	vp.queue_free()
	await frames(3)
	quit(0 if findings.is_empty() else 1)
