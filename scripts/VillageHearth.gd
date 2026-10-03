class_name VillageHearth
extends Control

## The Night Village Hearth (PRD §7): radio intel, plot briefing, workshop,
## granary rations, mutual-aid exchange, and the annual monsoon harvest.
## The whole screen is built in code from the low-poly UI kit (ui/UITheme.gd).

const RATION_EFFECTS = {
	GameState.Ration.LEAN: "ทีมหิว: ลมหายใจสูงสุดเหลือ 70% สหายทำงานช้าลง 15%",
	GameState.Ration.NORMAL: "ทีมพออิ่ม: ไม่มีโบนัส ไม่มีบทลงโทษ",
	GameState.Ration.FULL: "ทีมอิ่มท้อง: ลมหายใจฟื้นเร็วขึ้น 50% ทุกคนเดินและทำงานเร็วขึ้น",
}
const RATION_BUTTONS = {
	GameState.Ration.LEAN: "กินน้อย\nข้าว 0%",
	GameState.Ration.NORMAL: "กินปกติ\nข้าว −3%",
	GameState.Ration.FULL: "กินอิ่ม\nข้าว −7%",
}
const FAVOUR_BUTTONS = {
	GameState.Favour.SPRAYER: "ช่วยบ้านห้วยหินลาดปลูกป่า\n→ ยืมถังพ่นน้ำให้ตาโพ",
	GameState.Favour.WATER: "หาบน้ำให้บ้านแม่เลา\n→ ได้ภาชนะใส่น้ำเพิ่ม (+10 ลิตร)",
	GameState.Favour.SEEDS: "ช่วยบ้านหนองเต่าเก็บขิง\n→ ได้เมล็ดข้าวพื้นเมืองผลผลิตสูง",
}
const PROVERBS = [
	"เถ้าเลี้ยงเมล็ดข้าว เมฆบังเตาไฟ",
	"ไร่ที่พักไว้เจ็ดปี ยังจำป่าที่มันเคยเป็นได้",
	"หลายมือช่วยกันทำแนวกันไฟ มือเดียวที่ประมาทพาเจ้าหน้าที่มาถึงบ้าน",
	"เผาเมื่อลมหลับ นอนเมื่อถ่านดับ",
]

const ENDING_SCENE = "res://scenes/Ending.tscn"
var header_label: Label
var barn_value: Label
var barn_bar: SegmentBar
var scrutiny_value: Label
var scrutiny_bar: SegmentBar
var radio_text: Label
var radio_buttons: Array[Button] = []
var chatter_timer: Timer
var plot_title_label: Label
var plot_desc_label: Label
var plot_stats: GridContainer
var goal_rows: VBoxContainer
var workshop_label: Label
var sharpen_button: Button
var seal_button: Button
var granary_label: Label
var maelu_portrait: SubViewportContainer
var ration_buttons: Dictionary = {}
var exchange_label: Label
var favour_buttons: Dictionary = {}
var launch_button: Button

var current_radio_channel: int = 1
var _harvest_modal: Control
var _harvest_focus_scope: ModalFocusScope
var _harvest_card: FacetCard
var _harvest_scroll: ScrollContainer
var _harvest_content: VBoxContainer
var help_button: Button
var settings_button: Button
var harvest_button: Button
var settings_panel: SettingsPanel
var how_to_play: HowToPlay
var _card_columns: GridContainer
var _card_scroll: ScrollContainer
var _header_row: HBoxContainer
var _header_stats: HBoxContainer
var _barn_card: Control
var _watch_card: Control

func _ready() -> void:
	theme = UITheme.get_theme()
	_build()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
		AudioManager.instance.set_hearth_ambience(true)
	_tune_radio(1, false)
	_refresh()

	# Gamepad / Steam Deck: start with focus on the main action
	launch_button.grab_focus()

	var state = GameState.instance
	if not state.pending_harvest.is_empty():
		_show_harvest(state.pending_harvest)
	elif state.is_game_over():
		# Never sit at the Hearth with a finished campaign (it cannot be saved)
		_end_campaign.call_deferred()
	elif not state.seen_how_to_play and state.current_year == 1 and state.current_plot_index == 1:
		show_how_to_play()

func show_how_to_play() -> void:
	GameState.instance.seen_how_to_play = true
	if how_to_play:
		return
	how_to_play = HowToPlay.new()
	how_to_play.closed.connect(func():
		how_to_play = null)
	add_child(how_to_play)

