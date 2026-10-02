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
	if not event.is_action_pressed("pause"):
		return
	if _sub != null:
		return # The open sub-panel handles its own Esc
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
	resume_button.grab_focus()

func resume() -> void:
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
	card.padding = Vector4(28, 22, 28, 24)
	card.chamfer = 14.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(440, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_child(card)
	var box = UITheme.vbox(10)
	card.add_child(box)
	var title = UITheme.label("หยุดเกมชั่วคราว", "Title", UITheme.STRAW)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var clock = main.get("game_clock") if main else null
	if clock:
		box.add_child(UITheme.label("เวลาในไร่หยุดที่ %s" % _clock_text(clock.get_hours()), "Small"))
	resume_button = _button(box, "เล่นต่อ", resume, "PrimaryButton")
	_button(box, "วิธีเล่น", _open_how_to_play)
	_button(box, "ตั้งค่า", _open_settings)
	_button(box, "ยอมแพ้แปลงนี้ · ให้ดาวเทียมผ่านเลย", _give_up_plot)
	var note = UITheme.wrap(UITheme.label("นับเป็นการเผาตามสภาพตอนนี้ ดาวเทียมจะสแกนทันที", "Small", UITheme.DIM))
	box.add_child(note)
	_button(box, "ออกไปหน้าแรก (กลับไปก่อนเผาแปลงนี้)", _quit_to_title)
	return p

func _button(parent: Control, text: String, action: Callable, variation: String = "Button") -> Button:
	var b = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _clock_text(hours: float) -> String:
	var m = int(round(hours * 60.0))
	return "%02d:%02d" % [m / 60, m % 60]

func _open_how_to_play() -> void:
	var h = HowToPlay.new()
	h.process_mode = Node.PROCESS_MODE_ALWAYS
	h.closed.connect(func():
		_sub = null
		resume_button.grab_focus())
	_sub = h
	add_child(h)

func _open_settings() -> void:
	var s = SettingsPanel.new()
	s.closed.connect(func():
		_sub = null
		resume_button.grab_focus())
	s.how_to_play_requested.connect(func():
		s.close()
		_open_how_to_play())
	_sub = s
	add_child(s)

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
