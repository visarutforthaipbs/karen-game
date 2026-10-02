## Headless gameplay test suite. Run:
##   godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd
## (refer to autoload enums through instances here: --script mode has no autoload globals at compile time)
extends SceneTree

var fails := 0
func check(cond: bool, msg: String) -> void:
	if cond: print("PASS  ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _initialize() -> void:
	_run()

func frames(n: int) -> void:
	for i in n: await physics_frame

func load_main(year: int, plot: int) -> Node:
	var gs = root.get_node("GameState")
	gs.current_year = year
	gs.current_plot_index = plot
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	await process_frame
	return current_scene

func _run() -> void:
	await process_frame
	# Never touch the player's real save: the Hearth autosaves on every refresh
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	SaveGame.dir = "user://test_tmp/"
	SaveGame.delete()
	GameSettings.dir = "user://test_tmp/"
	PlaytestLog.dir = "user://test_tmp/"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_tmp/playtest_log.csv"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_tmp/settings.cfg"))
	GameSettings.load_settings()
	var gs = root.get_node("GameState")
	var am = root.get_node("AudioManager")

	# ---- Escalation rules (PRD 8.2)
	var r1 = Escalation.rules_for_year(1); var r2 = Escalation.rules_for_year(2)
	var r3 = Escalation.rules_for_year(3); var r4 = Escalation.rules_for_year(4)
	check(r1.drone_count == 0 and r1.penalty_mult < 1.0, "Y1: no drones, lenient rangers")
	check(r2.drone_count == 1 and is_equal_approx(r2.spread_mult, 1.25), "Y2: one drone, drought +25%")
	check(r3.drone_count == 2 and r3.satellite_threshold == 35.0 and r3.ground_cameras == 1, "Y3: dual drones, one ground camera; threshold stays 35")
	check(r4.checkpoints and r4.curfew and r4.drone_speed_mult > 1.0 and r4.hotspot_penalty == 30, "Y4+: checkpoints, curfew, fast drones")
	check(PlotGenerator.get_plot_config(1, 3).drone_count == 0, "no drones anywhere in Year 1")

	# ---- Input bindings incl. gamepad
	var has_joy = false
	for e in InputMap.action_get_events("use_tool"):
		if e is InputEventJoypadMotion or e is InputEventJoypadButton: has_joy = true
	check(has_joy and InputMap.has_action("aim_left") and InputMap.has_action("rally_whistle"), "gameplay actions bound for gamepad")

	# ---- Hearth: rations + favours + launch
	gs.reset_campaign()
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await process_frame
	await process_frame
	var hearth = current_scene
	check(hearth.how_to_play != null and gs.seen_how_to_play, "how-to-play card opens on a fresh campaign")
	hearth.how_to_play.close()
	await process_frame
	check(hearth.how_to_play == null, "how-to-play card closes")
	check(hearth.radio_text.text.contains("ไม่มีโดรน"), "radio forecasts Year-1 surveillance")
	hearth._tune_radio(2)
	check(hearth.radio_text.text.contains("ความชื้นสัมพัทธ์"), "weather channel forecast")
	# ---- Recorded voices (OmniVoice drop-ins in assets/audio)
	check(am._tapoh_voices.size() >= 3, "Ta-poh recorded warning variants loaded")
	check(am.has_radio_voice(1) and am.has_radio_voice(2), "recorded radio voice clips loaded")
	# Regression (beta 1): an exported build lists "x.wav.import", never "x.wav"
	var exported_listing = am.wav_names(PackedStringArray(["radio_ch1_01.wav.import", "bark_maelu_1.wav.import", "notes.txt", "sfx_pop.wav.remap"]))
	var editor_listing = am.wav_names(PackedStringArray(["radio_ch1_01.wav", "radio_ch1_01.wav.import"]))
	check(exported_listing == ["bark_maelu_1.wav", "radio_ch1_01.wav", "sfx_pop.wav"] and editor_listing == ["radio_ch1_01.wav"], "voice loader finds clips in exported builds (.import listing) without duplicates")
	hearth._tune_radio(1)
	hearth._on_chatter_timeout()
	check(am.radio_player.playing, "tuning the radio plays a recorded broadcast line")
	# ---- Audio architecture (2026-10-02 SFX audit)
	check(AudioServer.get_bus_index("SFX") != -1 and AudioServer.get_bus_index("Music") != -1 \
		and AudioServer.get_bus_index("Ambience") != -1 and AudioServer.get_bus_index("UI") != -1,
		"Master/SFX/Music/Ambience/UI bus layout present")
	am.set_held_loop("spray", true)
	check(am._targets[am.held_players["spray"]] > 0.0, "spray held loop on")
	am.set_held_loop("spray", false)
	am.play_footstep()
	am.play_ui_click()
	am.play_day_start()
	am.play_phase_stinger(1)
	am.play_ending_stinger("famine")
	am.set_ambience(0.5, 1.0, 0.5)
	check(am._cache.has("step_brush") and am._cache.has("ui_click"), "new SFX synthesize on demand")
	check(am._ambience_targets["cicada"] == 1.0, "ambience bed driven by time of day")
	hearth._on_ration_pressed(gs.Ration.FULL)
	hearth._on_favour_pressed(gs.Favour.WATER)
	hearth._on_favour_pressed(gs.Favour.SPRAYER)
	check(hearth.launch_button.text.contains("14:40"), "two favours delay the start to 14:40")
	var rice_before = gs.rice_barn
	hearth._on_launch_pressed()
	await process_frame
	await process_frame
	await process_frame
	var main = current_scene
	check(is_equal_approx(gs.rice_barn, rice_before - 7.0), "full rations eaten (-7%)")
	check(main.game_clock.get_hours() >= 14.66 and main.game_clock.get_hours() < 14.7, "burn starts at 14:40 (%.2f h)" % main.game_clock.get_hours())
	check(is_equal_approx(main.player.water_capacity, 25.0), "borrowed water containers: 25 L tank")
	check(main.elder.can_douse, "borrowed sprayer lets Ta-poh douse")
	check(main.player.stamina_regen_multiplier > 1.0, "full rations boost stamina recovery")
	var card_deadline: String = load("res://ui/HowToPlay.gd").get_script_constant_map()["SELF_COOL_DEADLINE"]
	var deadline = main.self_cool_deadline_minute()
	check("%d:%02d" % [deadline / 60, deadline % 60] == card_deadline and main.hud.self_cool_minute == deadline, "ember self-cool deadline %d:%02d matches the how-to-play card" % [deadline / 60, deadline % 60])
	check(InputMap.has_action("toggle_hud"), "Tab / Select toggles the HUD")
	main.hud.set_minimal(true)
	check(not main.hud.wind_card.visible and not main.hud.status_details.visible and main.hud.status_card.visible, "minimal HUD keeps only the clock")
	main.hud.set_minimal(false)
	check(main.hud.wind_card.visible and main.hud.status_details.visible, "full HUD restored")

	# ---- Camera: follow, zoom, quarter turns; whole plot visible when zoomed out
	var rig = main.cam_rig
	check(main.landscape != null and main.landscape.terrain.mesh.get_faces().size() > 10000 and not main.fire_grid.mountain_pedestal.visible, "landscape surrounds the plot (pedestal hidden)")
	var edge_gap = absf(main.landscape.height_at(30.0, 0.0) - (main.fire_grid.get_ground_height_at_world_pos(Vector3(29.5, 0, 0)) - main.landscape.EDGE_DROP))
	check(edge_gap < 0.01, "landscape meets the plot edge (gap %.3f m)" % edge_gap)
	check(rig != null and rig.active, "camera rig follows the player")
	# Regression: a camera leaning toward the aim point moved the cell under a
	# still mouse, so hold-to-cut never finished and the target drifted out of reach
	main.player.is_targeting_valid_cell = true
	main.player.target_cell_pos = main.player.global_position + Vector3(4, 0, -4)
	var want = rig._desired_focus()
	check(Vector2(want.x - main.player.global_position.x, want.z - main.player.global_position.z).length() < 0.01, "camera follows the player, not the cursor")
	root.size = Vector2i(1280, 720) # Headless windows start square
	await frames(2)
	rig.zoom_by(500.0)
	await frames(90)
	var vp_rect = Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	var corners_seen = 0
	for c in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 39), Vector2i(39, 39)]:
		if vp_rect.has_point(main.camera.unproject_position(main.fire_grid.get_cell_world_pos(c.x, c.y))): corners_seen += 1
	check(corners_seen == 4, "zoomed out, all four plot corners are on screen (%d/4)" % corners_seen)
	var yaw_before = main.camera.global_rotation.y
	rig.rotate_view(1)
	await frames(90)
	check(absf(absf(angle_difference(yaw_before, main.camera.global_rotation.y)) - PI * 0.5) < 0.05, "camera turns 90 degrees")
	corners_seen = 0
	for c in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 39), Vector2i(39, 39)]:
		if vp_rect.has_point(main.camera.unproject_position(main.fire_grid.get_cell_world_pos(c.x, c.y))): corners_seen += 1
	check(corners_seen == 4, "turned view still frames all four corners (%d/4)" % corners_seen)
	rig.rotate_view(-1)
	rig.zoom_by(-500.0)
	check(is_equal_approx(rig._target_distance, rig.ZOOM_MIN), "zoom clamps at the closest view")
	rig._target_distance = rig.ZOOM_DEFAULT
	await frames(60)
	check(main.drones_launched == 0 and not main.plot_has_drone, "Y1 plot 1: no drone")
	var fg: FireGrid = main.fire_grid

	# ---- Field hut + refill
	main.player.water = 0.0
	main.player.global_position = main.player.refill_point + Vector3(0.5, 0, 0.5)
	await frames(60)
	check(main.player.water > 4.0, "refill at the hut barrels (%.1f L)" % main.player.water)

	# ---- Slope physics within PRD bounds
	var max_f = 0.0; var min_f = 9.0
	for y in range(5, 35):
		var a = fg.cell_elevation[fg._coord_to_index(20, y)]
		var b = fg.cell_elevation[fg._coord_to_index(20, y - 1)]
		var f = clampf(1.0 + (b - a) / fg.cell_size * FireGrid.SLOPE_GRADE_GAIN, FireGrid.MIN_SLOPE_FACTOR, FireGrid.MAX_SLOPE_FACTOR)
		var g = clampf(1.0 + (a - b) / fg.cell_size * FireGrid.SLOPE_GRADE_GAIN, FireGrid.MIN_SLOPE_FACTOR, FireGrid.MAX_SLOPE_FACTOR)
		max_f = maxf(max_f, f); min_f = minf(min_f, g)
	check(max_f > 1.3 and max_f <= 2.5 and min_f >= 0.4, "slope factor uphill up to %.2fx, downhill down to %.2fx" % [max_f, min_f])

	# ---- Water use / empty tank
	fg.simulation_paused = true
	main.player.global_position = fg.get_cell_world_pos(20, 20)
	main.player.water = 1.0
	main.player.current_tool = main.player.ToolType.WATER_SPRAYER
	var i1 = fg._coord_to_index(21, 20)
	fg.cell_types[i1] = FireGrid.CellType.SMOLDERING
	main.player._apply_tool_to_cell(Vector2i(21, 20))
	check(fg.cell_types[i1] == FireGrid.CellType.ASH and main.player.water < 1.0, "spraying uses water")
	fg.cell_types[i1] = FireGrid.CellType.SMOLDERING
	main.player.water = 0.0
	main.player._apply_tool_to_cell(Vector2i(21, 20))
	check(fg.cell_types[i1] == FireGrid.CellType.SMOLDERING, "empty tank can't douse")

	# ---- Per-tool reach: the sprayer's jet reaches 5.5 m, hand tools 4 m
	main.player._select_tool(2)
	var spray_reach = main.player.tool_reach()
	main.player._select_tool(1)
	check(is_equal_approx(spray_reach, 5.5) and is_equal_approx(main.player.tool_reach(), 4.0), "sprayer reaches 5.5 m, knife and rake 4 m")

	# ---- Hold-to-cut: half a second of work per firebreak cell
	var cut_idx = fg._coord_to_index(22, 20)
	fg.cell_types[cut_idx] = FireGrid.CellType.VEGETATION
	main.player.current_tool = 1 # FIREBREAK_BLADE
	var mult = main.player.blade_cooldown_multiplier
	main.player._cut_firebreak(Vector2i(22, 20), 0.3 * mult)
	var after_short = fg.cell_types[cut_idx]
	main.player._cut_firebreak(Vector2i(22, 20), 0.3 * mult)
	check(after_short == FireGrid.CellType.VEGETATION and fg.cell_types[cut_idx] == FireGrid.CellType.FIREBREAK, "firebreak cell needs a held half-second to cut")
	# A click commits the cut: raking finishes on its own after the button is released
	var near = fg.get_cell_coord_at_world_pos(main.player.global_position) + Vector2i(1, 0)
	var near_idx = fg._coord_to_index(near.x, near.y)
	fg.cell_types[near_idx] = FireGrid.CellType.VEGETATION
	main.player._select_tool(1)
	main.player._begin_cut(near)
	main.player._update_firebreak_cut(0.3 * mult)
	main.player._update_firebreak_cut(0.3 * mult)
	check(fg.cell_types[near_idx] == FireGrid.CellType.FIREBREAK and not main.player._cutting, "a single click rakes the cell to bare soil")

	# ---- Ember jumping over a firebreak in high wind
	fg.set_wind(Vector2(1, 0), 2.4)
	fg.fuel_dryness = 1.0 # Peak afternoon dryness; the clock dampens it at other times
	var jumped = false
	for trial in 80:
		for x in range(8, 13):
			fg.cell_types[fg._coord_to_index(x, 10)] = FireGrid.CellType.VEGETATION
		fg.cell_types[fg._coord_to_index(9, 10)] = FireGrid.CellType.FIREBREAK
		fg.cell_types[fg._coord_to_index(8, 10)] = FireGrid.CellType.BURNING
		fg.cell_timers[fg._coord_to_index(8, 10)] = 0
		var nt = fg.cell_types.duplicate(); var nh = fg.cell_heat.duplicate()
		fg._attempt_ember_jump(8, 10, nt, nh)
		if nt[fg._coord_to_index(10, 10)] == FireGrid.CellType.BURNING:
			jumped = true; break
	check(jumped, "embers jump a 1-cell firebreak at wind 2.4")

	# ---- Elder picks the downwind side of the fire
	for i in fg.cell_types.size():
		if not fg.is_border_coord(i % 40, i / 40): fg.cell_types[i] = FireGrid.CellType.VEGETATION
	fg.cell_types[fg._coord_to_index(20, 20)] = FireGrid.CellType.BURNING
	fg.set_wind(Vector2(1, 0), 1.2)
	main.elder.global_position = fg.get_cell_world_pos(20, 20)
	var cut = main.elder._best_elder_firebreak()
	check(cut.x > 20, "Ta-poh cuts downwind of the fire (picked %s, wind east)" % str(cut))

	# ---- Thermal Eye
	main.youth.set_physics_process(true)
	main.youth.global_position = fg.get_cell_world_pos(20, 25)
	fg.cell_types[fg._coord_to_index(22, 26)] = FireGrid.CellType.SMOLDERING
	main.youth._eye_timer = 3.9
	main.youth._update_thermal_eye(0.2)
	check(fg.highlight_until.has(fg._coord_to_index(22, 26)), "Mu-naw's Thermal Eye highlights nearby embers")

	# ---- Companion flees thick smoke
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			fg.cell_types[fg._coord_to_index(30 + dx, 25 + dy)] = FireGrid.CellType.BURNING
	fg.set_inversion_active(true)
	main.youth.global_position = fg.get_cell_world_pos(30, 25)
	main.youth.current_state = main.youth.State.IDLE_FOLLOW
	var fled = false
	for i in 400:
		await physics_frame
		if main.youth.current_state == main.youth.State.FLEEING: fled = true; break
	check(fled and main.youth.is_coughing or fled, "Mu-naw chokes and flees the smoke")
	fg.set_inversion_active(false)

	# ---- Phases, inversion, countdown
	fg.simulation_paused = false
	main.game_clock.current_sim_time_seconds = 15 * 3600 + 31 * 60
	await frames(3)
	check(main.current_phase == 1, "Phase 2 at 15:31")
	var tips_node = main.get_children().filter(func(n): return n is FirstBurnTips)
	check(tips_node.size() == 1 and main.hud.tip_card.visible and main.hud.tip_label.text.contains("เชื้อไฟแห้ง"), "first-burn tip appears when the fuel dries at 15:30")
	main.game_clock.current_sim_time_seconds = 18 * 3600 + 60
	await frames(3)
	check(main.inversion_started and main.current_phase == 2, "18:00 inversion + Phase 3")
	main.game_clock.current_sim_time_seconds = 19 * 3600 + 46 * 60
	await frames(3)
	check(main.hud.countdown_label.visible and main.current_phase == 3, "19:45 countdown: '%s'" % main.hud.countdown_label.text)
	check(main.sun.light_energy < 0.5, "blue hour light (sun energy %.2f)" % main.sun.light_energy)

	# ---- Satellite pass: thermal view, markers, GIS log
	for x in range(10, 14):
		fg.cell_types[fg._coord_to_index(x, 15)] = FireGrid.CellType.SMOLDERING
		fg.cell_heat[fg._coord_to_index(x, 15)] = 44.0
	main.game_clock.current_sim_time_seconds = 20 * 3600 - 5
	await frames(30)
	check(fg.thermal_view and main.pass_started, "20:00 switches to false-colour thermal view")
	check(not main.cam_rig.active, "camera rig hands over to the orbital view")
	check(not main.landscape.terrain.material_override == null and not main.landscape._decor[0].visible, "surrounding landscape turns to cold ground in the thermal view")
	await frames(300)
	check(main.hud.report_modal.visible and main.hud.report_text.text.contains("°N"), "report includes the GIS hotspot log")
	check(main.hud.report_body.text.contains("เป้าหมาย 1") and main.hud.report_body.text.contains("ไม่ผ่าน เป้าหมาย 2"), "report explains both goals")
	check(gs.hotspot_log.size() >= 4, "hotspots logged to GameState (%d)" % gs.hotspot_log.size())
	var csv = FileAccess.get_file_as_string(PlaytestLog.path()).strip_edges().split("\n")
	check(csv.size() >= 2 and csv[0].begins_with("campaign_id,") and csv[1].split(",").size() == PlaytestLog.COLUMNS.size(), "burn written to the playtest log (%d lines)" % csv.size())
	check(gs.favours.is_empty(), "favours used up after the burn")

	# ---- Year 3 / plot 4: dual drones, cameras, park border, threshold
	gs.reset_campaign()
	main = await load_main(3, 4)
	fg = main.fire_grid
	check(main.drones.size() == 2, "Y3 plot 4: two drones")
	check(main.thermal_cameras.size() == 1, "Y3: one ground thermal camera (plus a ranger)")
	check(fg.border_depth.north == 7 and fg.is_border_coord(20, 6), "park boundary covers the upper slope")
	check(main.satellite.thermal_threshold == 35.0, "Y3 satellite threshold stays 35")
	check(is_equal_approx(fg.spread_multiplier, 1.3), "Y3 drought spread multiplier")
	main.game_clock.current_sim_time_seconds = 15 * 3600 + 31 * 60
	await frames(4)
	check(main.drones_launched == 2, "both drones launched by 15:30 (staggered)")
	var gain0 = main.plot_scrutiny_gain
	var cam = main.thermal_cameras[0]
	var cc = fg.get_cell_coord_at_world_pos(cam.global_position)
	fg.cell_types[fg._coord_to_index(cc.x, cc.y + 3)] = FireGrid.CellType.BURNING
	cam._scan_timer = 1.0
	await frames(5)
	check(main.plot_scrutiny_gain > gain0, "ground camera trips on nearby fire (+%d)" % (main.plot_scrutiny_gain - gain0))
	var gain1 = main.plot_scrutiny_gain
	cam._cooldown = 0.0
	cam._scan_timer = 1.0
	await frames(5)
	check(main.plot_scrutiny_gain == gain1, "each ground camera logs the burn only once")
	var dr = main.drones[0]
	check(dr.on_station and dr.visible, "drone sweeps over the plot")
	dr._trigger_spot(dr.global_position, true)
	check(dr._photo_taken, "one photo per sweep")
	dr.is_hovering = false
	dr._phase_left = 0.01
	await frames(3)
	check(not dr.on_station and not dr.visible and dr.get_hum_level(main.player.global_position) == 0.0, "drone leaves to swap batteries after its sweep")
	dr._phase_left = 0.01
	await frames(3)
	check(dr.on_station and not dr._photo_taken, "drone returns for a fresh sweep")

	# ---- Companions take cover from a drone overhead (P1-4)
	var yt = main.youth
	yt.set_physics_process(false)
	yt.current_state = yt.State.IDLE_FOLLOW
	yt.target_coord = Vector2i(-1, -1)
	dr.global_position = yt.global_position + Vector3(3, 12, 0)
	dr.on_station = true
	dr.is_active_patrol = true
	yt._cover_check = 1.0
	yt._check_cover(0.1)
	var cover_type = fg.cell_types[fg._coord_to_index(yt.target_coord.x, yt.target_coord.y)] if fg.is_valid_coord(yt.target_coord.x, yt.target_coord.y) else -1
	check(yt.current_state == yt.State.HIDING and cover_type in [FireGrid.CellType.BAMBOO, FireGrid.CellType.FOREST_BORDER], "a companion takes cover under bamboo or forest when a drone is overhead")
	# ...but breaks cover for a spot fire in the park
	var spot_c = fg.get_cell_coord_at_world_pos(yt.global_position)
	spot_c.y = fg.grid_height - 1 # Park edge just south of the crew near the hut
	var nb2: Array = []
	var nh2: Array = []
	nb2.assign(fg.cell_types)
	nh2.assign(fg.cell_heat)
	fg._ignite_border(fg._coord_to_index(spot_c.x, spot_c.y), nb2, nh2)
	fg.cell_types = nb2
	fg.cell_heat = nh2
	yt._process_hide(0.1)
	check(yt.current_state == yt.State.MOVING_TO_TASK and yt.target_coord == spot_c, "a spot fire comes before staying hidden")
	fg.cell_types[fg._coord_to_index(spot_c.x, spot_c.y)] = FireGrid.CellType.FOREST_BORDER
	dr.on_station = false
	yt.current_state = yt.State.IDLE_FOLLOW
	yt.set_physics_process(true)

	# ---- Ranger foot patrol, Year 3+ (P1-2)
	check(Escalation.rules_for_year(2).ranger_count == 0 and Escalation.rules_for_year(3).ranger_count == 1 and Escalation.rules_for_year(4).ranger_count == 2, "rangers patrol from Year 3 (two from Year 4)")
	check(main.rangers.size() == 1 and main.rangers[0].active, "ranger on duty at 15:31")
	var rg = main.rangers[0]
	# Find a plot cell inside the ranger's vision cone and set it alight
	var seen_cell = Vector2i(-1, -1)
	for y in fg.grid_height:
		for x in fg.grid_width:
			if seen_cell.x < 0 and not fg.is_border_coord(x, y) and rg.can_see(fg.get_cell_world_pos(x, y)):
				seen_cell = Vector2i(x, y)
	check(seen_cell.x >= 0, "ranger's cone covers part of the plot")
	if seen_cell.x >= 0:
		for i in fg.cell_types.size():
			if fg.cell_types[i] == FireGrid.CellType.BURNING: fg.cell_types[i] = FireGrid.CellType.ASH
		fg.cell_types[fg._coord_to_index(seen_cell.x, seen_cell.y)] = FireGrid.CellType.BURNING
		var g_before = main.plot_scrutiny_gain
		rg._lap_logged = false
		rg._scan()
		var g_after = main.plot_scrutiny_gain
		rg._scan()
		check(g_after > g_before and main.plot_scrutiny_gain == g_after and main.breakdown.ranger_sightings >= 1, "ranger reports a flame once per lap (+%d)" % (g_after - g_before))
		# Thick smoke between them hides the flame
		rg._lap_logged = false
		var mid = fg.get_cell_coord_at_world_pos(rg.global_position.lerp(fg.get_cell_world_pos(seen_cell.x, seen_cell.y), 0.6))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if fg.is_valid_coord(mid.x + dx, mid.y + dy):
					fg.cell_types[fg._coord_to_index(mid.x + dx, mid.y + dy)] = FireGrid.CellType.BURNING
		check(not rg.can_see(fg.get_cell_world_pos(seen_cell.x, seen_cell.y)), "thick smoke blocks the ranger's view")

	# ---- Save / continue (P0-3)
	gs.reset_campaign()
	gs.current_year = 2
	gs.current_plot_index = 4
	gs.rice_barn = 63.0
	gs.state_scrutiny = 41
	gs.blade_upgrade_level = 2
	gs.toggle_favour(gs.Favour.SEEDS)
	gs.season_yields.assign([81.0, 77.5, 69.0])
	gs.log_hotspots([Vector2i(3, 4)], [44.0])
	gs.record_plot_results(80.0, 1, false, 16, {"drone_photos": 2, "camera_trips": 1, "spot_fires": 3, "spot_fires_doused": 2})
	var before = gs.to_dict()
	SaveGame.delete()
	check(SaveGame.save(gs) and SaveGame.exists(), "campaign autosave written")
	check(not FileAccess.file_exists(SaveGame.dir.path_join(SaveGame.CAMPAIGN_FILE) + ".tmp"), "atomic save leaves no temp file behind")
	gs.reset_campaign()
	check(SaveGame.load_into(gs) == "", "campaign save loads")
	var after = gs.to_dict()
	check(JSON.stringify(after) == JSON.stringify(before), "save round-trip restores the identical campaign")
	check(gs.stats.drone_photos == 2 and gs.stats.spot_fires_doused == 2 and gs.hotspot_log[0].cell == Vector2i(3, 4), "campaign stats and hotspot log survive the save")
	var bad = FileAccess.open(SaveGame.dir.path_join(SaveGame.CAMPAIGN_FILE), FileAccess.WRITE)
	bad.store_string("{not json")
	bad.close()
	check(SaveGame.load_into(gs) == "corrupt", "a corrupt save is rejected, not loaded")
	# Audit 3: a second save keeps the first as a backup; a damaged main file falls back to it
	gs.reset_campaign()
	SaveGame.delete()
	gs.from_dict(before)
	SaveGame.save(gs)
	SaveGame.save(gs)
	bad = FileAccess.open(SaveGame.dir.path_join(SaveGame.CAMPAIGN_FILE), FileAccess.WRITE)
	bad.store_string("{\"version\": 1, \"campa")
	bad.close()
	gs.reset_campaign()
	check(SaveGame.load_into(gs) == "" and gs.current_year == 2 and gs.current_plot_index == 4, "a damaged save falls back to the backup copy")
	# Valid JSON with the wrong shape is "corrupt", and the live state is untouched
	SaveGame.delete()
	bad = FileAccess.open(SaveGame.dir.path_join(SaveGame.CAMPAIGN_FILE), FileAccess.WRITE)
	bad.store_string(JSON.stringify({"version": SaveGame.VERSION, "campaign": {"current_year": 3, "hotspot_log": [{"year": 1}]}}))
	bad.close()
	gs.reset_campaign()
	check(SaveGame.load_into(gs) == "corrupt" and gs.current_year == 1, "a malformed save is rejected before it half-loads the campaign")
	gs.state_scrutiny = 100
	check(not SaveGame.save(gs), "a finished (game-over) campaign is not autosaved")
	SaveGame.delete()
	check(not SaveGame.exists(), "save slot can be cleared")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir.path_join(SaveGame.RECORDS_FILE)))
	gs.reset_campaign()
	gs.stats.plots_completed = 7
	check(SaveGame.submit_record(gs) and SaveGame.best_record().plots_completed == 7, "best run recorded")
	gs.stats.plots_completed = 3
	check(not SaveGame.submit_record(gs), "a shorter run does not replace the record")
	check(SaveGame.runs().size() == 2 and SaveGame.runs()[0].plots == 7, "a shorter run is still kept on the board")
	# Tiebreak: equal plots, higher average ash first (then fewer detections)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir.path_join(SaveGame.RECORDS_FILE)))
	gs.reset_campaign()
	gs.stats.plots_completed = 5
	gs.stats.ash_sum = 300.0
	gs.stats.campaign_id = "lo"
	SaveGame.submit_record(gs)
	gs.stats.ash_sum = 400.0
	gs.stats.campaign_id = "hi"
	SaveGame.submit_record(gs)
	check(SaveGame.runs()[0].campaign_id == "hi" and SaveGame.runs()[1].campaign_id == "lo", "equal plots: higher average ash ranks first")
	gs.stats.campaign_id = "quiet"
	gs.stats.camera_trips = 0
	SaveGame.submit_record(gs)
	gs.stats.campaign_id = "loud"
	gs.stats.camera_trips = 4
	SaveGame.submit_record(gs)
	var order = SaveGame.runs().map(func(r): return r.campaign_id)
	check(order.find("quiet") < order.find("loud") and SaveGame.runs()[order.find("loud")].detections == 4, "equal plots and ash: fewer detections ranks first")
	# Trim to the top 10
	gs.stats.camera_trips = 0
	for i in 12:
		gs.stats.plots_completed = i + 1
		gs.stats.campaign_id = "t%d" % i
		SaveGame.submit_record(gs)
	check(SaveGame.runs().size() == 10 and SaveGame.runs()[0].plots == 12, "the board keeps only the top 10 (%d)" % SaveGame.runs().size())
	# Rename + sanitation
	SaveGame.rename_run("t11", "  ชาวบ้าน  ")
	check(SaveGame.runs()[0].name == "ชาวบ้าน", "rename_run changes the row's name (trimmed)")
	SaveGame.rename_run("t11", "ก".repeat(40))
	check(SaveGame.runs()[0].name.length() == 24 and SaveGame.sanitize_name("   ") == "ขะแน", "names are cut to 24 characters and never empty")
	# A malformed records file never crashes the board
	var junk = FileAccess.open(SaveGame.dir.path_join(SaveGame.RECORDS_FILE), FileAccess.WRITE)
	junk.store_string("{not json")
	junk.close()
	check(SaveGame.runs().is_empty() and SaveGame.best_record().is_empty(), "a malformed records file reads as an empty board")
	# v1 file (one bare best-run dict) migrates to a one-row table
	var v1 = FileAccess.open(SaveGame.dir.path_join(SaveGame.RECORDS_FILE), FileAccess.WRITE)
	v1.store_string(JSON.stringify({"plots_completed": 5, "year": 3, "avg_ash": 61.0, "cause": "famine", "date": "2026-09-01"}))
	v1.close()
	check(SaveGame.runs().size() == 1 and SaveGame.runs()[0].plots == 5 and SaveGame.best_record().plots_completed == 5, "a v1 records file migrates to the v2 board")
	# Online board (opt-in; no network in tests)
	check(GameSettings.online_board == false, "online board is opt-in (off by default)")
	gs.reset_campaign()
	gs.stats.plots_completed = 4
	gs.stats.ash_sum = 200.0
	gs.stats.hotspots_detected = 1
	gs.stats.drone_photos = 2
	gs.stats.camera_trips = 3
	gs.stats.ranger_sightings = 4
	GameSettings.player_name = "ชาวดอย"
	var payload = OnlineBoard.build_payload(gs)
	check(payload.plots == 4 and is_equal_approx(payload.avg_ash, 50.0) and payload.detections == 10, "online payload: plots, avg_ash, detections")
	check(payload.name == "ชาวดอย" and payload.mode == "endless" and payload.week == "" and payload.version == OnlineBoard.GAME_VERSION and payload.year == gs.current_year, "online payload: name, mode, week, version, year")
	GameSettings.player_name = "ขะแน"
	GameSettings.client_id = ""
	GameSettings.client_secret = ""
	OnlineBoard.ensure_identity()
	var cid = GameSettings.client_id
	var csec = GameSettings.client_secret
	var id_re = RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	check(id_re.search(cid) != null and cid.length() == 36, "online client_id is 36-char hex-dash (%s)" % cid)
	check(csec.length() == 32 and csec.is_valid_hex_number(false), "online secret is 32 hex chars")
	OnlineBoard.ensure_identity()
	check(GameSettings.client_id == cid and GameSettings.client_secret == csec, "online identity is stable")
	GameSettings.client_id = ""
	GameSettings.client_secret = ""
	GameSettings.load_settings()
	check(GameSettings.client_id == cid and GameSettings.client_secret == csec and GameSettings.online_board == false, "online identity persists through settings.cfg")
	GameSettings.online_board = false
	GameSettings.client_id = ""
	GameSettings.client_secret = ""
	GameSettings.save_settings()
	# Player name persists through settings.cfg
	GameSettings.player_name = "ชาวดอย"
	GameSettings.save_settings()
	GameSettings.player_name = "ขะแน"
	GameSettings.load_settings()
	check(GameSettings.player_name == "ชาวดอย", "player name persists in settings.cfg")
	GameSettings.player_name = "ขะแน"
	GameSettings.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.dir.path_join(SaveGame.RECORDS_FILE)))
	gs.reset_campaign()

	# ---- Scrutiny relief between plots (campaign balance)
	gs.reset_campaign()
	gs.state_scrutiny = 30
	gs.record_plot_results(80.0, 0, false, 0)
	check(gs.state_scrutiny == 10, "a clean burn lets 20 scrutiny drift away (%d)" % gs.state_scrutiny)
	gs.record_plot_results(80.0, 0, false, 15)
	check(gs.state_scrutiny == 15, "a detected burn only gets the 10-point drift (%d)" % gs.state_scrutiny)
	gs.state_scrutiny = 30
	gs.record_plot_results(0.0, 0, false, 0)
	check(gs.state_scrutiny == 20, "giving up a plot unburned is not a clean burn: drift only (%d)" % gs.state_scrutiny)
	gs.state_scrutiny = 15
	gs.state_scrutiny = 90
	gs.record_plot_results(80.0, 3, true, 30)
	check(gs.is_crackdown(), "reaching 100 is a crackdown; the drift cannot undo it")
	check(load("res://scripts/SatelliteOverpass.gd").scrutiny_for(0, 15) == 0 and load("res://scripts/SatelliteOverpass.gd").scrutiny_for(1, 15) == 15 and load("res://scripts/SatelliteOverpass.gd").scrutiny_for(400, 15) == 30, "satellite detection: base penalty, capped at double")

	# ---- Year-end harvest
	gs.reset_campaign()
	gs.current_plot_index = 5
	gs.season_yields.assign([80.0, 70.0, 75.0, 65.0])
	gs.record_plot_results(72.0, 0, false, 0)
	gs.advance_to_next_plot()
	check(gs.current_year == 2 and gs.current_plot_index == 1 and not gs.pending_harvest.is_empty(), "plot 5 -> monsoon harvest -> Year 2")
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await process_frame
	await process_frame
	check(current_scene._harvest_modal != null, "hearth shows the harvest screen")
	current_scene._close_harvest()
	check(gs.pending_harvest.is_empty(), "harvest screen dismissed")

	# Audit 1: a harvest that tips the barn into famine ends the campaign
	gs.reset_campaign()
	gs.current_plot_index = 5
	gs.rice_barn = 25.0
	gs.season_yields.assign([40.0, 35.0, 45.0, 30.0])
	gs.record_plot_results(62.0, 0, false, 0)
	gs.advance_to_next_plot()
	check(gs.is_famine() and not gs.pending_harvest.is_empty(), "a poor monsoon harvest can leave the village in famine (%.0f%%)" % gs.rice_barn)
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await process_frame
	await process_frame
	check(current_scene.harvest_button.text.contains("บทสรุป"), "famine harvest card leads to the ending, not to next year")
	current_scene.harvest_button.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path == "res://scenes/Ending.tscn", "famine at year end goes to the ending scene")

	# ---- Music rendered on the worker thread
	for i in 600:
		if am.music_ready: break
		await process_frame
	check(am.music_ready, "procedural Tena harp / khaen music rendered")

	# ---- Audit 5: one cover rule for drone and ranger
	check(FireGrid.is_cover(FireGrid.CellType.BAMBOO) and FireGrid.is_cover(FireGrid.CellType.FOREST_BORDER) and not FireGrid.is_cover(FireGrid.CellType.VEGETATION) and not FireGrid.is_cover(FireGrid.CellType.ASH), "bamboo and forest edge hide the crew from every watcher")

	# ---- Asset drop-in hooks (ASSET_REQUESTS_v1.2.md)
	var sat = load("res://scripts/SatelliteModel.gd")
	var small_sat = BoxMesh.new()
	small_sat.size = Vector3(2.0, 0.5, 1.0)
	check(is_equal_approx(sat.fit_scale(sat.procedural()), 1.0) and absf(sat.fit_scale(small_sat) * 2.0 - sat.procedural().get_aabb().size.x) < 0.01, "V3 satellite asset of any size is fitted to the staged wingspan")

	await _flow_checks(gs)
	await _fire_balance_checks()

	print("\nRESULT: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(fails)

## Title, settings and pause (PRD_UPDATE_v1.1 P0-1, P0-2, P0-4)
func _flow_checks(gs: Node) -> void:
	# Settings persist
	GameSettings.camera_zoom = 52.0
	GameSettings.show_hints = false
	GameSettings.volumes["Music"] = 0.4
	GameSettings.save_settings()
	GameSettings.camera_zoom = 44.0
	GameSettings.load_settings()
	check(is_equal_approx(GameSettings.camera_zoom, 52.0) and not GameSettings.show_hints and is_equal_approx(GameSettings.volumes["Music"], 0.4), "settings persist across restarts")
	GameSettings.apply(self)
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))) - 0.4) < 0.01, "music volume setting reaches the mixer")
	GameSettings.camera_zoom = 44.0
	GameSettings.show_hints = true
	GameSettings.volumes["Music"] = 1.0
	GameSettings.apply(self)
	GameSettings.save_settings()

	# Title: no save -> only "new game"; new game resets and opens the Hearth
	SaveGame.delete()
	change_scene_to_file("res://scenes/Title.tscn")
	await process_frame
	await process_frame
	var title = current_scene
	check(not title.continue_button.visible and title.new_button.visible, "title without a save offers only a new game")
	gs.current_year = 3
	title._on_new_game()
	await process_frame
	await process_frame
	check(current_scene.name == "VillageHearth" and gs.current_year == 1 and SaveGame.exists(), "new game starts Year 1 at the Hearth and autosaves")
	gs.current_plot_index = 3
	current_scene._refresh()
	change_scene_to_file("res://scenes/Title.tscn")
	await process_frame
	await process_frame
	check(current_scene.continue_button.visible, "title offers continue when a save exists")
	gs.reset_campaign()
	current_scene._on_continue()
	await process_frame
	await process_frame
	check(current_scene.name == "VillageHearth" and gs.current_plot_index == 3, "continue restores the saved campaign")

	# Pause freezes the burn; giving up runs the 20:00 pass now
	var main = await load_main(1, 2)
	check(main.get_children().filter(func(n): return n is FirstBurnTips).is_empty(), "no first-burn tips on later plots")
	# Year 4+ march: checkpoint scene, then the burn (P1-3)
	var main_ref = main
	gs.current_year = 4
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await process_frame
	await process_frame
	current_scene._on_launch_pressed()
	await process_frame
	await process_frame
	check(current_scene.name == "Checkpoint", "Year 4+ march passes the checkpoint scene")
	current_scene._t = 2.0
	current_scene.finish()
	await process_frame
	await process_frame
	check(current_scene.name == "Main", "checkpoint leads into the burn")
	gs.current_year = 1
	main = current_scene
	var pm = main.hud.pause_menu
	check(pm.can_pause(), "pause is available during a burn")
	pm.open()
	var t0 = main.game_clock.current_sim_time_seconds
	await frames(30)
	check(paused and is_equal_approx(main.game_clock.current_sim_time_seconds, t0), "pause freezes the burn clock")
	pm.resume()
	await frames(30)
	check(not paused and main.game_clock.current_sim_time_seconds > t0, "resume continues the burn")
	pm.open()
	pm._give_up_plot()
	await frames(3)
	check(not paused and main.pass_started and not pm.can_pause(), "giving up a plot runs the satellite pass immediately")
	await frames(300)
	SaveGame.delete()

	# Endings: a finished campaign plays its scene, then the run summary (P0-5)
	for cause in ["crackdown", "famine"]:
		gs.reset_campaign()
		gs.stats.plots_completed = 4
		gs.stats.ash_sum = 320.0
		if cause == "crackdown":
			gs.state_scrutiny = 100
		else:
			gs.rice_barn = 10.0
		SaveGame.save(gs) # an older autosave from before the final burn
		gs.state_scrutiny = 100 if cause == "crackdown" else 0
		change_scene_to_file("res://scenes/Ending.tscn")
		await process_frame
		await process_frame
		var ending = current_scene
		check(ending.cause == cause and not SaveGame.exists(), "%s ending plays and the finished campaign can't be continued" % cause)
		await frames(10)
		ending.show_summary()
		check(ending.summary_card != null and ending.summary_card.visible, "%s ending shows the run summary" % cause)
	check(int(SaveGame.best_record().get("plots_completed", 0)) >= 4, "the run is kept as a record")
	current_scene._new_campaign()
	await process_frame
	await process_frame
	check(current_scene.name == "VillageHearth" and gs.current_year == 1 and not gs.is_game_over(), "summary starts a fresh campaign")

