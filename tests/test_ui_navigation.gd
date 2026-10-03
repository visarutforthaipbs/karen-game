extends SceneTree

## Real keyboard/controller navigation across overlays, using isolated state.
## godot --headless --path . --script res://tests/test_ui_navigation.gd
class PauseFixture extends Node:
	var game_clock: Node
	var pass_started: bool = false
	var hud: Node
	var scans: int = 0

	func _on_satellite_pass() -> void:
		scans += 1
		pass_started = true

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ", message)
	if not ok:
		failures += 1

func settle() -> void:
	for i in 6:
		await process_frame

func key(code: int, shift: bool = false) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func joy(button: int) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func find_script(node: Node, path: String) -> Node:
	if node.get_script() == load(path):
		return node
	for child in node.get_children():
		var found = find_script(child, path)
		if found:
			return found
	return null

func collect_buttons(node: Node, output: Array) -> void:
	if node is Button:
		output.append(node)
	for child in node.get_children():
		collect_buttons(child, output)

func focused_inside(modal: Control) -> bool:
	var owner = root.gui_get_focus_owner()
	return owner != null and (owner == modal or modal.is_ancestor_of(owner))

func cycle_inside(modal: Control, context: String) -> void:
	var contained = true
	for reverse in [false, true]:
		for i in 32:
			await key(KEY_TAB, reverse)
			contained = contained and focused_inside(modal)
	for direction in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await joy(direction)
		contained = contained and focused_inside(modal)
	check(contained, context + " contains Tab, Shift-Tab and controller directional focus")

