class_name PauseMenu
extends Control

## Pause menu (P0-2) for the burn: Esc / Start freezes the whole burn (clock,
## fire, drones, crew) via SceneTree.paused; this node keeps running.

const TITLE_SCENE = "res://scenes/Title.tscn"

## The burn's MainController (HUD's parent)
var main: Node
var resume_button: Button
var _panel: Control
var _sub: Control
var _focus_scope: ModalFocusScope
var _sub_scope: ModalFocusScope
var _pause_card: Control
var _pause_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func can_pause() -> bool:
	if main == null or main.get("pass_started"):
		return false
	var hud = main.get("hud")
	return not (hud and hud.report_modal and hud.report_modal.visible)

func _unhandled_input(event: InputEvent) -> void:
	if _sub != null:
		if _sub_scope and event.is_action_pressed("ui_cancel"):
			_dismiss_confirmation()
			get_viewport().set_input_as_handled()
		return # Guide/Settings handle their own Back or Esc.
	if visible and event.is_action_pressed("ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pause"):
		return
	if visible:
		resume()
	elif can_pause():
		open()
	else:
		return
	get_viewport().set_input_as_handled()

func open() -> void:
	get_tree().paused = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel:
		_panel.queue_free()
	_panel = _build_panel()
	add_child(_panel)
	_focus_scope = ModalFocusScope.begin(_panel)
	if not get_viewport().size_changed.is_connected(_fit_panel):
		get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	resume_button.grab_focus()

func resume() -> void:
	if _focus_scope:
		_focus_scope.release()
		_focus_scope = null
	get_tree().paused = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel:
		_panel.queue_free()
		_panel = null

func _build_panel() -> Control:
	var p = Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.theme = UITheme.get_theme()
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.62)
	p.add_child(dim)
	var card = UITheme.card(Color(UITheme.PANEL, 0.97), UITheme.STRAW, 530)
	_pause_card = card
	card.padding = Vector4(28, 22, 28, 24)
	card.chamfer = 14.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(minf(560.0, get_viewport().get_visible_rect().size.x - 48.0), 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_child(card)
	var box = UITheme.vbox(10)
	_pause_box = box
	card.add_child(box)
	var title = UITheme.label("หยุดเกมชั่วคราว", "Title", UITheme.STRAW)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var clock = main.get("game_clock") if main else null
	if clock:
		box.add_child(UITheme.label(L10n.format("เวลาในไร่หยุดที่ %s", _clock_text(clock.get_hours())), "Small"))
	resume_button = _button(box, "เล่นต่อ", resume, "PrimaryButton")
	_button(box, "วิธีเล่น", _open_how_to_play)
	_button(box, "ตั้งค่า", _open_settings)
	_button(box, "ยอมแพ้แปลงนี้ · ให้ดาวเทียมผ่านเลย", func():
		_confirm_action("ให้ดาวเทียมสแกนแปลงตอนนี้? จะตัดสินจากเถ้าและความร้อนที่มีอยู่ และย้อนกลับไม่ได้", "ยืนยัน ให้สแกนตอนนี้", _give_up_plot))
	var note = UITheme.wrap(UITheme.label("นับเป็นการเผาตามสภาพตอนนี้ ดาวเทียมจะสแกนทันที", "Small", UITheme.MUTED))
	box.add_child(note)
	_button(box, "ออกไปหน้าแรก (กลับไปก่อนเผาแปลงนี้)", func():
		_confirm_action("กลับหน้าแรก? ความคืบหน้าระหว่างเผาแปลงนี้จะหายไป เกมที่บันทึกไว้ก่อนเผาจะยังอยู่", "ยืนยัน กลับหน้าแรก", _quit_to_title))
	box.minimum_size_changed.connect(_fit_panel)
	return p

func _button(parent: Control, text: String, action: Callable, variation: String = "Button") -> Button:
	var b = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _fit_panel() -> void:
	if not is_instance_valid(_pause_card) or _pause_card.is_queued_for_deletion():
		return
	var area = get_viewport().get_visible_rect().size
	_pause_card.custom_minimum_size.x = minf(560.0, area.x - 48.0)
	_pause_card.size = Vector2(_pause_card.custom_minimum_size.x, _pause_box.get_combined_minimum_size().y + 46.0)
	_pause_card.position = (area - _pause_card.size) * 0.5

func _clock_text(hours: float) -> String:
	var m = int(round(hours * 60.0))
	return "%02d:%02d" % [m / 60, m % 60]

func _open_how_to_play() -> void:
	var h = HowToPlay.new()
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	h.closed.connect(func():
		_sub = null)
	_sub = h
	add_child(h)

func _open_settings() -> void:
	var s = SettingsPanel.new()
	s.closed.connect(func():
		_sub = null)
	s.how_to_play_requested.connect(func():
		s.close()
		_open_how_to_play())
	_sub = s
	add_child(s)

func _confirm_action(question: String, confirm_text: String, action: Callable) -> void:
	if is_instance_valid(_sub):
		return
	_sub = Control.new()
	_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.theme = UITheme.get_theme()
	add_child(_sub)
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.8)
	_sub.add_child(dim)
	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.EMBER, 531)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.custom_minimum_size.x = minf(560.0, get_viewport().get_visible_rect().size.x - 48.0)
	_sub.add_child(card)
	var box = UITheme.vbox(14)
	card.add_child(box)
	box.add_child(UITheme.wrap(UITheme.label(question, "Title")))
	var row = UITheme.hbox(10)
	box.add_child(row)
	var cancel = _button(row, "ยกเลิก", _dismiss_confirmation, "PrimaryButton")
	var confirm = _button(row, confirm_text, func():
		_dismiss_confirmation()
		action.call())
	for button in [cancel, confirm]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 160.0
	_sub_scope = ModalFocusScope.begin(_sub)
	cancel.grab_focus()

func _dismiss_confirmation() -> void:
	if _sub_scope:
		_sub_scope.release()
		_sub_scope = null
	if is_instance_valid(_sub):
		_sub.queue_free()
	_sub = null

## The burn is judged as it stands: the 20:00 pass runs now (no penalty dodge)
func _give_up_plot() -> void:
	resume()
	if main and main.has_method("_on_satellite_pass") and not main.get("pass_started"):
		main._on_satellite_pass()

## Back to the title; the autosave from the Hearth before this burn is kept
func _quit_to_title() -> void:
	resume()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	get_tree().change_scene_to_file(TITLE_SCENE)
