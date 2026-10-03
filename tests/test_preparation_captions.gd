extends SceneTree

## Persistent accepted speech must leave the preparation choices scrollable.
var checks := 0
var failures := 0

func _initialize() -> void:
	var scratch = "user://preparation_captions_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	SaveGame.dir = scratch
	PlaytestLog.dir = scratch
	GameSettings.load_settings()
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func settle() -> void:
	for i in 10: await process_frame

func _run() -> void:
	await process_frame
	var state = root.get_node("GameState")
	var audio = root.get_node("AudioManager")
	var before = state.to_dict().duplicate(true)
	state.reset_campaign()
	state.seen_how_to_play = true
	state.current_year = 4
	var caption = audio.subtitle_overlay.card
	var initial_minimum_connections = caption.minimum_size_changed.get_connections().size()
	var initial_visibility_connections = caption.visibility_changed.get_connections().size()
	var initial_voice_connections = audio.voice_caption_changed.get_connections().size()
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await settle()
	var hearth = current_scene
	hearth.chatter_timer.stop()
	var streams: Array = []
	for pool in audio._radio_voices.values(): streams.append_array(pool)
	check(streams.size() == 14, "geometry covers all 14 approved radio recordings")
	var sequence := 0
	for physical in [Vector2i(1280, 720), Vector2i(1280, 800)]:
		root.size = physical
		for scale in [1.0, 1.3]:
			root.content_scale_factor = scale
			for locale in ["th", "en"]:
				L10n.set_locale(locale)
				await settle()
				var context = "%s %s scale%.1f" % [locale, physical, scale]
				var viewport = Rect2(Vector2.ZERO, root.get_visible_rect().size)
				var idle_bottom: float = hearth._card_scroll.get_global_rect().end.y
				var launch_before = hearth.launch_button.get_global_rect()
				var all_clear := true
				var all_accepted := true
				for stream in streams:
					audio.stop_all_loops()
					sequence += 1
					audio._play_speech("prep_geometry_%d" % sequence, stream, Vector3.INF, -2.0, 10)
					await settle()
					var card_rect = caption.get_global_rect()
					var scroll_rect = hearth._card_scroll.get_global_rect()
					all_accepted = all_accepted and caption.visible and audio.speech_player.playing
					all_clear = all_clear and scroll_rect.end.y <= card_rect.position.y - 1.0 and not card_rect.intersects(hearth.launch_button.get_global_rect()) and viewport.encloses(card_rect) and hearth.launch_button.get_global_rect().is_equal_approx(launch_before)
				check(all_accepted, context + " all 14 approved broadcasts retain accepted visible captions")
				check(all_clear, context + " radio clears scroll choices and pinned Launch")
				# Live minimum-height growth must reserve the rewrapped caption too.
				var long_th = "ทดสอบคำบรรยายที่ยาวขึ้นเพื่อให้เห็นการเว้นพื้นที่เหนือปุ่มเริ่มทำไร่ ".repeat(5)
				var long_en = "A longer caption checks that preparation choices remain visible while the line wraps above the launch action. ".repeat(5)
				L10n.register_message(long_th, long_en)
				audio.voice_caption_changed.emit("ตาโพ", long_th, 30.0)
				await settle()
				check(caption.size.y > 80.0 and hearth._caption_reservation.size.y >= caption.size.y - 1.0 and hearth._card_scroll.get_global_rect().end.y < caption.get_global_rect().position.y, context + " taller caption grows reservation without covering choices")
				for button in [hearth.ration_buttons[GameState.Ration.FULL], hearth.favour_buttons[GameState.Favour.SEEDS]]:
					button.grab_focus()
					await settle()
					check(hearth._card_scroll.get_global_rect().grow(1.0).encloses(button.get_global_rect()), context + " focus reveals ration/mutual-aid action while subtitle visible")
				hearth.show_settings()
				await settle()
				check(not caption.visible and not hearth._caption_reservation.visible, context + " modal hides caption and releases reservation")
				hearth.settings_panel.close()
				await settle()
				check(caption.visible and hearth._caption_reservation.visible and hearth._card_scroll.get_global_rect().end.y < caption.get_global_rect().position.y, context + " closing modal restores caption clearance")
				audio.stop_all_loops()
				await settle()
				print("CLEAR_GEOMETRY ", context, " idle=", idle_bottom, " current=", hearth._card_scroll.get_global_rect().end.y, " caption=", caption.visible, " reservation=", hearth._caption_reservation.visible)
				check(not caption.visible and not hearth._caption_reservation.visible and is_equal_approx(hearth._card_scroll.get_global_rect().end.y, idle_bottom), context + " clearing line restores full scroll body")
				check(viewport.encloses(hearth.launch_button.get_global_rect()) and hearth.launch_button.get_global_rect().is_equal_approx(launch_before), context + " Launch remains pinned through speech and modal transitions")
	current_scene.queue_free()
	await settle()
	check(caption.minimum_size_changed.get_connections().size() == initial_minimum_connections and caption.visibility_changed.get_connections().size() == initial_visibility_connections and audio.voice_caption_changed.get_connections().size() == initial_voice_connections, "leaving preparation removes all persistent caption listeners")
	state.from_dict(before)
	for file in DirAccess.get_files_at(GameSettings.dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.dir))
	await create_timer(0.2).timeout
	print("Preparation captions: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
