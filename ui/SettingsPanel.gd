class_name SettingsPanel
extends Control

## Settings overlay (P0-4), shared by the title screen, pause menu and Hearth.
## Values live in GameSettings (user://settings.cfg) and apply immediately.
## Touch devices use the V1 four-tab layout (owner-approved 2026-10-13): one
## pane at a time, every pane fitting 1280x720 without scrolling, language
## selector above the tabs and the save button pinned to the bottom. Desktop
## keeps the long two-column form unchanged.

signal closed
signal how_to_play_requested

## Tab titles in order; the first three double as the desktop section headers.
const TAB_TITLES: Array = ["เสียง", "การแสดงผล", "การเล่น", "ออนไลน์ · ข้อมูล"]

var close_button: Button
var language_picker: OptionButton
var _content_scroll: ScrollContainer
var delete_scores_button: Button
var online_status: Label
var _focus_scope: ModalFocusScope
var _delete_pending: bool = false
var _delete_requester: Callable = OnlineBoard.delete_my_scores

## Touch layout only: null / empty on desktop.
var tab_bar: HBoxContainer
var tab_buttons: Array = []
var tab_panes: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	GameSettings.ensure_loaded()
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.8)
	add_child(dim)

	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.STRAW, 501)
	card.padding = Vector4(20, 14, 20, 16) if UITheme.is_mobile() else Vector4(26, 20, 26, 22)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(1100 if UITheme.is_mobile() else 900, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var page = UITheme.vbox(12)
	card.add_child(page)
	var title = UITheme.label("ตั้งค่า", "Title", UITheme.STRAW)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 28)
	page.add_child(title)

	var language_row = UITheme.hbox(14)
	language_row.add_child(UITheme.label("ภาษา / Language", "Body", UITheme.CREAM))
	language_picker = OptionButton.new()
	language_picker.name = "LanguagePicker"
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	language_picker.add_item("ไทย", 0)
	language_picker.add_item("English", 1)
	language_picker.select(1 if GameSettings.locale == "en" else 0)
	language_picker.custom_minimum_size = Vector2(220, 36)
	language_picker.focus_mode = Control.FOCUS_ALL
	language_picker.item_selected.connect(func(index: int):
		Localization.set_language("en" if index == 1 else "th"))
	language_row.add_child(language_picker)
	page.add_child(language_row)

	# Touch: the tab bar sits directly under the language row, above the body.
	if UITheme.is_mobile():
		_build_tab_bar(page)

	# Keep every setting reachable at increased text size and on smaller
	# displays. Keyboard/controller focus scrolls the body into view.
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "SettingsBody"
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.follow_focus = true
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size.y = _body_height()
	page.add_child(_content_scroll)
	get_viewport().size_changed.connect(func():
		_content_scroll.custom_minimum_size.y = _body_height())
	if UITheme.is_mobile():
		_build_touch_panes()
	else:
		_build_desktop_body()

	var foot = UITheme.hbox(0)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(foot)
	close_button = Button.new()
	close_button.theme_type_variation = "PrimaryButton"
	close_button.text = "บันทึกและปิด"
	close_button.custom_minimum_size = Vector2(300, 48)
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	_focus_scope = ModalFocusScope.begin(self)
	close_button.grab_focus()
	# Notch padding and 44 pt targets for the overlay's own controls.
	UITheme.apply_safe_area(self)
	UITheme.apply_touch_targets(self)

## Desktop body: the original two-column form inside one scroll region.
## Touch body: four panes, one per tab, all built so each fits 1280x720.
func _body_height() -> float:
	if UITheme.is_mobile():
		return maxf(200.0, UITheme.safe_area_rect().size.y - 400.0)
	return minf(440.0, maxf(160.0, UITheme.safe_area_rect().size.y - 220.0))

