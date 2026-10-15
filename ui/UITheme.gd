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
static var _touch_targets_installed: bool = false
## Test-only override for safe_area_insets() ({left, top, right, bottom} in
## canvas px); empty = use the display's real safe area.
static var debug_insets: Dictionary = {}

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

# ---------------------------------------------------------------------------
# Mobile (iPhone / iPad landscape): notch, rounded corners, home indicator
# ---------------------------------------------------------------------------

## Marks a layer that already carries the safe-area padding, so a nested
## overlay never pads twice.
const SAFE_AREA_META := "_uts_safe_area"
## 44 pt on the iPhone's ~2x canvas maps to 88 canvas pixels.
const TOUCH_MIN := 88.0

## Touch device? `--touch` lets headless tests force the mobile UI path.
## Thai text on phones (owner feedback 0.3.3: "text too small for mobile").
## A landscape iPhone shrinks the 1280x720 canvas to ~393 pt tall, about 0.55 pt
## per canvas px, so 13 px Small text was 7 pt and 15 px body 8 pt (Apple's floor
## is 11 pt; Thai stacked vowels/tone marks need more than Latin). On a phone the
## text, not the layout, grows so body text lands near 12.6 pt and Small near
## 11 pt. Tablets and desktop compute <= 1.0 and keep their sizes exactly.
const PHONE_TEXT_SCALE := 1.55
const BODY_TARGET_PT := 12.6
static var _text_scale: float = -1.0

static func text_scale() -> float:
	if _text_scale > 0.0:
		return _text_scale
	_text_scale = 1.0
	if is_mobile():
		_text_scale = PHONE_TEXT_SCALE
		var pt := _points_per_canvas_px()
		if pt > 0.0:
			_text_scale = clampf(BODY_TARGET_PT / (15.0 * pt), 1.0, PHONE_TEXT_SCALE)
	return _text_scale

## Thai typesetting: never strand a unit on its own line ("196 / น.)"). Joins a
## number and the short unit after it with a no-break space (U+00A0).
static var _unit_re: RegEx = null

static func keep_units(text: String) -> String:
	if _unit_re == null:
		# units (escaped so the catalog check does not read the pattern as UI text):
		# น. ล. ม. นาย ลำ จุด ตัว TU
		_unit_re = RegEx.create_from_string("(\\d) (\u0e19\\.|\u0e25\\.|\u0e21\\.|\u0e19\u0e32\u0e22|\u0e25\u0e33|\u0e08\u0e38\u0e14|\u0e15\u0e31\u0e27|TU)")
	return _unit_re.sub(text, "$1\u00a0$2", true)

## Font size for the current device: desktop/tablet unchanged, phones scaled.
static func fs(size: float) -> int:
	return int(round(size * text_scale()))

## Points per canvas pixel on a real touch screen (0 when unknown, e.g. headless:
## tests then get the phone scale, the case that matters for layout).
static func _points_per_canvas_px() -> float:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--touch"):
		return 0.0   # tests / captures simulate a phone
	var px := DisplayServer.screen_get_size()
	var scale := DisplayServer.screen_get_scale()
	if px.x <= 0 or px.y <= 0 or scale <= 0.0:
		return 0.0
	var long_pt := float(maxi(px.x, px.y)) / scale
	var short_pt := float(mini(px.x, px.y)) / scale
	return minf(long_pt / 1280.0, short_pt / 720.0)

static func is_mobile() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")

static func _zero_insets() -> Dictionary:
	return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

## Display cutout / rounded corners / home indicator in canvas pixels.
## Always zero in headless, for a floating desktop window (it does not sit
## under the cutout) and when the OS reports no safe area, or one equal to
## the screen. Display pixels are scaled into canvas units via
## canvas (Window.content_scale_size) / window size.
static func safe_area_insets() -> Dictionary:
	var insets := _zero_insets()
	if not debug_insets.is_empty():
		return debug_insets.duplicate()   # tests: simulate a notch / home indicator
	if DisplayServer.get_name() == "headless":
		return insets
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return insets
	# Screen rects and the safe area are reported in the same global space
	# (on macOS the display itself starts at y = 1428, for example).
	var screen := Rect2i(DisplayServer.screen_get_position(), screen_size)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return insets
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return insets
	# A floating window is never under the notch: only a window covering the
	# display (the mobile/fullscreen case) inherits the OS insets.
	if window_size.x < screen_size.x * 0.9 or window_size.y < screen_size.y * 0.9:
		return insets
	var left := clampf(float(safe.position.x) - float(screen.position.x), 0.0, float(screen_size.x))
	var top := clampf(float(safe.position.y) - float(screen.position.y), 0.0, float(screen_size.y))
	var right := clampf(float(screen.end.x) - float(safe.end.x), 0.0, float(screen_size.x))
	var bottom := clampf(float(screen.end.y) - float(safe.end.y), 0.0, float(screen_size.y))
	if left + top + right + bottom <= 0.0:
		return insets
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return insets
	var canvas: Vector2i = tree.root.content_scale_size
	if canvas.x <= 0 or canvas.y <= 0:
		return insets
	var sx := float(canvas.x) / float(window_size.x)
	var sy := float(canvas.y) / float(window_size.y)
	return {"left": left * sx, "top": top * sy, "right": right * sx, "bottom": bottom * sy}