func show_settings() -> void:
	if settings_panel:
		return
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(func():
		settings_panel = null)
	settings_panel.how_to_play_requested.connect(func():
		settings_panel.close()
		show_how_to_play())
	add_child(settings_panel)

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("101724")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var page = UITheme.vbox(8)
	margin.add_child(page)

	page.add_child(_build_header())

	# The cards scroll when the window is short; the launch button below stays pinned
	var scroll = ScrollContainer.new()
	_card_scroll = scroll
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var columns = GridContainer.new()
	_card_columns = columns
	columns.columns = 3
	columns.add_theme_constant_override("h_separation",12)
	columns.add_theme_constant_override("v_separation",12)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)

	var left = UITheme.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 300
	columns.add_child(left)
	left.add_child(_build_radio())
	left.add_child(_build_granary())

	var centre = _build_plot_brief()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.custom_minimum_size.x = 340
	centre.size_flags_stretch_ratio = 1.05
	columns.add_child(centre)

	var right = UITheme.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 340
	columns.add_child(right)
	right.add_child(_build_workshop())
	right.add_child(_build_exchange())

	var launch_row = UITheme.hbox(0)
	launch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(launch_row)
	launch_button = Button.new()
	launch_button.theme_type_variation = "PrimaryButton"
	launch_button.custom_minimum_size = Vector2(560, 48)
	launch_button.pressed.connect(_on_launch_pressed)
	launch_row.add_child(launch_button)
	resized.connect(_fit_layout)
	_fit_layout.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		# Wait for translated Control minimum sizes; no refresh or autosave needed.
		_fit_layout.call_deferred()

func _fit_layout() -> void:
	if not _card_columns: return
	var available = maxf(240.0, size.x - 40.0)
	# Measure the complete header as if its two reserve cards were on row one.
	# English and larger UI scales can need the second row even at 1280 pixels.
	var row_width = _barn_card.get_combined_minimum_size().x + _watch_card.get_combined_minimum_size().x
	var count = 2
	for child in _header_row.get_children():
		if child != _barn_card and child != _watch_card:
			row_width += child.get_combined_minimum_size().x
			count += 1
	row_width += float(count - 1) * _header_row.get_theme_constant("separation")
	var separate_stats = row_width > available
	var stats_parent: HBoxContainer = _header_stats if separate_stats else _header_row
	for card in [_barn_card, _watch_card]:
		if card.get_parent() != stats_parent:
			card.reparent(stats_parent, false)
	if not separate_stats:
		_header_row.move_child(_barn_card, 1)
		_header_row.move_child(_watch_card, 2)
	_header_stats.visible = separate_stats
	# The minimum widths include translated headings/buttons, not a fixed cutoff.
	var widths: Array[float] = []
	for column in _card_columns.get_children():
		widths.append(column.get_combined_minimum_size().x)
	var gap = float(_card_columns.get_theme_constant("h_separation"))
	var three_width = widths[0] + widths[1] + widths[2] + 2.0 * gap
	var two_width = maxf(widths[0], widths[2]) + widths[1] + gap
	_card_columns.columns = 3 if three_width <= available - 14.0 else (2 if two_width <= available - 14.0 else 1)
	launch_button.custom_minimum_size.x = minf(560.0, maxf(240.0, available - 8.0))
	_fit_harvest_layout()

func _card(kind: String, title: String, tint: Color, seed_value: int, expand: bool = true) -> VBoxContainer:
	var card = UITheme.card(Color(UITheme.PANEL, 0.93), tint, seed_value)
	if expand:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box = UITheme.vbox(8)
	card.add_child(box)
	var heading = UITheme.header(kind, title, tint)
	var heading_label = heading.get_child(heading.get_child_count() - 1) as Label
	UITheme.wrap(heading_label)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(heading)
	return box

