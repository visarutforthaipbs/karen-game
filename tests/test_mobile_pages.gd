extends SceneTree

## Owner-approved V1 layouts (2026-10-13), touch only, desktop unchanged:
##   * Settings: a 4-tab bar (เสียง / การแสดงผล / การเล่น / ออนไลน์ · ข้อมูล)
##     over one pane at a time; every pane fits 1280x720 with no scrolling,
##     the language selector stays above the tabs and บันทึกและปิด stays pinned.
##   * How to play: four pages with Previous / Next, an "n / 4" indicator and
##     the acknowledge button on every page.
##
## Run twice, both headless:
##   godot --headless --path . --script res://tests/test_mobile_pages.gd -- --touch
##   godot --headless --path . --script res://tests/test_mobile_pages.gd

## Tab titles the panel must expose (kept local: referencing the
## SettingsPanel class here would compile it before the autoloads exist).
const EXPECTED_TABS: Array = ["เสียง", "การแสดงผล", "การเล่น", "ออนไลน์ · ข้อมูล"]

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

## A Button/CheckButton with this exact text, visible in the current pane.
func button_text_exists(node: Node, text: String) -> bool:
	var buttons: Array = []
	collect(node, "button", buttons)
	for button in buttons:
		if button.text == text and button.is_visible_in_tree():
			return true
	return false

func inside(control: Control) -> bool:
	return root.get_visible_rect().grow(1.0).encloses(control.get_global_rect())

## Every visible control sits inside the 1280x720 canvas.
func all_visible_inside(node: Node) -> bool:
	var items: Array = []
	collect(node, "control", items)
	for item in items:
		if item.is_visible_in_tree() and not inside(item):
			return false
	return true

## The body region never needs a swipe: content height <= viewport height.
func body_fits(scroll: ScrollContainer) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	return scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1.0

func send_touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)

func tap(control: Control) -> void:
	var p: Vector2 = control.get_global_rect().get_center()
	send_touch(p, true)
	await process_frame
	send_touch(p, false)
	await settle()

