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

var header_label: Label
var barn_value: Label
var barn_bar: SegmentBar
var scrutiny_value: Label
var scrutiny_bar: SegmentBar
var radio_text: Label
var radio_buttons: Array[Button] = []
var plot_title_label: Label
var plot_desc_label: Label
var plot_stats: GridContainer
var goal_rows: VBoxContainer
var workshop_label: Label
var sharpen_button: Button
var seal_button: Button
var granary_label: Label
var ration_buttons: Dictionary = {}
var exchange_label: Label
var favour_buttons: Dictionary = {}
var launch_button: Button

var current_radio_channel: int = 1
var _harvest_modal: Control

func _ready() -> void:
	theme = UITheme.get_theme()
	_build()
	_tune_radio(1, false)
	_refresh()

	# Gamepad / Steam Deck: start with focus on the main action
	launch_button.grab_focus()

	if not GameState.instance.pending_harvest.is_empty():
		_show_harvest(GameState.instance.pending_harvest)

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build() -> void:
	var backdrop = HearthBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var page = UITheme.vbox(12)
	margin.add_child(page)

	page.add_child(_build_header())

	var columns = UITheme.hbox(12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left = UITheme.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_build_radio())
	left.add_child(_build_granary())

	var centre = _build_plot_brief()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_stretch_ratio = 1.05
	columns.add_child(centre)

	var right = UITheme.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(_build_workshop())
	right.add_child(_build_exchange())

	var launch_row = UITheme.hbox(0)
	launch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(launch_row)
	launch_button = Button.new()
	launch_button.theme_type_variation = "PrimaryButton"
	launch_button.custom_minimum_size = Vector2(560, 54)
	launch_button.pressed.connect(_on_launch_pressed)
	launch_row.add_child(launch_button)

func _card(kind: String, title: String, tint: Color, seed_value: int, expand: bool = true) -> VBoxContainer:
	var card = UITheme.card(Color(UITheme.PANEL, 0.93), tint, seed_value)
	if expand:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box = UITheme.vbox(8)
	card.add_child(box)
	box.add_child(UITheme.header(kind, title, tint))
	return box