func _button(text: String, toggle: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 44
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	return b

func _build_header() -> Control:
	var header = UITheme.vbox(6)
	var row = UITheme.hbox(16)
	_header_row = row
	header.add_child(row)
	_header_stats = UITheme.hbox(12)
	header.add_child(_header_stats)
	var titles = UITheme.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(titles)
	var name_row = UITheme.hbox(12)
	titles.add_child(name_row)
	var game_title = TitleLogo.new()
	game_title.compact = true
	game_title.size_px = 36.0
	name_row.add_child(game_title)
	var tag = UITheme.label("ข้างเตาไฟยามค่ำ", "Kicker", UITheme.MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag)
	header_label = UITheme.wrap(UITheme.label("", "Body", UITheme.CREAM))
	titles.add_child(header_label)

	var barn = _header_stat("rice", "ข้าวในยุ้ง", UITheme.STRAW, 201)
	_barn_card = barn[0]
	row.add_child(barn[0])
	barn_value = barn[1]
	barn_bar = barn[2]
	barn_bar.set_markers([{"at": GameState.FAMINE_THRESHOLD, "color": UITheme.RUBY}])

	var watch = _header_stat("eye", "ความเพ่งเล็งของรัฐ", UITheme.STATE, 202)
	_watch_card = watch[0]
	row.add_child(watch[0])
	scrutiny_value = watch[1]
	scrutiny_bar = watch[2]
	scrutiny_bar.set_markers([{"at": 75.0, "color": UITheme.RUBY}])

	help_button = _button("วิธีเล่น")
	help_button.custom_minimum_size = Vector2(110, 0)
	help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help_button.add_theme_font_size_override("font_size", 17)
	help_button.pressed.connect(show_how_to_play)
	row.add_child(help_button)

	# Volume and the rest live in the shared, saved Settings panel
	settings_button = _button("ตั้งค่า")
	settings_button.custom_minimum_size = Vector2(96, 0)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_button.add_theme_font_size_override("font_size", 17)
	settings_button.pressed.connect(show_settings)
	row.add_child(settings_button)
	return header

func _header_stat(kind: String, title: String, tint: Color, seed_value: int) -> Array:
	var card = UITheme.card(Color(UITheme.STATE_DEEP if tint == UITheme.STATE else UITheme.PANEL, 0.93), tint, seed_value)
	card.padding = Vector4(14, 9, 14, 11)
	card.custom_minimum_size = Vector2(250, 0)
	var box = UITheme.vbox(5)
	card.add_child(box)
	var top = UITheme.hbox(8)
	box.add_child(top)
	var ic = UITheme.icon(kind, tint, 18.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var t = UITheme.label(title, "Small")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var v = UITheme.label("", "Title", tint)
	v.add_theme_font_size_override("font_size", 17)
	top.add_child(v)
	var bar = SegmentBar.new()
	bar.segments = 20
	bar.fill_color = tint
	bar.custom_minimum_size = Vector2(0, 9)
	box.add_child(bar)
	return [card, v, bar]

func _build_radio() -> Control:
	var box = _card("radio", "วิทยุทรานซิสเตอร์", UITheme.STRAW, 211)
	var channels = UITheme.hbox(6)
	box.add_child(channels)
	var group = ButtonGroup.new()
	for ch in [[1, "88.5 ป่าไม้"], [2, "94.2 อากาศ"], [3, "101.0 เตหน่ากู"]]:
		var b = _button(ch[1], true)
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_tune_radio.bind(ch[0]))
		channels.add_child(b)
		radio_buttons.append(b)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	radio_text = UITheme.wrap(UITheme.label("", "Small", Color("cfe3cf")))
	radio_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(radio_text)
	return box.get_parent()

func _build_plot_brief() -> Control:
	var box = _card("mountain", "แปลงที่จะเผาพรุ่งนี้", UITheme.EMERALD, 221)
	plot_title_label = UITheme.wrap(UITheme.label("", "Title", UITheme.EMERALD))
	plot_title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(plot_title_label)
	plot_desc_label = UITheme.wrap(UITheme.label("", "Body"))
	box.add_child(plot_desc_label)
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", _rule())
	box.add_child(sep)
	plot_stats = GridContainer.new()
	plot_stats.columns = 2
	plot_stats.add_theme_constant_override("h_separation", 14)
	plot_stats.add_theme_constant_override("v_separation", 2)
	box.add_child(plot_stats)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var goals = UITheme.card(Color(UITheme.INK, 0.6), UITheme.STRAW, 222)
	goals.padding = Vector4(14, 10, 14, 12)
	box.add_child(goals)
	var gb = UITheme.vbox(6)
	goals.add_child(gb)
	gb.add_child(UITheme.label("เป้าหมายพรุ่งนี้", "Kicker"))
	goal_rows = UITheme.vbox(2)
	gb.add_child(goal_rows)
	return box.get_parent()

func _goal(kind: String, color: Color, text: String) -> void:
	var row = UITheme.hbox(10)
	var ic = UITheme.icon(kind, color, 20.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l = UITheme.wrap(UITheme.label(text, "Small", UITheme.CREAM))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	goal_rows.add_child(row)

func _rule() -> StyleBoxLine:
	var s = StyleBoxLine.new()
	s.color = Color(UITheme.CREAM, 0.12)
	s.thickness = 1
	return s

func _build_workshop() -> Control:
	var box = _card("hammer", "โรงซ่อมเครื่องมือ", UITheme.CLAY.lightened(0.2), 231, false)
	workshop_label = UITheme.wrap(UITheme.label("", "Small", UITheme.CREAM))
	box.add_child(workshop_label)
	sharpen_button = _button("ลับมีดพร้า · ใช้ข้าว 10%")
	sharpen_button.pressed.connect(_on_sharpen_pressed)
	box.add_child(sharpen_button)
	seal_button = _button("เปลี่ยนซีลถังพ่นน้ำ · ใช้ข้าว 10%")
	seal_button.pressed.connect(_on_seal_pressed)
	box.add_child(seal_button)
	return box.get_parent()

func _build_granary() -> Control:
	var box = _card("rice", "แม่หลู · ยุ้งข้าวและเสบียง", UITheme.STRAW, 241, false)
	granary_label = UITheme.wrap(UITheme.label("", "Small", UITheme.CREAM))
	var keeper_row := HBoxContainer.new()
	box.add_child(keeper_row)
	maelu_portrait = SubViewportContainer.new()
	maelu_portrait.set_script(load("res://scripts/MaeluVillagePortrait.gd"))
	keeper_row.add_child(maelu_portrait)
	granary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keeper_row.add_child(granary_label)
	var row = UITheme.hbox(6)
	box.add_child(row)
	var group = ButtonGroup.new()
	for level in RATION_BUTTONS:
		var b = _button(RATION_BUTTONS[level], true)
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_ration_pressed.bind(level))
		b.pressed.connect(Callable(maelu_portrait, "granary_gesture"))
		row.add_child(b)
		ration_buttons[level] = b
	return box.get_parent()

func _build_exchange() -> Control:
	var box = _card("hands", "เอาแรง · แลกแรงงานกับหมู่บ้านใกล้เคียง", UITheme.EMERALD, 251)
	exchange_label = UITheme.wrap(UITheme.label("", "Small", UITheme.CREAM))
	box.add_child(exchange_label)
	for f in FAVOUR_BUTTONS:
		var b = _button(FAVOUR_BUTTONS[f], true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UITheme.font("regular"))
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_favour_pressed.bind(f))
		box.add_child(b)
		favour_buttons[f] = b
	return box.get_parent()

# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------

func _stat(label_text: String, value: String, warn: bool = false) -> void:
	var l = UITheme.label(label_text, "Small")
	plot_stats.add_child(l)
	var v = UITheme.wrap(UITheme.label(value, "Small", UITheme.EMBER if warn else UITheme.CREAM))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plot_stats.add_child(v)

func _refresh() -> void:
	var state = GameState.instance
	var cfg: PlotGenerator.PlotConfig = state.plot_config()
	var rules: Escalation.YearRules = cfg.rules

	header_label.text = L10n.format("ปีที่ %d · แปลงที่ %d/%d · ฤดูแล้งของไร่หมุนเวียน", [state.current_year, state.current_plot_index, GameState.PLOTS_PER_YEAR])
	barn_value.text = "%.0f%%" % state.rice_barn
	barn_bar.value = state.rice_barn
	barn_bar.fill_color = UITheme.RUBY if state.rice_barn < 40.0 else UITheme.STRAW
	scrutiny_value.text = "%d/100" % state.state_scrutiny
	scrutiny_bar.value = state.state_scrutiny
	scrutiny_bar.fill_color = UITheme.RUBY if state.state_scrutiny >= 75 else UITheme.STATE

	plot_title_label.text = cfg.name
	plot_desc_label.text = cfg.description
	for c in plot_stats.get_children():
		plot_stats.remove_child(c)
		c.queue_free()
	var strong_wind = cfg.wind_base_speed > FireGrid.EMBER_JUMP_WIND
	var drones = "ไม่มีรายงาน" if cfg.drone_count == 0 else L10n.format("%d ลำ · 15:00–18:00%s", [cfg.drone_count, " · ความเร็วสูง" if rules.drone_speed_mult > 1.0 else ""])
	_stat("ความสูงของเนิน", L10n.format("%.1f ม. · ไฟขึ้นเนินเร็ว ×%.1f", [cfg.terrain_rise(), cfg.uphill_spread_factor()]))
	_stat("ความหนาแน่นของไผ่", L10n.format("%.0f%% · เสี่ยงปล้องระเบิด", (cfg.bamboo_ratio * 100.0)), cfg.bamboo_ratio > 0.3)
	_stat("ลมหุบเขา", L10n.format("×%.1f%s", [cfg.wind_base_speed, " · ลูกไฟข้ามแนวกันไฟได้" if strong_wind else ""]), strong_wind)
	_stat("โดรนลาดตระเวน", drones, cfg.drone_count > 0)
	_stat("กล้องความร้อนภาคพื้น", L10n.format("%d ตัวที่แนวเขตอุทยาน", rules.ground_cameras) if rules.ground_cameras > 0 else "ไม่มี", rules.ground_cameras > 0)
	_stat("เจ้าหน้าที่เดินตรวจ", L10n.format("%d นาย · 15:30–18:30", rules.ranger_count) if rules.ranger_count > 0 else "ไม่มี", rules.ranger_count > 0)
	_stat("ความเข้มงวดของป่าอนุรักษ์", "×%.1f" % cfg.national_park_strictness, cfg.national_park_strictness > 1.5)
	_stat("เกณฑ์ดาวเทียม VIIRS", L10n.format("%d TU · ถูกจับได้ เพ่งเล็ง +%d–%d", [roundi(rules.satellite_threshold), rules.hotspot_penalty, rules.hotspot_penalty * 2]))
	_stat("ภัยแล้งเร่งไฟ", "+%d%%" % roundi((rules.spread_mult - 1.0) * 100.0), rules.spread_mult > 1.0)

	for c in goal_rows.get_children():
		goal_rows.remove_child(c)
		c.queue_free()
	var start = UITheme.clock_text(state.labour_delay_minutes())
	_goal("clock", UITheme.STRAW, L10n.format("เผาในหน้าต่างเงาดาวเทียม %s–20:00 น.", start))
	_goal("rice", UITheme.EMERALD, L10n.format("เผาให้ได้เถ้า ≥%d%% ของแปลง ข้าวจึงจะเต็มยุ้ง", (65 if state.has_favour(GameState.Favour.SEEDS) else 75)))
	_goal("satellite", UITheme.STATE, L10n.format("ก่อน 20:00 ดับทุกจุดที่ร้อนตั้งแต่ %d TU ไม่ให้ VIIRS เห็น", roundi(rules.satellite_threshold)))
	_goal("crew", UITheme.STRAW, L10n.format("ตาโพถางแนวกันไฟ%s · มูนอตามดับถ่าน", (" และฉีดน้ำได้" if state.has_favour(GameState.Favour.SPRAYER) else "")))

	workshop_label.text = L10n.format("มีดพร้า: ระดับ %d/3 · ถางแนวกันไฟเร็วขึ้น %d%%\nซีลถังพ่นน้ำ: ระดับ %d/3 · ใช้น้ำ %.2f ลิตรต่อครั้ง", [
		state.blade_upgrade_level, state.blade_upgrade_level * 20,
		state.sprayer_upgrade_level, 1.0 - 0.15 * state.sprayer_upgrade_level
	])
	sharpen_button.disabled = state.blade_upgrade_level >= 3 or not state.can_afford_upgrade()
	seal_button.disabled = state.sprayer_upgrade_level >= 3 or not state.can_afford_upgrade()

	# Granary
	for level in ration_buttons:
		var b: Button = ration_buttons[level]
		b.set_pressed_no_signal(state.ration_level == level)
		b.disabled = not state.can_afford_ration(level)
	granary_label.text = L10n.format("อดอยากเมื่อข้าวในยุ้งเหลือ %d%% หรือน้อยกว่า\n%s — %s\nเผาครั้งก่อนได้เถ้า %.0f%% → %s", [
		roundi(GameState.FAMINE_THRESHOLD),
		GameState.RATION_NAMES[state.ration_level], RATION_EFFECTS[state.ration_level],
		state.last_burn_yield, _yield_outlook(state),
	])

	# Mutual aid exchange
	for f in favour_buttons:
		favour_buttons[f].set_pressed_no_signal(state.has_favour(f))
	exchange_label.text = L10n.format("เอาแรงแต่ละครั้งกินเวลาเผาพรุ่งนี้ %d นาที%s · เริ่มเผา %s", [
		state.favour_minutes(),
		" (ด่านทหารทำให้เดินทางช้าลง)" if rules.checkpoints else "",
		start,
	])
	launch_button.text = L10n.format("เดินขึ้นไร่ · เริ่มเผา %s น.", start)
	# Autosave: every Hearth change is kept, so quitting never loses the campaign
	SaveGame.save(state)