func run() -> void:
	expect_touch = OS.get_cmdline_user_args().has("--touch")
	root.size = Vector2i(1280, 720)
	await process_frame

	# Isolate settings/saves: closing the panel writes settings.cfg.
	var original = {"settings": GameSettings.dir, "save": SaveGame.dir, "log": PlaytestLog.dir}
	var scratch = "user://mobile_pages_fixture_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	SaveGame.dir = scratch
	PlaytestLog.dir = scratch

	check(UITheme.is_mobile() == expect_touch, "is_mobile() follows --touch (%s)" % str(expect_touch))

	# --- Settings ----------------------------------------------------------
	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await settle()
	check(is_instance_valid(settings.close_button) and settings.close_button.is_visible_in_tree() and inside(settings.close_button),
		"settings save-and-close is visible inside the canvas")
	check(settings.language_picker.is_visible_in_tree() and inside(settings.language_picker),
		"language selector is visible above the tabs")

	if expect_touch:
		check(settings.tab_bar != null and settings.tab_bar.is_visible_in_tree(), "touch settings builds a tab bar")
		check(settings.tab_buttons.size() == 4 and settings.tab_panes.size() == 4,
			"settings exposes four tabs and four panes (%d tabs, %d panes)" % [settings.tab_buttons.size(), settings.tab_panes.size()])
		var titles_ok: bool = settings.tab_buttons.size() == 4
		var tall_ok: bool = settings.tab_buttons.size() == 4
		for tab in settings.tab_buttons:
			titles_ok = titles_ok and (tab.text in EXPECTED_TABS or (not OnlineBoard.available() and tab.text == "ข้อมูล · ช่วยเหลือ"))
			tall_ok = tall_ok and tab.custom_minimum_size.y >= UITheme.TOUCH_MIN and tab.size.y >= UITheme.TOUCH_MIN
		check(titles_ok, "tabs read เสียง / การแสดงผล / การเล่น / ออนไลน์ · ข้อมูล")
		check(tall_ok, "every tab meets the 88 px touch target")
		check(inside(settings.tab_bar), "the tab bar sits inside the 1280x720 canvas")
		check(settings.tab_panes[0].is_visible_in_tree() and not settings.tab_panes[1].is_visible_in_tree(),
			"the first pane opens alone")

		for i in 4:
			await tap(settings.tab_buttons[i])
			check(settings.tab_panes[i].is_visible_in_tree(), "tab %d shows its pane" % (i + 1))
			var others_shown: bool = false
			for j in 4:
				others_shown = others_shown or (j != i and settings.tab_panes[j].is_visible_in_tree())
			check(not others_shown, "tab %d hides the other panes" % (i + 1))
			check(settings.tab_buttons[i].button_pressed,
				"tab %d stays pressed while its pane shows" % (i + 1))
			check(settings.language_picker.is_visible_in_tree() and inside(settings.language_picker),
				"language selector visible on pane %d" % (i + 1))
			check(settings.close_button.is_visible_in_tree() and inside(settings.close_button),
				"save-and-close visible on pane %d" % (i + 1))
			check(all_visible_inside(settings) and body_fits(settings._content_scroll),
				"pane %d fits 1280x720 without scrolling" % (i + 1))
		if OnlineBoard.available():
			check(settings.delete_scores_button.is_visible_in_tree() and inside(settings.delete_scores_button),
				"score removal is reachable on the last tab")
			check(button_text_exists(settings, "ส่งผลการเล่นขึ้นกระดานออนไลน์") and has_label(settings, "สำหรับผู้ทดสอบ"),
				"online board and tester tools live on the last tab")
		else:
			# App Store offline build: no leaderboard controls; Data / Help instead
			var policy = settings.find_child("PrivacyPolicyButton", true, false)
			var support = settings.find_child("SupportButton", true, false)
			check(settings.delete_scores_button == null and not button_text_exists(settings, "ส่งผลการเล่นขึ้นกระดานออนไลน์"),
				"offline build has no online board controls")
			check(policy != null and policy.is_visible_in_tree() and inside(policy)
				and support != null and support.is_visible_in_tree() and inside(support),
				"privacy and support actions are reachable on the last tab")
			check(has_label(settings, "สำหรับผู้ทดสอบ"), "tester tools still live on the last tab")
	else:
		check(settings.tab_bar == null, "desktop settings has no tab bar")
		check(settings.tab_buttons.is_empty() and settings.tab_panes.is_empty(), "desktop builds no tabs or panes")
		check(settings._content_scroll != null and settings._content_scroll.is_inside_tree(),
			"desktop keeps the single settings ScrollContainer")
		var body = settings._content_scroll.get_child(0)
		check(body is HBoxContainer and body.get_child_count() == 2,
			"desktop keeps the original two-column body")
		check(settings._content_scroll.is_ancestor_of(settings.delete_scores_button),
			"desktop keeps every setting inside the scroll body")
		check(has_label(settings, "เสียง") and has_label(settings, "การแสดงผล") and has_label(settings, "การเล่น"),
			"desktop keeps its section headers")
		check(has_label(settings, "กระดานออนไลน์ (เบตา)"), "desktop keeps the online board section")
		check(all_visible_inside(settings), "desktop settings fits the canvas at 1280x720")
		check(settings.close_button.custom_minimum_size.y < UITheme.TOUCH_MIN,
			"desktop buttons keep their authored height")
	settings.close()
	await settle()

	# --- How to play -------------------------------------------------------
	var guide = load("res://ui/HowToPlay.gd").new()
	root.add_child(guide)
	await settle()
	check(guide.controls_grid != null and guide.controls_grid.get_child_count() > 0, "guide builds a controls table")
	check(is_instance_valid(guide.close_button) and guide.close_button.is_visible_in_tree() and inside(guide.close_button),
		"guide acknowledge button is visible inside the canvas")

	if expect_touch:
		check(guide.pages.size() == 4, "guide exposes four pages (%d)" % guide.pages.size())
		check(guide.page_indicator != null and guide.page_indicator.text == "1 / 4", "guide opens on page 1 / 4")
		check(guide.prev_button.size.y >= UITheme.TOUCH_MIN and guide.next_button.size.y >= UITheme.TOUCH_MIN,
			"Previous / Next meet the 88 px touch target")
		check(has_label(guide, guide.TOUCH_HEADER), "touch controls section exists")
		check(not has_label(guide, guide.KEYBOARD_HEADER), "keyboard/gamepad table stays off touch")
		check(guide.guide_scroll == null, "touch guide drops the scroll region")
		# Next cycles the four pages; the indicator and the footer follow.
		for step in 5:
			var page_no: int = posmod(step, 4) + 1
			check(guide.page_indicator.text == "%d / 4" % page_no,
				"indicator reads %s (page %d)" % [guide.page_indicator.text, page_no])
			var shown: int = 0
			for page in guide.pages:
				shown += 1 if page.is_visible_in_tree() else 0
			check(shown == 1 and guide.pages[page_no - 1].is_visible_in_tree(), "page %d is the only visible page" % page_no)
			check(guide.close_button.is_visible_in_tree() and inside(guide.close_button),
				"acknowledge button visible on page %d" % page_no)
			check(all_visible_inside(guide), "page %d fits 1280x720 without scrolling" % page_no)
			if page_no == 4:
				check(guide.controls_grid.is_visible_in_tree(), "the touch controls table shows on page 4")
			if step < 4:
				await tap(guide.next_button)
		await tap(guide.prev_button)
		check(guide.page_indicator.text == "4 / 4", "Previous wraps from the first page to the last")
		check(guide.pages[3].is_visible_in_tree(), "Previous shows the last page")
		# A leftward swipe across the page area also turns the page.
		var area: Vector2 = guide.pages_stack.get_global_rect().get_center()
		send_touch(area + Vector2(120, 0), true)
		await process_frame
		send_touch(area + Vector2(-120, 0), false)
		await settle()
		check(guide.page_indicator.text == "1 / 4", "a left swipe turns the page (%s)" % guide.page_indicator.text)
	else:
		check(guide.pages.is_empty() and guide.page_indicator == null and guide.prev_button == null,
			"desktop guide has no pager")
		check(guide.guide_scroll != null and guide.guide_scroll.is_inside_tree(), "desktop keeps the scrolling guide body")
		check(guide.guide_columns != null and guide.guide_columns.columns == 2, "desktop keeps the two reading columns")
		check(guide.guide_scroll.get_v_scroll_bar().max_value > guide.guide_scroll.size.y + 1,
			"desktop guide body still overflows at 1280x720")
		check(guide.guide_scroll.focus_next == guide.guide_scroll.get_path_to(guide.close_button),
			"desktop keyboard focus still returns to the acknowledge button")
		check(has_label(guide, guide.KEYBOARD_HEADER) and not has_label(guide, guide.TOUCH_HEADER),
			"desktop shows the keyboard/gamepad table")
		check(all_visible_inside(guide), "desktop guide fits the canvas at 1280x720")
		check(guide.controls_grid.is_visible_in_tree(), "desktop controls table stays in the tree")
	guide.close()
	await settle()

	# --- Opening film inside a safe-area-inset parent (owner playtest: the top bar
	# and the third button ran off the right edge on the iPhone) ------------------
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = 59.0
	host.offset_right = -59.0
	host.offset_bottom = -21.0
	root.add_child(host)
	var film = load("res://ui/OpeningFilm.gd").new()
	host.add_child(film)
	await settle()
	var host_rect: Rect2 = host.get_global_rect()
	var top_rect: Rect2 = film.top_panel.get_global_rect()
	var cap_rect: Rect2 = film.caption_card.get_global_rect()
	var skip_rect: Rect2 = film.skip_button.get_global_rect()
	check(host_rect.grow(1.0).encloses(top_rect), "opening film top bar stays inside its inset parent (%s in %s)" % [top_rect, host_rect])
	check(host_rect.grow(1.0).encloses(skip_rect), "opening film skip button stays inside its inset parent")
	check(host_rect.grow(1.0).encloses(cap_rect), "opening film caption stays inside its inset parent")
	film.close()
	await settle()
	host.queue_free()
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
	print("MOBILE PAGES RESULT: %d (%d checks, touch=%s)" % [failures, checks, str(expect_touch)])
	quit(1 if failures else 0)
