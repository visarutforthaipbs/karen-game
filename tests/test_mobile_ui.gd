extends SceneTree

## Mobile UI readiness for the iPhone / iPad landscape port:
## touch detection, safe-area math, 44 pt targets, the hidden Quit button,
## the touch controls section of the guide, and auto-pause on focus loss.
##
## Run twice, both headless:
##   godot --headless --path . --script res://tests/test_mobile_ui.gd -- --touch
##   godot --headless --path . --script res://tests/test_mobile_ui.gd

var checks: int = 0
var failures: int = 0
var expect_touch: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 8:
		await process_frame

func collect(node: Node, kind: String, result: Array) -> void:
	if kind == "control" and node is Control:
		result.append(node)
	elif kind == "label" and node is Label:
		result.append(node)
	elif kind == "button" and node is Button:
		result.append(node)
	for child in node.get_children():
		collect(child, kind, result)

func has_label(node: Node, text: String) -> bool:
	var labels: Array = []
	collect(node, "label", labels)
	for label in labels:
		if label.text == text:
			return true
	return false

func all_buttons(node: Node) -> Array:
	var buttons: Array = []
	collect(node, "button", buttons)
	return buttons

func inset_zero(control: Control) -> bool:
	return control.offset_left == 0.0 and control.offset_top == 0.0 \
		and control.offset_right == 0.0 and control.offset_bottom == 0.0

