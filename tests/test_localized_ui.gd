extends SceneTree

## Native logical-viewport checks: unlike a SubViewport capture, the root's
## content scale is applied, so maximum-size text gets the real smaller canvas.
class PauseFixture extends Node:
	var game_clock: Node
	var pass_started: bool = false
	var hud: Node

class ReportFixture extends Node:
	var state_scrutiny: int = 80
	var last_barn_target: float = 75.0
	var last_rice_change: float = -25.0
	var last_scrutiny_relief: int = 10
	var rice_barn: float = 45.0
	func is_crackdown() -> bool:
		return state_scrutiny >= 100
	func is_famine() -> bool:
		return rice_barn <= 20
	func is_game_over() -> bool:
		return is_crackdown() or is_famine()

var _fails: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("PASS: ", message)
	else:
		_fails += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 6:
		await process_frame

func inside(control: Control) -> bool:
	var bounds = control.get_global_rect()
	var area = root.get_visible_rect().size
	return bounds.position.x >= -0.5 and bounds.position.y >= -0.5 and bounds.end.x <= area.x + 0.5 and bounds.end.y <= area.y + 0.5

func collect_buttons(node: Node, result: Array) -> void:
	if node is Button:
		result.append(node)
	for child in node.get_children():
		collect_buttons(child, result)

func collect_names(node: Node, result: Array) -> void:
	if node is LineEdit:
		result.append(node)
	for child in node.get_children():
		collect_names(child, result)

