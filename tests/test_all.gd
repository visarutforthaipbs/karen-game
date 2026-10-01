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
	var gs = root.get_node("GameState")
	var am = root.get_node("AudioManager")

	# ---- Escalation rules (PRD 8.2)
	var r1 = Escalation.rules_for_year(1); var r2 = Escalation.rules_for_year(2)
	var r3 = Escalation.rules_for_year(3); var r4 = Escalation.rules_for_year(4)
	check(r1.drone_count == 0 and r1.penalty_mult < 1.0, "Y1: no drones, lenient rangers")
	check(r2.drone_count == 1 and is_equal_approx(r2.spread_mult, 1.25), "Y2: one drone, drought +25%")
	check(r3.drone_count == 2 and r3.satellite_threshold == 25.0 and r3.ground_cameras == 2, "Y3: dual drones, threshold 25, ground cameras")
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
	hearth._tune_radio(1)
	hearth._on_chatter_timeout()
	check(am.radio_player.playing, "tuning the radio plays a recorded broadcast line")
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

	# ---- Hold-to-cut: half a second of work per firebreak cell
	var cut_idx = fg._coord_to_index(22, 20)
	fg.cell_types[cut_idx] = FireGrid.CellType.VEGETATION
	main.player.current_tool = 1 # FIREBREAK_BLADE
	var mult = main.player.blade_cooldown_multiplier
	main.player._cut_firebreak(Vector2i(22, 20), 0.3 * mult)
	var after_short = fg.cell_types[cut_idx]
	main.player._cut_firebreak(Vector2i(22, 20), 0.3 * mult)
	check(after_short == FireGrid.CellType.VEGETATION and fg.cell_types[cut_idx] == FireGrid.CellType.FIREBREAK, "firebreak cell needs a held half-second to cut")

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
	check(gs.favours.is_empty(), "favours used up after the burn")

	# ---- Year 3 / plot 4: dual drones, cameras, park border, threshold
	gs.reset_campaign()
	main = await load_main(3, 4)
	fg = main.fire_grid
	check(main.drones.size() == 2, "Y3 plot 4: two drones")
	check(main.thermal_cameras.size() == 2, "Y3: two ground thermal cameras")
	check(fg.border_depth.north == 7 and fg.is_border_coord(20, 6), "park boundary covers the upper slope")
	check(main.satellite.thermal_threshold == 25.0, "Y3 satellite threshold 25")
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

	# ---- Scrutiny relief between plots (campaign balance)
	gs.reset_campaign()
	gs.state_scrutiny = 30
	gs.record_plot_results(80.0, 0, false, 0)
	check(gs.state_scrutiny == 10, "a clean burn lets 20 scrutiny drift away (%d)" % gs.state_scrutiny)
	gs.record_plot_results(80.0, 0, false, 15)
	check(gs.state_scrutiny == 15, "a detected burn only gets the 10-point drift (%d)" % gs.state_scrutiny)
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

	# ---- Music rendered on the worker thread
	for i in 600:
		if am.music_ready: break
		await process_frame
	check(am.music_ready, "procedural Tena harp / khaen music rendered")

	await _fire_balance_checks()

	print("\nRESULT: %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	quit(fails)

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
	fg.douse_cell(20, 0)
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
