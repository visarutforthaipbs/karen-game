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
	check(mat.albedo_color.a >= 0.7 and mat.no_depth_test, "touch marker is opaque enough and drawn over brush")
	var frames := ind.get_children().filter(func(n): return n.name.begins_with("IndicatorFrame"))
	check(frames.size() == 4, "touch marker has a dark 4-sided frame (%d)" % frames.size())

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