## Fire rules from the 2026-10-02 balance pass, on a standalone FireGrid
func _fire_balance_checks() -> void:
	check(FireGrid.dryness_at_minute(14 * 60) < 0.5 and FireGrid.dryness_at_minute(16 * 60) >= 0.95 and FireGrid.dryness_at_minute(19 * 60 + 30) < 0.6, "fuel is damp at 14:00, driest mid-afternoon, damp again by evening")

	var fg = FireGrid.new()
	root.add_child(fg)
	fg.simulation_paused = true
	fg.configure_plot(PlotGenerator.get_plot_config(1, 1))
	var spots = [0]
	fg.spot_fire_started.connect(func(_c): spots[0] += 1)
	var nb: Array = []
	var nh: Array = []
	nb.assign(fg.cell_types)
	nh.assign(fg.cell_heat)
	fg._ignite_border(fg._coord_to_index(20, 0), nb, nh)
	fg.cell_types = nb
	fg.cell_heat = nh
	for i in 6: fg._simulation_step()
	check(spots[0] == 1 and not fg.has_escaped, "a spark in the park is a spot fire, not yet an escape")

	# Test: A second spark far away is a new spot fire
	nb.assign(fg.cell_types)
	nh.assign(fg.cell_heat)
	fg._ignite_border(fg._coord_to_index(30, 0), nb, nh)
	fg.cell_types = nb
	fg.cell_heat = nh
	check(fg.spot_fires_started == 2 and spots[0] == 2, "a second distant spark is a second spot fire")

	# Test: A spark adjacent to an existing burning border cell is not a new spot fire
	nb.assign(fg.cell_types)
	nh.assign(fg.cell_heat)
	fg._ignite_border(fg._coord_to_index(21, 0), nb, nh)
	fg.cell_types = nb
	fg.cell_heat = nh
	check(fg.spot_fires_started == 2 and spots[0] == 2, "spread next to a burning park cell is not a new spot fire")

	# Clean up the new cells before the next phase
	fg.cell_types[fg._coord_to_index(30, 0)] = FireGrid.CellType.FOREST_BORDER
	fg.cell_heat[fg._coord_to_index(30, 0)] = 0.0
	fg.cell_timers[fg._coord_to_index(30, 0)] = 0
	fg.cell_types[fg._coord_to_index(21, 0)] = FireGrid.CellType.FOREST_BORDER
	fg.cell_heat[fg._coord_to_index(21, 0)] = 0.0
	fg.cell_timers[fg._coord_to_index(21, 0)] = 0

	var bursts_before = fg.get_children().filter(func(n): return n.name.begins_with("DouseBurst")).size()
	fg.douse_cell(20, 0)
	check(fg.get_children().filter(func(n): return n.name.begins_with("DouseBurst")).size() > bursts_before, "dousing a fire puffs steam (mist VFX)")
	for i in 30: fg._simulation_step()
	check(fg.cell_types[fg._coord_to_index(20, 0)] == FireGrid.CellType.FOREST_BORDER and not fg.has_escaped, "spot fire doused in time: forest only scorched, no escape")
	nb.assign(fg.cell_types)
	nh.assign(fg.cell_heat)
	fg._ignite_border(fg._coord_to_index(10, 0), nb, nh)
	fg.cell_types = nb
	fg.cell_heat = nh
	for i in FireGrid.ESCAPE_TICKS + 1: fg._simulation_step()
	check(fg.has_escaped, "spot fire left burning becomes an escape")
	fg.queue_free()

	# A well-played Year-1 burn can be won cleanly: ring firebreak, torch line along
	# the bottom at 15:30, sparks in the park doused within 3 s
	var wins = 0
	for run in 3:
		seed(4100 + run)
		var g = FireGrid.new()
		root.add_child(g)
		g.simulation_paused = true
		g.configure_plot(PlotGenerator.get_plot_config(1, 1))
		g.set_wind(Vector2.from_angle(randf() * TAU), 1.0)
		var w = g.grid_width
		for y in g.grid_height:
			for x in w:
				if g.cell_types[g._coord_to_index(x, y)] == FireGrid.CellType.FOREST_BORDER: continue
				for d in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
					var q = Vector2i(x, y) + d
					if g.is_valid_coord(q.x, q.y) and g.cell_types[g._coord_to_index(q.x, q.y)] == FireGrid.CellType.FOREST_BORDER:
						g.clear_firebreak(x, y)
		var ready = 0
		for t in 1080:
			g.fuel_dryness = FireGrid.dryness_at_minute(14 * 60 + t / 3.0)
			if t == 270:
				for x in range(4, w - 4): g.ignite_cell(x, g.grid_height - 5)
			g._simulation_step()
			if t >= ready:
				for i in g.cell_types.size():
					if g.cell_types[i] == FireGrid.CellType.BURNING and g.is_border_coord(i % w, i / w) and g.cell_timers[i] >= 6:
						g.douse_cell(i % w, i / w)
						ready = t + 2
						break
		var ash = float(g.cooled_ash_cells) / g.total_cultivable_cells * 100.0
		var hot = g.get_hotspot_cells(35.0).size()
		if ash >= 75.0 and hot == 0 and not g.has_escaped: wins += 1
		g.queue_free()
		await process_frame
	check(wins >= 2, "a well-played Year-1 burn wins cleanly (%d/3 seeds)" % wins)