func run() -> void:
	expect_touch = OS.get_cmdline_user_args().has("--touch")
	root.size = Vector2i(1280, 720)
	await process_frame

	# Isolate settings/saves: the focus-loss path writes settings.cfg.
	var original = {"settings": GameSettings.dir, "save": SaveGame.dir, "log": PlaytestLog.dir}
	var scratch = "user://mobile_ui_fixture_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	SaveGame.dir = scratch
	PlaytestLog.dir = scratch

	# --- 1. Detection and safe-area math -----------------------------------
	check(UITheme.is_mobile() == expect_touch, "is_mobile() follows --touch (%s)" % expect_touch)
	var insets: Dictionary = UITheme.safe_area_insets()
	var zero := true
	for side in ["left", "top", "right", "bottom"]:
		zero = zero and float(insets[side]) == 0.0
	check(zero, "headless reports no safe-area insets")
	check(UITheme.safe_area_rect().size == root.get_visible_rect().size, "safe area rect equals the visible canvas in headless")

	var probe := Control.new()
	probe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(probe)
	UITheme.apply_safe_area(probe)
	check(inset_zero(probe) and not probe.has_meta(UITheme.SAFE_AREA_META), "apply_safe_area is a no-op without insets")
	UITheme.apply_safe_area(probe)
	check(inset_zero(probe), "apply_safe_area never pads twice")
	probe.queue_free()
	await settle()

	# --- 2. 44 pt touch targets --------------------------------------------
	var loose := Button.new()
	loose.custom_minimum_size = Vector2.ZERO
	UITheme.apply_touch_targets(loose)
	check(loose.custom_minimum_size.y == (UITheme.TOUCH_MIN if expect_touch else 0.0),
		"apply_touch_targets raises buttons to 88 px only on touch")
	var themed := Button.new()
	themed.theme = UITheme.get_theme()
	themed.text = "A"
	root.add_child(themed)
	var themed_height := themed.get_combined_minimum_size().y
	check((themed_height >= UITheme.TOUCH_MIN) == expect_touch,
		"buttons entering the tree are floored at 88 px only on touch (%.0f px)" % themed_height)
	loose.free()
	themed.queue_free()

	# --- 3. Title screen ----------------------------------------------------
	var title = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	await settle()
	check(is_instance_valid(title.quit_button), "title builds its Quit button")
	check(title.quit_button.visible == (not expect_touch), "Quit hidden on mobile, shown on desktop")
	check(title._menu.get_child_count() == 5, "title menu keeps all five entries")
	var focus_ok := true
	for child in title._menu.get_children():
		if child is Button and child.visible:
			child.grab_focus()
			await process_frame
			if root.gui_get_focus_owner() != child:
				focus_ok = false
	check(focus_ok, "every visible title button still takes focus")
	var title_buttons := all_buttons(title)
	var title_targets_ok := true
	for button in title_buttons:
		if button == title.quit_button:
			continue
		if button.size.y < 0.0:
			title_targets_ok = false
		if expect_touch and button.custom_minimum_size.y < UITheme.TOUCH_MIN:
			title_targets_ok = false
		if not expect_touch and button.custom_minimum_size.y > 60.0:
			title_targets_ok = false
	check(title_targets_ok, "title buttons carry the 88 px target only on touch")
	title.queue_free()
	await settle()

	# --- 4. How to play -----------------------------------------------------
	var guide = load("res://ui/HowToPlay.gd").new()
	root.add_child(guide)
	await settle()
	check(guide.controls_grid.get_child_count() > 0, "guide builds a controls table")
	check(has_label(guide, guide.TOUCH_HEADER) == expect_touch, "touch controls section shown only on touch")
	check(has_label(guide, guide.KEYBOARD_HEADER) == (not expect_touch), "keyboard/gamepad section hidden on touch")
	check(L10n.english(guide.TOUCH_HEADER) == "Controls (touch screen)", "touch header has an English catalog entry")
	check(L10n.english("ปุ่มขวา · สั่งงาน") == "Right buttons · order", "touch rows have English catalog entries")
	check(guide.close_button.custom_minimum_size.y >= (UITheme.TOUCH_MIN if expect_touch else 48.0),
		"guide close button meets the touch target on mobile")
	var guide_inside := true
	for button in all_buttons(guide):
		if not Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(button.get_global_rect()):
			guide_inside = false
	check(guide_inside, "guide buttons stay inside the canvas")
	guide.close()
	await settle()

	# --- 5. Settings overlay ------------------------------------------------
	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await settle()
	check(is_instance_valid(settings.close_button) and settings.close_button.visible, "settings footer visible")
	check(settings.close_button.custom_minimum_size.y >= (UITheme.TOUCH_MIN if expect_touch else 48.0),
		"settings close button meets the touch target on mobile")
	settings.close()
	await settle()

	# --- 6. Auto-pause on app focus loss ------------------------------------
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play = true
	change_scene_to_file("res://scenes/Main.tscn")
	for frame in 12:
		await process_frame
	var main = current_scene
	check(main != null and main.has_method("_notification"), "Main scene loaded")
	if main == null:
		finish(original, scratch)
		return
	check(not paused, "burn starts unpaused")
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	if expect_touch:
		check(paused, "focus loss pauses the burn on touch devices")
		check(main.hud.pause_menu.visible, "focus loss opens the pause menu on touch devices")
		main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await process_frame
		check(paused and main.hud.pause_menu.visible, "repeated focus loss does not reopen the menu")
	else:
		check(not paused and not main.hud.pause_menu.visible, "desktop focus loss keeps Beta 3 behaviour (no auto-pause)")
		main.hud.pause_menu.open()
		await process_frame
		check(paused and main.hud.pause_menu.visible, "manual pause still works on desktop")
	check(inset_zero(main.hud.root), "HUD root keeps zero offsets without insets")
	check((main.hud.hint_label.text == main.hud.TOUCH_HINT) == expect_touch, "HUD control hint follows the device")
	main.hud.pause_menu.close()
	await process_frame
	check(not paused and not main.hud.pause_menu.visible, "closing the pause menu restores the burn")
	main.notification(NOTIFICATION_APPLICATION_PAUSED)
	await process_frame
	check(paused and main.hud.pause_menu.visible, "app pause parks the burn under the menu")
	main.hud.pause_menu.close()
	await process_frame
	check(not paused, "app pause can be dismissed")

	finish(original, scratch)

func finish(original: Dictionary, scratch: String) -> void:
	var audio = root.get_node_or_null("AudioManager")
	if audio:
		audio.stop_all_loops()
	GameSettings.dir = original.settings
	SaveGame.dir = original.save
	PlaytestLog.dir = original.log
	for file in DirAccess.open(scratch).get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch + "/" + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	print("MOBILE UI RESULT: %d (%d checks, touch=%s)" % [failures, checks, str(expect_touch)])
	quit(1 if failures else 0)
