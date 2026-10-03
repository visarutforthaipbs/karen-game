class_name GameHUD
extends CanvasLayer

## Burn-day HUD, built in code from the low-poly UI kit (ui/UITheme.gd).
## Kept small so the hillside stays playable: status + goals (top left), wind
## (top centre), state watch (top right), tools (bottom left), crew (bottom
## centre), breath and water (bottom right).

const TOOL_SLOTS = [
	{"key": "1", "icon": "flame"},
	{"key": "2", "icon": "blade"},
	{"key": "3", "icon": "drop"},
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

# Top left: one compact status card (clock, phase, timeline, the two goals)
var status_card: FacetCard
var status_details: VBoxContainer
var clock_label: Label
var phase_kicker: Label
var phase_label: Label
var timeline: SegmentBar
var countdown_label: Label
var goal_ash_value: Label
var goal_ash_mark: LowPolyIcon
var goal_heat_value: Label
var goal_heat_mark: LowPolyIcon
var goal_cool_value: Label
var goal_cool_mark: LowPolyIcon
var hotspot_label: Label

# Top centre: wind chip
var wind_card: FacetCard
var wind_compass: WindCompass
var wind_label: Label
var fuel_label: Label

# Top right: state watch chip
var state_card: FacetCard
var scrutiny_value: Label
var scrutiny_bar: SegmentBar

# Bottom: tools, crew, vitals
var bottom_layer: Control
var tool_col: VBoxContainer
var tool_label: Label
var hint_label: Label
var _tool_slots: Array[FacetCard] = []
var crew_row: HBoxContainer
var _crew_cards: Dictionary = {}
var vitals_card: FacetCard
var breath_value: Label
var breath_bar: SegmentBar
var water_value: Label
var water_bar: SegmentBar
var breath_hint: Label
var refill_hint: Label
var refill_marker: HBoxContainer
var refill_marker_text: Label
var _last_exposure := 0.0

# Banners and alerts, stacked under the wind chip
var banner_stack: VBoxContainer
var alert_card: FacetCard
var alert_label: Label
var tip_card: FacetCard
var tip_label: Label
var _tip_serial: int = 0
var elder_warning_banner: FacetCard
var elder_warning_text: Label
var drone_banner: FacetCard
var drone_text: Label
var _drone_icon: LowPolyIcon
var _ranger_face: Control

# 20:00 satellite pass
var satellite_thermal_screen: Control
var telemetry_card: FacetCard
var satellite_telemetry_label: Label
var thermal_legend: FacetCard
var report_modal: Control
var pause_menu: PauseMenu
var report_title: Label
var report_body: Label
var report_tip: Label
var report_stats: HBoxContainer
var report_text: Label
var continue_button: Button

## Keep the hillside visible: panels fade when the player or the cursor is
## behind them, and Tab / Select collapses the HUD to the clock alone.
const PANEL_ALPHA: float = 0.82
const FADED_ALPHA: float = 0.16
const HINT_SECONDS: float = 40.0
var minimal: bool = false
var _fade_targets: Array[Control] = []
var _camera: Camera3D
var _player: Node3D
var _in_play: bool = true

var _alert_serial: int = 0
var _barn_target: float = 75.0
var _hotspots: int = 0
var _yield: float = 0.0
## In-game minute after which fresh embers cannot cool by themselves before 20:00
var self_cool_minute: int = 17 * 60 + 16

func _ready() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	if GameState.instance:
		_barn_target = GameState.instance.barn_target()

	_build_inversion_overlay()
	_build_satellite_screen()
	_build_status_card()
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
	pause_menu = PauseMenu.new()
	pause_menu.main = get_parent()
	root.add_child(pause_menu)
	var debug = DebugOverlay.new()
	debug.main = get_parent()
	root.add_child(debug)
	_fade_targets = [status_card, wind_card, state_card, banner_stack, tool_col, crew_row, vitals_card]
	_hide_hint_later()

## MainController hands over the camera and player so panels can get out of the way
func track(camera: Camera3D, player: Node3D) -> void:
	_camera = camera
	_player = player
	wind_compass.camera = camera

func _unhandled_input(event: InputEvent) -> void:
	if _in_play and event.is_action_pressed("toggle_hud"):
		set_minimal(not minimal)
		get_viewport().set_input_as_handled()

func set_minimal(on: bool) -> void:
	minimal = on
	status_details.visible = not on
	for c in [wind_card, state_card, tool_col, crew_row, vitals_card, refill_marker]:
		c.visible = not on

func _process(delta: float) -> void:
	if not _in_play:
		return
	_update_refill_guidance()
	var points: Array[Vector2] = [root.get_global_mouse_position()]
	if _camera and _player and is_instance_valid(_player) and not _camera.is_position_behind(_player.global_position):
		# Cover the whole character, not just its feet
		var feet = _camera.unproject_position(_player.global_position)
		points.append(feet)
		points.append(_camera.unproject_position(_player.global_position + Vector3.UP * 1.6))
	for c in _fade_targets:
		var target = 1.0
		if c.visible:
			var rect = c.get_global_rect().grow(18.0)
			for p in points:
				if rect.has_point(p):
					target = FADED_ALPHA
					break
		c.modulate.a = move_toward(c.modulate.a, target, delta * 6.0)

func _hide_hint_later() -> void:
	await get_tree().create_timer(HINT_SECONDS).timeout
	if is_instance_valid(hint_label):
		var tw = create_tween()
		tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)
		await tw.finished
		hint_label.visible = false

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

