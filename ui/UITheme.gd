class_name UITheme
extends RefCounted

## Low-poly UI kit: palette, Thai fonts and a shared Theme.
## Kanit (Cadson Demak, OFL) is the village voice; Chakra Petch is the state's
## surveillance readouts. Panels are chamfered slabs with a lit top facet and a
## hard extruded underside, matching the flat-shaded hillside.

# Palette (PRD §9.1)
const INK = Color("101318")
const PANEL = Color("1b1f26")
const PANEL_HI = Color("272c35")
const CREAM = Color("f3ead6")
const MUTED = Color("a8a493")
const DIM = Color("6f6d64")
const EMERALD = Color("46b37a")
const EMERALD_DEEP = Color("1f5a3d")
const STRAW = Color("eac46b")
const CLAY = Color("c8643b")
const EMBER = Color("ff8a3d")
const RUBY = Color("e5484d")
const WATER = Color("5fb9ff")
const STATE = Color("7fe3ff")      # cold surveillance cyan
const STATE_DEEP = Color("0d1a2b")

const CHAMFER: int = 10

const FONT_FILES = {
	"light": "res://assets/fonts/Kanit-Light.ttf",
	"regular": "res://assets/fonts/Kanit-Regular.ttf",
	"medium": "res://assets/fonts/Kanit-Medium.ttf",
	"semibold": "res://assets/fonts/Kanit-SemiBold.ttf",
	"bold": "res://assets/fonts/Kanit-Bold.ttf",
	"state": "res://assets/fonts/ChakraPetch-Medium.ttf",
	"state_bold": "res://assets/fonts/ChakraPetch-SemiBold.ttf",
}

static var _theme: Theme
static var _fonts: Dictionary = {}

static func font(weight: String) -> Font:
	if not _fonts.has(weight):
		_fonts[weight] = load(FONT_FILES[weight])
	return _fonts[weight]

## Chamfered slab: flat face, lit top edge, hard drop for depth
static func slab(bg: Color, depth: int = 4, chamfer: int = CHAMFER) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(chamfer)
	sb.corner_detail = 1
	sb.border_width_top = 2
	sb.border_color = bg.lightened(0.22)
	if depth > 0:
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, depth)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

static func outline(color: Color, width: int = 2, chamfer: int = CHAMFER) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(chamfer)
	sb.corner_detail = 1
	sb.set_border_width_all(width)
	sb.border_color = color
	sb.set_expand_margin_all(3)
	return sb

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t = Theme.new()
	t.default_font = font("regular")
	t.default_font_size = 16

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("line_spacing", "Label", 1)

	_label_variation(t, "Title", "semibold", 19, CREAM)
	_label_variation(t, "Kicker", "medium", 13, STRAW)
	_label_variation(t, "Body", "regular", 15, CREAM)
	_label_variation(t, "Small", "regular", 13, MUTED)
	_label_variation(t, "BigNumber", "bold", 36, CREAM)
	_label_variation(t, "StateText", "state", 15, STATE)
	_label_variation(t, "StateBig", "state_bold", 30, RUBY)

	# Buttons: slabs that press down into the panel
	_button_styles(t, "Button", PANEL_HI, EMERALD_DEEP)
	t.set_font("font", "Button", font("medium"))
	t.set_font_size("font_size", "Button", 15)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", CREAM)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)

	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton", CLAY.lerp(EMBER, 0.35), EMBER, 6)
	t.set_font("font", "PrimaryButton", font("semibold"))
	t.set_font_size("font_size", "PrimaryButton", 20)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "PrimaryButton", INK)

	var panel = slab(Color(PANEL, 0.94), 5)
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 10)

	var scroll_grabber = slab(DIM, 0, 3)
	scroll_grabber.set_content_margin_all(3)
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", slab(MUTED, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", slab(STRAW, 0, 3))
	var track = StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.25)
	track.content_margin_left = 4
	track.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", track)

	_theme = t
	return t

static func _label_variation(t: Theme, name: String, weight: String, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font(weight))
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)

static func _button_styles(t: Theme, type: String, face: Color, selected: Color, depth: int = 4) -> void:
	var normal = slab(face, depth)
	var hover = slab(face.lightened(0.1), depth)
	var pressed = slab(selected, 1)
	pressed.content_margin_top += depth - 1
	pressed.content_margin_bottom -= depth - 1
	var disabled = slab(Color(face.darkened(0.35), 0.8), 1)
	disabled.border_color = disabled.bg_color
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, outline(STRAW))

# ---------------------------------------------------------------------------
# Small builders shared by the HUD and the Village Hearth
# ---------------------------------------------------------------------------

static func label(text: String = "", variation: String = "Body", color: Variant = null) -> Label:
	var l = Label.new()
	l.text = text
	l.theme_type_variation = variation
	if color != null:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Text that sits straight on the 3D view needs an outline to stay legible
static func outlined(l: Label, size: int = 6) -> Label:
	l.add_theme_constant_override("outline_size", size)
	return l

static func icon(kind: String, color: Color, size: float = 24.0) -> LowPolyIcon:
	var i = LowPolyIcon.new()
	i.kind = kind
	i.color = color
	i.custom_minimum_size = Vector2(size, size)
	return i

## Icon + kicker label row used as card headers
static func header(kind: String, text: String, color: Color = STRAW) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var i = icon(kind, color, 20.0)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(i)
	row.add_child(label(text, "Kicker", color))
	return row

static func vbox(sep: int = 6) -> VBoxContainer:
	var b = VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func hbox(sep: int = 10) -> HBoxContainer:
	var b = HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func card(base: Color = PANEL, accent: Color = STRAW, seed_value: int = 1) -> FacetCard:
	var c = FacetCard.new()
	c.base_color = base
	c.accent = accent
	c.seed_value = seed_value
	return c

## Thai compass names; directions are in grid space (+x east, +y south)
static func cardinal_th(v: Vector2) -> String:
	if v.length() < 0.01:
		return "ลมสงบ"
	var octant = posmod(int(round(8.0 * atan2(v.y, v.x) / TAU)), 8)
	return ["ตะวันออก", "ตะวันออกเฉียงใต้", "ใต้", "ตะวันตกเฉียงใต้", "ตะวันตก", "ตะวันตกเฉียงเหนือ", "เหนือ", "ตะวันออกเฉียงเหนือ"][octant]

static func clock_text(start_delay_minutes: int) -> String:
	return "%d:%02d" % [14 + start_delay_minutes / 60, start_delay_minutes % 60]
