class_name GameHUD
extends CanvasLayer

## Burn-day HUD, built in code from the low-poly UI kit (ui/UITheme.gd).
## Layout: clock + phase timeline (top left), wind (top centre), state watch
## (top right), tools (bottom left), crew (bottom centre), vitals (bottom right).

const TOOL_SLOTS = [
	{"key": "1", "icon": "flame", "short": "จุดไฟ"},
	{"key": "2", "icon": "blade", "short": "ถางแนว"},
	{"key": "3", "icon": "drop", "short": "พ่นน้ำ"},
]
const WINDOW_START_MIN: int = 14 * 60
const WINDOW_END_MIN: int = 20 * 60

## 18:00 inversion post-process (PRD §4.3): sepia, softened, ground-hugging haze, vignette
const INVERSION_SHADER = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 col = textureLod(screen_texture, SCREEN_UV, strength * 0.35).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(lum) * vec3(1.12, 0.92, 0.66);
	float haze = smoothstep(0.2, 1.0, SCREEN_UV.y) * 0.4;
	float drift = sin(SCREEN_UV.x * 9.0 + TIME * 0.25) * sin(SCREEN_UV.y * 7.0 - TIME * 0.18) * 0.05;
	vec3 hazed = mix(sepia, vec3(0.72, 0.52, 0.32), clamp(haze + drift, 0.0, 1.0));
	float vignette = smoothstep(0.95, 0.35, distance(SCREEN_UV, vec2(0.5)));
	vec3 graded = mix(col, hazed, 0.6) * mix(0.75, 1.0, vignette);
	COLOR = vec4(mix(col, graded, strength), 1.0);
}
"""

var root: Control
var inversion_overlay: ColorRect
var _inversion_material: ShaderMaterial

# Top left: clock & phase
var clock_label: Label
var phase_kicker: Label
var phase_label: Label
var goal_label: Label
var timeline: SegmentBar

# Top centre: wind
var wind_card: FacetCard
var wind_compass: WindCompass
var wind_label: Label
var wind_note: Label

# Top right: state watch
var scrutiny_value: Label
var scrutiny_bar: SegmentBar
var hotspot_label: Label
var countdown_label: Label

# Bottom: tools, crew, vitals
var bottom_layer: Control
var tool_label: Label
var _tool_slots: Array[FacetCard] = []
var crew_row: HBoxContainer
var _crew_cards: Dictionary = {}
var breath_value: Label
var breath_bar: SegmentBar
var water_value: Label
var water_bar: SegmentBar
var yield_value: Label
var yield_bar: SegmentBar

# Banners and alerts, stacked under the wind card
var banner_stack: VBoxContainer
var alert_card: FacetCard
var alert_label: Label
var elder_warning_banner: FacetCard
var elder_warning_text: Label
var drone_banner: FacetCard
var drone_text: Label
var _drone_icon: LowPolyIcon

# 20:00 satellite pass
var satellite_thermal_screen: Control
var telemetry_card: FacetCard
var satellite_telemetry_label: Label
var thermal_legend: FacetCard
var report_modal: Control
var report_title: Label
var report_body: Label
var report_stats: HBoxContainer
var report_text: Label
var continue_button: Button

var _alert_serial: int = 0
var _barn_target: float = 75.0

func _ready() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	if GameState.instance and GameState.instance.has_favour(GameState.Favour.SEEDS):
		_barn_target = 65.0

	_build_inversion_overlay()
	_build_satellite_screen()
	_build_clock_card()
	_build_wind_card()
	_build_state_card()
	bottom_layer = Control.new()
	bottom_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_layer)
	_build_tool_bar()
	_build_crew_row()
	_build_vitals_card()
	_build_banners()
	_build_report()

# ---------------------------------------------------------------------------
# Layout helpers
# ---------------------------------------------------------------------------

func _pin(c: Control, anchor: Vector2, offset: Vector2, width: float = 0.0) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	if anchor.x == 0.5:
		c.offset_left = -width * 0.5
		c.offset_right = width * 0.5
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif anchor.x == 1.0:
		c.offset_left = offset.x - width
		c.offset_right = offset.x
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		c.offset_left = offset.x
		c.offset_right = offset.x + width
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor.y == 1.0 else Control.GROW_DIRECTION_END
	if width > 0.0:
		c.custom_minimum_size.x = width

func _stat_row(icon_kind: String, title: String, color: Color) -> Array:
	var row = UITheme.hbox(8)
	var i = UITheme.icon(icon_kind, color, 18.0)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(i)
	var name_label = UITheme.label(title, "Small", UITheme.MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value = UITheme.label("", "Body")
	value.add_theme_font_override("font", UITheme.font("semibold"))
	row.add_child(value)
	return [row, value]

func _bar(segments: int, color: Color, height: float = 10.0) -> SegmentBar:
	var b = SegmentBar.new()
	b.segments = segments
	b.fill_color = color
	b.custom_minimum_size = Vector2(0, height)
	return b

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_inversion_overlay() -> void:
	inversion_overlay = ColorRect.new()
	inversion_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inversion_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = INVERSION_SHADER
	_inversion_material = ShaderMaterial.new()
	_inversion_material.shader = shader
	inversion_overlay.material = _inversion_material
	inversion_overlay.color = Color.WHITE
	inversion_overlay.visible = false
	root.add_child(inversion_overlay)

func _build_clock_card() -> void:
	var card = UITheme.card(Color(UITheme.PANEL, 0.9), UITheme.STRAW, 11)
	_pin(card, Vector2(0, 0), Vector2(16, 16), 330)
	root.add_child(card)
	var box = UITheme.vbox(4)
	card.add_child(box)

	var top = UITheme.hbox(12)
	box.add_child(top)
	clock_label = UITheme.label("14:00", "BigNumber")
	top.add_child(clock_label)
	var side = UITheme.vbox(0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	side.add_child(UITheme.label("หน้าต่างเงาดาวเทียม", "Kicker"))
	phase_kicker = UITheme.label("14:00 – 20:00", "Small")
	side.add_child(phase_kicker)

	timeline = _bar(24, UITheme.EMERALD, 9)
	timeline.max_value = WINDOW_END_MIN - WINDOW_START_MIN
	var colors = PackedColorArray()
	for i in 24:
		var m = WINDOW_START_MIN + i * 15
		colors.append(UITheme.EMERALD if m < 15 * 60 + 30 else UITheme.EMBER if m < 18 * 60 else UITheme.CLAY if m < 19 * 60 + 45 else UITheme.RUBY)
	timeline.segment_colors = colors
	timeline.set_markers([{"at": 4 * 60.0, "color": UITheme.STRAW}, {"at": 5 * 60.0 + 45.0, "color": UITheme.RUBY}])
	var timeline_margin = MarginContainer.new()
	timeline_margin.add_theme_constant_override("margin_top", 6)
	timeline_margin.add_theme_constant_override("margin_bottom", 4)
	timeline_margin.add_child(timeline)
	box.add_child(timeline_margin)

	phase_label = UITheme.label("", "Title", UITheme.STRAW)
	phase_label.add_theme_font_size_override("font_size", 17)
	box.add_child(UITheme.wrap(phase_label))
	goal_label = UITheme.wrap(UITheme.label("", "Small", UITheme.CREAM))
	box.add_child(goal_label)

func _build_wind_card() -> void:
	wind_card = UITheme.card(Color(UITheme.PANEL, 0.9), UITheme.CREAM, 23)
	wind_card.padding = Vector4(12, 8, 16, 10)
	_pin(wind_card, Vector2(0.5, 0), Vector2(0, 16), 290)
	root.add_child(wind_card)
	var row = UITheme.hbox(12)
	wind_card.add_child(row)
	wind_compass = WindCompass.new()
	row.add_child(wind_compass)
	var col = UITheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UITheme.label("ลมหุบเขาพัดไปทาง", "Kicker", UITheme.MUTED))
	wind_label = UITheme.label("", "Title")
	wind_label.add_theme_font_size_override("font_size", 17)
	col.add_child(wind_label)
	wind_note = UITheme.label("ลูกไฟปลิวข้ามแนวกันไฟได้", "Small", UITheme.EMBER)
	wind_note.visible = false
	col.add_child(wind_note)

func _build_state_card() -> void:
	var card = UITheme.card(Color(UITheme.STATE_DEEP, 0.92), UITheme.STATE, 37)
	_pin(card, Vector2(1, 0), Vector2(-16, 16), 300)
	root.add_child(card)
	var box = UITheme.vbox(6)
	card.add_child(box)
	box.add_child(UITheme.header("eye", "สายตารัฐ · การเฝ้าระวัง", UITheme.STATE))

	var s = _stat_row("eye", "ความเพ่งเล็งของรัฐ", UITheme.STATE)
	box.add_child(s[0])
	scrutiny_value = s[1]
	scrutiny_value.theme_type_variation = "StateText"
	scrutiny_bar = _bar(20, UITheme.STATE, 10)
	scrutiny_bar.set_markers([{"at": 75.0, "color": UITheme.RUBY}])
	box.add_child(scrutiny_bar)

	var h = _stat_row("hotspot", "จุดร้อนที่ดาวเทียมจะเห็น", UITheme.EMBER)
	box.add_child(h[0])
	hotspot_label = h[1]
	hotspot_label.theme_type_variation = "StateText"
	hotspot_label.add_theme_font_size_override("font_size", 20)

	countdown_label = UITheme.label("", "StateBig")
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.visible = false
	box.add_child(countdown_label)

func _build_tool_bar() -> void:
	var col = UITheme.vbox(8)
	_pin(col, Vector2(0, 1), Vector2(16, -16), 0)
	bottom_layer.add_child(col)
	tool_label = UITheme.outlined(UITheme.label("", "Title"))
	tool_label.add_theme_font_size_override("font_size", 17)
	col.add_child(tool_label)
	var row = UITheme.hbox(8)
	col.add_child(row)
	for i in TOOL_SLOTS.size():
		var slot = TOOL_SLOTS[i]
		var card = UITheme.card(Color(UITheme.PANEL, 0.9), UITheme.DIM, 50 + i)
		card.padding = Vector4(10, 8, 10, 8)
		card.chamfer = 9.0
		card.custom_minimum_size = Vector2(84, 0)
		row.add_child(card)
		var box = UITheme.vbox(2)
		card.add_child(box)
		box.add_child(UITheme.label(slot.key, "Kicker", UITheme.MUTED))
		var ic = UITheme.icon(slot.icon, [UITheme.EMBER, UITheme.CREAM, UITheme.WATER][i], 34.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(ic)
		var name = UITheme.label(slot.short, "Small", UITheme.CREAM)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		_tool_slots.append(card)
	var hint = UITheme.outlined(UITheme.label("คลิกซ้าย ใช้เครื่องมือ · คลิกขวา สั่งงานสหาย · Space เป่านกหวีด", "Small", UITheme.CREAM), 4)
	col.add_child(hint)

func _build_crew_row() -> void:
	crew_row = UITheme.hbox(10)
	crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(crew_row, Vector2(0.5, 1), Vector2(0, -16), 440)
	bottom_layer.add_child(crew_row)

func _crew_card(who: String) -> Label:
	if _crew_cards.has(who):
		return _crew_cards[who]
	var is_elder = who == "ตาโพ"
	var tint = UITheme.STRAW if is_elder else UITheme.EMERALD
	var card = UITheme.card(Color(UITheme.PANEL, 0.88), tint, 70 + _crew_cards.size())
	card.padding = Vector4(12, 8, 12, 10)
	card.custom_minimum_size = Vector2(210, 0)
	crew_row.add_child(card)
	var box = UITheme.vbox(2)
	card.add_child(box)
	box.add_child(UITheme.header("crew", "%s · %s" % [who, "ผู้เฒ่า" if is_elder else "คนหนุ่ม"], tint))
	var status = UITheme.label("", "Small", UITheme.CREAM)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(status)
	_crew_cards[who] = status
	return status

func _build_vitals_card() -> void:
	var card = UITheme.card(Color(UITheme.PANEL, 0.9), UITheme.EMERALD, 91)
	_pin(card, Vector2(1, 1), Vector2(-16, -16), 300)
	bottom_layer.add_child(card)
	var box = UITheme.vbox(5)
	card.add_child(box)

	var b = _stat_row("lungs", "ลมหายใจ", UITheme.CREAM)
	box.add_child(b[0])
	breath_value = b[1]
	breath_bar = _bar(16, UITheme.EMERALD)
	box.add_child(breath_bar)

	var w = _stat_row("drop", "น้ำในถังพ่น", UITheme.WATER)
	box.add_child(w[0])
	water_value = w[1]
	water_bar = _bar(15, UITheme.WATER)
	box.add_child(water_bar)

	var y = _stat_row("rice", "ผลผลิตข้าว (แปลงเถ้า)", UITheme.STRAW)
	box.add_child(y[0])
	yield_value = y[1]
	yield_bar = _bar(20, UITheme.STRAW)
	yield_bar.set_markers([{"at": 60.0, "color": UITheme.RUBY}, {"at": _barn_target, "color": UITheme.EMERALD}])
	box.add_child(yield_bar)

func _build_banners() -> void:
	banner_stack = UITheme.vbox(8)
	_pin(banner_stack, Vector2(0.5, 0), Vector2(0, 92), 600)
	root.add_child(banner_stack)

	elder_warning_banner = UITheme.card(Color(UITheme.PANEL, 0.95), UITheme.STRAW, 17)
	elder_warning_banner.visible = false
	banner_stack.add_child(elder_warning_banner)
	var er = UITheme.hbox(14)
	elder_warning_banner.add_child(er)
	var wi = UITheme.icon("wind", UITheme.STRAW, 34.0)
	wi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	er.add_child(wi)
	var ecol = UITheme.vbox(0)
	ecol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	er.add_child(ecol)
	ecol.add_child(UITheme.label("ตาโพ · ผู้เฒ่าอ่านลม", "Kicker"))
	elder_warning_text = UITheme.wrap(UITheme.label("", "Body"))
	ecol.add_child(elder_warning_text)

	drone_banner = UITheme.card(Color(UITheme.STATE_DEEP, 0.95), UITheme.STATE, 29)
	drone_banner.visible = false
	banner_stack.add_child(drone_banner)
	var dr = UITheme.hbox(14)
	drone_banner.add_child(dr)
	_drone_icon = UITheme.icon("drone", UITheme.STATE, 32.0)
	_drone_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dr.add_child(_drone_icon)
	drone_text = UITheme.wrap(UITheme.label("", "StateText"))
	drone_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(drone_text)

	alert_card = UITheme.card(Color(UITheme.INK, 0.9), UITheme.EMBER, 5)
	alert_card.padding = Vector4(22, 12, 22, 14)
	alert_card.visible = false
	banner_stack.add_child(alert_card)
	alert_label = UITheme.wrap(UITheme.label("", "Title"))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_card.add_child(alert_label)

func _build_satellite_screen() -> void:
	satellite_thermal_screen = Control.new()
	satellite_thermal_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	satellite_thermal_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	satellite_thermal_screen.visible = false
	root.add_child(satellite_thermal_screen)

	var tint = ColorRect.new()
	tint.name = "ThermalTint"
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0.04, 0.08, 0.22, 0.12)
	satellite_thermal_screen.add_child(tint)

	telemetry_card = UITheme.card(Color(UITheme.STATE_DEEP, 0.92), UITheme.STATE, 41)
	_pin(telemetry_card, Vector2(0.5, 0), Vector2(0, 16), 560)
	satellite_thermal_screen.add_child(telemetry_card)
	satellite_telemetry_label = UITheme.label("", "StateText")
	satellite_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	telemetry_card.add_child(satellite_telemetry_label)

	thermal_legend = UITheme.card(Color(UITheme.STATE_DEEP, 0.92), UITheme.STATE, 63)
	_pin(thermal_legend, Vector2(0, 1), Vector2(16, -16), 370)
	satellite_thermal_screen.add_child(thermal_legend)

func _legend_row(colors: Array, text: String) -> HBoxContainer:
	var row = UITheme.hbox(8)
	for c in colors:
		var sw = ColorRect.new()
		sw.color = c
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
	row.add_child(UITheme.label(text, "Small", UITheme.CREAM))
	return row

func _build_report() -> void:
	report_modal = Control.new()
	report_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	report_modal.visible = false
	root.add_child(report_modal)
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.55)
	report_modal.add_child(dim)

	var card = UITheme.card(Color(UITheme.PANEL, 0.97), UITheme.STATE, 101)
	card.padding = Vector4(26, 22, 26, 24)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(780, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	report_modal.add_child(card)
	var box = UITheme.vbox(12)
	card.add_child(box)

	box.add_child(UITheme.header("satellite", "รายงานดาวเทียมโคจรผ่าน 20:00 · NOAA-20 / S-NPP VIIRS", UITheme.STATE))
	report_title = UITheme.wrap(UITheme.label("", "Title"))
	report_title.add_theme_font_override("font", UITheme.font("bold"))
	report_title.add_theme_font_size_override("font_size", 28)
	box.add_child(report_title)
	report_body = UITheme.wrap(UITheme.label("", "Body"))
	box.add_child(report_body)

	report_stats = UITheme.hbox(8)
	box.add_child(report_stats)

	var gis = UITheme.card(UITheme.STATE_DEEP, UITheme.STATE, 102)
	gis.padding = Vector4(14, 10, 14, 12)
	box.add_child(gis)
	report_text = UITheme.label("", "StateText")
	report_text.add_theme_font_size_override("font_size", 13)
	gis.add_child(report_text)

	continue_button = Button.new()
	continue_button.theme_type_variation = "PrimaryButton"
	continue_button.custom_minimum_size = Vector2(0, 50)
	continue_button.pressed.connect(_on_continue_pressed)
	box.add_child(continue_button)

func _report_tile(title: String, value: String, color: Color) -> FacetCard:
	var tile = UITheme.card(UITheme.PANEL_HI, color, 110 + report_stats.get_child_count())
	tile.padding = Vector4(12, 10, 12, 10)
	tile.chamfer = 8.0
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = UITheme.vbox(0)
	tile.add_child(b)
	b.add_child(UITheme.wrap(UITheme.label(title, "Small")))
	var v = UITheme.label(value, "Title", color)
	v.add_theme_font_size_override("font_size", 22)
	b.add_child(v)
	return tile

# ---------------------------------------------------------------------------
# Updates (called by MainController)
# ---------------------------------------------------------------------------

func update_clock(time_str: String) -> void:
	clock_label.text = time_str
	var parts = time_str.split(":")
	if parts.size() == 2:
		timeline.value = parts[0].to_int() * 60 + parts[1].to_int() - WINDOW_START_MIN

func update_phase(title: String, objective: String) -> void:
	# Titles look like "ระยะ 2 · เผาใหญ่ (15:30–18:00)": split the time range out
	var open = title.rfind("(")
	if open > 0:
		phase_label.text = title.substr(0, open).strip_edges()
		phase_kicker.text = title.substr(open + 1).trim_suffix(")")
	else:
		phase_label.text = title
	goal_label.text = objective

## Empty text hides the countdown
func update_countdown(text: String) -> void:
	countdown_label.visible = text != ""
	countdown_label.text = text

func update_water(current: float, capacity: float) -> void:
	water_value.text = "%.1f / %d ลิตร" % [current, roundi(capacity)]
	water_bar.max_value = capacity
	water_bar.value = current
	water_bar.fill_color = UITheme.RUBY if current < 1.0 else UITheme.WATER
	water_value.add_theme_color_override("font_color", UITheme.RUBY if current < 1.0 else UITheme.CREAM)

func update_crew_status(who: String, status: String) -> void:
	_crew_card(who).text = status

func update_hotspots(count: int) -> void:
	hotspot_label.text = str(count)
	var c = UITheme.EMERALD if count == 0 else UITheme.STRAW if count <= 5 else UITheme.RUBY
	hotspot_label.add_theme_color_override("font_color", c)

func update_rice_yield(yield_pct: float) -> void:
	yield_value.text = "%.1f%%" % yield_pct
	yield_bar.value = yield_pct
	yield_bar.fill_color = UITheme.EMERALD if yield_pct >= _barn_target else UITheme.STRAW

func update_scrutiny(scrutiny: int) -> void:
	scrutiny_value.text = "%d / 100" % scrutiny
	scrutiny_bar.value = scrutiny
	var c = UITheme.RUBY if scrutiny >= 75 else UITheme.STRAW if scrutiny >= 35 else UITheme.STATE
	scrutiny_bar.fill_color = c
	scrutiny_value.add_theme_color_override("font_color", c)

func update_wind(dir: Vector2, speed: float) -> void:
	var strong = speed > FireGrid.EMBER_JUMP_WIND
	wind_label.text = "%s  ×%.1f" % [UITheme.cardinal_th(dir), speed]
	wind_label.add_theme_color_override("font_color", UITheme.EMBER if strong else UITheme.CREAM)
	wind_note.visible = strong
	wind_compass.set_wind(dir, strong)

func update_stamina(current: float, max_stamina: float, smoke_exposure: float) -> void:
	var pct = int(current)
	breath_bar.value = current
	breath_bar.set_markers([{"at": max_stamina, "color": UITheme.DIM}] if max_stamina < 100.0 else [])
	if smoke_exposure >= PlayerController.SMOKE_COUGH_THRESHOLD:
		breath_value.text = "%d%% · กำลังไอ!" % pct
		breath_bar.fill_color = UITheme.RUBY
		breath_value.add_theme_color_override("font_color", UITheme.RUBY)
	else:
		breath_value.text = "%d%%%s" % [pct, " · ข้าวไม่พอกิน" if max_stamina < 100.0 else ""]
		breath_bar.fill_color = UITheme.EMERALD
		breath_value.add_theme_color_override("font_color", UITheme.CREAM)

func update_tool(tool_name: String) -> void:
	tool_label.text = tool_name
	var active = PlayerController.TOOL_LABELS.values().find(tool_name)
	for i in _tool_slots.size():
		var on = i == active
		_tool_slots[i].accent = UITheme.STRAW if on else UITheme.DIM
		_tool_slots[i].base_color = Color(UITheme.PANEL_HI.lightened(0.08), 0.96) if on else Color(UITheme.PANEL, 0.8)
		_tool_slots[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.7)

func show_alert(message: String, duration: float = 3.0) -> void:
	_alert_serial += 1
	var serial = _alert_serial
	alert_label.text = message
	alert_card.visible = true
	alert_card.modulate.a = 1.0
	await get_tree().create_timer(duration).timeout
	if serial != _alert_serial:
		return
	var tw = create_tween()
	tw.tween_property(alert_card, "modulate:a", 0.0, 0.35)
	await tw.finished
	if serial == _alert_serial:
		alert_card.visible = false
		alert_label.text = ""

func show_elder_wind_warning(new_dir: Vector2, speed: float) -> void:
	elder_warning_banner.visible = true
	var embers = " ลูกไฟจะข้ามแนวกันไฟ!" if speed > FireGrid.EMBER_JUMP_WIND else ""
	elder_warning_text.text = "“ลมกำลังจะเปลี่ยนทิศ!” อีก 10 วินาที ลมจะพัดไปทาง%s%s" % [UITheme.cardinal_th(new_dir), embers]
	await get_tree().create_timer(7.0).timeout
	elder_warning_banner.visible = false

func show_drone_alert(message: String, is_danger: bool = false) -> void:
	drone_banner.visible = true
	drone_text.text = message
	var c = UITheme.RUBY if is_danger else UITheme.STATE
	drone_text.add_theme_color_override("font_color", c)
	drone_banner.accent = c
	_drone_icon.color = c
	await get_tree().create_timer(5.0).timeout
	drone_banner.visible = false

## 0..1 strength of the sepia inversion post-process
func set_inversion_strength(strength: float) -> void:
	if not _inversion_material:
		return
	_inversion_material.set_shader_parameter("strength", strength)
	inversion_overlay.visible = strength > 0.001

func trigger_inversion_visual(duration: float = 4.0) -> void:
	if not _inversion_material: return
	inversion_overlay.visible = true
	var tween = create_tween()
	tween.tween_method(set_inversion_strength, 0.0, 0.6, duration)

func show_satellite_sweep_ui(threshold: float = 35.0) -> void:
	set_inversion_strength(0.0)
	update_countdown("")
	bottom_layer.visible = false
	wind_card.visible = false
	banner_stack.visible = false
	satellite_thermal_screen.visible = true
	satellite_telemetry_label.text = "[ NOAA-20 / S-NPP VIIRS · ดาวเทียมตรวจวัดความร้อนอินฟราเรด ]\nแบนด์ I-4 (3.74 μm) · อัลกอริทึมตรวจจับไฟป่า\nกำลังประเมินสัญญาณความร้อนทั่วแปลง..."
	for c in thermal_legend.get_children():
		c.queue_free()
	var box = UITheme.vbox(6)
	thermal_legend.add_child(box)
	box.add_child(UITheme.header("satellite", "ภาพความร้อนสีเทียม", UITheme.STATE))
	box.add_child(_legend_row([Color("ffffff"), Color("ffd933")], "≥ %d TU · ถูกตรวจพบเป็นจุดความร้อน" % roundi(threshold)))
	box.add_child(_legend_row([Color("f25919"), Color("730d73")], "อุ่น ยังต่ำกว่าเกณฑ์"))
	box.add_child(_legend_row([Color("0a1038")], "พื้นเย็น / เถ้าที่ดับสนิทแล้ว"))
	box.add_child(_legend_row([Color("ff1a1a")], "จุดผิดปกติที่ถูกบันทึก"))

## Called after the burn has been committed to GameState, so `state` is final
func show_resolution_report(final_yield: float, detected_hotspots: int, escaped: bool, state: Node, hotspot_penalty: int = 15, gis_lines: PackedStringArray = PackedStringArray()) -> void:
	var scrutiny: int = state.state_scrutiny
	telemetry_card.visible = false
	report_modal.visible = true

	var title = ""
	var body = ""
	var tone = UITheme.EMERALD
	if state.is_crackdown():
		title = "รัฐปราบปราม! เจ้าหน้าที่บุกหมู่บ้าน"
		body = "เจ้าหน้าที่ป่าไม้บุกค้นหมู่บ้าน ยึดเครื่องมือทำไร่ และจับกุมผู้เฒ่า\nจบเกม · ความเพ่งเล็ง %d/100" % scrutiny
		tone = UITheme.RUBY
	elif state.is_famine():
		title = "หมู่บ้านอดอยาก!"
		body = "ยุ้งข้าวว่างเปล่า ครอบครัวต้องทิ้งดอยลงไปเป็นแรงงานขัดหนี้ในพื้นราบ\nจบเกม · ข้าวในยุ้งเหลือ %.0f%%" % state.rice_barn
		tone = UITheme.RUBY
	elif escaped:
		title = "ไฟลามเข้าป่าอนุรักษ์!"
		body = "เจ้าหน้าที่เปิดการสอบสวน หมู่บ้านถูกจับตาอย่างใกล้ชิด"
		tone = UITheme.EMBER
	elif detected_hotspots > 0:
		title = "VIIRS ตรวจพบความร้อนผิดปกติ!"
		body = "%d จุดความร้อนขึ้นบนแดชบอร์ด GIS ของรัฐ หมู่บ้านถูกปรับหนัก · ความเพ่งเล็ง +%d" % [detected_hotspots, detected_hotspots * hotspot_penalty]
		tone = UITheme.EMBER
	elif final_yield < 60.0:
		title = "เผาไม่หมดแปลง"
		body = "เถ้าไม่พอสำหรับต้นกล้าข้าวไร่ หน้าหนาวนี้หมู่บ้านจะหิวหนัก"
		tone = UITheme.STRAW
	else:
		title = "ผ่านหน้าต่างดาวเทียมโดยไม่ถูกตรวจพบ!"
		body = "ได้แปลงเถ้าแร่ธาตุที่สะอาด ไม่มีสัญญาณความร้อนให้ดาวเทียมเห็น\nฤดูมรสุมนี้ข้าวจะงามทั้งหมู่บ้าน"
	report_title.text = title
	report_title.add_theme_color_override("font_color", tone)
	report_body.text = body

	for c in report_stats.get_children():
		c.queue_free()
	report_stats.add_child(_report_tile("แปลงเถ้าพร้อมปลูก", "%.1f%%" % final_yield, UITheme.EMERALD if final_yield >= 60.0 else UITheme.STRAW))
	report_stats.add_child(_report_tile("จุดร้อนที่ถูกตรวจพบ", str(detected_hotspots), UITheme.EMERALD if detected_hotspots == 0 else UITheme.RUBY))
	report_stats.add_child(_report_tile("ไฟลามเข้าป่า", "ใช่" if escaped else "ไม่", UITheme.RUBY if escaped else UITheme.EMERALD))
	report_stats.add_child(_report_tile("ความเพ่งเล็ง", "%d/100" % scrutiny, UITheme.RUBY if scrutiny >= 75 else UITheme.STATE))
	report_stats.add_child(_report_tile("ข้าวในยุ้ง", "%.0f%%" % state.rice_barn, UITheme.RUBY if state.rice_barn < 40.0 else UITheme.STRAW))

	if gis_lines.is_empty():
		report_text.text = "บันทึกจุดความร้อน GISTDA / FIRMS: ไม่มีรายการ"
	else:
		report_text.text = "บันทึกจุดความร้อน GISTDA / FIRMS\n" + "\n".join(gis_lines)

	continue_button.text = "เริ่มแคมเปญใหม่" if state.is_game_over() else "กลับหมู่บ้าน · นั่งข้างเตาไฟ"
	continue_button.grab_focus()

func _on_continue_pressed() -> void:
	if GameState.instance:
		# Results were already recorded when the satellite pass resolved
		if GameState.instance.is_game_over():
			GameState.instance.reset_campaign()
		else:
			GameState.instance.advance_to_next_plot()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	get_tree().change_scene_to_file("res://scenes/VillageHearth.tscn")

static func vector_to_cardinal(v: Vector2) -> String:
	return UITheme.cardinal_th(v)