func _bar(segments: int, color: Color, height: float = 8.0) -> SegmentBar:
	var b = SegmentBar.new()
	b.segments = segments
	b.fill_color = color
	b.slant = 3.0
	b.custom_minimum_size = Vector2(0, height)
	return b

func _chip(base: Color, accent: Color, seed_value: int) -> FacetCard:
	var c = UITheme.card(Color(base, PANEL_ALPHA), accent, seed_value)
	c.padding = Vector4(10, 6, 12, 7)
	c.chamfer = 8.0
	c.facet_size = 48.0
	return c

func _small(text: String = "", color: Color = UITheme.CREAM) -> Label:
	var l = UITheme.label(text, "Small", color)
	l.add_theme_font_size_override("font_size", 13)
	return l

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

func _build_status_card() -> void:
	status_card = _chip(UITheme.PANEL, UITheme.STRAW, 11)
	status_card.padding = Vector4(12, 8, 12, 10)
	_pin(status_card, Vector2(0, 0), Vector2(12, 12), 236)
	root.add_child(status_card)
	var box = UITheme.vbox(4)
	status_card.add_child(box)

	var top = UITheme.hbox(10)
	box.add_child(top)
	clock_label = UITheme.label("14:00", "BigNumber")
	clock_label.add_theme_font_size_override("font_size", 28)
	top.add_child(clock_label)
	var side = UITheme.vbox(-2)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	phase_label = _small("", UITheme.STRAW)
	phase_label.add_theme_font_override("font", UITheme.font("semibold"))
	phase_label.clip_text = true
	phase_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	side.add_child(phase_label)
	phase_kicker = _small("14:00 – 20:00", UITheme.MUTED)
	side.add_child(phase_kicker)

	countdown_label = UITheme.label("", "StateBig")
	countdown_label.add_theme_font_size_override("font_size", 20)
	countdown_label.visible = false
	box.add_child(countdown_label)

	status_details = UITheme.vbox(4)
	box.add_child(status_details)
	timeline = _bar(24, UITheme.EMERALD, 6)
	timeline.max_value = WINDOW_END_MIN - WINDOW_START_MIN
	var colors = PackedColorArray()
	for i in 24:
		var m = WINDOW_START_MIN + i * 15
		colors.append(UITheme.EMERALD if m < 15 * 60 + 30 else UITheme.EMBER if m < 18 * 60 else UITheme.CLAY if m < 19 * 60 + 45 else UITheme.RUBY)
	timeline.segment_colors = colors
	timeline.set_markers([{"at": 4 * 60.0, "color": UITheme.STRAW}, {"at": 5 * 60.0 + 45.0, "color": UITheme.RUBY}])
	var timeline_margin = MarginContainer.new()
	timeline_margin.add_theme_constant_override("margin_top", 6)
	timeline_margin.add_theme_constant_override("margin_bottom", 2)
	timeline_margin.add_child(timeline)
	status_details.add_child(timeline_margin)

	var a = _goal_row(status_details)
	goal_ash_mark = a[0]
	goal_ash_value = a[1]
	var h = _goal_row(status_details)
	goal_heat_mark = h[0]
	goal_heat_value = h[1]
	hotspot_label = goal_heat_value
	var c = _goal_row(status_details)
	goal_cool_mark = c[0]
	goal_cool_value = c[1]
	_refresh_goals(WINDOW_START_MIN)