func _button(text: String, toggle: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	return b

func _build_header() -> Control:
	var row = UITheme.hbox(16)
	var titles = UITheme.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(titles)
	var name_row = UITheme.hbox(12)
	titles.add_child(name_row)
	var game_title = UITheme.label("เงาเมฆา", "Title", UITheme.STRAW)
	game_title.add_theme_font_override("font", UITheme.font("bold"))
	game_title.add_theme_font_size_override("font_size", 34)
	name_row.add_child(game_title)
	var tag = UITheme.label("ข้างเตาไฟยามค่ำ · SATELLITE SHADOW", "Kicker", UITheme.MUTED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(tag)
	header_label = UITheme.label("", "Body", UITheme.CREAM)
	titles.add_child(header_label)

	var barn = _header_stat("rice", "ข้าวในยุ้ง", UITheme.STRAW, 201)
	row.add_child(barn[0])
	barn_value = barn[1]
	barn_bar = barn[2]
	barn_bar.set_markers([{"at": GameState.FAMINE_THRESHOLD, "color": UITheme.RUBY}])

	var watch = _header_stat("eye", "ความเพ่งเล็งของรัฐ", UITheme.STATE, 202)
	row.add_child(watch[0])
	scrutiny_value = watch[1]
	scrutiny_bar = watch[2]
	scrutiny_bar.set_markers([{"at": 75.0, "color": UITheme.RUBY}])
	return row

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
	plot_stats.add_theme_constant_override("v_separation", 7)
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
	goal_rows = UITheme.vbox(5)
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
	var box = _card("rice", "ยุ้งข้าวและเสบียง", UITheme.STRAW, 241, false)
	granary_label = UITheme.wrap(UITheme.label("", "Small", UITheme.CREAM))
	box.add_child(granary_label)
	var row = UITheme.hbox(6)
	box.add_child(row)
	var group = ButtonGroup.new()
	for level in RATION_BUTTONS:
		var b = _button(RATION_BUTTONS[level], true)
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_ration_pressed.bind(level))
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

	header_label.text = "ปีที่ %d · แปลงที่ %d/%d · ฤดูแล้งของไร่หมุนเวียน" % [state.current_year, state.current_plot_index, GameState.PLOTS_PER_YEAR]
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
	var drones = "ไม่มีรายงาน" if cfg.drone_count == 0 else "%d ลำ · 15:00–18:00%s" % [cfg.drone_count, " · ความเร็วสูง" if rules.drone_speed_mult > 1.0 else ""]
	_stat("ความสูงของเนิน", "%.1f ม. · ไฟขึ้นเนินเร็ว ×%.1f" % [cfg.terrain_rise(), cfg.uphill_spread_factor()])
	_stat("ความหนาแน่นของไผ่", "%.0f%% · เสี่ยงปล้องระเบิด" % (cfg.bamboo_ratio * 100.0), cfg.bamboo_ratio > 0.3)
	_stat("ลมหุบเขา", "×%.1f%s" % [cfg.wind_base_speed, " · ลูกไฟข้ามแนวกันไฟได้" if strong_wind else ""], strong_wind)
	_stat("โดรนลาดตระเวน", drones, cfg.drone_count > 0)
	_stat("กล้องความร้อนภาคพื้น", "%d ตัวที่แนวเขตอุทยาน" % rules.ground_cameras if rules.ground_cameras > 0 else "ไม่มี", rules.ground_cameras > 0)
	_stat("ความเข้มงวดของป่าอนุรักษ์", "×%.1f" % cfg.national_park_strictness, cfg.national_park_strictness > 1.5)
	_stat("เกณฑ์ดาวเทียม VIIRS", "%d TU · เพ่งเล็ง +%d ต่อจุด" % [roundi(rules.satellite_threshold), rules.hotspot_penalty])
	_stat("ภัยแล้งเร่งไฟ", "+%d%%" % roundi((rules.spread_mult - 1.0) * 100.0), rules.spread_mult > 1.0)

	for c in goal_rows.get_children():
		goal_rows.remove_child(c)
		c.queue_free()
	var start = UITheme.clock_text(state.labour_delay_minutes())
	_goal("clock", UITheme.STRAW, "เผาในหน้าต่างเงาดาวเทียม %s–20:00 น." % start)
	_goal("rice", UITheme.EMERALD, "เผาให้ได้เถ้า ≥%d%% ของแปลง ข้าวจึงจะเต็มยุ้ง" % (65 if state.has_favour(GameState.Favour.SEEDS) else 75))
	_goal("satellite", UITheme.STATE, "ก่อน 20:00 ดับทุกจุดที่ร้อนตั้งแต่ %d TU ไม่ให้ VIIRS เห็น" % roundi(rules.satellite_threshold))
	_goal("crew", UITheme.STRAW, "ตาโพถางแนวกันไฟ%s · มูนอตามดับถ่าน" % (" และฉีดน้ำได้" if state.has_favour(GameState.Favour.SPRAYER) else ""))

	workshop_label.text = "มีดพร้า: ระดับ %d/3 · ถางแนวกันไฟเร็วขึ้น %d%%\nซีลถังพ่นน้ำ: ระดับ %d/3 · ใช้น้ำ %.2f ลิตรต่อครั้ง" % [
		state.blade_upgrade_level, state.blade_upgrade_level * 20,
		state.sprayer_upgrade_level, 1.0 - 0.15 * state.sprayer_upgrade_level
	]
	sharpen_button.disabled = state.blade_upgrade_level >= 3 or not state.can_afford_upgrade()
	seal_button.disabled = state.sprayer_upgrade_level >= 3 or not state.can_afford_upgrade()

	# Granary
	for level in ration_buttons:
		var b: Button = ration_buttons[level]
		b.set_pressed_no_signal(state.ration_level == level)
		b.disabled = not state.can_afford_ration(level)
	granary_label.text = "อดอยากเมื่อข้าวในยุ้งต่ำกว่า %d%%\n%s — %s\nเผาครั้งก่อนได้เถ้า %.0f%% → %s" % [
		roundi(GameState.FAMINE_THRESHOLD),
		GameState.RATION_NAMES[state.ration_level], RATION_EFFECTS[state.ration_level],
		state.last_burn_yield, _yield_outlook(state),
	]

	# Mutual aid exchange
	for f in favour_buttons:
		favour_buttons[f].set_pressed_no_signal(state.has_favour(f))
	exchange_label.text = "เอาแรงแต่ละครั้งกินเวลาเผาพรุ่งนี้ %d นาที%s · เริ่มเผา %s" % [
		state.favour_minutes(),
		" (ด่านทหารทำให้เดินทางช้าลง)" if rules.checkpoints else "",
		start,
	]
	launch_button.text = "เดินขึ้นไร่ · เริ่มเผา %s น." % start

func _yield_outlook(state: Node) -> String:
	var seeds = state.has_favour(GameState.Favour.SEEDS)
	return "≥%d%% ข้าวเต็มยุ้ง ต่ำกว่า 60%% หมายถึงความหิว" % (65 if seeds else 75)

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

	match channel:
		1:
			var lines = PackedStringArray()
			for l in rules.headlines():
				lines.append("· " + l)
			radio_text.text = """[FM 88.5 MHz · กรมป่าไม้]
“...สถานี 4 ถึงทุกหน่วย มาตรการห้ามเผาเด็ดขาดมีผลทั่วทั้งลุ่มน้ำ พื้นที่เฝ้าระวังพรุ่งนี้: %s...”

%s""" % [cfg.name.get_slice(":", 0), "\n".join(lines)]
		2:
			var wind_dir = UITheme.cardinal_th(state.forecast_wind_direction())
			var storm = "\nเมฆฝนฟ้าคะนองก่อตัวเหนือสันดอย พายุก่อนมรสุมจะมาถึงช่วงค่ำ" if cfg.storm_front else ""
			var gusty = " ลมกระโชกแปรปรวนบนสันดอยที่เปิดโล่ง" if cfg.wind_shift_interval.x < 50.0 else ""
			radio_text.text = """[FM 94.2 MHz · พยากรณ์อากาศบนดอย]
“...ความชื้นสัมพัทธ์ %d%% ลมหุบเขาช่วงบ่ายพัดไปทาง%s แรง ×%.1f%s คาดว่าลมจะเปลี่ยนทิศทุก %d–%d นาที ชั้นอากาศผกผันจะกดควันไว้ติดพื้นตั้งแต่พระอาทิตย์ตก 18:00 น....”%s""" % [
				rules.humidity_pct, wind_dir, cfg.wind_base_speed, gusty,
				roundi(cfg.wind_shift_interval.x / 1.5), roundi(cfg.wind_shift_interval.y / 1.5), storm,
			]
		3:
			radio_text.text = """[FM 101.0 MHz · เตหน่ากูและเพลงพื้นบ้านปกาเกอะญอ]
“...(เสียงเตหน่ากูเจ็ดสายกับแคนไม้ไผ่ดังก้องในกระท่อม)... ผู้เฒ่าเตือนเราว่า: %s”""" % PROVERBS[(state.current_year + state.current_plot_index) % PROVERBS.size()]

# ---------------------------------------------------------------------------
# Choices
# ---------------------------------------------------------------------------

func _on_ration_pressed(level: int) -> void:
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
		_refresh()

func _on_seal_pressed() -> void:
	var state = GameState.instance
	if state and state.can_afford_upgrade() and state.sprayer_upgrade_level < 3:
		state.rice_barn -= state.UPGRADE_RICE_COST
		state.sprayer_upgrade_level += 1
		_refresh()

func _on_launch_pressed() -> void:
	GameState.instance.consume_rations()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	# Change scene to Main hillside burn
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ---------------------------------------------------------------------------
# Annual monsoon harvest
# ---------------------------------------------------------------------------

func _show_harvest(h: Dictionary) -> void:
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
	card.custom_minimum_size = Vector2(680, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_harvest_modal.add_child(card)
	var box = UITheme.vbox(12)
	card.add_child(box)

	box.add_child(UITheme.header("rice", "เก็บเกี่ยวหน้ามรสุม · ปีที่ %d" % h.year, UITheme.EMERALD))
	var title = UITheme.wrap(UITheme.label("ฝนมาแล้ว ข้าวไร่งอกงามในแปลงเถ้า", "Title"))
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
		tb.add_child(UITheme.label("แปลง %d" % (i + 1), "Small"))
		var v = UITheme.label("%.0f%%" % h.yields[i], "Title", UITheme.EMERALD if h.yields[i] >= 60.0 else UITheme.STRAW)
		tb.add_child(v)
		yields.add_child(tile)

	box.add_child(UITheme.wrap(UITheme.label("เถ้าเฉลี่ยทั้งฤดู %.0f%%  →  ยุ้งข้าว %+.0f%%\nฝนมรสุมชะความเพ่งเล็งของรัฐออกไป %d" % [h.average, h.rice_delta, h.scrutiny_relief], "Body")))

	var news = PackedStringArray()
	for l in h.next_rules:
		news.append("· " + l)
	var state_card = UITheme.card(UITheme.STATE_DEEP, UITheme.STATE, 320)
	state_card.padding = Vector4(14, 10, 14, 12)
	box.add_child(state_card)
	var sb = UITheme.vbox(4)
	state_card.add_child(sb)
	sb.add_child(UITheme.header("eye", "ปีที่ %d · สิ่งที่รัฐจะนำมา" % h.next_year, UITheme.STATE))
	sb.add_child(UITheme.wrap(UITheme.label("\n".join(news), "Small", UITheme.CREAM)))

	var close = Button.new()
	close.theme_type_variation = "PrimaryButton"
	close.text = "เริ่มปีที่ %d" % h.next_year
	close.custom_minimum_size = Vector2(0, 50)
	close.pressed.connect(_close_harvest)
	box.add_child(close)
	close.grab_focus()

	if AudioManager.instance:
		AudioManager.instance.play_harvest_chime()

func _close_harvest() -> void:
	GameState.instance.pending_harvest = {}
	if _harvest_modal:
		_harvest_modal.queue_free()
		_harvest_modal = null
	launch_button.grab_focus()
	_refresh()
