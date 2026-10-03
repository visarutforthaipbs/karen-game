class_name SettingsPanel
extends Control

## Settings overlay (P0-4), shared by the title screen, pause menu and Hearth.
## Values live in GameSettings (user://settings.cfg) and apply immediately.

signal closed
signal how_to_play_requested

var close_button: Button
var language_picker: OptionButton
var _content_scroll: ScrollContainer
var delete_scores_button: Button
var online_status: Label
var _focus_scope: ModalFocusScope
var _delete_pending: bool = false
var _delete_requester: Callable = OnlineBoard.delete_my_scores

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
	card.padding = Vector4(26, 20, 26, 22)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(900, 0)
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

	# Keep every setting reachable at increased text size and on smaller
	# displays. Keyboard/controller focus scrolls the body into view.
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "SettingsBody"
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.follow_focus = true
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size.y = minf(440.0, maxf(160.0, get_viewport_rect().size.y - 220.0))
	page.add_child(_content_scroll)
	get_viewport().size_changed.connect(func():
		_content_scroll.custom_minimum_size.y = minf(440.0, maxf(160.0, get_viewport_rect().size.y - 220.0)))
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
	var name_row = UITheme.hbox(10)
	var name_label = UITheme.label("ชื่อบนกระดาน", "Small", UITheme.CREAM)
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
	right.add_child(name_row)
	var howto = Button.new()
	howto.text = "แสดงวิธีเล่นอีกครั้ง"
	howto.pressed.connect(func(): how_to_play_requested.emit())
	right.add_child(howto)

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

	right.add_child(UITheme.header("hammer", "สำหรับผู้ทดสอบ", UITheme.MUTED))
	right.add_child(_toggle_row("เครื่องมือทดสอบ (F3 ข้อมูล · F5–F10 ข้ามเวลา/บังคับเหตุการณ์)", GameSettings.debug_tools, func(on):
		GameSettings.debug_tools = on))
	var logs = Button.new()
	logs.text = "เปิดโฟลเดอร์บันทึกการเล่น"
	logs.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://")))
	right.add_child(logs)

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