## The visible canvas minus the safe-area insets. Screens that centre a card
## in the viewport lay out against this instead of the raw visible rect.
static func safe_area_rect() -> Rect2:
	var size := Vector2.ZERO
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		size = tree.root.get_visible_rect().size
	var insets := safe_area_insets()
	var pad := Vector2(insets.left + insets.right, insets.top + insets.bottom)
	return Rect2(Vector2(insets.left, insets.top), Vector2(maxf(0.0, size.x - pad.x), maxf(0.0, size.y - pad.y)))

## Pad a top-level UI layer away from the display cutout. Edges pinned to a
## side of the parent move inward; floating (centre-anchored) children stay
## put — their parent is already inset. No-op when the layer, or any layer
## above it, already carries the insets, and a complete no-op on desktop.
static func apply_safe_area(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var insets := safe_area_insets()
	if insets.left + insets.top + insets.right + insets.bottom <= 0.0:
		return
	if control.has_meta(SAFE_AREA_META):
		return
	var parent := control.get_parent()
	while parent:
		if parent is Control and parent.has_meta(SAFE_AREA_META):
			return
		parent = parent.get_parent()
	control.set_meta(SAFE_AREA_META, true)
	if is_equal_approx(control.anchor_left, 0.0):
		control.offset_left += insets.left
	elif is_equal_approx(control.anchor_left, 1.0):
		control.offset_left -= insets.right
	if is_equal_approx(control.anchor_right, 1.0):
		control.offset_right -= insets.right
	elif is_equal_approx(control.anchor_right, 0.0):
		control.offset_right += insets.left
	if is_equal_approx(control.anchor_top, 0.0):
		control.offset_top += insets.top
	elif is_equal_approx(control.anchor_top, 1.0):
		control.offset_top -= insets.bottom
	if is_equal_approx(control.anchor_bottom, 1.0):
		control.offset_bottom -= insets.bottom
	elif is_equal_approx(control.anchor_bottom, 0.0):
		control.offset_bottom += insets.top

## Raise every Button under `node` to the 44 pt touch target. Desktop is
## untouched; the shared Theme already gives all buttons an 88 px floor.
static func apply_touch_targets(node: Node) -> void:
	if not is_mobile() or node == null:
		return
	install_touch_targets()
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, TOUCH_MIN)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, TOUCH_MIN)
	for child in node.get_children():
		apply_touch_targets(child)

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t = Theme.new()
	t.default_font = font("regular")
	t.default_font_size = fs(16)

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("line_spacing", "Label", 1)

	_label_variation(t, "Title", "semibold", fs(19), CREAM)
	_label_variation(t, "Kicker", "medium", fs(13), STRAW)
	_label_variation(t, "Body", "regular", fs(15), CREAM)
	_label_variation(t, "Small", "regular", fs(13), MUTED)
	_label_variation(t, "BigNumber", "bold", fs(36), CREAM)
	_label_variation(t, "StateText", "state", fs(15), STATE)
	_label_variation(t, "StateBig", "state_bold", fs(30), RUBY)

	# Buttons: slabs that press down into the panel
	_button_styles(t, "Button", PANEL_HI, EMERALD_DEEP)
	t.set_font("font", "Button", font("medium"))
	t.set_font_size("font_size", "Button", fs(15))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", CREAM)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM)

	t.set_type_variation("PrimaryButton", "Button")
	_button_styles(t, "PrimaryButton", CLAY.lerp(EMBER, 0.35), EMBER, 6)
	t.set_font("font", "PrimaryButton", font("semibold"))
	t.set_font_size("font_size", "PrimaryButton", fs(20))
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

	# Editable controls share the same palette and visible keyboard focus.
	# Sliders highlight both their filled track and thumb when focused.
	var slider_track = slab(INK, 0, 3)
	slider_track.set_content_margin_all(3)
	var slider_fill = slab(MUTED, 0, 3)
	slider_fill.set_content_margin_all(3)
	var slider_focus = slab(STRAW, 0, 3)
	slider_focus.set_content_margin_all(3)
	t.set_stylebox("slider", "HSlider", slider_track)
	t.set_stylebox("grabber_area", "HSlider", slider_fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", slider_focus)
	t.set_icon("grabber", "HSlider", _slider_thumb(CREAM))
	t.set_icon("grabber_highlight", "HSlider", _slider_thumb(STRAW))
	t.set_icon("grabber_disabled", "HSlider", _slider_thumb(DIM))
	t.set_stylebox("normal", "LineEdit", slab(INK, 0, 5))
	t.set_stylebox("read_only", "LineEdit", slab(PANEL, 0, 5))
	t.set_stylebox("focus", "LineEdit", outline(STRAW, 2, 5))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", STRAW)
	t.set_color("selection_color", "LineEdit", EMERALD_DEEP)
	t.set_color("font_selected_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)

	# Touch devices: a Theme cannot express a minimum size, so the 44 pt floor
	# is applied to every Button as it enters the tree (see install_touch_targets).
	if is_mobile():
		install_touch_targets()

	_theme = t
	return t

## Floors every Button created at runtime — including screens that build
## their own controls (the Hearth, overlays, touch pads). Installed once, and
## only on touch devices, so desktop layout is untouched.
static func install_touch_targets() -> void:
	if _touch_targets_installed or not is_mobile():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_touch_targets_installed = true
	tree.node_added.connect(_on_node_added)

static func _on_node_added(node: Node) -> void:
	if node is Button:
		var button := node as Button
		button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, TOUCH_MIN)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, TOUCH_MIN)
	elif node is ScrollContainer:
		install_touch_scroll(node as ScrollContainer)

