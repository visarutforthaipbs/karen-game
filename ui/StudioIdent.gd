extends Control

## Doisaket Game Lab studio ident: text only, white on the UI ink.
## "DOISAKET" settles in letter by letter, "GAME LAB" follows, the lockup holds
## long enough to read, then fades to the title. Any tap / key skips.
## Boot scene; tests load Title.tscn directly. `--no-ident` skips.

const NEXT := "res://scenes/Title.tscn"
const NAME_TEXT := "DOISAKET"
const SUB_TEXT := "GAME LAB"
const LETTER_STEP := 0.11     # seconds between letters of DOISAKET
const LETTER_RISE := 0.55     # seconds for one letter to settle
const SUB_DELAY := 1.25       # when GAME LAB starts
const SUB_RISE := 0.7
const RULE_DELAY := 1.9       # thin rule between the two lines
const HOLD_UNTIL := 5.2       # lockup fully readable until here
const FADE := 0.6

var _t := 0.0
var _done := false
var _letters: Array[Label] = []
var _sub: Label
var _rule: ColorRect
var _veil: ColorRect
var _name_row: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.INK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_name_row = HBoxContainer.new()
	_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_row.add_theme_constant_override("separation", 6)
	_name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_name_row)
	for ch in NAME_TEXT:
		var l := Label.new()
		l.text = ch
		l.add_theme_font_override("font", UITheme.font("state_bold"))
		l.add_theme_font_size_override("font_size", 92)
		l.add_theme_color_override("font_color", UITheme.CREAM)
		l.modulate.a = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_row.add_child(l)
		_letters.append(l)

	_rule = ColorRect.new()
	_rule.color = Color(UITheme.CREAM, 0.55)
	_rule.custom_minimum_size = Vector2(0, 2)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rule)

	_sub = Label.new()
	_sub.text = SUB_TEXT
	_sub.add_theme_font_override("font", UITheme.font("state"))
	_sub.add_theme_font_size_override("font_size", 34)
	_sub.add_theme_color_override("font_color", Color(UITheme.CREAM, 0.85))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.modulate.a = 0.0
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_sub)

	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = UITheme.INK
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	if OS.get_cmdline_user_args().has("--no-ident"):
		_finish()

static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	for i in _letters.size():
		var a := _ease_out((_t - i * LETTER_STEP) / LETTER_RISE)
		var l := _letters[i]
		l.modulate.a = a
		l.position.y = (1.0 - a) * 28.0   # settles down into place
	var s := _ease_out((_t - SUB_DELAY) / SUB_RISE)
	_sub.modulate.a = s
	_sub.position.y = (1.0 - s) * 14.0
	var r := _ease_out((_t - RULE_DELAY) / 0.6)
	_rule.custom_minimum_size.x = r * 220.0
	_rule.modulate.a = r
	_veil.modulate.a = clampf((_t - HOLD_UNTIL) / FADE, 0.0, 1.0)
	if _t >= HOLD_UNTIL + FADE:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file.call_deferred(NEXT)
