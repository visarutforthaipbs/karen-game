extends SceneTree

## Native runtime regression for localized gameplay text. No player saves touched.
## godot --headless --path . --fixed-fps 60 --script res://tests/test_localized_gameplay.gd
var failures: int = 0
var visited: int = 0

func check(condition: bool, message: String) -> void:
	print("PASS  " if condition else "FAIL  ", message)
	if not condition:
		failures += 1

func has_thai(value: String) -> bool:
	for character in value:
		var code = character.unicode_at(0)
		if code >= 0x0E01 and code <= 0x0E5B:
			return true
	return false

func scan_controls(node: Node, context: String) -> void:
	if node is Label or node is Button:
		var translated: String = node.tr(node.text)
		if has_thai(translated):
			check(false, context + " untranslated control: " + translated)
		visited += 1
	for child in node.get_children():
		scan_controls(child, context)

func check_hearth_layout(hearth: Node, scale: float) -> void:
	root.content_scale_factor = scale
	for i in 6:
		await process_frame
	hearth._fit_layout()
	for i in 6:
		await process_frame
	var viewport_width: float = hearth.get_viewport_rect().size.x
	check(hearth.settings_button.get_global_rect().end.x <= viewport_width + 1.0, "English header fits viewport at UI scale %.1f" % scale)
	check(hearth._card_columns.size.x <= hearth._card_scroll.size.x + 1.0, "English card grid avoids horizontal clipping at UI scale %.1f" % scale)
	check(hearth.launch_button.get_global_rect().end.y <= hearth.get_viewport_rect().size.y + 1.0, "launch action remains pinned inside viewport at UI scale %.1f" % scale)
	var last_favour: Control = hearth.favour_buttons[2]
	hearth._card_scroll.scroll_vertical = 0
	hearth.launch_button.grab_focus()
	for i in range(24):
		var event = InputEventAction.new()
		event.action = "ui_focus_next"
		event.pressed = true
		Input.parse_input_event(event)
		for frame in 3: await process_frame
		if last_favour.has_focus(): break
	check(last_favour.has_focus(), "keyboard navigation reaches final mutual-aid choice at UI scale %.1f" % scale)
	var clip: Rect2 = hearth._card_scroll.get_global_rect()
	var item: Rect2 = last_favour.get_global_rect()
	check(item.position.y >= clip.position.y - 1.0 and item.end.y <= clip.end.y + 1.0, "last mutual-aid choice reachable by vertical scrolling at UI scale %.1f" % scale)
	# D-pad navigation must also reveal controls without a wheel or explicit
	# ensure_control_visible call from this test.
	hearth._card_scroll.scroll_vertical = 0
	hearth.radio_buttons[0].grab_focus()
	for i in range(4):
		var gamepad = InputEventJoypadButton.new()
		gamepad.button_index = JOY_BUTTON_DPAD_DOWN
		gamepad.pressed = true
		Input.parse_input_event(gamepad)
		for frame in 3: await process_frame
		gamepad.pressed = false
		Input.parse_input_event(gamepad)
	var focused: Control = root.gui_get_focus_owner()
	if focused and hearth._card_columns.is_ancestor_of(focused):
		check(hearth._card_scroll.get_global_rect().encloses(focused.get_global_rect()), "controller focus scrolls its preparation action into view at UI scale %.1f" % scale)