func stop_audio_tree(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio_tree(child)

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var output = "res://artifacts/localization_20261003"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _run() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await create_timer(10.0).timeout
	await process_frame
	root.size = Vector2i(1280, 720)
	var initial_locale = TranslationServer.get_locale()
	var initial_scale = root.content_scale_factor
	var state = root.get_node("GameState")
	var before: Dictionary = state.to_dict().duplicate(true)
	for scale in [1.0, 1.3]:
		root.content_scale_factor = scale
		await settle()
		for locale in ["en", "th"]:
			root.size = Vector2i(1280, 720)
			await settle()
			L10n.set_locale(locale)
			var context = "%s scale %.1f (%s)" % [locale, scale, str(root.get_visible_rect().size)]
			var guide = load("res://ui/HowToPlay.gd").new()
			root.add_child(guide)
			await settle()
			await capture("guide_%s_scale_%d" % [locale, int(scale * 100)])
			check(inside(guide.guide_card), "guide fits logical canvas: " + context)
			check(inside(guide.close_button), "guide close button stays visible: " + context)
			check(guide.guide_columns.columns == (1 if scale > 1.0 else 2), "guide reading columns reflow: " + context)
			var horizontal_fit = true
			for label in guide.controls_grid.get_children():
				if label is Label and label.get_global_rect().end.x > guide.guide_scroll.get_global_rect().end.x + 0.5:
					horizontal_fit = false
			check(horizontal_fit, "long controls fit without horizontal clipping: " + context)
			guide.guide_scroll.grab_focus()
			var key = InputEventKey.new()
			key.keycode = KEY_END
			key.pressed = true
			guide.guide_scroll.gui_input.emit(key)
			await settle()
			var last = guide.controls_grid.get_child(guide.controls_grid.get_child_count() - 1)
			await capture("guide_controls_%s_scale_%d" % [locale, int(scale * 100)])
			check(last.get_global_rect().end.y <= guide.guide_scroll.get_global_rect().end.y + 0.5, "keyboard End reaches final control row: " + context)
			check(guide.guide_scroll.focus_next == guide.guide_scroll.get_path_to(guide.close_button), "keyboard focus can return to close button: " + context)
			guide.queue_free()
			await settle()

			var fixture = PauseFixture.new()
			root.add_child(fixture)
			var menu = load("res://ui/PauseMenu.gd").new()
			menu.main = fixture
			root.add_child(menu)
			menu.open()
			await settle()
			check(inside(menu._panel.get_child(1)), "pause menu fits: " + context)
			check(inside(menu.resume_button), "resume remains visible: " + context)
			menu.resume()
			menu.queue_free()
			fixture.queue_free()
			await settle()

			var hud = load("res://ui/HUD.gd").new()
			root.add_child(hud)
			await settle()
			var gis = PackedStringArray()
			for i in 6:
				gis.append("#%02d  18.12345°N  98.12345°E  99 TU" % i)
			gis.append(L10n.format("... และอีก %d จุด", 12))
			var report_fixture = ReportFixture.new()
			for cause in ["failed", "crackdown", "famine"]:
				report_fixture.state_scrutiny = 100 if cause == "crackdown" else 80
				report_fixture.rice_barn = 15.0 if cause == "famine" else 45.0
				hud.show_resolution_report(56, 18, true, report_fixture, 60, gis)
				await settle()
				check(inside(hud.report_modal.get_child(1)), "maximum GIS %s report fits: %s" % [cause, context])
				check(inside(hud.continue_button), "report continue remains visible: " + context)
				hud.report_scroll.grab_focus()
				hud.report_scroll.gui_input.emit(key)
				await settle()
				check(hud.report_text.get_global_rect().end.y <= hud.report_scroll.get_global_rect().end.y + 0.5, "keyboard reaches last GIS line: " + context)
				await capture("report_%s_%s_scale_%d" % [cause, locale, int(scale * 100)])
			report_fixture.free()
			hud.queue_free()
			await settle()
	# Change the scale while the guide is already open, as Settings does.
	root.content_scale_factor = 1.0
	L10n.set_locale("en")
	var guide = load("res://ui/HowToPlay.gd").new()
	root.add_child(guide)
	await settle()
	root.content_scale_factor = 1.3
	await settle()
	check(inside(guide.guide_card) and inside(guide.close_button), "open guide reflows after text scale changes")
	guide.queue_free()
	await settle()
	check(state.to_dict() == before, "UI locale/scale checks preserve campaign state")
	# Title checks use only isolated save files and disable the online board.
	var previous_save_dir = SaveGame.dir
	var previous_settings_dir = GameSettings.dir
	var previous_setting_locale = GameSettings.locale
	var previous_setting_scale = GameSettings.ui_scale
	var previous_board = GameSettings.online_board
	var previous_fullscreen = GameSettings.fullscreen
	var scratch = "user://localized_ui_title_scratch"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	SaveGame.dir = scratch
	GameSettings.dir = scratch
	GameSettings.online_board = false
	GameSettings.fullscreen = false
	for scale in [1.0, 1.3]:
		for has_save in [false, true]:
			SaveGame.delete()
			if has_save:
				SaveGame.write_atomic(scratch.path_join(SaveGame.CAMPAIGN_FILE), JSON.stringify({"version": SaveGame.VERSION, "campaign": before}))
			GameSettings.ui_scale = scale
			GameSettings.locale = "th"
			root.size = Vector2i(1280, 720)
			var title = load("res://scenes/Title.tscn").instantiate()
			root.add_child(title)
			await settle()
			for locale in ["th", "en"]:
				L10n.set_locale(locale)
				await settle()
				var context = "title %s scale %.1f save %s" % [locale, scale, str(has_save)]
				check(title.continue_button.visible == has_save, "continue follows saved campaign: " + context)
				var reached_all = true
				for button in title._menu.get_children():
					if button is Button and button.visible:
						button.grab_focus()
						await settle()
						if not inside(button) or not title.menu_scroll.get_global_rect().encloses(button.get_global_rect()):
							reached_all = false
				check(reached_all, "keyboard/controller can expose every menu button: " + context)
				check(inside(title.quit_button), "quit stays reachable: " + context)
				var settings = title._menu.get_child(3)
				check(settings.tr(settings.text) == ("Settings" if locale == "en" else "ตั้งค่า / Settings"), "English language discovery is visible: " + context)
				(title.continue_button if has_save else title.new_button).grab_focus()
				await settle()
				await capture("title_%s_scale_%d_save_%s" % [locale, int(scale * 100), str(has_save)])
				if scale == 1.0 and has_save:
					await capture("title_" + locale)
			title.queue_free()
			await settle()
	# Exercise both full ending lifecycles with isolated finished campaigns.
	var previous_name = GameSettings.player_name
	GameSettings.player_name = "Localization tester"
	for scale in [1.0, 1.3]:
		root.size = Vector2i(1280, 720)
		root.content_scale_factor = scale
		await settle()
		for cause in ["crackdown", "famine"]:
			for locale in ["th", "en"]:
				L10n.set_locale(locale)
				state.from_dict(before.duplicate(true))
				state.current_year = 6
				state.rice_barn = 15.0 if cause == "famine" else 66.0
				state.state_scrutiny = 100 if cause == "crackdown" else 74
				state.stats.plots_completed = 27
				state.stats.ash_sum = 2052.0
				state.stats.campaign_id = "ending_%s_%s_%s" % [cause, locale, str(scale)]
				SaveGame.write_atomic(scratch.path_join(SaveGame.CAMPAIGN_FILE), JSON.stringify({"version": SaveGame.VERSION, "campaign": before}))
				var ending = load("res://scenes/Ending.tscn").instantiate()
				root.add_child(ending)
				await settle()
				ending.set_process(false)
				ending._t = 15.1
				ending._process(0.0)
				await settle()
				var context = "%s ending %s scale %.1f" % [cause, locale, scale]
				check(ending.cause == cause and not SaveGame.exists(), "ending records and removes finished save: " + context)
				check(inside(ending._caption), "long ending caption fits: " + context)
				check(inside(ending._skip_hint), "ending skip hint fits: " + context)
				await capture("ending_caption_%s_%s_scale_%d" % [cause, locale, int(scale * 100)])
				ending.show_summary()
				await settle()
				check(inside(ending.summary_card), "ending summary fits: " + context)
				# Simulate the async rank result without any network request/account.
				ending.summary_online_label.text = L10n.format("อันดับออนไลน์ #%d (เบตา)", 999)
				ending.summary_online_label.show()
				await settle()
				check(inside(ending.summary_card), "async online rank cannot overflow summary: " + context)
				var buttons = []
				collect_buttons(ending.summary_card, buttons)
				var footer_visible = buttons.size() == 2
				for button in buttons:
					button.grab_focus()
					await settle()
					footer_visible = footer_visible and inside(button)
				check(footer_visible, "ending retry/title buttons stay visible: " + context)
				var names = []
				collect_names(ending.summary_card, names)
				var name_reachable = names.size() == 1
				for name in names:
					name.grab_focus()
					await settle()
					name_reachable = name_reachable and inside(name) and ending.summary_scroll.get_global_rect().encloses(name.get_global_rect()) and name.text == "Localization tester"
				check(name_reachable, "ending name remains editable and untranslated: " + context)
				ending.summary_scroll.grab_focus()
				var end = InputEventKey.new()
				end.keycode = KEY_END
				end.pressed = true
				ending.summary_scroll.gui_input.emit(end)
				await settle()
				check(ending.summary_online_label.get_global_rect().end.y <= ending.summary_scroll.get_global_rect().end.y + 0.5, "keyboard reaches final ending rank line: " + context)
				await capture("ending_summary_%s_%s_scale_%d" % [cause, locale, int(scale * 100)])
				ending.queue_free()
				await settle()
	state.from_dict(before.duplicate(true))
	state.stats = before.stats.duplicate(true)
	GameSettings.player_name = previous_name
	SaveGame.delete()
	for file in [SaveGame.RECORDS_FILE, SaveGame.RECORDS_FILE + ".bak", SaveGame.RECORDS_FILE + ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	SaveGame.dir = previous_save_dir
	GameSettings.dir = previous_settings_dir
	GameSettings.locale = previous_setting_locale
	GameSettings.ui_scale = previous_setting_scale
	GameSettings.online_board = previous_board
	GameSettings.fullscreen = previous_fullscreen
	check(state.to_dict() == before, "title save fixtures never alter the campaign")
	root.content_scale_factor = initial_scale
	L10n.set_locale(initial_locale)
	var audio = root.get_node("AudioManager")
	audio.stop_all_loops()
	audio.set_process(false)
	stop_audio_tree(audio)
	await create_timer(0.1).timeout
	print("Localized UI: %d checks, %d failures" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