func _build_tab_bar(page: VBoxContainer) -> void:
	tab_bar = UITheme.hbox(10)
	tab_bar.name = "TabBar"
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group = ButtonGroup.new()
	for i in TAB_TITLES.size():
		var tab = Button.new()
		tab.name = "Tab%d" % (i + 1)
		tab.text = "ข้อมูล · ช่วยเหลือ" if i == 3 and not OnlineBoard.available() else TAB_TITLES[i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = UITheme.TOUCH_MIN
		tab.pressed.connect(_show_tab.bind(i))
		tab_bar.add_child(tab)
		tab_buttons.append(tab)
		var pane = UITheme.vbox(8)
		pane.name = "Pane%d" % (i + 1)
		pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_panes.append(pane)
	page.add_child(tab_bar)

## Every pane stays in the tree (so a hidden setting is still reachable for
## the language switch and for tests); only the selected one is visible.
func _show_tab(index: int) -> void:
	if tab_panes.is_empty():
		return
	var current := wrapi(index, 0, tab_panes.size())
	for i in tab_panes.size():
		tab_panes[i].visible = i == current
		tab_buttons[i].button_pressed = i == current

func _touch_columns() -> Array:
	var row = UITheme.hbox(18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a = UITheme.vbox(8)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = UITheme.vbox(8)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(b)
	return [row, a, b]

## The four panes. Same settings, signals and callbacks as the desktop form;
## the only difference is grouping, so no pane outgrows the 44 pt scroll-less
## budget at 1280x720.
func _build_touch_panes() -> void:
	var stack = UITheme.vbox(0)
	stack.name = "TabPanes"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(stack)
	for pane in tab_panes:
		stack.add_child(pane)

	# 1 · sound: every volume slider.
	tab_panes[0].add_child(UITheme.header("radio", TAB_TITLES[0], UITheme.STRAW))
	for b in GameSettings.VOLUME_BUSES:
		var bus: String = b[0]
		tab_panes[0].add_child(_slider_row(b[1], GameSettings.volumes.get(bus, 1.0), 0.0, 1.0, 0.05, func(v):
			GameSettings.volumes[bus] = v
			GameSettings.apply(get_tree()), "%d%%", 100.0))

	# 2 · display: fullscreen (meaningless on iOS), text/panel scale, detail.
	tab_panes[1].add_child(UITheme.header("eye", TAB_TITLES[1], UITheme.STRAW))
	if OS.get_name() != "iOS":
		tab_panes[1].add_child(_toggle_row("เต็มจอ", GameSettings.fullscreen, func(on):
			GameSettings.fullscreen = on
			GameSettings.apply(get_tree())))
	tab_panes[1].add_child(_slider_row("ขนาดตัวหนังสือและแผง", GameSettings.ui_scale, 0.85, 1.3, 0.05, func(v):
		GameSettings.ui_scale = v
		GameSettings.apply(get_tree()), "×%.2f", 1.0))
	tab_panes[1].add_child(_toggle_row("ภูมิทัศน์รอบแปลงแบบละเอียด (ปิดเพื่อให้ลื่นขึ้นบน Steam Deck)", GameSettings.landscape_detail == "high", func(on):
		GameSettings.landscape_detail = "high" if on else "low"))

	# 3 · gameplay: camera and hints left, name and the guide button right.
	var play = _touch_columns()
	tab_panes[2].add_child(play[0])
	play[1].add_child(UITheme.header("crew", TAB_TITLES[2], UITheme.STRAW))
	play[1].add_child(_slider_row("ระยะกล้องเริ่มต้น", GameSettings.camera_zoom, 26.0, 64.0, 1.0, func(v):
		GameSettings.camera_zoom = v, "%d ม.", 1.0))
	play[1].add_child(_toggle_row("แสดงคำแนะนำปุ่มควบคุม", GameSettings.show_hints, func(on):
		GameSettings.show_hints = on))
	play[2].add_child(_toggle_row("เคล็ดลับระหว่างเผาครั้งแรก", GameSettings.first_burn_tips, func(on):
		GameSettings.first_burn_tips = on))
	play[2].add_child(_board_name_row())
	var howto = Button.new()
	howto.text = "แสดงวิธีเล่นอีกครั้ง"
	howto.pressed.connect(func(): how_to_play_requested.emit())
	play[2].add_child(howto)

	# 4 · online board + data: privacy note and score removal left, tester
	# tools right (the score-removal action lives on this last tab).
	var online = _touch_columns()
	tab_panes[3].add_child(online[0])
	if OnlineBoard.available():
		online[1].add_child(UITheme.header("satellite", "กระดานออนไลน์ (เบตา)", UITheme.MUTED))
		online[1].add_child(_toggle_row("ส่งผลการเล่นขึ้นกระดานออนไลน์", GameSettings.online_board, func(on):
			GameSettings.online_board = on
			if on:
				OnlineBoard.ensure_identity()
			_update_delete_button()))
		var online_note = UITheme.label("ส่งเฉพาะชื่อบนกระดานและคะแนน ไม่มีอีเมลหรือข้อมูลส่วนตัว กระดานเบตาใช้ระบบเกียรติยศ ลบคะแนนของคุณได้ทุกเมื่อ", "Small", UITheme.MUTED)
		online_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		online[1].add_child(online_note)
		var wipe = Button.new()
		delete_scores_button = wipe
		wipe.text = "ลบคะแนนของฉันออกจากกระดานออนไลน์"
		_update_delete_button()
		wipe.pressed.connect(_delete_scores)
		online[1].add_child(wipe)
		online_status = UITheme.wrap(UITheme.label("", "Small", UITheme.MUTED))
		online_status.visible = false
		online[1].add_child(online_status)
	else:
		_build_offline_help(online[1])

	# Phones/tablets have no F-keys and no file browser for user://, so the
	# tester tools and the log-folder button only appear on touch PCs.
	if _handheld_os():
		online[2].visible = false
	else:
		online[2].add_child(UITheme.header("hammer", "สำหรับผู้ทดสอบ", UITheme.MUTED))
		online[2].add_child(_toggle_row("เครื่องมือทดสอบ (F3 ข้อมูล · F5–F10 ข้ามเวลา/บังคับเหตุการณ์)", GameSettings.debug_tools, func(on):
			GameSettings.debug_tools = on))
		var logs = Button.new()
		logs.text = "เปิดโฟลเดอร์บันทึกการเล่น"
		logs.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
		online[2].add_child(logs)

	_show_tab(0)

## A real phone / tablet OS (iOS, Android); `--handheld` simulates it in tests.
static func _handheld_os() -> bool:
	return OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--handheld")

func _board_name_row() -> HBoxContainer:
	var name_row = UITheme.hbox(10)
	var name_label = UITheme.label("ชื่อบนกระดาน" if OnlineBoard.available() else "ชื่อในสถิติในเครื่อง", "Small", UITheme.CREAM)
	name_label.custom_minimum_size = Vector2(170, 0)
	name_row.add_child(name_label)
	var name_edit = LineEdit.new()
	name_edit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_edit.text = GameSettings.player_name
	name_edit.max_length = SaveGame.NAME_MAX
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.focus_mode = Control.FOCUS_ALL
	name_edit.text_changed.connect(func(t: String): GameSettings.player_name = t)
	name_row.add_child(name_edit)
	return name_row

func _build_desktop_body() -> void:
	var cols = UITheme.hbox(18)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(cols)
	var left = UITheme.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right = UITheme.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	left.add_child(UITheme.header("radio", "เสียง", UITheme.STRAW))
	for b in GameSettings.VOLUME_BUSES:
		var bus: String = b[0]
		left.add_child(_slider_row(b[1], GameSettings.volumes.get(bus, 1.0), 0.0, 1.0, 0.05, func(v):
			GameSettings.volumes[bus] = v
			GameSettings.apply(get_tree()), "%d%%", 100.0))

	left.add_child(UITheme.header("eye", "การแสดงผล", UITheme.STRAW))
	left.add_child(_toggle_row("เต็มจอ", GameSettings.fullscreen, func(on):
		GameSettings.fullscreen = on
		GameSettings.apply(get_tree())))
	left.add_child(_slider_row("ขนาดตัวหนังสือและแผง", GameSettings.ui_scale, 0.85, 1.3, 0.05, func(v):
		GameSettings.ui_scale = v
		GameSettings.apply(get_tree()), "×%.2f", 1.0))
	left.add_child(_toggle_row("ภูมิทัศน์รอบแปลงแบบละเอียด (ปิดเพื่อให้ลื่นขึ้นบน Steam Deck)", GameSettings.landscape_detail == "high", func(on):
		GameSettings.landscape_detail = "high" if on else "low"))

	right.add_child(UITheme.header("crew", "การเล่น", UITheme.STRAW))
	right.add_child(_slider_row("ระยะกล้องเริ่มต้น", GameSettings.camera_zoom, 26.0, 64.0, 1.0, func(v):
		GameSettings.camera_zoom = v, "%d ม.", 1.0))
	right.add_child(_toggle_row("แสดงคำแนะนำปุ่มควบคุม", GameSettings.show_hints, func(on):
		GameSettings.show_hints = on))
	right.add_child(_toggle_row("เคล็ดลับระหว่างเผาครั้งแรก", GameSettings.first_burn_tips, func(on):
		GameSettings.first_burn_tips = on))
	right.add_child(_board_name_row())
	var howto = Button.new()
	howto.text = "แสดงวิธีเล่นอีกครั้ง"
	howto.pressed.connect(func(): how_to_play_requested.emit())
	right.add_child(howto)

	if OnlineBoard.available():
		right.add_child(UITheme.header("satellite", "กระดานออนไลน์ (เบตา)", UITheme.MUTED))
		right.add_child(_toggle_row("ส่งผลการเล่นขึ้นกระดานออนไลน์", GameSettings.online_board, func(on):
			GameSettings.online_board = on
			if on:
				OnlineBoard.ensure_identity()
			_update_delete_button()))
		var online_note = UITheme.label("ส่งเฉพาะชื่อบนกระดานและคะแนน ไม่มีอีเมลหรือข้อมูลส่วนตัว กระดานเบตาใช้ระบบเกียรติยศ ลบคะแนนของคุณได้ทุกเมื่อ", "Small", UITheme.MUTED)
		online_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(online_note)
		var wipe = Button.new()
		delete_scores_button = wipe
		wipe.text = "ลบคะแนนของฉันออกจากกระดานออนไลน์"
		_update_delete_button()
		wipe.pressed.connect(_delete_scores)
		right.add_child(wipe)
		online_status = UITheme.wrap(UITheme.label("", "Small", UITheme.MUTED))
		online_status.visible = false
		right.add_child(online_status)
	else:
		_build_offline_help(right)

	right.add_child(UITheme.header("hammer", "สำหรับผู้ทดสอบ", UITheme.MUTED))
	right.add_child(_toggle_row("เครื่องมือทดสอบ (F3 ข้อมูล · F5–F10 ข้ามเวลา/บังคับเหตุการณ์)", GameSettings.debug_tools, func(on):
		GameSettings.debug_tools = on))
	var logs = Button.new()
	logs.text = "เปิดโฟลเดอร์บันทึกการเล่น"
	logs.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	right.add_child(logs)

func _build_offline_help(parent: Node) -> void:
	parent.add_child(UITheme.header("satellite", "ข้อมูล · ช่วยเหลือ", UITheme.MUTED))
	parent.add_child(UITheme.wrap(UITheme.label("เวอร์ชันนี้เล่นแบบออฟไลน์ ไม่มีการส่งคะแนนออนไลน์", "Small", UITheme.MUTED)))
	var policy := Button.new()
	policy.name = "PrivacyPolicyButton"
	policy.text = "นโยบายความเป็นส่วนตัว"
	policy.pressed.connect(func(): OS.shell_open("https://undertwoskies-ios-support.undertwoskies-game.workers.dev/privacy/"))
	parent.add_child(policy)
	var help := Button.new()
	help.name = "SupportButton"
	help.text = "ติดต่อผู้พัฒนา"
	help.pressed.connect(func(): OS.shell_open("https://undertwoskies-ios-support.undertwoskies-game.workers.dev/support/"))
	parent.add_child(help)

func _update_delete_button() -> void:
	if is_instance_valid(delete_scores_button):
		delete_scores_button.disabled = _delete_pending or GameSettings.client_id == "" or GameSettings.client_secret == ""

func _delete_scores() -> void:
	if _delete_pending or GameSettings.client_id == "" or GameSettings.client_secret == "":
		return
	_delete_pending = true
	_update_delete_button()
	online_status.text = "กำลังลบคะแนนออนไลน์…"
	online_status.show()
	_delete_requester.call(self, _on_delete_complete)

func _on_delete_complete(deleted: int) -> void:
	_delete_pending = false
	_update_delete_button()
	online_status.text = L10n.format("ลบคะแนนออนไลน์แล้ว %d รายการ", deleted) if deleted >= 0 else "ลบคะแนนไม่สำเร็จ โปรดลองอีกครั้ง"
	online_status.add_theme_color_override("font_color", UITheme.EMERALD if deleted >= 0 else UITheme.EMBER)
	online_status.show()

func _slider_row(text: String, value: float, lo: float, hi: float, step: float, on_change: Callable, fmt: String, shown_scale: float) -> Control:
	var row = UITheme.hbox(10)
	var l = UITheme.label(text, "Small", UITheme.CREAM)
	l.custom_minimum_size = Vector2(170, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var slider = HSlider.new()
	slider.scrollable = false
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)
	var shown = UITheme.label(L10n.format(fmt, value * shown_scale), "Small", UITheme.STRAW)
	shown.custom_minimum_size = Vector2(58, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	slider.value_changed.connect(func(v):
		shown.text = L10n.format(fmt, v * shown_scale)
		on_change.call(v))
	return row

func _toggle_row(text: String, on: bool, on_change: Callable) -> Control:
	var b = CheckButton.new()
	b.text = text
	b.button_pressed = on
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", UITheme.font("regular"))
	b.add_theme_font_size_override("font_size", 14)
	b.toggled.connect(func(v): on_change.call(v))
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	GameSettings.save_settings()
	if _focus_scope:
		_focus_scope.release()
	closed.emit()
	queue_free()
