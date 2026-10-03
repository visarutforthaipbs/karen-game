extends SceneTree

## Native geometry/focus and feedback regression. Uses isolated settings/saves.
## Run without --fixed-fps: warning lifetimes deliberately use wall time.
var failures: int = 0

func check(ok: bool, message: String) -> void:
	print("PASS  " if ok else "FAIL  ", message)
	if not ok: failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var original_dirs = [GameSettings.dir, SaveGame.dir, PlaytestLog.dir]
	var original_locale = GameSettings.locale
	var original_scale = root.content_scale_factor
	var sandbox = "user://test_gameplay_ui_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	GameSettings.dir = sandbox
	SaveGame.dir = sandbox
	PlaytestLog.dir = sandbox
	var state = root.get_node("GameState")
	var audio = root.get_node("AudioManager")
	var caption_resize_connections = audio.subtitle_overlay.card.resized.get_connections().size()
	var caption_visibility_connections = audio.subtitle_overlay.card.visibility_changed.get_connections().size()
	state.reset_campaign()
	state.seen_how_to_play = true
	# Avoid first-burn timers changing the diagnostic tip.
	state.current_year = 4
	change_scene_to_file("res://scenes/Main.tscn")
	for frame in 6: await process_frame
	var main = current_scene
	var hud = main.hud
	main.game_clock.pause_clock()
	hud.show_tip(FirstBurnTips.TIPS.start, 0.15)
	hud.show_alert("ลูกไฟตกในป่า!", 0.15)
	paused = true
	await create_timer(0.30).timeout
	check(hud.tip_card.visible and hud.alert_card.visible and hud.hint_label.visible, "pause preserves tutorial instruction and alert reading time")
	paused = false
	await create_timer(0.70).timeout
	check(not hud.tip_card.visible and not hud.alert_card.visible, "tutorial tip and alert expire after gameplay resumes")
	var streams: Array = audio._tapoh_voices.duplicate()
	for pool in audio._radio_voices.values(): streams.append_array(pool)
	for pool in audio._bark_voices.values(): streams.append_array(pool)
	var speech_index = 0
	for locale in ["th", "en"]:
		L10n.set_locale(locale)
		for scale in [1.0, 1.3]:
			root.content_scale_factor = scale
			for frame in 8: await process_frame
			var phases: Array = main.PHASES.duplicate()
			phases.append({"title": "ระยะ 5 · ดาวเทียมโคจรผ่าน (20:00)"})
			for phase in phases:
				hud.update_phase(phase.title, "")
				for frame in 6: await process_frame
				check(hud.phase_label.get_visible_line_count() == hud.phase_label.get_line_count() and hud.status_card.get_global_rect().encloses(hud.phase_label.get_global_rect()), "%s %.1f ongoing phase instruction fully visible: %s" % [locale, scale, hud.phase_label.tr(hud.phase_label.text)])
			hud.show_tip(FirstBurnTips.TIPS.spray)
			for stream in streams:
				audio.stop_all_loops()
				speech_index += 1
				audio._play_speech("ui_geometry_%d" % speech_index, stream, Vector3.INF, -2.0, 10)
				for frame in 6: await process_frame
				var caption = audio.subtitle_overlay.card.get_global_rect()
				var tip = hud.tip_card.get_global_rect()
				if stream == streams[0]:
					print("GEOMETRY ", locale, " ", scale, " caption=", caption, " tip=", tip, " visible=", audio.subtitle_overlay.card.visible)
				check(audio.subtitle_overlay.card.visible and not caption.intersects(tip) and tip.end.y <= caption.position.y - 11.0 and tip.position.y >= 0.0, "%s %.1f instructional tip clears %s" % [locale, scale, stream.resource_path.get_file()])
				for control in [hud.tool_col, hud.crew_row, hud.vitals_card]:
					check(not caption.intersects(control.get_global_rect()), "%s %.1f caption clears %s for %s" % [locale, scale, control.name, stream.resource_path.get_file()])
			audio.stop_all_loops()
			for frame in 5: await process_frame
			check(is_equal_approx(hud.tip_card.get_global_rect().end.y, hud.root.size.y - 64.0), "%s %.1f tip returns to original position after speech" % [locale, scale])
			hud._update_refill_guidance()
			if hud._refill_marker_obscured():
				check(not hud.refill_marker.visible, "%s %.1f world refill cue stays behind instructional overlays" % [locale, scale])
			var original_marker = hud.refill_marker.position
			hud.refill_marker.position = hud.tip_card.position + Vector2(40, 30)
			check(hud._refill_marker_obscured(), "%s %.1f projected refill cue detects tip occlusion" % [locale, scale])
			hud.refill_marker.position = original_marker

	root.content_scale_factor = 1.0
	for frame in 5: await process_frame
	L10n.set_locale("en")
	root.content_scale_factor = 1.3
	for frame in 6: await process_frame
	hud.show_elder_wind_warning(Vector2.RIGHT, 2.0)
	hud.show_drone_alert(L10n.format("เจ้าหน้าที่เห็นทีมอยู่ข้างกองไฟ! · ความเพ่งเล็ง +%d", 7), true, true)
	hud.show_alert("ลูกไฟตกในป่าอุทยาน! รีบฉีดน้ำดับภายใน 8 วินาที ก่อนไฟลาม", 10.0)
	audio._play_speech("dense_ui_priority", streams[3], Vector3.INF, -2.0, 10)
	hud.show_tip(FirstBurnTips.TIPS.spray, 0.3)
	for frame in 8: await process_frame
	var remaining: float = hud._tip_remaining
	await create_timer(0.45).timeout
	check(not hud.tip_card.visible and hud._tip_requested and is_equal_approx(hud._tip_remaining, remaining), "dense warning/caption stack defers tutorial without losing reading time")
	for warning in [hud.elder_warning_banner, hud.drone_banner, hud.alert_card]: warning.hide()
	for frame in 6: await process_frame
	check(hud.tip_card.visible, "deferred tutorial returns when danger stack clears")
	await create_timer(0.4).timeout
	check(not hud.tip_card.visible and not hud._tip_requested, "deferred tutorial expires after its visible reading duration")
	audio.stop_all_loops()

	# Real nested focus scopes, including Settings over an outer modal, hide
	# captions without modifying audio or resurrecting finished dialogue.
	GameSettings.online_board = false
	audio._play_speech("modal_caption_live", streams[3], Vector3.INF, -2.0, 10)
	var modal = Control.new()
	hud.root.add_child(modal)
	var scope = ModalFocusScope.begin(modal)
	check(not audio.subtitle_overlay.card.visible and not audio.subtitle_overlay.line_label.text.is_empty() and audio.speech_player.playing, "modal suspends caption presentation while retaining live recording")
	var settings = load("res://ui/SettingsPanel.gd").new()
	modal.add_child(settings)
	check(audio.subtitle_overlay._modal_depth == 2, "real Settings nests caption suppression in outer modal")
	settings.close()
	check(not audio.subtitle_overlay.card.visible and audio.subtitle_overlay._modal_depth == 1, "closing Settings keeps outer-modal caption suppression")
	scope.release()
	check(audio.subtitle_overlay.card.visible and audio.subtitle_overlay._modal_depth == 0, "closing final modal restores ongoing caption")
	scope.release()
	check(audio.subtitle_overlay._modal_depth == 0, "idempotent focus-scope release cannot unbalance caption nesting")
	modal.queue_free()
	await process_frame
	for clear_method in ["finish", "language"]:
		audio.stop_all_loops()
		audio._play_speech("modal_caption_clear_" + clear_method, streams[3], Vector3.INF, -2.0, 10)
		modal = Control.new()
		hud.root.add_child(modal)
		scope = ModalFocusScope.begin(modal)
		if clear_method == "finish":
			audio.speech_player.stop()
			for frame in 3: await process_frame
		else:
			L10n.set_locale("th")
		scope.release()
		check(not audio.subtitle_overlay.card.visible and audio.subtitle_overlay.line_label.text.is_empty(), "modal close cannot resurrect caption cleared by " + clear_method)
		modal.queue_free()
		await process_frame
	audio.stop_all_loops()
	root.content_scale_factor = 1.0
	for frame in 6: await process_frame
	hud.show_drone_alert("กำลังถ่ายภาพจุดร้อน", true)
	hud.show_elder_wind_warning(Vector2.RIGHT, 1.0)
	# Put the actual pointer over the warning. Passive panels still get out of
	# the playfield, but time-sensitive danger information must stay readable.
	root.warp_mouse(hud.banner_stack.get_global_rect().get_center())
	hud._process(1.0)
	check(hud.banner_stack.modulate.a >= 0.99 and not hud._fade_targets.has(hud.banner_stack), "danger banners remain readable under pointer")
	root.warp_mouse(hud.status_card.get_global_rect().get_center())
	hud._process(1.0)
	check(hud.status_card.modulate.a < 0.2, "passive status panel still fades under pointer")
	await create_timer(4.5).timeout
	hud.show_drone_alert("เจ้าหน้าที่เห็นขะแน", true, true)
	hud.show_elder_wind_warning(Vector2.UP, 2.0)
	await create_timer(0.75).timeout
	check(hud.drone_banner.visible and hud.drone_text.text == "เจ้าหน้าที่เห็นขะแน", "older drone timer cannot hide newer ranger warning")
	await create_timer(2.0).timeout
	check(hud.elder_warning_banner.visible, "older wind timer cannot hide newer wind warning")
	await create_timer(1.45).timeout
	paused = true
	await create_timer(1.5).timeout
	check(hud.drone_banner.visible and hud.elder_warning_banner.visible, "gameplay warnings retain remaining time while burn is paused")
	paused = false
	await create_timer(1.05).timeout
	check(not hud.drone_banner.visible and hud.elder_warning_banner.visible, "latest warnings retain distinct five/seven-second lifetimes")
	await create_timer(2.0).timeout
	check(not hud.elder_warning_banner.visible, "latest wind warning eventually clears")

	state.state_scrutiny = 100
	hud.show_resolution_report(75.0, 2, false, state)
	for frame in 6: await process_frame
	check(hud.continue_button.text == "ดูบทสรุปของหมู่บ้าน", "game-over report names its actual village-outcome destination")
	for step in 8:
		var event = InputEventAction.new()
		event.action = "ui_focus_next"
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		var focus = root.gui_get_focus_owner()
		check(focus != null and hud.report_modal.is_ancestor_of(focus), "report keyboard focus stays inside modal")
	check(hud.pause_menu.focus_mode == Control.FOCUS_NONE, "report excludes underlying pause UI from focus")
	if hud._report_focus_scope:
		hud._report_focus_scope.release()
	audio.stop_all_loops()
	current_scene.queue_free()
	await process_frame
	check(audio.subtitle_overlay._gameplay_bottom_limit < 0.0, "leaving burn restores ordinary subtitle margin")
	await create_timer(0.15).timeout
	check(audio.subtitle_overlay.card.resized.get_connections().size() == caption_resize_connections, "leaving burn removes persistent caption resize listener")
	check(audio.subtitle_overlay.card.visibility_changed.get_connections().size() == caption_visibility_connections, "leaving burn removes persistent caption visibility listener")
	GameSettings.dir = original_dirs[0]
	SaveGame.dir = original_dirs[1]
	PlaytestLog.dir = original_dirs[2]
	GameSettings.locale = original_locale
	L10n.set_locale(original_locale)
	root.content_scale_factor = original_scale
	for file in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	print("Gameplay UI failures: ", failures)
	quit(1 if failures else 0)
