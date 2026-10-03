extends SceneTree

## Headless checks for language persistence and live UI changes. No real saves
## or settings are written: settings point to an isolated scratch directory.
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var old_dir = GameSettings.dir
	var old_locale = GameSettings.locale
	var old_scale = GameSettings.ui_scale
	var scratch = "user://localization_test_scratch"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join(GameSettings.FILE)))
	GameSettings.online_board = true
	GameSettings.client_id = "previous-player-id"
	GameSettings.client_secret = "previous-player-secret"
	GameSettings.fullscreen = true
	GameSettings.show_hints = false
	GameSettings.load_settings()
	check(not GameSettings.online_board and GameSettings.client_id.is_empty() and GameSettings.client_secret.is_empty(), "empty settings never inherit a previous online opt-in or identity")
	check(not GameSettings.fullscreen and GameSettings.show_hints, "missing settings restore display and gameplay defaults")
	check(GameSettings.locale == "th", "existing settings without a locale default to Thai")
	var state = root.get_node("GameState")
	var campaign_before: Dictionary = state.to_dict().duplicate(true)
	var localization = root.get_node("Localization")
	L10n.set_locale("th")
	var label = Label.new()
	label.text = "ตั้งค่า"
	root.add_child(label)
	await process_frame
	var thai_width = label.get_minimum_size().x
	localization.set_language("en")
	await process_frame
	check(label.text == "ตั้งค่า" and label.tr(label.text) == "Settings", "already-open controls retain source and translate to English")
	check(not is_equal_approx(thai_width, label.get_minimum_size().x), "native Label shaping refreshes without rebuilding the scene")
	GameSettings.locale = "th"
	GameSettings.load_settings()
	check(GameSettings.locale == "en", "English preference survives a settings reload")
	var report = L10n.join([L10n.format("แปลง %d", 3), L10n.format("%d ม.", 44)])
	check(report == "แปลง 3\n44 ม.", "composed reports keep Thai canonical text")
	check(str(TranslationServer.translate(report)) == "Plot 3\n44 m", "nested parameterized report translates as a whole")
	var row = L10n.format("%d. %s · %d แปลง · ปีที่ %d · เถ้า %.0f%%", [1, "ตาโพ", 7, 2, 83.0], false)
	check(L10n.english(row) == "1. ตาโพ · 7 plots · Year 2 · Ash 83%", "player-entered names are protected even when matching a character name")
	check(L10n.english(L10n.format("%s · ปีที่ %d\n%s", ["ตาโพ", 2, "ตั้งค่า"])) == "Ta-poh · Year 2\nSettings", "ordinary dynamic arguments resolve catalog translations")
	localization.set_language("th")
	await process_frame
	check(str(TranslationServer.translate(report)) == report, "existing dynamic reports switch back to Thai")
	check(state.to_dict() == campaign_before, "language changes preserve campaign state")
	localization.set_language("unsupported")
	check(GameSettings.locale == "th" and TranslationServer.get_locale() == "th", "unsupported locale falls back to Thai")
	var config = ConfigFile.new()
	config.set_value("accessibility", "locale", "unsupported")
	config.save(scratch.path_join(GameSettings.FILE))
	GameSettings.load_settings()
	check(GameSettings.locale == "th", "malformed stored locale is validated")

	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await process_frame
	settings.language_picker.select(1)
	settings.language_picker.item_selected.emit(1)
	await process_frame
	check(GameSettings.locale == "en" and TranslationServer.get_locale() == "en", "in-game language picker applies English immediately")
	check(settings.language_picker.focus_mode == Control.FOCUS_ALL, "language picker supports keyboard/controller focus")
	check(settings.close_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "settings close button fits at 1280×720")
	GameSettings.ui_scale = 1.3
	GameSettings.apply(self)
	await process_frame
	await process_frame
	check(settings.close_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "settings remain accessible at maximum text scale")
	settings.queue_free()
	label.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch.path_join(GameSettings.FILE)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = old_dir
	GameSettings.load_settings()
	GameSettings.locale = old_locale
	GameSettings.ui_scale = old_scale
	GameSettings.apply(self)
	print("Localization: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