## Godot 4.7.2's ScrollContainer only drag-scrolls from mouse events, and this
## project turns mouse emulation off (finger #0 emulation breaks two-thumb play),
## so menus could not be swiped on the phone (iPhone scrolling audit, 2026-10-13).
## This handler scrolls a container directly from screen drags. A swipe that
## starts on a Button stays on the button (MOUSE_FILTER_STOP), so it neither
## scrolls nor misfires; swipes over text and blank content scroll.
const TOUCH_SCROLL_META := &"uts_touch_scroll"

static func install_touch_scroll(sc: ScrollContainer) -> void:
	if sc == null or not is_mobile() or sc.has_meta(TOUCH_SCROLL_META):
		return
	sc.set_meta(TOUCH_SCROLL_META, true)
	sc.gui_input.connect(Callable(UITheme, "_touch_scroll_input").bind(sc))

## Install on every ScrollContainer already under `node` (screens built before
## the installer ran, or tests that construct UI directly).
static func apply_touch_scroll(node: Node) -> void:
	if node == null or not is_mobile():
		return
	if node is ScrollContainer:
		install_touch_scroll(node)
	for child in node.get_children():
		apply_touch_scroll(child)

static func _touch_scroll_input(event: InputEvent, sc: ScrollContainer) -> void:
	if not (event is InputEventScreenDrag) or not is_instance_valid(sc):
		return
	var drag := event as InputEventScreenDrag
	var moved := false
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var before := sc.scroll_vertical
		sc.scroll_vertical = before - int(round(drag.relative.y))
		moved = moved or sc.scroll_vertical != before
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var before_h := sc.scroll_horizontal
		sc.scroll_horizontal = before_h - int(round(drag.relative.x))
		moved = moved or sc.scroll_horizontal != before_h
	if moved or absf(drag.relative.y) > 0.0 or absf(drag.relative.x) > 0.0:
		sc.accept_event()

static func _slider_thumb(color: Color) -> ImageTexture:
	var image = Image.create(14, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 18:
		for x in 14:
			# Cut corners keep the thumb legible against faceted panels.
			if x + y >= 3 and (13 - x) + y >= 3 and x + (17 - y) >= 3 and (13 - x) + (17 - y) >= 3:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

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

## Character portrait from assets/ui/portraits/<id>_256.png (rendered from the
## installed rigs), or a crew icon when it is missing.
## ids: khanae, tapoh, munaw, maelu, ranger
static func portrait(id: String, size: float, fallback_tint: Color = STRAW) -> Control:
	var path = "res://assets/ui/portraits/%s_256.png" % id
	if not ResourceLoader.exists(path):
		return icon("crew", fallback_tint, size * 0.7)
	var t = TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Thai crew name -> portrait id
static func portrait_id(name_th: String) -> String:
	return {"ขะแน": "khanae", "ตาโพ": "tapoh", "มูนอ": "munaw", "แม่ลู": "maelu"}.get(name_th, "")

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
