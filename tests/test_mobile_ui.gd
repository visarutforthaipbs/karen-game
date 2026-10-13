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

## First visible ScrollContainer under `node` whose content overflows vertically.
func overflowing_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer and node.is_visible_in_tree():
		var sc := node as ScrollContainer
		if sc.get_v_scroll_bar().max_value > sc.size.y + 1.0:
			return sc
	for child in node.get_children():
		var found := overflowing_scroll(child)
		if found:
			return found
	return null

## A point over text / blank content (not a Button) inside the container.
func text_point(sc: ScrollContainer) -> Vector2:
	var labels: Array = []
	collect(sc, "label", labels)
	var area := sc.get_global_rect()
	for label in labels:
		var r: Rect2 = label.get_global_rect()
		var p := r.get_center()
		if area.has_point(p) and label.is_visible_in_tree():
			return p
	return area.get_center()

func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)

func drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)

## Finger swipe upward over content: returns [before, after] scroll offsets.
func swipe_up(sc: ScrollContainer, start: Vector2, distance: float = 160.0) -> Array:
	var before := sc.scroll_vertical
	touch(3, start, true)
	await process_frame
	var pos := start
	for i in 4:
		pos += Vector2(0, -distance / 4.0)
		drag(3, pos, Vector2(0, -distance / 4.0))
		await process_frame
	touch(3, pos, false)
	await process_frame
	return [before, sc.scroll_vertical]

