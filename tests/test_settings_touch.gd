extends SceneTree

## Regression: actual screen-touch events, not value assignment or signal emission.
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + label)
func settle() -> void:
	for i in 8: await process_frame
func finger(pos: Vector2, down: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.index = index
	e.pressed = down
	Input.parse_input_event(e)
func drag(pos: Vector2, relative: Vector2, index: int = 0) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	e.relative = relative
	e.index = index
	Input.parse_input_event(e)
func tap(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	finger(pos, true)
	await process_frame
	finger(pos, false)
	await settle()
func find_sliders(node: Node) -> Array:
	var found := []
	if node is HSlider: found.append(node)
	for child in node.get_children(): found.append_array(find_sliders(child))
	return found
func set_with_finger(slider: HSlider, fraction: float) -> void:
	var rect := slider.get_global_rect()
	var pos := rect.position + rect.size * Vector2(fraction, 0.5)
	finger(pos, true)
	await process_frame
	finger(pos, false)
	await settle()
func run() -> void:
	root.size = Vector2i(1561, 720) if OS.get_cmdline_user_args().has("--notch") else Vector2i(1280, 720)
	if OS.get_cmdline_user_args().has("--notch"):
		UITheme.debug_insets = {"left": 59.0, "right": 59.0, "bottom": 21.0, "top": 0.0}
	await settle()
	var settings = load("res://scripts/GameSettings.gd")
	var previous_dir: String = settings.dir
	settings.dir = "user://test_settings_touch"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(settings.dir))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.dir.path_join("settings.cfg")))
	settings.load_settings()
	var panel = load("res://ui/SettingsPanel.gd").new()
	root.add_child(panel)
	await settle()
	var slider: HSlider = find_sliders(panel)[0]
	var rect := slider.get_global_rect()
	if UITheme.is_mobile():
		check(rect.size.y >= UITheme.TOUCH_MIN, "volume slider has a full finger-sized hit area")
		var body_rect: Rect2 = panel._content_scroll.get_global_rect()
		for s in find_sliders(panel.tab_panes[0]):
			check(body_rect.grow(1).encloses(s.get_global_rect()), "entire audio slider hit area fits inside Settings body")
		var has_fullscreen := false
		for button in panel.find_children("*", "CheckButton", true, false):
			has_fullscreen = has_fullscreen or button.text == "เต็มจอ"
		check(has_fullscreen == not panel._handheld_os(), "fullscreen control is available only on touch PCs, not handhelds")
		var pos := rect.position + rect.size * Vector2(0.25, 0.5)
		finger(pos, true)
		await process_frame
		check(slider.value < 0.5, "finger tap changes volume from 100 percent")
		var end := rect.position + rect.size * Vector2(0.7, 0.5)
		drag(end, end - pos)
		await process_frame
		finger(end, false)
		await settle()
		check(slider.value > 0.5 and slider.value < 0.9, "finger drag changes volume continuously")
		check(is_equal_approx(settings.volumes["Master"], slider.value), "touch value reaches GameSettings")
		# Same input while paused: the Settings overlay must still own the finger.
		paused = true
		var sound_sliders := find_sliders(panel.tab_panes[0])
		for i in sound_sliders.size():
			var s: HSlider = sound_sliders[i]
			await set_with_finger(s, 0.3)
			var bus: String = settings.VOLUME_BUSES[i][0]
			check(s.value > 0.0 and s.value < 0.5 and is_equal_approx(settings.volumes[bus], s.value), "%s responds to touch while paused" % bus)
			var bus_id := AudioServer.get_bus_index(bus)
			check(bus_id >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(bus_id), linear_to_db(s.value)), "%s changes the actual mixer bus" % bus)
		paused = false
		# A second finger cannot steal the slider, nor can it end finger 0's drag.
		var start := rect.position + rect.size * Vector2(0.3, 0.5)
		finger(start, true)
		await process_frame
		var owned := slider.value
		finger(rect.position + rect.size * Vector2(0.8, 0.5), true, 1)
		await process_frame
		check(is_equal_approx(slider.value, owned), "second finger cannot steal the slider")
		finger(rect.position + rect.size * Vector2(0.8, 0.5), false, 1)
		drag(rect.position + rect.size * Vector2(0.7, 0.5), Vector2(60, 0))
		await process_frame
		check(slider.value > 0.5, "first finger keeps dragging after second finger releases")
		# Drag outside the hit rectangle still clamps to the full range.
		drag(rect.position + Vector2(-100, rect.size.y * 0.5), Vector2(-500, 0))
		await process_frame
		check(is_equal_approx(slider.value, slider.min_value), "drag outside left clamps at zero")
		drag(rect.end + Vector2(100, -rect.size.y * 0.5), Vector2(1000, 0))
		await process_frame
		check(is_equal_approx(slider.value, slider.max_value), "drag outside right clamps at maximum")
		finger(start, false)
		await settle()
		# Cancellation releases ownership without applying its final position.
		finger(start, true)
		await process_frame
		owned = slider.value
		var canceled := InputEventScreenTouch.new()
		canceled.position = rect.end
		canceled.index = 0
		canceled.pressed = false
		canceled.canceled = true
		Input.parse_input_event(canceled)
		await settle()
		check(is_equal_approx(slider.value, owned), "canceled touch does not jump the volume")
		await set_with_finger(slider, 0.6)
		check(slider.value > 0.5, "new touch works after cancellation")
		# Other Settings controls: camera zoom and text scale use the same adapter.
		await tap(panel.tab_buttons[2])
		var zoom: HSlider = find_sliders(panel.tab_panes[2])[0]
		await set_with_finger(zoom, 0.25)
		check(settings.camera_zoom < 44.0 and is_equal_approx(settings.camera_zoom, zoom.value), "camera default zoom changes by finger")
		await tap(panel.tab_buttons[1])
		var scale_slider: HSlider = find_sliders(panel.tab_panes[1])[0]
		await set_with_finger(scale_slider, 0.7)
		check(settings.ui_scale > 1.05 and is_equal_approx(settings.ui_scale, scale_slider.value), "UI scale changes by finger")
		root.content_scale_factor = 1.0
		await settle()
		# Language: the reviewer's "switch to English and it's stuck". A finger
		# must change the locale live and leave the page usable afterwards.
		check(not panel.language_picker.visible and panel.language_buttons.size() == 2, "phone shows two language buttons instead of a dropdown")
		var localization = root.get_node("Localization")
		await tap(panel.language_buttons[1])
		check(TranslationServer.get_locale().begins_with("en") and settings.locale == "en", "finger tap on English switches the locale live")
		check(TranslationServer.translate("ตั้งค่า") == "Settings", "English translation is active after the tap")
		await tap(panel.tab_buttons[3])
		check(panel.tab_panes[3].visible, "page is still usable after switching language")
		await tap(panel.language_buttons[0])
		check(settings.locale == "th" and panel.language_buttons[0].button_pressed and not panel.language_buttons[1].button_pressed, "finger tap on ไทย switches back and highlights the choice")
		check(localization != null, "localization autoload present")
		# Name field: finger tap must focus it (focus raises the iOS keyboard).
		await tap(panel.tab_buttons[2])
		var edit: LineEdit = null
		for cand in panel.tab_panes[2].find_children("*", "LineEdit", true, false):
			if cand.is_visible_in_tree():
				edit = cand
		check(edit != null, "board-name field is on the play tab")
		await tap(edit)
		check(edit.has_focus() and edit.get_global_rect().size.y >= UITheme.TOUCH_MIN, "finger tap focuses the board-name field")
		edit.release_focus()
		# Every toggle on every tab flips under a finger.
		for i in panel.tab_panes.size():
			await tap(panel.tab_buttons[i])
			for toggle in panel.tab_panes[i].find_children("*", "CheckButton", true, false):
				if not toggle.is_visible_in_tree():
					continue
				var was: bool = toggle.button_pressed
				await tap(toggle)
				check(toggle.button_pressed != was, "toggle '%s' flips under a finger" % toggle.text.substr(0, 16))
				await tap(toggle)
	else:
		check(rect.size.y < UITheme.TOUCH_MIN, "desktop slider keeps its compact height")
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = rect.position + rect.size * Vector2(0.25, 0.5)
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await settle()
		check(slider.value < 0.5, "desktop mouse volume adjustment is preserved")
	var expected := slider.value
	var expected_zoom: float = settings.camera_zoom
	var expected_scale: float = settings.ui_scale
	panel.close()
	await settle()
	settings.load_settings()
	check(is_equal_approx(settings.volumes["Master"], expected), "volume survives save and reload")
	check(is_equal_approx(settings.camera_zoom, expected_zoom) and is_equal_approx(settings.ui_scale, expected_scale), "zoom and UI scale survive save and reload")
	# Repeated HUD restore must preserve platform-specific tool visibility.
	var hud = load("res://ui/HUD.gd").new()
	root.add_child(hud)
	await settle()
	check(hud.tool_col.visible == not UITheme.is_mobile(), "tool slots start with correct platform visibility")
	for i in 3:
		hud.set_minimal(true)
		check(not hud.tool_col.visible, "minimal mode hides tool slots")
		hud.set_minimal(false)
		check(hud.tool_col.visible == not UITheme.is_mobile(), "restoring HUD keeps tool slots desktop-only")
	hud.queue_free()
	await settle()
	for f in DirAccess.get_files_at(settings.dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.dir))
	settings.dir = previous_dir
	settings.load_settings()
	root.content_scale_factor = 1.0
	print("SETTINGS TOUCH RESULT: %d (%d checks)" % [failures, checks])
	quit(1 if failures else 0)
