## Fire balance probe (not part of test_all). Run: godot --headless --path . --script res://tests/balance_sim.gd (~4 min)
## Headless balance probe: drives FireGrid's real CA with scripted strategies.
## 1 tick = 0.5 s real = 20 s in-game. 14:00 -> 20:00 = 1080 ticks.
extends SceneTree

const TICKS_PER_GAME_MIN = 3.0
var only_case = []

func _initialize() -> void:
	await process_frame
	var cases = [[1, 1], [1, 2], [1, 3], [2, 5]]
	var strategies = ["pray_c_1530", "ring_line_1400", "ring_line_1530", "ring_line_1530_resp", "ring_c_1530_resp", "ring_line_1700_resp"]
	for c in cases:
		for s in strategies:
			var runs = 8
			var esc = 0; var spots = 0; var yield_sum = 0.0; var burned_sum = 0.0; var hot_sum = 0; var t90s = []; var douses = 0
			for r in runs:
				var res = run_burn(c[0], c[1], s, 2000 + r)
				if res.escaped: esc += 1
				spots += res.spots
				yield_sum += res.yield
				burned_sum += res.burned
				hot_sum += res.hotspots
				douses += res.douses
				if res.t90 > 0: t90s.append(res.t90)
			var t90txt = "never" if t90s.is_empty() else "%d min (%d/%d runs)" % [int(t90s.reduce(func(a, b): return a + b) / t90s.size()), t90s.size(), runs]
			print("Y%d P%d %-20s escape %d/%d spots %4.1f doused %4.1f | burned %5.1f%% ash %5.1f%% hot@20:00 %5.1f | 90%% burned after %s" % [c[0], c[1], s, esc, runs, float(spots) / runs, float(douses) / runs, burned_sum / runs, yield_sum / runs, float(hot_sum) / runs, t90txt])
	quit()

func run_burn(year: int, plot: int, strategy: String, seed_v: int) -> Dictionary:
	seed(seed_v)
	var cfg = PlotGenerator.get_plot_config(year, plot)
	var fg = FireGrid.new()
	root.add_child(fg)
	fg.simulation_paused = true
	fg.configure_plot(cfg)
	var spots = [0]
	fg.spot_fire_started.connect(func(_c): spots[0] += 1)
	var angle = randf() * TAU
	fg.set_wind(Vector2(cos(angle), sin(angle)), cfg.wind_base_speed)
	var w = fg.grid_width; var h = fg.grid_height
	if strategy.begins_with("ring"):
		for y in h:
			for x in w:
				if fg.cell_types[fg._coord_to_index(x, y)] == FireGrid.CellType.FOREST_BORDER:
					continue
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if fg.is_valid_coord(x + dx, y + dy) and fg.cell_types[fg._coord_to_index(x + dx, y + dy)] == FireGrid.CellType.FOREST_BORDER:
							fg.clear_firebreak(x, y)
	var light_min = 0
	if strategy.contains("1530"): light_min = 90
	if strategy.contains("1700"): light_min = 180
	var light_tick = int(light_min * TICKS_PER_GAME_MIN)
	var respond = strategy.ends_with("resp")
	var next_shift = randi_range(100, 170)
	var t90 = -1
	var douses = 0
	var douse_ready = 0
	var total = fg.total_cultivable_cells
	for t in 1080:
		fg.fuel_dryness = FireGrid.dryness_at_minute(14 * 60 + t / TICKS_PER_GAME_MIN)
		if t == light_tick:
			if strategy.contains("_line_"):
				# Drip-torch line along the bottom (south) of the plot: headfire runs uphill
				var row = h - fg.border_depth.south - 3
				for x in range(fg.border_depth.west + 2, w - fg.border_depth.east - 2):
					fg.ignite_cell(x, row)
			else:
				fg.ignite_cell(w / 2, h / 2)
		if t == next_shift:
			var a = randf() * TAU
			fg.set_wind(Vector2(cos(a), sin(a)), randf_range(0.7, 1.4) * cfg.wind_base_speed)
			next_shift += randi_range(100, 170)
		fg._simulation_step()
		# Crew response: one douse per 2 ticks on any park spot fire older than 3 s
		if respond and t >= douse_ready:
			for i in fg.cell_types.size():
				if fg.cell_types[i] == FireGrid.CellType.BURNING and fg.is_border_coord(i % w, i / w) and fg.cell_timers[i] >= 6:
					fg.douse_cell(i % w, i / w)
					douses += 1
					douse_ready = t + 2
					break
		if t90 < 0 and t > light_tick and t % 3 == 0:
			var burned = 0
			for i in fg.cell_types.size():
				var ty = fg.cell_types[i]
				if not fg.is_border_coord(i % w, i / w) and (ty == FireGrid.CellType.BURNING or ty == FireGrid.CellType.SMOLDERING or ty == FireGrid.CellType.ASH):
					burned += 1
			if burned >= total * 0.8:
				t90 = int((t - light_tick) / TICKS_PER_GAME_MIN)
	var burned_end = 0
	for i in fg.cell_types.size():
		var ty = fg.cell_types[i]
		if not fg.is_border_coord(i % w, i / w) and (ty == FireGrid.CellType.SMOLDERING or ty == FireGrid.CellType.ASH or ty == FireGrid.CellType.BURNING):
			burned_end += 1
	var res = {
		"escaped": fg.has_escaped,
		"spots": spots[0],
		"douses": douses,
		"yield": float(fg.cooled_ash_cells) / float(total) * 100.0,
		"burned": float(burned_end) / float(total) * 100.0,
		"hotspots": fg.get_hotspot_cells(cfg.rules.satellite_threshold).size(),
		"t90": t90,
	}
	fg.queue_free()
	return res
