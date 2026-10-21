extends SceneTree
## 0.3.3 phone UX fixes (iPhone playtest feedback 2026-10-13). Run:
##   godot --headless --path . --script res://tests/test_mobile_feedback.gd -- --touch --handheld
## A tutorial wording · B target marker · C silent-tap feedback · D tap skips
## cut-scenes · E order-button help · G no keyboard-only settings on phones.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok:
		failures += 1

func keyboard_words(text: String) -> bool:
	for word in ["กด 1", "กด 2", "กด 3", "คลิก", "กดค้าง", "ล้อเมาส์"]:
		if text.contains(word):
			return true
	return false

func all_text(node: Node) -> String:
	var out := ""
	if node is Label or node is Button:
		out += String(node.text) + "\n"
	for child in node.get_children():
		out += all_text(child)
	return out

func run() -> void:
	root.size = Vector2i(1280, 720)
	check(UITheme.is_mobile(), "touch mode active (--touch)")

	# A · tutorial wording
	for key in FirstBurnTips.TIPS:
		var text := FirstBurnTips.tip_text(key)
		check(not keyboard_words(text), "first-burn tip '%s' has no key/mouse wording on touch" % key)
	check(FirstBurnTips.TOUCH_TIPS.start.contains("สั่งงาน"), "start tip explains the Orders button")

	change_scene_to_file("res://scenes/Main.tscn")
	for i in 3:
		await process_frame
	var game = current_scene
	game.set_process(false)
	game.fire_grid.simulation_paused = true
	for actor in [game.player, game.elder, game.youth]:
		actor.set_physics_process(false)
	check(not keyboard_words(game.phase_goal(0)), "phase 1 goal has no hold-the-mouse wording on touch")
	check(game.phase_goal(1) == game.PHASES[1].goal, "later phase goals unchanged")

	# B · target marker readable around the finger
	var p = game.player
	var ind: MeshInstance3D = p.target_indicator
	var mat := (ind.mesh as BoxMesh).material as StandardMaterial3D
	check(mat.albedo_color.a >= 0.2 and mat.albedo_color.a <= 0.45 and mat.no_depth_test,
		"touch marker is a soft translucent fill drawn over brush")
	var frames := ind.get_children().filter(func(n): return n.name.begins_with("IndicatorFrame"))
	var rim: StandardMaterial3D = (frames[0].mesh as BoxMesh).material if frames.size() > 0 else null
	check(frames.size() == 4 and rim != null and rim.albedo_color.v > 0.8 and rim.albedo_color.a < 0.75,
		"touch marker has a light translucent 4-sided rim (%d)" % frames.size())

	# Thai text on phones: nothing below ~11 pt at the iPhone landscape scale (0.546 pt/px)
	check(is_equal_approx(UITheme.text_scale(), UITheme.PHONE_TEXT_SCALE), "phone text scale active in touch tests")
	var th: Theme = UITheme.get_theme()
	for v in ["Small", "Kicker", "Body", "Title"]:
		check(th.get_font_size("font_size", v) * 0.546 >= 10.9, "%s text >= 11 pt on iPhone (%d px)" % [v, th.get_font_size("font_size", v)])
	check(th.get_font_size("font_size", "Button") * 0.546 >= 12.0, "button text >= 12 pt on iPhone")
	check(UITheme.keep_units("ถ่านเย็นเอง (196 น.)") == "ถ่านเย็นเอง (196\u00a0น.)", "a number keeps its Thai unit on the same line")
	check(UITheme.keep_units("15/15 ล. · 2 นาย") == "15/15\u00a0ล. · 2\u00a0นาย", "litres and people stay with their numbers")

	# C · a tap that cannot act explains why
	var fg = game.fire_grid
	var here: Vector2i = fg.get_cell_coord_at_world_pos(p.global_position)
	var near := here
	var far := Vector2i(clampi(here.x + 12, 0, fg.grid_width - 1), here.y)
	if fg.get_cell_world_pos(far.x, far.y).distance_to(p.global_position) <= p.tool_reach():
		far = Vector2i(clampi(here.x - 12, 0, fg.grid_width - 1), here.y)
	p.touch_aim_active = true
	p.is_targeting_valid_cell = true
	p.current_tool = p.ToolType.FIREBREAK_BLADE
	var got: Array = []
	p.action_feedback.connect(func(m): got.append(m))
	p.target_cell_coord = far
	p.target_cell_pos = fg.get_cell_world_pos(far.x, far.y)
	p._feedback_cooldown = 0.0
	p._touch_tap_feedback()
	check(got.size() == 1 and got[0] == p.TOO_FAR, "out-of-reach tap says it is too far")
	await process_frame
	check(game.hud.alert_label.text == p.TOO_FAR and game.hud.alert_card.visible, "HUD shows the too-far alert")
	fg.cell_types[fg._coord_to_index(near.x, near.y)] = FireGrid.CellType.FIREBREAK
	p.target_cell_coord = near
	p.target_cell_pos = fg.get_cell_world_pos(near.x, near.y)
	p._feedback_cooldown = 0.0
	p._touch_tap_feedback()
	check(got.size() == 2 and got[1] == p.NO_BRUSH, "blade tap on bare soil says there is no brush")
	p._touch_tap_feedback()
	check(got.size() == 2, "feedback is rate-limited (no spam while dragging)")
	fg.cell_types[fg._coord_to_index(near.x, near.y)] = FireGrid.CellType.VEGETATION
	p._feedback_cooldown = 0.0
	p._touch_tap_feedback()
	check(got.size() == 2, "a valid in-reach blade tap stays silent")

	# C/E · order on a cell with no work, and the Orders button explains itself
	fg.cell_types[fg._coord_to_index(near.x, near.y)] = FireGrid.CellType.ASH
	game._on_order_pinged(near, fg.get_cell_world_pos(near.x, near.y))
	check(game.hud.alert_label.text == game.NO_ORDER_HERE, "order on ash explains who handles what")
	var tc = game.find_child("TouchControls", true, false)
	check(tc != null, "touch overlay present")
	if tc:
		check(tc.BUTTON_DEFS.filter(func(d): return d.id == "ping")[0].label == "สั่งงาน", "order button is captioned สั่งงาน")
		tc._press_button("ping")
		check(tc.is_ping_armed() and game.hud.alert_label.text == tc.PING_HELP, "arming Orders shows what the next tap does")
		tc._press_button("ping")

		# 0.3.4 playtest: the stack covered the vitals card once it grew mid-burn
		game.hud.vitals_card.custom_minimum_size.y = 260.0
		for i in 8:
			await process_frame
		var vit: Rect2 = game.hud.vitals_card.get_global_rect()
		check(not tc.get_stack_rect().intersects(vit), "button stack re-fits above a vitals card that grew mid-burn (%s vs %s)" % [tc.get_stack_rect(), vit])
		game.hud.vitals_card.custom_minimum_size.y = 0.0

		# Hide-panels button: the desktop Tab "minimal" mode on touch
		var hud_rect: Rect2 = tc._buttons["hud"]["rect"]
		check(hud_rect.size.y >= UITheme.TOUCH_MIN and not hud_rect.intersects(game.hud.status_card.get_global_rect()), "hide-panels button is a full touch target beside the clock card")
		tc._press_button("hud")
		for i in 4:
			await process_frame
		check(game.hud.minimal and not game.hud.vitals_card.visible and not game.hud.crew_row.visible, "hide-panels button hides the HUD panels")
		check((tc._buttons["hud"]["caption"] as Label).text == tc.HUD_HIDDEN_LABEL, "button then reads แสดงแผง")
		check(not tc.get_stack_rect().intersects(tc._buttons["hud"]["rect"]), "hide button never overlaps the action stack")
		tc._press_button("hud")
		for i in 4:
			await process_frame
		check(not game.hud.minimal and game.hud.vitals_card.visible, "pressing again restores the panels")
		check(not game.hud.tool_col.visible, "mobile keyboard tool slots stay hidden after restoring panels")

		# 0.3.6 forest-fire arrows
		var arrows: ForestFireArrows = game.hud.fire_arrows
		var park := Vector2i(fg.grid_width - 1, 1)
		check(fg.is_border_coord(park.x, park.y), "test cell is in the park ring")
		var pidx: int = fg._coord_to_index(park.x, park.y)
		fg.cell_types[pidx] = FireGrid.CellType.BURNING
		fg.active_burning_indices.append(pidx)
		check(arrows.park_fire_cells().has(park), "a burning park cell is picked up")
		arrows._refresh_left = 0.0
		for i in 3:
			await process_frame
		check(arrows.targets.size() >= 1, "an arrow or ring targets the escaped fire")
		var free: Rect2 = game.hud._arrow_bounds()
		for c in [game.hud.status_card, game.hud.crew_row, game.hud.vitals_card]:
			check(not free.intersects(c.get_global_rect()), "arrow field stays clear of %s" % c.name)
		var button_before: Rect2 = tc._buttons["hud"]["rect"]
		tc._press_button("hud")
		for i in 6:
			await process_frame
		check(arrows.visible and arrows.targets.size() >= 1, "hidden panels keep the fire arrows")
		check(tc._buttons["hud"]["rect"].position == button_before.position, "the hide button does not jump when panels hide")
		# 0.3.6 loading hint: phones paint "กำลังเตรียมแปลง…" before the hillside builds
		var hearth_scene: Node = load("res://scenes/VillageHearth.tscn").instantiate()
		root.add_child(hearth_scene)
		await process_frame
		var hint_seen := false
		hearth_scene._on_launch_pressed()
		await process_frame
		for layer in root.get_children():
			if layer is CanvasLayer and layer.layer == 100:
				hint_seen = true
		check(hint_seen, "launch paints the loading hint on phones")
		hearth_scene.queue_free()   # freed before the wait ends: the launcher must not swap scenes
		tc._press_button("hud")
		fg.cell_types[pidx] = FireGrid.CellType.FOREST_BORDER
		fg.active_burning_indices.erase(pidx)

	# G · phone Settings: no F-keys, no dead log-folder button
	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	for i in 6:
		await process_frame
	var text := all_text(settings)
	check(not text.contains("F3") and not text.contains("เปิดโฟลเดอร์บันทึกการเล่น"), "phone settings hide keyboard-only tester tools and the log folder")
	settings.queue_free()

	# D · a tap skips the checkpoint cut-scene
	change_scene_to_file("res://scenes/Checkpoint.tscn")
	for i in 3:
		await process_frame
	var cp = current_scene
	cp._t = cp.SKIP_AFTER + 0.1
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(640, 360)
	cp._unhandled_input(touch)
	check(cp._done, "a screen tap skips the checkpoint scene")
	var ending_src := FileAccess.get_file_as_string("res://ui/EndingScene.gd")
	check(ending_src.contains("InputEventScreenTouch and event.pressed) or (event is InputEventJoypadButton"), "ending skip accepts screen taps")
	for i in 4:
		await process_frame
	var am = root.get_node_or_null("AudioManager")
	if am and am.has_method("stop_all_loops"):
		am.stop_all_loops()
	for i in 4:
		await process_frame
	print("MOBILE FEEDBACK RESULT: ", failures)
	quit(1 if failures else 0)