func _yield_outlook(state: Node) -> String:
	var seeds = state.has_favour(GameState.Favour.SEEDS)
	return L10n.format("≥%d%% ข้าวเต็มยุ้ง ต่ำกว่า 60%% หมายถึงความหิว", (65 if seeds else 75))

# ---------------------------------------------------------------------------
# Radio
# ---------------------------------------------------------------------------

func _tune_radio(channel: int, with_sound: bool = true) -> void:
	current_radio_channel = channel
	for i in radio_buttons.size():
		radio_buttons[i].set_pressed_no_signal(i + 1 == channel)
	var state = GameState.instance
	var cfg: PlotGenerator.PlotConfig = state.plot_config()
	var rules: Escalation.YearRules = cfg.rules

	if AudioManager.instance:
		if with_sound:
			AudioManager.instance.play_radio_tune()
		AudioManager.instance.play_hearth_music(channel == 3)
		AudioManager.instance.set_radio_static(0.15 if channel == 3 else 0.45)
	_start_chatter()

	match channel:
		1:
			var lines = PackedStringArray()
			for l in rules.headlines():
				lines.append(L10n.concat(["· ", l]))
			radio_text.text = L10n.format("""[FM 88.5 MHz · กรมป่าไม้]
“...สถานี 4 ถึงทุกหน่วย มาตรการห้ามเผาเด็ดขาดมีผลทั่วทั้งลุ่มน้ำ พื้นที่เฝ้าระวังพรุ่งนี้: %s...”

%s""", [cfg.name.get_slice(":", 0), L10n.join(lines)])
		2:
			var wind_dir = UITheme.cardinal_th(state.forecast_wind_direction())
			var storm = "\nเมฆฝนฟ้าคะนองก่อตัวเหนือสันดอย พายุก่อนมรสุมจะมาถึงช่วงค่ำ" if cfg.storm_front else ""
			var gusty = " ลมกระโชกแปรปรวนบนสันดอยที่เปิดโล่ง" if cfg.wind_shift_interval.x < 50.0 else ""
			radio_text.text = L10n.format("""[FM 94.2 MHz · พยากรณ์อากาศบนดอย]
“...ความชื้นสัมพัทธ์ %d%% ลมหุบเขาช่วงบ่ายพัดไปทาง%s แรง ×%.1f%s คาดว่าลมจะเปลี่ยนทิศทุก %d–%d นาที ชั้นอากาศผกผันจะกดควันไว้ติดพื้นตั้งแต่พระอาทิตย์ตก 18:00 น....”%s""", [
				rules.humidity_pct, wind_dir, cfg.wind_base_speed, gusty,
				roundi(cfg.wind_shift_interval.x / 1.5), roundi(cfg.wind_shift_interval.y / 1.5), storm,
			])
		3:
			radio_text.text = L10n.format("""[FM 101.0 MHz · เตหน่ากูและเพลงพื้นบ้านปกาเกอะญอ]
“...(เสียงเตหน่ากูเจ็ดสายกับแคนไม้ไผ่ดังก้องในกระท่อม)... ผู้เฒ่าเตือนเราว่า: %s”""", PROVERBS[(state.current_year + state.current_plot_index) % PROVERBS.size()])

