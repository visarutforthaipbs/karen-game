extends SceneTree

## Touch-controls overlay regression for the iPhone/iPad landscape port.
## Run:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_touch_controls.gd -- --touch
## Real InputEventScreenTouch/Drag events are injected through
## Input.parse_input_event, exactly as the OS feeds them on device.

var fails := 0

func check(cond: bool, msg: String) -> void:
	if cond: print("PASS  ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

## Records polled one-shot edges (is_action_just_pressed), the same way
## PlayerController polls tool buttons in _physics_process.
class EdgeProbe extends Node:
	var watch: Array = []
	var seen: Dictionary = {}
	func _physics_process(_delta: float) -> void:
		for a in watch:
			if Input.is_action_just_pressed(a):
				seen[a] = int(seen.get(a, 0)) + 1

func _initialize() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func send_touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)

func send_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)

func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	# Isolated sandbox: never touch the real save / settings / playtest log.
	var sandbox := "user://test_touch_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	SaveGame.dir = sandbox
	GameSettings.dir = sandbox
	PlaytestLog.dir = sandbox
	GameSettings.load_settings()
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play = true

	# ---- activation guard (static; proves desktop stays untouched)
	var tc = load("res://scripts/TouchControls.gd")
	check(tc != null, "TouchControls script loads")
	check(not tc.should_activate(PackedStringArray(), false, false), "desktop without --touch: overlay stays off")
	check(tc.should_activate(PackedStringArray(["--touch"]), false, false), "--touch forces the overlay (headless hook)")
	check(tc.should_activate(PackedStringArray(), true, false), "touchscreen device: overlay on")
	check(tc.should_activate(PackedStringArray(), false, true), "mobile feature: overlay on")

	var probe := EdgeProbe.new()
	probe.watch = ["use_tool", "ping_companion", "cam_zoom_cycle", "cam_rotate_right", "tool_torch", "tool_blade", "tool_sprayer"]
	root.add_child(probe)

	state.current_year = 1
	state.current_plot_index = 0
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 10:
		await process_frame
	var main = current_scene
	var overlay = main.get_node_or_null("TouchControls")
	check(overlay != null and overlay is CanvasLayer, "overlay instantiated under --touch (CanvasLayer)")
	if overlay == null:
		print("TOUCH RESULT: ", fails)
		quit(1)
		return
	check(overlay.is_active(), "overlay reports active")
	var player = main.find_child("Player", true, false)
	check(player != null, "player present")
	if player == null:
		print("TOUCH RESULT: ", fails)
		quit(1)
		return
	check(player.touch_aim_active == false and player.using_gamepad_aim == false, "aim idle before any touch")
	player.set_input_enabled(true)   # MainController gates input by phase; tests drive it directly
	main.game_clock.pause_clock()

	# ---- layout: safe field, joystick zone, button targets
	var field: Rect2 = overlay.get_field_rect()
	var zone: Rect2 = overlay.get_joystick_zone_rect()
	check(field.size.x > 0.0 and field.size.y > 0.0, "safe field computed")
	check(is_equal_approx(zone.size.x, field.size.x * 0.40), "joystick zone = left 40% of the field")
	check(zone.position == field.position and is_equal_approx(zone.size.y, field.size.y), "joystick zone spans the field height")
	var torch_r: Rect2 = overlay.get_button_rect("torch")
	check(torch_r.size.x >= 88.0 and torch_r.size.y >= 88.0, "buttons are >= 88 px touch targets")
	check(field.encloses(torch_r) and field.encloses(overlay.get_button_rect("pause")), "buttons sit inside the safe field")
	check(not zone.has_point(torch_r.position), "buttons are outside the joystick zone")
	check(is_equal_approx(field.end.x - overlay.get_stack_rect().end.x, 16.0), "stack rests one 16 px margin inside the right field edge")

	# ---- joystick: press, deadzone, drag, clamp, release
	var jc: Vector2 = zone.position + zone.size * 0.5
	send_touch(0, jc, true)
	await frames(2)
	check(overlay.get_move_vector() == Vector2.ZERO, "press inside the deadzone: no movement")
	send_drag(0, jc + Vector2(105, 0), Vector2(105, 0))
	await frames(2)
	var mv: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(mv.x > 0.5, "drag right: move_right strength > 0.5 (got %.2f)" % mv.x)
	check(is_equal_approx(mv.y, 0.0), "drag right: no vertical drift")
	check(overlay.get_move_vector().x > 0.5, "API get_move_vector mirrors the input")
	send_drag(0, jc + Vector2(77, -77), Vector2(-28, -77))
	await frames(2)
	mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(mv.x > 0.2 and mv.y < -0.2, "diagonal drag moves up-right")
	send_drag(0, jc + Vector2(400, 0), Vector2(323, 77))
	await frames(2)
	mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(mv.x > 0.9, "drag past the radius clamps to full strength (got %.2f)" % mv.x)
	send_touch(0, jc + Vector2(400, 0), false)
	await frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "release clears movement")
	check(not Input.is_action_pressed("move_right"), "move_right action released on lift")

	# ---- blade button, then the world-touch test holds the blade (no fire)
	var blade_r: Rect2 = overlay.get_button_rect("blade")
	send_touch(2, blade_r.get_center(), true)
	await frames(3)
	check(int(player.current_tool) == 1, "blade button selects the firebreak blade")
	check(int(probe.seen.get("tool_blade", 0)) >= 1, "tool_blade one-shot edge polled by physics frame")
	send_touch(2, blade_r.get_center(), false)
	await frames(2)

	# ---- world touch: aim position + held use_tool
	var cam = main.get_viewport().get_camera_3d()
	check(cam != null, "camera present")
	var aim: Vector2 = cam.unproject_position(player.global_position) + Vector2(0, -40)
	if zone.has_point(aim):
		aim.x = zone.end.x + 60.0
	while overlay.is_over_button(aim):
		aim.y -= 120.0
	check(not zone.has_point(aim), "aim point lands in the right zone")
	var fg = player.fire_grid
	var coord: Vector2i = fg.raycast_cell(cam.project_ray_origin(aim), cam.project_ray_normal(aim))
	check(fg.is_valid_coord(coord.x, coord.y), "aim point targets a valid fire-grid cell")
	send_touch(1, aim, true)
	await frames(3)
	check(player.touch_aim_active, "world touch activates touch aim")
	check(Input.is_action_pressed("use_tool"), "world touch holds use_tool")
	check(int(probe.seen.get("use_tool", 0)) >= 1, "use_tool one-shot edge visible to physics polling")
	check(player.touch_aim_position.distance_to(aim) < 2.0, "touch aim position = the touch point")
	check(player.using_gamepad_aim == false, "touch aim overrides the gamepad cursor")
	check(player.is_targeting_valid_cell, "player targets a valid cell at the touch")
	send_drag(1, aim + Vector2(60, 0), Vector2(60, 0))
	await frames(3)
	check(player.touch_aim_position.distance_to(aim + Vector2(60, 0)) < 2.0, "drag updates the aim (rake a line)")
	check(Input.is_action_pressed("use_tool"), "use_tool still held while dragging")
	send_touch(1, aim + Vector2(60, 0), false)
	await frames(3)
	check(not Input.is_action_pressed("use_tool"), "lifting the aim finger releases use_tool")

	# ---- tool buttons round-trip
	for row in [["torch", 0], ["sprayer", 2], ["torch", 0]]:
		var r: Rect2 = overlay.get_button_rect(row[0])
		send_touch(3, r.get_center(), true)
		await frames(3)
		check(int(player.current_tool) == row[1], "button %s selects tool %d" % [row[0], row[1]])
		send_touch(3, r.get_center(), false)
		await frames(2)

	# ---- whistle reaches the player signal
	var whistled := [false]
	player.whistle_blown.connect(func(): whistled[0] = true)
	var w_r: Rect2 = overlay.get_button_rect("whistle")
	send_touch(4, w_r.get_center(), true)
	await frames(3)
	check(whistled[0], "whistle button blows the rally whistle")
	check(overlay.fire_count("whistle") == 1, "whistle button counts its activation")
	send_touch(4, w_r.get_center(), false)
	await frames(2)

	# ---- zoom / rotate fire their camera actions
	send_touch(5, overlay.get_button_rect("zoom").get_center(), true)
	await frames(3)
	check(int(probe.seen.get("cam_zoom_cycle", 0)) >= 1, "zoom button fires cam_zoom_cycle")
	send_touch(5, overlay.get_button_rect("zoom").get_center(), false)
	await frames(2)
	send_touch(6, overlay.get_button_rect("rotate").get_center(), true)
	await frames(3)
	check(int(probe.seen.get("cam_rotate_right", 0)) >= 1, "rotate button fires cam_rotate_right")
	send_touch(6, overlay.get_button_rect("rotate").get_center(), false)
	await frames(2)

	# ---- ping toggle: arm, then the world tap orders instead of using the tool
	var pinged := [false]
	var ping_cell := [Vector2i(-1, -1)]
	player.order_pinged.connect(func(c: Vector2i, _p: Vector3): pinged[0] = true; ping_cell[0] = c)
	var p_r: Rect2 = overlay.get_button_rect("ping")
	send_touch(7, p_r.get_center(), true)
	await frames(2)
	check(overlay.is_ping_armed(), "ping button arms the next order")
	send_touch(7, p_r.get_center(), false)
	await frames(2)
	check(overlay.is_ping_armed(), "toggle stays armed after the finger lifts")
	# The camera has turned since the earlier raycast: recompute the expected cell.
	var coord_ping: Vector2i = fg.raycast_cell(cam.project_ray_origin(aim), cam.project_ray_normal(aim))
	check(fg.is_valid_coord(coord_ping.x, coord_ping.y), "ping aim still on a valid cell after the camera moves")
	send_touch(8, aim, true)
	await frames(3)
	check(pinged[0], "world tap while armed pings the companion")
	check(ping_cell[0] == coord_ping, "ping targets the cell under the touch")
	check(not overlay.is_ping_armed(), "ping disarms after one order")
	check(not Input.is_action_pressed("use_tool"), "armed world tap never holds use_tool")
	send_touch(8, aim, false)
	await frames(2)
	# Toggle cycle: re-arm, then disarm again so later world taps use the tool.
	send_touch(9, p_r.get_center(), true)
	await frames(2)
	check(overlay.is_ping_armed(), "ping tap re-arms the toggle")
	send_touch(9, p_r.get_center(), false)
	await frames(2)
	send_touch(15, p_r.get_center(), true)
	await frames(2)
	check(not overlay.is_ping_armed(), "next ping tap disarms the toggle")
	send_touch(15, p_r.get_center(), false)
	await frames(2)

	# ---- two thumbs: joystick + aim simultaneously
	var jc2: Vector2 = zone.position + zone.size * 0.5
	send_touch(10, jc2, true)
	send_drag(10, jc2 + Vector2(105, 0), Vector2(105, 0))
	send_touch(11, aim, true)
	await frames(3)
	mv = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	check(mv.x > 0.5, "two-thumb: joystick drives movement")
	check(Input.is_action_pressed("use_tool"), "two-thumb: aim finger holds use_tool")
	check(player.touch_aim_active, "two-thumb: aim active alongside movement")
	check(overlay.get_move_vector().x > 0.5, "two-thumb: overlay move vector reflects the joystick")
	send_touch(10, jc2 + Vector2(105, 0), false)
	send_touch(11, aim, false)
	await frames(3)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "two-thumb release clears movement")
	check(not Input.is_action_pressed("use_tool"), "two-thumb release lifts use_tool")

	# ---- a finger that starts on a button never becomes an aim touch
	var aim_before: Vector2 = player.touch_aim_position
	var zoom_c: Vector2 = overlay.get_button_rect("zoom").get_center()
	send_touch(12, zoom_c, true)
	await frames(2)
	check(player.touch_aim_position.distance_to(aim_before) < 2.0, "button finger does not overwrite the aim position")
	check(not Input.is_action_pressed("use_tool"), "button finger never holds use_tool")
	send_touch(12, zoom_c, false)
	await frames(2)

	# ---- pause: the pause menu owns the screen; the overlay hides and ignores
	# touches until the burn resumes (its Resume button is ordinary GUI).
	var pz: Rect2 = overlay.get_button_rect("pause")
	send_touch(13, pz.get_center(), true)
	await create_timer(0.2).timeout
	check(paused, "pause button pauses the burn")
	send_touch(13, pz.get_center(), false)
	await frames(2)
	check(not overlay.visible, "overlay hides under the pause menu")
	send_touch(13, pz.get_center(), true)
	await create_timer(0.2).timeout
	check(paused, "hidden overlay ignores touches (pause menu owns them)")
	send_touch(13, pz.get_center(), false)
	main.hud.pause_menu.close()
	await frames(3)
	check(not paused and overlay.visible, "closing the pause menu brings the overlay back")

	# ---- iPhone playtest regressions (2026-10-12 report)
	var vitals: Rect2 = main.hud.vitals_card.get_global_rect()
	var state_rect: Rect2 = main.hud.state_card.get_global_rect()
	var clear_of_cards := true
	for id in ["torch", "blade", "sprayer", "whistle", "ping", "zoom", "rotate", "pause"]:
		var r: Rect2 = overlay.get_button_rect(id)
		if r.intersects(vitals) or r.intersects(state_rect):
			clear_of_cards = false
		if r.size.x < 88.0 or r.size.y < 88.0:
			clear_of_cards = false
	check(clear_of_cards, "P1: button stack never covers the vitals / state cards and stays >= 88 px")
	var stack: Rect2 = overlay.get_stack_rect()
	check(stack.end.x <= overlay.get_field_rect().end.x and stack.position.x > overlay.get_field_rect().size.x * 0.75, "stack hugs the right edge")
	var subs = root.get_node("AudioManager").subtitle_overlay
	subs._caption_changed("ตาโพ", "ลมเปลี่ยนทิศ", 1.0)
	await frames(2)
	check(not subs.card.get_global_rect().intersects(stack), "P2: voice captions stay clear of the button stack")
	subs._caption_changed("", "", 0.0)
	main.hud.report_modal.visible = true
	await frames(2)
	check(not overlay.visible, "P2: overlay hides over the 20:00 report")
	main.hud.report_modal.visible = false
	await frames(2)
	check(overlay.visible, "overlay returns after the report closes")
	main.pass_started = true
	await frames(2)
	check(not overlay.visible, "overlay hides during the satellite pass")
	main.pass_started = false
	await frames(2)
	check(overlay.visible, "overlay returns after the pass flag clears")

	# ---- removing the overlay never leaves a stuck action
	send_touch(14, jc2, true)
	send_drag(14, jc2 + Vector2(105, 0), Vector2(105, 0))
	await frames(2)
	check(Input.is_action_pressed("move_right"), "joystick held before overlay removal")
	overlay.free()
	await frames(2)
	check(not Input.is_action_pressed("move_right"), "removing the overlay releases movement")
	check(not Input.is_action_pressed("use_tool"), "removing the overlay releases use_tool")
	probe.free()

	print("TOUCH RESULT: ", fails)
	quit(1 if fails else 0)