## One finger tap at a control's centre: a ScreenTouch press then release.
func tap(control: Control) -> void:
	var centre := control.get_global_rect().get_center()
	touch(9, centre, true)
	await process_frame
	touch(9, centre, false)
	await process_frame
	await process_frame

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
	# iPhone scrolling audit P1: every visible title action fits without a swipe.
	var title_fits := true
	for child in title._menu.get_children():
		if child is Button and child.visible and not root.get_visible_rect().encloses(child.get_global_rect()):
			title_fits = false
	check(title_fits, "all visible title actions are inside the 1280x720 viewport without scrolling")
	check((title._menu is GridContainer) == expect_touch, "title menu is a 2x2 grid only on touch")
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
	# iPhone scrolling audit P2: a finger swipe over the guide text scrolls it.
	# Screens that now fit 1280x720 have no body to swipe: skip with a note.
	var guide_scroll := overflowing_scroll(guide)
	if guide_scroll:
		check(true, "guide content overflows at 1280x720 (scroll region exists)")
		var r: Array = await swipe_up(guide_scroll, text_point(guide_scroll))
		check((r[1] > r[0]) == expect_touch, "swipe over guide text scrolls on touch (%d -> %d), not on desktop" % [r[0], r[1]])
	else:
		check(true, "SKIP: guide fits 1280x720 without overflow, so there is no body to swipe")
	guide.close()
	await settle()

	# --- 5. Settings overlay ------------------------------------------------
	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await settle()
	check(is_instance_valid(settings.close_button) and settings.close_button.visible, "settings footer visible")
	check(settings.close_button.custom_minimum_size.y >= (UITheme.TOUCH_MIN if expect_touch else 48.0),
		"settings close button meets the touch target on mobile")
	# iPhone scrolling audit P1: swipe over the settings body reveals the lower controls.
	# Only when the body actually overflows; a fitting body is a PASS-skip.
	var settings_scroll := overflowing_scroll(settings)
	if settings_scroll:
		check(true, "settings body overflows at 1280x720 (scroll region exists)")
		var r: Array = await swipe_up(settings_scroll, text_point(settings_scroll), 240.0)
		check((r[1] > r[0]) == expect_touch, "swipe over settings text scrolls on touch (%d -> %d)" % [r[0], r[1]])
		# A swipe that starts on a button must not activate it.
		var victim: Button = null
		for b in all_buttons(settings_scroll):
			if b.is_visible_in_tree() and settings_scroll.get_global_rect().has_point(b.get_global_rect().get_center()):
				victim = b
				break
		if victim:
			var fired := [false]
			victim.pressed.connect(func(): fired[0] = true)
			var start: Vector2 = victim.get_global_rect().get_center()
			touch(4, start, true)
			await process_frame
			var pos := start
			for i in 4:
				pos += Vector2(0, -40)
				drag(4, pos, Vector2(0, -40))
				await process_frame
			touch(4, pos, false)
			await settle()
			check(not fired[0], "a swipe that starts on a settings button does not activate it")
	else:
		check(true, "SKIP: settings fits 1280x720 without overflow, so there is no body to swipe")
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

	# --- 7. Dusk inversion stays legible at the overview zoom (playtest P1) ---
	var sky = main.sky
	var env: Environment = main.world_environment.environment
	sky.inversion_strength = 1.0
	sky.view_distance = sky.CALIBRATED_VIEW_DISTANCE
	sky.apply_time(19.4)
	var fog_default: float = env.fog_density
	var hfog_default: float = env.fog_height_density
	check(is_equal_approx(sky.depth_scale(), 1.0), "fog is unscaled at the authored 44 m camera")
	sky.view_distance = main.cam_rig.zoom_max
	sky.apply_time(19.4)
	var expected: float = clampf(pow(sky.CALIBRATED_VIEW_DISTANCE / main.cam_rig.zoom_max, sky.DEPTH_SCALE_EXPONENT), sky.MIN_DEPTH_SCALE, 1.0)
	check(is_equal_approx(env.fog_density, fog_default * expected) and is_equal_approx(env.fog_height_density, hfog_default * expected), "overview zoom scales distance and height fog by the squared distance ratio")
	check(expected < 0.5 and expected >= sky.MIN_DEPTH_SCALE, "overview fog lands between the floor and half of the authored density")
	main.cam_rig.distance = main.cam_rig.zoom_max
	await process_frame
	check(is_equal_approx(sky.view_distance, main.cam_rig.zoom_max), "MainController feeds the live camera distance to the sky each frame")

	# --- 8. Village preparation: tabs on touch, three columns on desktop ------
	state.current_year = 4
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await settle()
	var hearth = current_scene
	if hearth and hearth.get("chatter_timer"):
		hearth.chatter_timer.stop()
	var tab_labels: Array[String] = ["แปลง", "วิทยุ", "เสบียง", "โรงซ่อม · เอาแรง"]
	if expect_touch:
		# V1 "tabs, no scrolling": one pinned tab bar, one visible pane.
		check(hearth._tab_bar != null and hearth._tab_bar.is_visible_in_tree(), "touch preparation builds a pinned tab bar")
		check(hearth._tab_buttons.size() == 4 and hearth._tab_panes.size() == 4, "tab bar carries four tabs and four panes")
		check(hearth._card_columns.columns == 1, "touch body is a one-column pane area")
		var labels_ok := true
		var targets_ok := true
		for i in 4:
			if i < hearth._tab_buttons.size():
				if hearth._tab_buttons[i].text != tab_labels[i]:
					labels_ok = false
				if hearth._tab_buttons[i].size.y < UITheme.TOUCH_MIN:
					targets_ok = false
		check(labels_ok, "tab labels are the four approved Thai literals")
		var first_tab_height: float = hearth._tab_buttons[0].size.y if hearth._tab_buttons.size() > 0 else 0.0
		check(targets_ok, "every tab button is at least 88 px tall (%.0f px)" % first_tab_height)
		check(hearth._active_tab == 0 and hearth._tab_panes[0].is_visible_in_tree(), "the default tab is แปลง")
		# The one label that must be on screen behind each tab.
		var tab_content: Array = [hearth.plot_title_label, hearth.radio_text, hearth.granary_label, hearth.workshop_label]
		for i in 4:
			await tap(hearth._tab_buttons[i])
			await settle()
			check(hearth._active_tab == i, "tapping tab %d activates it (%s)" % [i, tab_labels[i]])
			var panes_ok := true
			var highlight_ok := true
			for j in 4:
				if hearth._tab_panes[j].is_visible_in_tree() != (i == j):
					panes_ok = false
				if (hearth._tab_buttons[j].theme_type_variation == "PrimaryButton") != (i == j):
					highlight_ok = false
			check(panes_ok, "tab %s shows only its own pane" % tab_labels[i])
			check(highlight_ok, "tab %s alone is highlighted" % tab_labels[i])
			var content_ok: bool = tab_content[i].is_visible_in_tree()
			if i == 3:
				# Workshop and mutual aid share one row, side by side.
				content_ok = content_ok and hearth.exchange_label.is_visible_in_tree() \
					and hearth.exchange_label.get_global_rect().position.x >= hearth.workshop_label.get_global_rect().end.x - 1.0
			check(content_ok, "pane %s reuses the matching preparation card" % tab_labels[i])
			var body: ScrollContainer = hearth._card_scroll
			var max_value: float = body.get_v_scroll_bar().max_value
			check(max_value <= body.size.y + 1.0, "pane %s fits the 1280x720 body without scrolling (%.0f <= %.0f)" % [tab_labels[i], max_value, body.size.y])
		# Back to the default tab so the checks below start from the plot pane.
		await tap(hearth._tab_buttons[0])
		await settle()
	else:
		check(hearth._tab_bar == null, "desktop preparation builds no tab bar")
		check(hearth._tab_panes.is_empty() and hearth._tab_buttons.is_empty(), "desktop builds no hidden pane set")
		check(hearth._card_columns.columns == 3, "desktop keeps the three-column grid at 1280 px wide")
		check(hearth.plot_title_label.is_visible_in_tree() and hearth.radio_text.is_visible_in_tree() \
			and hearth.granary_label.is_visible_in_tree() and hearth.workshop_label.is_visible_in_tree() \
			and hearth.exchange_label.is_visible_in_tree(), "desktop still shows every preparation card at once")
	var village_scroll := overflowing_scroll(hearth)
	if village_scroll:
		check(true, "village preparation body overflows at 1280x720 (scroll region exists)")
		var r: Array = await swipe_up(village_scroll, text_point(village_scroll), 240.0)
		check((r[1] > r[0]) == expect_touch, "swipe over the village briefing scrolls on touch (%d -> %d)" % [r[0], r[1]])
	elif expect_touch:
		check(true, "SKIP: the tabbed village body fits 1280x720 on touch, so there is nothing to swipe")
	else:
		check(false, "village preparation body overflows at 1280x720 (scroll region exists)")
	# iPhone playtest cycles 3-4: with the home-indicator inset the speech caption
	# landed on the Launch button. Simulate the iPhone insets and show a caption.
	UITheme.debug_insets = {"left": 59.0, "top": 0.0, "right": 59.0, "bottom": 21.0}
	hearth._fit_layout()
	var subs = root.get_node("AudioManager").subtitle_overlay
	subs._caption_changed("ตาโพ", "ปีนี้ฝนมาช้า ลมแรงจากทางตะวันตก เตรียมแนวกันไฟให้ดีก่อนจุด", 1.0)
	await settle()
	var launch_rect: Rect2 = hearth.launch_button.get_global_rect()
	var cap_rect: Rect2 = subs.card.get_global_rect()
	check(hearth.launch_button.is_visible_in_tree() and not cap_rect.intersects(launch_rect), "village caption stays clear of Launch under iPhone insets (%s vs %s)" % [cap_rect, launch_rect])
	subs._caption_changed("", "", 0.0)
	UITheme.debug_insets = {}
	hearth._fit_layout()
	await settle()

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