## Recorded broadcast lines over the static: one when tuning, then while listening.
## Channel 3 is music and stays voiceless.
func _start_chatter() -> void:
	if chatter_timer == null:
		chatter_timer = Timer.new()
		chatter_timer.one_shot = true
		chatter_timer.timeout.connect(_on_chatter_timeout)
		add_child(chatter_timer)
	chatter_timer.stop()
	if _can_chatter():
		chatter_timer.start(randf_range(0.6, 1.2))

func _can_chatter() -> bool:
	return AudioManager.instance != null and current_radio_channel != 3 \
		and AudioManager.instance.has_radio_voice(current_radio_channel) \
		and not is_instance_valid(_harvest_modal)

func _on_chatter_timeout() -> void:
	if not _can_chatter() or chatter_timer == null:
		return
	var am = AudioManager.instance
	if am.radio_player != null and am.radio_player.playing:
		chatter_timer.start(randf_range(8.0, 14.0)) # line still going, wait it out
		return
	am.play_radio_voice(current_radio_channel)
	chatter_timer.start(randf_range(24.0, 40.0))

# ---------------------------------------------------------------------------
# Choices
# ---------------------------------------------------------------------------

func _on_ration_pressed(level: int) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_grain()
	GameState.instance.ration_level = level
	_refresh()

