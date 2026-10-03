class_name DebugOverlay
extends Control

## Tester tools (P0-10). Only active when GameSettings.debug_enabled():
## F3 info overlay · F5 +30 min · F6 jump to 19:45 · F7 replay this burn one
## year harsher · F8 fill water · F9 force a spot fire · F10 force a crackdown.

var main: Node
var _label: Label
var _shown: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card = UITheme.card(Color(UITheme.INK, 0.86), UITheme.STATE, 540)
	card.padding = Vector4(12, 8, 12, 10)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -330.0
	card.offset_right = -12.0
	card.offset_top = 70.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(card)
	_label = UITheme.label("", "StateText")
	_label.add_theme_font_size_override("font_size", 12)
	card.add_child(_label)
	card.visible = false

func _card() -> Control:
	return get_child(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or not GameSettings.debug_enabled() or main == null:
		return
	var handled = true
	match event.physical_keycode:
		KEY_F3:
			_shown = not _shown
			_card().visible = _shown
		KEY_F5:
			main.game_clock.current_sim_time_seconds += 30 * 60
		KEY_F6:
			main.game_clock.current_sim_time_seconds = maxf(main.game_clock.current_sim_time_seconds, (19 * 60 + 45) * 60)
		KEY_F7:
			var gs = GameState.instance
			gs.current_year = gs.current_year % 4 + 1
			get_tree().paused = false
			get_tree().reload_current_scene()
		KEY_F8:
			main.player.water = main.player.water_capacity
			main.player.water_changed.emit(main.player.water, main.player.water_capacity)
		KEY_F9:
			var fg = main.fire_grid
			fg._ignite_border(fg._coord_to_index(fg.grid_width / 2, 0), fg.cell_types, fg.cell_heat)
		KEY_F10:
			main.plot_scrutiny_gain += 100
			if not main.pass_started:
				main._on_satellite_pass()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _shown or main == null:
		return
	var fg = main.fire_grid
	var p = main.player
	var cell = "-"
	if p.is_targeting_valid_cell:
		var idx = fg._coord_to_index(p.target_cell_coord.x, p.target_cell_coord.y)
		cell = "%s %s heat %.0f" % [str(p.target_cell_coord), FireGrid.CellType.keys()[fg.cell_types[idx]], fg.cell_heat[idx]]
	var b: Dictionary = main.breakdown
	_label.text = L10n.join(PackedStringArray([
		L10n.format("FPS %d · ปี %d แปลง %d", [Engine.get_frames_per_second(), GameState.instance.current_year, GameState.instance.current_plot_index]),
		L10n.format("ช่อง %s", cell),
		L10n.format("เชื้อไฟแห้ง %.2f · ลม ×%.1f", [fg.fuel_dryness, fg.wind_speed_multiplier]),
		L10n.format("ลุกไหม้ %d · จุดร้อน %d · ไฟป่า %d", [fg.active_burning_indices.size(), fg.active_hotspot_count, fg.burning_border_cells]),
		L10n.format("เพ่งเล็งรอบนี้ +%d (ดาวเทียม %d โดรน %d กล้อง %d ลามป่า %d เจ้าหน้าที่ %d)", [main.plot_scrutiny_gain, b.satellite, b.drone, b.camera, b.escape, b.get("ranger", 0)]),
		"F5 +30น. · F6 19:45 · F7 ปีถัดไป · F8 น้ำเต็ม · F9 ลูกไฟ · F10 ถูกปราบ",
	]))