func _goal_row(box: VBoxContainer) -> Array:
	var row = UITheme.hbox(7)
	box.add_child(row)
	var mark = UITheme.icon("hotspot", UITheme.STRAW, 14.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var value = _small()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	return [mark, value]

func _set_mark(mark: LowPolyIcon, ok: bool, warn_color: Color) -> void:
	mark.kind = "check" if ok else "hotspot"
	mark.color = UITheme.EMERALD if ok else warn_color

func _refresh_goals(now: int) -> void:
	var ash_ok = _yield >= _barn_target
	goal_ash_value.text = "เถ้า %.0f%% · เป้า %d%%" % [_yield, roundi(_barn_target)]
	goal_ash_value.add_theme_color_override("font_color", UITheme.EMERALD if ash_ok else UITheme.CREAM)
	_set_mark(goal_ash_mark, ash_ok, UITheme.STRAW if _yield >= 60.0 else UITheme.RUBY)

	var heat_ok = _hotspots == 0
	goal_heat_value.text = "ไม่มีถ่านร้อน · ปลอดภัย" if heat_ok else "ถ่านร้อน %d จุด · ต้องเป็น 0" % _hotspots
	goal_heat_value.add_theme_color_override("font_color", UITheme.EMERALD if heat_ok else UITheme.EMBER)
	_set_mark(goal_heat_mark, heat_ok, UITheme.EMBER)

	var left = self_cool_minute - now
	var deadline = "%d:%02d" % [self_cool_minute / 60, self_cool_minute % 60]
	if left > 0:
		goal_cool_value.text = "จุดไฟก่อน %s ถ่านเย็นเอง (%d น.)" % [deadline, left]
		goal_cool_value.add_theme_color_override("font_color", UITheme.CREAM)
		_set_mark(goal_cool_mark, true, UITheme.STRAW)
	else:
		goal_cool_value.text = "เลย %s · ถ่านใหม่ต้องฉีดน้ำ" % deadline
		goal_cool_value.add_theme_color_override("font_color", UITheme.STRAW)
		_set_mark(goal_cool_mark, false, UITheme.STRAW)

## MainController passes the real deadline from the fire and clock timings
func set_self_cool_minute(minute: int) -> void:
	self_cool_minute = minute
	timeline.set_markers([
		{"at": float(minute - WINDOW_START_MIN), "color": UITheme.EMBER},
		{"at": 4 * 60.0, "color": UITheme.STRAW},
		{"at": 5 * 60.0 + 45.0, "color": UITheme.RUBY},
	])
	_refresh_goals(WINDOW_START_MIN + int(timeline.value))

func _build_wind_card() -> void:
	wind_card = _chip(UITheme.PANEL, UITheme.CREAM, 23)
	wind_card.padding = Vector4(6, 5, 14, 6)
	_pin(wind_card, Vector2(0.5, 0), Vector2(0, 12), 0)
	root.add_child(wind_card)
	var row = UITheme.hbox(8)
	wind_card.add_child(row)
	wind_compass = WindCompass.new()
	wind_compass.custom_minimum_size = Vector2(30, 30)
	row.add_child(wind_compass)
	var col = UITheme.vbox(-2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	wind_label = _small()
	wind_label.add_theme_font_override("font", UITheme.font("medium"))
	col.add_child(wind_label)
	fuel_label = _small("", UITheme.MUTED)
	fuel_label.add_theme_font_size_override("font_size", 12)
	col.add_child(fuel_label)
	update_fuel(FireGrid.dryness_at_minute(WINDOW_START_MIN))

func _build_state_card() -> void:
	state_card = _chip(UITheme.STATE_DEEP, UITheme.STATE, 37)
	_pin(state_card, Vector2(1, 0), Vector2(-12, 12), 196)
	root.add_child(state_card)
	var box = UITheme.vbox(4)
	state_card.add_child(box)
	var row = UITheme.hbox(7)
	box.add_child(row)
	var ic = UITheme.icon("eye", UITheme.STATE, 16.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var t = _small("ความเพ่งเล็งของรัฐ", UITheme.MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	scrutiny_value = UITheme.label("", "StateText")
	scrutiny_value.add_theme_font_size_override("font_size", 14)
	row.add_child(scrutiny_value)
	scrutiny_bar = _bar(20, UITheme.STATE, 6)
	scrutiny_bar.set_markers([{"at": 75.0, "color": UITheme.RUBY}])
	box.add_child(scrutiny_bar)

func _build_tool_bar() -> void:
	tool_col = UITheme.vbox(5)
	_pin(tool_col, Vector2(0, 1), Vector2(12, -12), 0)
	bottom_layer.add_child(tool_col)
	hint_label = UITheme.outlined(_small("คลิกซ้าย ใช้ · คลิกขวา สั่งสหาย · Space นกหวีด · ล้อเมาส์ ซูม · Z/C หมุนกล้อง · Tab ซ่อนแผง · Esc หยุดเกม"), 4)
	hint_label.visible = GameSettings.show_hints
	tool_col.add_child(hint_label)
	tool_label = UITheme.outlined(_small(), 4)
	tool_label.add_theme_font_override("font", UITheme.font("semibold"))
	tool_col.add_child(tool_label)
	var row = UITheme.hbox(6)
	tool_col.add_child(row)
	for i in TOOL_SLOTS.size():
		var slot = TOOL_SLOTS[i]
		var card = _chip(UITheme.PANEL, UITheme.DIM, 50 + i)
		card.padding = Vector4(6, 4, 6, 5)
		card.custom_minimum_size = Vector2(52, 52)
		row.add_child(card)
		var box = UITheme.vbox(0)
		card.add_child(box)
		var key = _small(slot.key, UITheme.MUTED)
		key.add_theme_font_size_override("font_size", 11)
		box.add_child(key)
		var ic = UITheme.icon(slot.icon, [UITheme.EMBER, UITheme.CREAM, UITheme.WATER][i], 26.0)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(ic)
		_tool_slots.append(card)

func _build_crew_row() -> void:
	crew_row = UITheme.hbox(6)
	crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(crew_row, Vector2(0.5, 1), Vector2(0, -12), 0)
	bottom_layer.add_child(crew_row)

func _crew_card(who: String) -> Label:
	if _crew_cards.has(who):
		return _crew_cards[who]
	var tint = UITheme.STRAW if who == "ตาโพ" else UITheme.EMERALD
	var card = _chip(UITheme.PANEL, tint, 70 + _crew_cards.size())
	crew_row.add_child(card)
	var row = UITheme.hbox(6)
	card.add_child(row)
	var ic = UITheme.portrait(UITheme.portrait_id(who), 26.0, tint)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var name = _small(who, tint)
	name.add_theme_font_override("font", UITheme.font("semibold"))
	row.add_child(name)
	var status = _small()
	status.custom_minimum_size = Vector2(130, 0)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(status)
	_crew_cards[who] = status
	return status

func _vital_row(box: VBoxContainer, kind: String, color: Color, segments: int) -> Array:
	var row = UITheme.hbox(7)
	box.add_child(row)
	var ic = UITheme.icon(kind, color, 15.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var bar = _bar(segments, color, 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var value = _small()
	value.custom_minimum_size = Vector2(54, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [bar, value]

func _build_vitals_card() -> void:
	vitals_card = _chip(UITheme.PANEL, UITheme.EMERALD, 91)
	_pin(vitals_card, Vector2(1, 1), Vector2(-12, -12), 196)
	bottom_layer.add_child(vitals_card)
	var box = UITheme.vbox(5)
	vitals_card.add_child(box)
	box.add_child(_small("ลมหายใจ"))
	var b = _vital_row(box, "lungs", UITheme.EMERALD, 14)
	breath_bar = b[0]
	breath_value = b[1]
	var w = _vital_row(box, "drop", UITheme.WATER, 14)
	water_bar = w[0]
	water_value = w[1]
	breath_hint = UITheme.wrap(_small())
	breath_hint.add_theme_font_size_override("font_size", 12)
	box.add_child(breath_hint)
	refill_hint = UITheme.wrap(_small())
	refill_hint.add_theme_font_size_override("font_size", 12)
	box.add_child(refill_hint)
	refill_marker = UITheme.hbox(5)
	refill_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refill_marker.add_child(UITheme.icon("drop", UITheme.WATER, 22.0))
	refill_marker_text = _small("เติมน้ำ")
	refill_marker_text.add_theme_color_override("font_shadow_color", Color.BLACK)
	refill_marker_text.add_theme_constant_override("shadow_offset_x", 2)
	refill_marker_text.add_theme_constant_override("shadow_offset_y", 2)
	refill_marker.add_child(refill_marker_text)
	root.add_child(refill_marker)

func _build_banners() -> void:
	banner_stack = UITheme.vbox(5)
	_pin(banner_stack, Vector2(0.5, 0), Vector2(0, 56), 460)
	root.add_child(banner_stack)

	elder_warning_banner = _chip(UITheme.PANEL, UITheme.STRAW, 17)
	elder_warning_banner.visible = false
	banner_stack.add_child(elder_warning_banner)
	var er = UITheme.hbox(8)
	elder_warning_banner.add_child(er)
	var face = UITheme.portrait("tapoh", 34.0)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	er.add_child(face)
	var wi = UITheme.icon("wind", UITheme.STRAW, 20.0)
	wi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	er.add_child(wi)
	elder_warning_text = UITheme.wrap(_small())
	elder_warning_text.add_theme_font_size_override("font_size", 14)
	elder_warning_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	er.add_child(elder_warning_text)

	drone_banner = _chip(UITheme.STATE_DEEP, UITheme.STATE, 29)
	drone_banner.visible = false
	banner_stack.add_child(drone_banner)
	var dr = UITheme.hbox(8)
	drone_banner.add_child(dr)
	_drone_icon = UITheme.icon("drone", UITheme.STATE, 20.0)
	_drone_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dr.add_child(_drone_icon)
	_ranger_face = UITheme.portrait("ranger", 30.0, UITheme.STATE)
	_ranger_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ranger_face.visible = false
	dr.add_child(_ranger_face)
	drone_text = UITheme.wrap(UITheme.label("", "StateText"))
	drone_text.add_theme_font_size_override("font_size", 14)
	drone_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dr.add_child(drone_text)

	alert_card = _chip(UITheme.INK, UITheme.EMBER, 5)
	alert_card.visible = false
	banner_stack.add_child(alert_card)
	alert_label = UITheme.wrap(UITheme.label("", "Body"))
	alert_label.add_theme_font_override("font", UITheme.font("medium"))
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_card.add_child(alert_label)

	# First-burn tips (FirstBurnTips): straw card above the crew chips
	tip_card = _chip(UITheme.PANEL, UITheme.STRAW, 7)
	tip_card.padding = Vector4(14, 8, 16, 10)
	_pin(tip_card, Vector2(0.5, 1), Vector2(0, -64), 560)
	tip_card.visible = false
	bottom_layer.add_child(tip_card)
	var tip_row = UITheme.hbox(10)
	tip_card.add_child(tip_row)
	var tip_icon = UITheme.icon("hotspot", UITheme.STRAW, 18.0)
	tip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip_row.add_child(tip_icon)
	var tip_col = UITheme.vbox(0)
	tip_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_row.add_child(tip_col)
	tip_col.add_child(_small("เคล็ดลับเผาครั้งแรก", UITheme.STRAW))
	tip_label = UITheme.wrap(UITheme.label("", "Body"))
	tip_label.add_theme_font_size_override("font_size", 15)
	tip_col.add_child(tip_label)

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
	report_tip = UITheme.wrap(UITheme.label("", "Small", UITheme.STRAW))
	box.add_child(report_tip)

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
		var now = parts[0].to_int() * 60 + parts[1].to_int()
		timeline.value = now - WINDOW_START_MIN
		_refresh_goals(now)

## The objective sentence is announced as an alert when the phase changes;
## the status card keeps only the short title and its time range.
func update_phase(title: String, _objective: String) -> void:
	# Titles look like "ระยะ 2 · เผาใหญ่ (15:30–18:00)": split the time range out
	var open = title.rfind("(")
	if open > 0:
		phase_label.text = title.substr(0, open).strip_edges()
		phase_kicker.text = title.substr(open + 1).trim_suffix(")")
	else:
		phase_label.text = title

## Empty text hides the countdown
func update_countdown(text: String) -> void:
	countdown_label.visible = text != ""
	countdown_label.text = text

func update_water(current: float, capacity: float) -> void:
	water_value.text = "%.0f/%d ล." % [current, roundi(capacity)]
	water_bar.max_value = capacity
	water_bar.value = current
	water_bar.fill_color = UITheme.RUBY if current < 1.0 else UITheme.WATER
	water_value.add_theme_color_override("font_color", UITheme.RUBY if current < 1.0 else UITheme.CREAM)

func update_crew_status(who: String, status: String) -> void:
	_crew_card(who).text = status

func update_hotspots(count: int) -> void:
	_hotspots = count
	_refresh_goals(WINDOW_START_MIN + int(timeline.value))

func update_rice_yield(yield_pct: float) -> void:
	_yield = yield_pct
	_refresh_goals(WINDOW_START_MIN + int(timeline.value))

func update_scrutiny(scrutiny: int) -> void:
	scrutiny_value.text = "%d/100" % scrutiny
	scrutiny_bar.value = scrutiny
	var c = UITheme.RUBY if scrutiny >= 75 else UITheme.STRAW if scrutiny >= 35 else UITheme.STATE
	scrutiny_bar.fill_color = c
	scrutiny_value.add_theme_color_override("font_color", c)

func update_wind(dir: Vector2, speed: float) -> void:
	var strong = speed > FireGrid.EMBER_JUMP_WIND
	wind_label.text = "ลม%s ×%.1f%s" % [UITheme.cardinal_th(dir), speed, " · ลูกไฟปลิว!" if strong else ""]
	wind_label.add_theme_color_override("font_color", UITheme.EMBER if strong else UITheme.CREAM)
	wind_compass.set_wind(dir, strong)

## Afternoon fuel dryness: tells the player when fire will run and when it will stall
func update_fuel(dryness: float) -> void:
	var mood = "เชื้อไฟชื้น ไฟลามช้า" if dryness < 0.6 else ("เชื้อไฟแห้ง ไฟลามเร็ว" if dryness >= 0.9 else "เชื้อไฟกำลังแห้ง")
	fuel_label.text = "%s · %d%%" % [mood, roundi(dryness * 100.0)]
	fuel_label.add_theme_color_override("font_color", UITheme.WATER if dryness < 0.6 else (UITheme.EMBER if dryness >= 0.9 else UITheme.STRAW))

func update_stamina(current: float, max_stamina: float, smoke_exposure: float) -> void:
	breath_bar.value = current
	breath_bar.set_markers([{"at": max_stamina, "color": UITheme.DIM}] if max_stamina < 100.0 else [])
	var coughing = smoke_exposure >= PlayerController.SMOKE_COUGH_THRESHOLD
	breath_value.text = "ไอ! %d%%" % int(current) if coughing else "%d%%" % int(current)
	breath_hint.text = ("ควันลดลง · ยังไออยู่" if smoke_exposure < _last_exposure else "ออกจากควันเพื่อฟื้นลมหายใจ") if coughing else ("กำลังฟื้นลมหายใจ" if current < max_stamina else "")
	breath_hint.visible = not breath_hint.text.is_empty()
	_last_exposure = smoke_exposure
	breath_bar.fill_color = UITheme.RUBY if coughing else UITheme.EMERALD
	breath_value.add_theme_color_override("font_color", UITheme.RUBY if coughing else UITheme.CREAM)

func update_tool(tool_name: String) -> void:
	tool_label.text = tool_name
	var active = PlayerController.TOOL_LABELS.values().find(tool_name)
	for i in _tool_slots.size():
		var on = i == active
		_tool_slots[i].accent = UITheme.STRAW if on else UITheme.DIM
		_tool_slots[i].base_color = Color(UITheme.PANEL_HI.lightened(0.08), 0.92) if on else Color(UITheme.PANEL, 0.7)
		_tool_slots[i].modulate = Color.WHITE if on else Color(1, 1, 1, 0.65)

func show_tip(text: String, duration: float = 10.0) -> void:
	_tip_serial += 1
	var serial = _tip_serial
	tip_label.text = text
	tip_card.visible = true
	await get_tree().create_timer(duration).timeout
	if serial == _tip_serial:
		tip_card.visible = false

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
	var embers = " · ลูกไฟจะข้ามแนวกันไฟ!" if speed > FireGrid.EMBER_JUMP_WIND else ""
	elder_warning_text.text = "ตาโพ: “อีก 10 วิ ลมจะเปลี่ยนไปพัดทาง%s”%s" % [UITheme.cardinal_th(new_dir), embers]
	await get_tree().create_timer(7.0).timeout
	elder_warning_banner.visible = false

## `from_ranger` shows the ranger's portrait instead of the drone icon
func show_drone_alert(message: String, is_danger: bool = false, from_ranger: bool = false) -> void:
	drone_banner.visible = true
	drone_text.text = message
	_drone_icon.visible = not from_ranger
	_ranger_face.visible = from_ranger
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
	# The thermal image is the show now: keep only the clock and state cards, fully opaque
	set_minimal(false)
	_in_play = false
	refill_marker.hide()
	for c in _fade_targets:
		c.modulate.a = 1.0
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
func show_resolution_report(final_yield: float, detected_hotspots: int, escaped: bool, state: Node, satellite_scrutiny: int = 0, gis_lines: PackedStringArray = PackedStringArray()) -> void:
	var scrutiny: int = state.state_scrutiny
	telemetry_card.visible = false
	report_modal.visible = true

	var target: float = state.last_barn_target
	var rice_change: float = state.last_rice_change
	var ash_ok = rice_change > 0.0
	var heat_ok = detected_hotspots == 0

	var title = ""
	var tone = UITheme.EMERALD
	var lines = PackedStringArray()
	if state.is_crackdown():
		title = "รัฐปราบปราม! เจ้าหน้าที่บุกหมู่บ้าน"
		lines.append("เจ้าหน้าที่ป่าไม้บุกค้นหมู่บ้าน ยึดเครื่องมือทำไร่ และจับกุมผู้เฒ่า · จบเกม")
		tone = UITheme.RUBY
	elif state.is_famine():
		title = "หมู่บ้านอดอยาก!"
		lines.append("ยุ้งข้าวว่างเปล่า ครอบครัวต้องทิ้งดอยลงไปเป็นแรงงานขัดหนี้ในพื้นราบ · จบเกม")
		tone = UITheme.RUBY
	elif escaped:
		title = "ไฟลามเข้าป่าอนุรักษ์!"
		tone = UITheme.EMBER
	elif ash_ok and heat_ok:
		title = "สำเร็จ! ข้าวเต็มยุ้ง และดาวเทียมไม่เห็นอะไรเลย"
	elif heat_ok:
		title = "รอดสายตาดาวเทียม แต่เถ้ายังไม่พอ"
		tone = UITheme.STRAW
	elif ash_ok:
		title = "ข้าวเต็มยุ้ง แต่ VIIRS เห็นจุดร้อน"
		tone = UITheme.EMBER
	else:
		title = "VIIRS เห็นจุดร้อน และเถ้าไม่พอ"
		tone = UITheme.RUBY

	# One line per goal, so the player always sees what decided the round
	var rice_text = "ยุ้งข้าว +%.0f%%" % rice_change if rice_change > 0.0 else ("ยุ้งข้าวเท่าเดิม" if rice_change == 0.0 else "ยุ้งข้าว %.0f%% หมู่บ้านจะหิว" % rice_change)
	lines.append("%s เป้าหมาย 1 · เถ้า %.0f%% (เป้า %d%%) → %s" % ["ผ่าน" if ash_ok else "ไม่ผ่าน", final_yield, roundi(target), rice_text])
	if heat_ok:
		lines.append("ผ่าน เป้าหมาย 2 · ดาวเทียมไม่พบจุดร้อน")
	else:
		lines.append("ไม่ผ่าน เป้าหมาย 2 · ดาวเทียมพบ %d จุด → ความเพ่งเล็ง +%d" % [detected_hotspots, satellite_scrutiny])
	if escaped:
		lines.append("ไฟลามเข้าป่าอนุรักษ์ เจ้าหน้าที่เปิดการสอบสวน")
	if state.last_scrutiny_relief > 0:
		lines.append("เจ้าหน้าที่หันไปสนใจหมู่บ้านอื่น ความเพ่งเล็ง −%d%s" % [state.last_scrutiny_relief, " (เผาสะอาด)" if state.last_scrutiny_relief >= GameState.PLOT_SCRUTINY_DECAY + GameState.CLEAN_BURN_BONUS else ""])
	report_title.text = title
	report_title.add_theme_color_override("font_color", tone)
	report_body.text = "\n".join(lines)

	var tips = PackedStringArray()
	if not ash_ok:
		tips.append("จุดไฟให้ทั่วแปลงก่อน %d:%02d และฉีดน้ำถ่านคุให้กลายเป็นเถ้า" % [self_cool_minute / 60, self_cool_minute % 60])
	if not heat_ok:
		tips.append("ช่วง 18:00–20:00 ฉีดน้ำถ่านทุกจุด ดูช่องเป้าหมายข้อ 2 ให้เป็น 0")
	if escaped:
		tips.append("ถางแนวกันไฟฝั่งป่าอุทยานให้เสร็จก่อนจุดไฟ")
	report_tip.text = "เคล็ดลับรอบหน้า: " + " · ".join(tips)
	report_tip.visible = not tips.is_empty() and not state.is_game_over()

	for c in report_stats.get_children():
		c.queue_free()
	var ash_color = UITheme.EMERALD if ash_ok else (UITheme.STRAW if final_yield >= 60.0 else UITheme.RUBY)
	report_stats.add_child(_report_tile("เถ้า (เป้า %d%%)" % roundi(target), "%.1f%%" % final_yield, ash_color))
	report_stats.add_child(_report_tile("จุดร้อนที่ถูกตรวจพบ", str(detected_hotspots), UITheme.EMERALD if heat_ok else UITheme.RUBY))
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
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	# Results were already recorded when the satellite pass resolved.
	# A finished campaign plays its ending and run summary (EndingScene).
	if GameState.instance and GameState.instance.is_game_over():
		get_tree().change_scene_to_file("res://scenes/Ending.tscn")
		return
	if GameState.instance:
		GameState.instance.advance_to_next_plot()
	get_tree().change_scene_to_file("res://scenes/VillageHearth.tscn")

static func vector_to_cardinal(v: Vector2) -> String:
	return UITheme.cardinal_th(v)

## Project the actual refill location; the edge cue appears only for an empty tank.
func _update_refill_guidance() -> void:
	if not _player or not _camera or _player.refill_point == Vector3.INF:
		refill_marker.hide()
		return
	var near: bool = Vector2(_player.global_position.x - _player.refill_point.x, _player.global_position.z - _player.refill_point.z).length() <= _player.REFILL_RADIUS
	var full: bool = _player.water >= _player.water_capacity
	refill_hint.text = ("น้ำเต็มแล้ว" if full else "กำลังเติมน้ำ %.0f / %.0f ลิตร" % [_player.water, _player.water_capacity]) if near and _player.input_enabled else ("เติมน้ำที่ถังข้างเถียงนา" if not full else "")
	refill_hint.visible = not refill_hint.text.is_empty()
	var area := get_viewport().get_visible_rect().size
	var point := _camera.unproject_position(_player.refill_point + Vector3.UP * 1.4)
	var behind := _camera.is_position_behind(_player.refill_point)
	var bounds := Rect2(Vector2(24, 240), area - Vector2(180, 420))
	var offscreen := behind or not bounds.has_point(point)
	refill_marker.visible = not minimal and (not offscreen or _player.water <= 0.0)
	if behind:
		point = area * 0.5 - (point - area * 0.5)
	var direction := point - area * 0.5
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var arrow: String = arrows[posmod(roundi(direction.angle() / (PI / 4.0)), 8)]
	refill_marker_text.text = ("เติมน้ำ " + arrow) if offscreen else "เติมน้ำ"
	refill_marker.position = Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))