func _on_favour_pressed(f: int) -> void:
	GameState.instance.toggle_favour(f)
	_refresh()

func _on_sharpen_pressed() -> void:
	var state = GameState.instance
	if state and state.can_afford_upgrade() and state.blade_upgrade_level < 3:
		state.rice_barn -= state.UPGRADE_RICE_COST
		state.blade_upgrade_level += 1
		if AudioManager.instance:
			AudioManager.instance.play_workshop()
		_refresh()

func _on_seal_pressed() -> void:
	var state = GameState.instance
	if state and state.can_afford_upgrade() and state.sprayer_upgrade_level < 3:
		state.rice_barn -= state.UPGRADE_RICE_COST
		state.sprayer_upgrade_level += 1
		if AudioManager.instance:
			AudioManager.instance.play_workshop()
		_refresh()

func _on_launch_pressed() -> void:
	GameState.instance.consume_rations()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	# Change scene to Main hillside burn
	# Year 4+: the march passes a military checkpoint first (CheckpointScene)
	var scene = "res://scenes/Checkpoint.tscn" if GameState.instance.rules().checkpoints else "res://scenes/Main.tscn"
	get_tree().change_scene_to_file(scene)

# ---------------------------------------------------------------------------
# Annual monsoon harvest
# ---------------------------------------------------------------------------

func _show_harvest(h: Dictionary) -> void:
	# The annual report owns attention; delay background broadcast chatter until
	# it closes, so a radio caption cannot obscure the report's pinned action.
	if chatter_timer:
		chatter_timer.stop()
	if AudioManager.instance:
		AudioManager.instance.play_hearth_music(current_radio_channel == 3)
	_harvest_modal = Control.new()
	_harvest_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_harvest_modal)
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.7)
	_harvest_modal.add_child(dim)

	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.EMERALD, 301)
	card.padding = Vector4(28, 24, 28, 26)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	_harvest_card = card
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_harvest_modal.add_child(card)
	var frame = UITheme.vbox(12)
	card.add_child(frame)
	_harvest_scroll = ScrollContainer.new()
	_harvest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_harvest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_harvest_scroll.focus_mode = Control.FOCUS_ALL
	_harvest_scroll.follow_focus = true
	frame.add_child(_harvest_scroll)
	var box = UITheme.vbox(12)
	_harvest_content = box
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_harvest_scroll.add_child(box)

	# A poor harvest can tip the barn into famine: the campaign ends here, it does
	# not carry on unsaved (audit finding 1)
	var over = GameState.instance.is_game_over()
	var famine = GameState.instance.end_cause() == "famine"
	box.add_child(UITheme.header("rice", L10n.format("เก็บเกี่ยวหน้ามรสุม · ปีที่ %d", h.year), UITheme.EMERALD))
	var title = UITheme.wrap(UITheme.label("ฝนมาแล้ว แต่ข้าวที่ได้ไม่พอกินถึงปีหน้า" if famine else "ฝนมาแล้ว ข้าวไร่งอกงามในแปลงเถ้า", "Title"))
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	var yields = UITheme.hbox(8)
	box.add_child(yields)
	for i in h.yields.size():
		var tile = UITheme.card(UITheme.PANEL_HI, UITheme.STRAW, 310 + i)
		tile.padding = Vector4(10, 8, 10, 8)
		tile.chamfer = 8.0
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tb = UITheme.vbox(0)
		tile.add_child(tb)
		tb.add_child(UITheme.label(L10n.format("แปลง %d", (i + 1)), "Small"))
		var v = UITheme.label("%.0f%%" % h.yields[i], "Title", UITheme.EMERALD if h.yields[i] >= 60.0 else UITheme.STRAW)
		tb.add_child(v)
		yields.add_child(tile)

	box.add_child(UITheme.wrap(UITheme.label(L10n.format("เถ้าเฉลี่ยทั้งฤดู %.0f%%  →  ยุ้งข้าว %+.0f%%\nฝนมรสุมชะความเพ่งเล็งของรัฐออกไป %d", [h.average, h.rice_delta, h.scrutiny_relief]), "Body")))

	var news = PackedStringArray()
	for l in h.next_rules:
		news.append(L10n.concat(["· ", l]))
	var state_card = UITheme.card(UITheme.STATE_DEEP, UITheme.STATE, 320)
	state_card.padding = Vector4(14, 10, 14, 12)
	state_card.visible = not over # No next year to announce
	box.add_child(state_card)
	var sb = UITheme.vbox(4)
	state_card.add_child(sb)
	sb.add_child(UITheme.header("eye", L10n.format("ปีที่ %d · สิ่งที่รัฐจะนำมา", h.next_year), UITheme.STATE))
	sb.add_child(UITheme.wrap(UITheme.label(L10n.join(news), "Small", UITheme.CREAM)))

	if over:
		var warn = UITheme.wrap(UITheme.label((L10n.format("ข้าวในยุ้งเหลือ %.0f%% หลังเก็บเกี่ยว เกณฑ์อดอยากคือ %.0f%% หรือน้อยกว่า · หมู่บ้านอดอยาก", [GameState.instance.rice_barn, GameState.FAMINE_THRESHOLD])) if famine else "ความเพ่งเล็งถึง 100 · รัฐบุกหมู่บ้าน", "Title", UITheme.RUBY))
		warn.add_theme_font_size_override("font_size", 20)
		box.add_child(warn)
	var close = Button.new()
	close.theme_type_variation = "PrimaryButton"
	close.text = "ดูบทสรุปของหมู่บ้าน" if over else L10n.format("เริ่มปีที่ %d", h.next_year)
	close.custom_minimum_size = Vector2(0, 50)
	close.pressed.connect(_end_campaign if over else _close_harvest)
	harvest_button = close
	frame.add_child(close)
	close.focus_next = close.get_path_to(_harvest_scroll)
	close.focus_previous = close.focus_next
	close.focus_neighbor_left = close.focus_next
	close.focus_neighbor_right = close.focus_next
	_harvest_scroll.focus_next = _harvest_scroll.get_path_to(close)
	_harvest_scroll.focus_previous = _harvest_scroll.focus_next
	_harvest_scroll.focus_neighbor_left = _harvest_scroll.focus_next
	_harvest_scroll.focus_neighbor_right = _harvest_scroll.focus_next
	_harvest_focus_scope = ModalFocusScope.begin(_harvest_modal)
	close.grab_focus()
	_fit_harvest_layout.call_deferred()

	# On a campaign end the Ending scene plays the stinger; the card stays quiet
	if AudioManager.instance and not over:
		AudioManager.instance.play_harvest_chime()