func check_harvest_layout(hearth: Node, state: Node, locale: String, scale: float, outcome: String) -> void:
	L10n.set_locale(locale)
	root.content_scale_factor = scale
	for i in 6:
		await process_frame
	state.rice_barn = 15.0 if outcome == "famine" else 80.0
	state.state_scrutiny = 100 if outcome == "crackdown" else 40
	var fixture = {"year": 7, "yields": [75.0, 65.0, 80.0, 70.0, 90.0], "average": 76.0, "rice_delta": 15.0, "scrutiny_relief": 30, "next_year": 8, "next_rules": Escalation.rules_for_year(8).headlines()}
	state.pending_harvest = fixture.duplicate(true)
	hearth._show_harvest(fixture)
	for i in 8:
		await process_frame
	var context = "%s %.1f %s harvest" % [locale, scale, outcome]
	var area: Rect2 = hearth.get_viewport_rect()
	var card: Rect2 = hearth._harvest_card.get_global_rect()
	var action: Rect2 = hearth.harvest_button.get_global_rect()
	check(area.encloses(card) and card.size.y <= area.size.y - 38.0, context + " entire modal bounded by viewport")
	check(card.encloses(action) and action.end.y <= area.end.y - 18.0, context + " action stays visible below scroll body")
	check(hearth._harvest_content.size.x <= hearth._harvest_scroll.size.x + 1.0, context + " narrative has no horizontal overflow")
	check(hearth._harvest_content.get_child(2).get_child_count() == 5, context + " includes five-yield breakdown and summary")
	check(hearth.launch_button.focus_mode == Control.FOCUS_NONE and hearth.settings_button.focus_mode == Control.FOCUS_NONE, context + " modal excludes underlying preparation actions from focus")
	for step in 6:
		var tab = InputEventAction.new()
		tab.action = "ui_focus_next"
		tab.pressed = true
		Input.parse_input_event(tab)
		await process_frame
		var focus = root.gui_get_focus_owner()
		check(focus and hearth._harvest_modal.is_ancestor_of(focus), context + " Tab remains in harvest focus scope")
	hearth.harvest_button.grab_focus()
	check(not hearth._can_chatter() and hearth.chatter_timer.is_stopped(), context + " annual report delays background speech")
	var scroll: ScrollContainer = hearth._harvest_scroll
	var max_scroll = int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	if max_scroll > 0:
		var key = InputEventKey.new()
		key.keycode = KEY_DOWN
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		check(scroll.scroll_vertical > 0, context + " keyboard scrolls narrative while action focused")
		key.pressed = false
		Input.parse_input_event(key)
		for step in range(20):
			var gamepad = InputEventJoypadButton.new()
			gamepad.button_index = JOY_BUTTON_DPAD_DOWN
			gamepad.pressed = true
			Input.parse_input_event(gamepad)
			await process_frame
			gamepad.pressed = false
			Input.parse_input_event(gamepad)
			await process_frame
		var clip = scroll.get_global_rect()
		var content = hearth._harvest_content.get_global_rect()
		check(content.end.y <= clip.end.y + 1.0, context + " controller reaches final narrative line")
		check(hearth.harvest_button.has_focus(), context + " continue action remains focused during scrolling")
	check(state.pending_harvest == fixture, context + " browsing preserves pending harvest")
	var headline = hearth._harvest_content.get_child(1) as Label
	check(headline.text.contains("ไม่พอกิน") == (outcome == "famine"), context + " famine headline appears only for famine")
	var callback = Callable(hearth, "_close_harvest" if outcome == "success" else "_end_campaign")
	check(hearth.harvest_button.pressed.is_connected(callback), context + " uses correct continue or ending callback")
	if locale == "en":
		scan_controls(hearth._harvest_modal, context)
	hearth._harvest_modal.queue_free()
	hearth._harvest_modal = null
	hearth._harvest_card = null
	hearth._harvest_scroll = null
	hearth._harvest_content = null
	await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var original_settings_dir = GameSettings.dir
	var original_save_dir = SaveGame.dir
	var original_log_dir = PlaytestLog.dir
	var original_locale: String = GameSettings.locale
	var original_scale = root.content_scale_factor
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	var sandbox = "user://test_localized_gameplay_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	GameSettings.dir = sandbox
	SaveGame.dir = sandbox
	PlaytestLog.dir = sandbox
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play = true
	L10n.set_locale("en")

	# All plot names/descriptions and surveillance years must resolve independently.
	for year in [1, 2, 3, 4, 8]:
		for line in Escalation.rules_for_year(year).headlines():
			check(not has_thai(L10n.english(line)), "year %d surveillance headline" % year)
	for plot in range(1, 7):
		var config = PlotGenerator.get_plot_config(4, plot)
		check(not has_thai(L10n.english(config.name)) and not has_thai(L10n.english(config.description)), "plot %d name and description" % plot)

	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await process_frame
	await process_frame
	var hearth = current_scene
	await check_hearth_layout(hearth, 1.0)
	await check_hearth_layout(hearth, 1.3)
	root.content_scale_factor = 1.0
	for i in 4: await process_frame
	scan_controls(hearth, "initial hearth")
	for year in [1, 4]:
		state.current_year = year
		state.current_plot_index = 5
		state.favours = {0: true, 1: true, 2: true}
		state.ration_level = 2
		hearth._refresh()
		for channel in [1, 2, 3]:
			hearth._tune_radio(channel, false)
			check(not has_thai(hearth.radio_text.tr(hearth.radio_text.text)), "year %d radio channel %d" % [year, channel])
		scan_controls(hearth, "prepared year %d hearth" % year)
	var snapshot = [state.current_year, state.current_plot_index, state.rice_barn, state.state_scrutiny, state.favours.duplicate()]
	var radio_source: String = hearth.radio_text.text
	L10n.set_locale("th")
	await process_frame
	check(hearth.radio_text.tr(radio_source) == radio_source, "live Thai restores original radio text")
	L10n.set_locale("en")
	await process_frame
	check(not has_thai(hearth.radio_text.tr(radio_source)), "live English restores translated radio text")
	check(snapshot == [state.current_year, state.current_plot_index, state.rice_barn, state.state_scrutiny, state.favours], "language change preserves campaign state")

	var harvest = {"year": 4, "yields": [75.0, 65.0, 80.0, 70.0, 90.0], "average": 76.0, "rice_delta": 15.0, "scrutiny_relief": 30, "next_year": 5, "next_rules": Escalation.rules_for_year(5).headlines()}
	hearth._show_harvest(harvest)
	scan_controls(hearth._harvest_modal, "harvest")
	check(hearth.harvest_button.tr(hearth.harvest_button.text) == "Begin year 5", "harvest advances with English year label")
	hearth._close_harvest()
	await process_frame
	for locale in ["en", "th"]:
		for scale in [1.0, 1.3]:
			for outcome in ["success", "famine", "crackdown"]:
				await check_harvest_layout(hearth, state, locale, scale, outcome)
	state.rice_barn = 80.0
	state.state_scrutiny = 40
	state.pending_harvest = {}
	root.content_scale_factor = 1.0
	L10n.set_locale("en")

	# Real burn controller: dynamic alerts, phase joins, countdown and companion names.
	state.current_year = 4
	state.current_plot_index = 5
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	paused = true
	check(not has_thai(L10n.english(main.hud.alert_label.text)), "labour-delay intro composes English")
	main._update_phase(19 * 60 + 45)
	check(not has_thai(L10n.english(main.hud.alert_label.text)), "countdown phase alert composes English")
	main._on_companion_coughing(main.elder)
	check(not has_thai(L10n.english(main.hud.alert_label.text)), "elder cough alert translates display name")
	main._on_companion_coughing(main.youth)
	check(not has_thai(L10n.english(main.hud.alert_label.text)), "youth cough alert translates display name")
	main._on_ranger_spotted(Vector3.ZERO, true)
	main._on_ranger_spotted(Vector3.ZERO, false)
	main._on_satellite_closing(5)
	check(not has_thai(L10n.english(main.hud.alert_label.text)), "satellite countdown alert translates")
	check(main.elder.display_name() == "ตาโพ" and main.youth.display_name() == "มูนอ", "localization preserves internal companion identity")

	paused = false
	if current_scene:
		current_scene.queue_free()
	await process_frame
	GameSettings.dir = original_settings_dir
	SaveGame.dir = original_save_dir
	PlaytestLog.dir = original_log_dir
	GameSettings.locale = original_locale
	root.content_scale_factor = original_scale
	L10n.set_locale(original_locale)
	for file in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	print("Localized gameplay controls inspected: ", visited, "; failures: ", failures)
	quit(1 if failures else 0)