func _run() -> void:
	await process_frame
	var old_settings_dir = GameSettings.dir
	var old_save_dir = SaveGame.dir
	var old_log_dir = PlaytestLog.dir
	var old_scale = root.content_scale_factor
	var old_locale = TranslationServer.get_locale()
	var state = root.get_node("GameState")
	var old_state: Dictionary = state.to_dict().duplicate(true)
	var sandbox = "user://ui_navigation_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	GameSettings.dir = sandbox
	SaveGame.dir = sandbox
	PlaytestLog.dir = sandbox
	GameSettings.load_settings()
	GameSettings.locale = "en"
	GameSettings.fullscreen = false
	root.size = Vector2i(1280, 720)
	state.reset_campaign()
	state.seen_how_to_play = true
	state.rice_barn = 47.0
	state.current_year = 3
	SaveGame.save(state)
	var saved_before = FileAccess.get_file_as_string(sandbox.path_join(SaveGame.CAMPAIGN_FILE))
	var campaign_before: Dictionary = state.to_dict().duplicate(true)

	var title = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	await settle()
	title.new_button.grab_focus()
	await key(KEY_ENTER)
	check(is_instance_valid(title._overlay), "keyboard opens saved-game replacement confirmation")
	if is_instance_valid(title._overlay):
		var confirmation: Control = title._overlay
		title._on_new_game()
		check(title._overlay == confirmation and state.to_dict() == campaign_before and FileAccess.get_file_as_string(sandbox.path_join(SaveGame.CAMPAIGN_FILE)) == saved_before, "repeated New Game cannot bypass confirmation or mutate campaign/save")
		await cycle_inside(confirmation, "new-game confirmation")
		await key(KEY_ESCAPE)
		check(not is_instance_valid(title._overlay), "Escape cancels replacement confirmation")
		check(state.to_dict() == campaign_before and FileAccess.get_file_as_string(sandbox.path_join(SaveGame.CAMPAIGN_FILE)) == saved_before, "confirmation browsing and cancellation preserve existing save")
		check(root.gui_get_focus_owner() == title.new_button, "confirmation cancellation restores its opener")

	var title_settings: Button = title._menu.get_child(3)
	title_settings.grab_focus()
	await joy(JOY_BUTTON_A)
	var settings = find_script(title, "res://ui/SettingsPanel.gd")
	check(settings != null, "controller A opens Settings from title")
	if settings:
		await cycle_inside(settings, "title Settings")
		var settings_buttons: Array = []
		collect_buttons(settings, settings_buttons)
		for button in settings_buttons:
			if button.text == "แสดงวิธีเล่นอีกครั้ง":
				button.grab_focus()
		await joy(JOY_BUTTON_A)
		await settle()
		var guide = find_script(title, "res://ui/HowToPlay.gd")
		check(guide != null, "Settings can transition to guide")
		if guide:
			check(title.new_button.focus_mode == Control.FOCUS_NONE and title.continue_button.focus_mode == Control.FOCUS_NONE, "Settings-to-guide transition keeps underlying title disabled after deferred teardown")
			await cycle_inside(guide, "replacement guide")
			await joy(JOY_BUTTON_B)
			check(not is_instance_valid(guide), "controller B closes guide")
		check(title.new_button.focus_mode != Control.FOCUS_NONE and title_settings.focus_mode != Control.FOCUS_NONE, "closing sibling guide restores title focus modes")
	check(state.to_dict() == campaign_before, "title overlay navigation preserves campaign state")
	title.queue_free()
	await settle()

	var hearth = load("res://scenes/VillageHearth.tscn").instantiate()
	root.add_child(hearth)
	root.content_scale_factor = 1.3
	await settle()
	var prep_visible = true
	var prep_buttons = 0
	for i in 18:
		await key(KEY_TAB)
		var owner = root.gui_get_focus_owner()
		if owner is Button and hearth._card_columns.is_ancestor_of(owner):
			prep_buttons += 1
			prep_visible = prep_visible and hearth._card_scroll.get_global_rect().grow(1.0).encloses(owner.get_global_rect())
	check(prep_buttons >= 10 and prep_visible, "prep automatically exposes every focused ration, upgrade and mutual-aid choice at maximum UI scale")
	hearth.settings_button.grab_focus()
	hearth.show_settings()
	await settle()
	if hearth.settings_panel:
		await cycle_inside(hearth.settings_panel, "prep Settings")
		await joy(JOY_BUTTON_B)
		check(hearth.settings_panel == null, "controller B closes prep Settings")
		check(root.gui_get_focus_owner() == hearth.settings_button, "prep Settings restores originating settings button")
	hearth.queue_free()
	await settle()
	root.content_scale_factor = 1.0

	var fixture = PauseFixture.new()
	root.add_child(fixture)
	var menu = load("res://ui/PauseMenu.gd").new()
	menu.main = fixture
	root.add_child(menu)
	menu.open()
	await settle()
	check(paused and menu.visible, "pause freezes gameplay")
	var pause_settings: Button = menu._pause_box.get_child(3)
	pause_settings.grab_focus()
	await joy(JOY_BUTTON_A)
	check(menu._sub != null, "controller A opens paused Settings")
	if menu._sub:
		await cycle_inside(menu._sub, "paused Settings")
		await joy(JOY_BUTTON_B)
		check(menu._sub == null and menu.visible and paused, "Back closes only paused Settings and leaves pause active")
		check(menu.resume_button.focus_mode != Control.FOCUS_NONE and root.gui_get_focus_owner() == pause_settings, "nested scope restores pause controls and originating Settings focus")
		await joy(JOY_BUTTON_A)
		var paused_settings_buttons: Array = []
		collect_buttons(menu._sub, paused_settings_buttons)
		for button in paused_settings_buttons:
			if button.text == "แสดงวิธีเล่นอีกครั้ง":
				button.grab_focus()
		await joy(JOY_BUTTON_A)
		var paused_guide = find_script(menu, "res://ui/HowToPlay.gd")
		check(paused_guide != null and paused and menu.resume_button.focus_mode == Control.FOCUS_NONE, "paused Settings-to-guide replacement keeps pause controls disabled")
		if paused_guide:
			await cycle_inside(paused_guide, "paused replacement guide")
			await joy(JOY_BUTTON_B)
			check(menu._sub == null and paused and menu.visible, "controller B closes paused replacement guide exactly one level")
			check(menu.resume_button.focus_mode != Control.FOCUS_NONE and root.gui_get_focus_owner() == pause_settings, "paused replacement guide restores originating Settings focus")
		await cycle_inside(menu, "pause menu")
	var surrender: Button = menu._pause_box.get_child(4)
	surrender.grab_focus()
	await joy(JOY_BUTTON_A)
	check(menu._sub != null and paused and fixture.scans == 0, "controller A opens surrender confirmation without scanning")
	if menu._sub:
		await cycle_inside(menu._sub, "surrender confirmation")
		await joy(JOY_BUTTON_B)
		check(menu._sub == null and menu.visible and paused and fixture.scans == 0, "controller B cancels surrender one level without changing gameplay")
		check(root.gui_get_focus_owner() == surrender, "surrender cancellation restores destructive action's opener")
	var quit_button: Button = menu._pause_box.get_child(6)
	quit_button.grab_focus()
	await joy(JOY_BUTTON_A)
	check(menu._sub != null and paused, "quit-to-title requires confirmation")
	await key(KEY_ESCAPE)
	check(menu._sub == null and menu.visible and paused, "Escape cancels quit-to-title without leaving pause")
	surrender.grab_focus()
	await joy(JOY_BUTTON_A)
	if menu._sub:
		var confirmation_buttons: Array = []
		collect_buttons(menu._sub, confirmation_buttons)
		check(confirmation_buttons.size() == 2 and root.gui_get_focus_owner() == confirmation_buttons[0], "destructive confirmation initially focuses safe Cancel")
		confirmation_buttons[1].grab_focus()
		await joy(JOY_BUTTON_A)
		check(fixture.scans == 1 and not paused and not menu.visible and menu._sub == null, "controller A confirms exactly one surrender scan and resumes")
	fixture.pass_started = false
	menu.open()
	await settle()
	await joy(JOY_BUTTON_B)
	check(not paused and not menu.visible, "controller B resumes from pause")
	menu.resume()
	menu.queue_free()
	fixture.queue_free()
	await settle()

	state.from_dict(old_state)
	root.get_node("AudioManager").stop_all_loops()
	GameSettings.dir = old_settings_dir
	SaveGame.dir = old_save_dir
	PlaytestLog.dir = old_log_dir
	GameSettings.load_settings()
	L10n.set_locale(old_locale)
	root.content_scale_factor = old_scale
	for file in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	await settle()
	print("UI navigation: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