func _fit_harvest_layout() -> void:
	if not is_instance_valid(_harvest_card):
		return
	# Only the narrative body scrolls. The continue/ending action stays visible.
	var width = minf(680.0, maxf(300.0, size.x - 48.0))
	var height = minf(640.0, maxf(240.0, size.y - 40.0))
	_harvest_card.offset_left = -width * 0.5
	_harvest_card.offset_right = width * 0.5
	_harvest_card.offset_top = -height * 0.5
	_harvest_card.offset_bottom = height * 0.5

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_harvest_modal) or not is_instance_valid(_harvest_scroll):
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus != harvest_button and focus != _harvest_scroll:
		return
	# The body has no buttons. D-pad/arrows scroll it while Enter/A remains on
	# the fixed action; Tab cycles the two focus targets within the modal.
	var delta = 0
	if event.is_action_pressed("ui_down", true):
		delta = 72
	elif event.is_action_pressed("ui_up", true):
		delta = -72
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_PAGEDOWN:
			delta = int(_harvest_scroll.size.y * 0.85)
		elif event.keycode == KEY_PAGEUP:
			delta = -int(_harvest_scroll.size.y * 0.85)
	if delta != 0:
		_harvest_scroll.scroll_vertical += delta
		get_viewport().set_input_as_handled()

func _end_campaign() -> void:
	if is_instance_valid(_harvest_focus_scope):
		_harvest_focus_scope.release()
	GameState.instance.pending_harvest = {}
	get_tree().change_scene_to_file(ENDING_SCENE)

func _close_harvest() -> void:
	GameState.instance.pending_harvest = {}
	if is_instance_valid(_harvest_focus_scope):
		_harvest_focus_scope.release()
		_harvest_focus_scope = null
	if _harvest_modal:
		_harvest_modal.queue_free()
		_harvest_modal = null
		_harvest_card = null
		_harvest_scroll = null
		_harvest_content = null
	launch_button.grab_focus()
	_start_chatter()
	_refresh()
