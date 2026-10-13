extends Control

## Manually measured text lockup: no containers own animated positions.
const NEXT := "res://scenes/Title.tscn"
const NAME_TEXT := "DOISAKET"
const SUB_TEXT := "GAME LAB"
const LETTER_STEP := 0.10
const LETTER_RISE := 0.55
const RULE_DELAY := 1.30
const SUB_DELAY := 1.65
const SUB_RISE := 0.55
const HOLD_UNTIL := 5.50
const FADE := 0.60

var _t := 0.0
var _done := false
var _letters: Array[Label] = []
var _sub: Control
var _sub_letters: Array[Label] = []
var _rule: ColorRect
var _veil: ColorRect
var _name_origins: Array[Vector2] = []
var _sub_origin := Vector2.ZERO
var _scale := 1.0
var _name_width := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.INK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for ch in NAME_TEXT:
		_letters.append(_glyph(ch, UITheme.font("state_bold"), self))
	_rule = ColorRect.new()
	_rule.color = Color(UITheme.CREAM, 0.55)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_sub = Control.new()
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	for ch in SUB_TEXT:
		_sub_letters.append(_glyph(ch, UITheme.font("state"), _sub))
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = UITheme.INK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	resized.connect(_layout)
	_layout()
	if OS.get_cmdline_user_args().has("--no-ident"):
		_finish()

func _glyph(ch: String, font: Font, parent: Node) -> Label:
	var label := Label.new()
	label.text = ch
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", UITheme.CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _layout() -> void:
	if _sub == null:
		return
	_scale = minf(size.x / 1280.0, size.y / 720.0)
	var name_size := maxi(1, roundi(92.0 * _scale))
	var sub_size := maxi(1, roundi(28.0 * _scale))
	var name_font := UITheme.font("state_bold")
	var sub_font := UITheme.font("state")
	var widths: Array[float] = []
	_name_width = 0.0
	for l in _letters:
		l.add_theme_font_size_override("font_size", name_size)
		var w := name_font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		widths.append(w)
		l.size = Vector2(w, l.get_combined_minimum_size().y)
		_name_width += w
	_name_width += (_letters.size() - 1) * 2.0 * _scale
	_name_origins.clear()
	var x := (size.x - _name_width) * 0.5
	var y := size.y * 0.5 - 76.0 * _scale
	for i in _letters.size():
		_name_origins.append(Vector2(x, y))
		x += widths[i] + 2.0 * _scale
	var sub_width := 0.0
	for l in _sub_letters:
		l.add_theme_font_size_override("font_size", sub_size)
		var w := sub_font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x
		l.size = Vector2(w, l.get_combined_minimum_size().y)
		l.position = Vector2(sub_width, 0.0)
		sub_width += w + sub_size * 0.25
	sub_width -= sub_size * 0.25
	_sub.size = Vector2(sub_width, _sub_letters[0].size.y)
	_sub_origin = Vector2((size.x - sub_width) * 0.5, size.y * 0.5 + 43.0 * _scale)
	_apply_motion()

static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

func _apply_motion() -> void:
	var tracking := (1.0 - _ease_out(_t / 1.25)) * 92.0 * 0.06 * _scale
	for i in _letters.size():
		var a := _ease_out((_t - i * LETTER_STEP) / LETTER_RISE)
		_letters[i].modulate.a = a
		_letters[i].position = _name_origins[i] + Vector2((i - 3.5) * tracking, -(1.0 - a) * 27.6 * _scale)
	var r := _ease_out((_t - RULE_DELAY) / 0.35)
	_rule.size = Vector2(220.0 * _scale * r, maxf(1.0, _scale))
	_rule.position = Vector2((size.x - _rule.size.x) * 0.5, size.y * 0.5 + 25.0 * _scale)
	_rule.modulate.a = r
	var s := _ease_out((_t - SUB_DELAY) / SUB_RISE)
	_sub.modulate.a = s
	_sub.position = _sub_origin + Vector2(0, -(1.0 - s) * 8.0 * _scale)
	_veil.modulate.a = clampf((_t - HOLD_UNTIL) / FADE, 0.0, 1.0)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_apply_motion()
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
