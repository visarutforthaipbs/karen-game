extends SceneTree
## Save recovery and campaign-boundary regression tests.
## All disk writes use a unique scratch user folder; no online scores are submitted.
var failures := 0
var passes := 0
var sandbox: String
var state: Node

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		print("FAIL ", label)

func frames(n := 6) -> void:
	for i in n:
		await process_frame

func write_fixture(path: String, payload: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()

func run() -> void:
	await process_frame
	sandbox = "user://save_recovery_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	SaveGame.dir = sandbox
	GameSettings.dir = sandbox
	PlaytestLog.dir = sandbox
	GameSettings.load_settings()
	GameSettings.online_board = false
	state = root.get_node("GameState")
	root.size = Vector2i(1280, 720)
	# Complete a season normally, save the pending harvest, restart into the Hearth.
	state.reset_campaign()
	state.seen_how_to_play = true
	state.current_year = 3
	state.current_plot_index = 5
	state.rice_barn = 70.0
	state.state_scrutiny = 63
	state.season_yields.assign([70.0, 75.0, 80.0, 85.0])
	state.record_plot_results(90.0, 0, false, 0)
	state.advance_to_next_plot()
	check(state.current_year == 4 and state.current_plot_index == 1, "season rolls into Year 4/plot 1")
	check(state.pending_harvest.yields.size() == 5 and is_equal_approx(state.pending_harvest.average, 80.0), "pending harvest retains all five yields")
	var barn_after_harvest: float = state.rice_barn
	check(SaveGame.save(state), "pending harvest saves")
	state.reset_campaign()
	check(SaveGame.load_into(state) == "" and not state.pending_harvest.is_empty(), "pending harvest restores before scene transition")
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await frames()
	var hearth = current_scene
	check(is_instance_valid(hearth.harvest_button), "restored Hearth shows annual harvest action")
	hearth._close_harvest()
	await frames()
	check(state.pending_harvest.is_empty(), "harvest close clears pending state")
	check(is_equal_approx(state.rice_barn, barn_after_harvest), "harvest acknowledgement does not apply rice twice")
	state.reset_campaign()
	check(SaveGame.load_into(state) == "" and state.pending_harvest.is_empty(), "acknowledged harvest remains cleared after reload")
	state.ration_level = GameState.Ration.NORMAL
	var before_launch: float = state.rice_barn
	hearth._on_launch_pressed()
	await frames()
	check(current_scene.name == "Checkpoint", "Year 4 launch enters checkpoint")
	check(is_equal_approx(state.rice_barn, before_launch - 3.0), "rations charged once on launch")
	current_scene.finish()
	await frames()
	check(current_scene.name == "Main", "checkpoint finishes into gameplay")
	check(is_equal_approx(state.rice_barn, before_launch - 3.0), "checkpoint does not charge rations again")
	root.get_node("AudioManager").stop_all_loops()
	current_scene.queue_free()
	await frames(2)
	# Normal new-campaign boundary: the prior campaign's last-burn summary must reset.
	state.record_plot_results(87.0, 2, true, 20)
	state.last_rice_change = -25.0
	state.last_barn_target = 65.0
	state.last_scrutiny_relief = 12
	state.last_breakdown = {"drone": 12}
	state.seen_how_to_play = true
	state.reset_campaign()
	check(state.last_burn_yield == 0.0 and state.last_burn_hotspots == 0 and not state.last_burn_escaped and state.last_rice_change == 0.0 and state.last_barn_target == 75.0 and state.last_scrutiny_relief == 0, "new campaign clears previous campaign last-burn summary")
	check(not state.seen_how_to_play and state.last_breakdown.is_empty(), "new campaign resets contextual tutorial flag and source breakdown")
	state.seen_how_to_play = true
	change_scene_to_file("res://scenes/VillageHearth.tscn")
	await frames()
	print("NEW_CAMPAIGN_GRANARY=", current_scene.granary_label.text)
	check(not current_scene.granary_label.text.contains("87%"), "Year 1 granary never displays the previous campaign's 87% burn")
	current_scene.queue_free()
	await frames(2)
	# Syntactically valid damaged main save should fail validation and use valid backup.
	SaveGame.delete()
	state.reset_campaign()
	state.current_year = 2
	state.current_plot_index = 4
	SaveGame.save(state)
	SaveGame.save(state)
	var campaign_path = sandbox.path_join(SaveGame.CAMPAIGN_FILE)
	var data = JSON.parse_string(FileAccess.get_file_as_string(campaign_path))
	data.campaign.ration_level = 99
	var file = FileAccess.open(campaign_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	state.reset_campaign()
	var reason = SaveGame.load_into(state)
	print("INVALID_RATION_LOAD reason=", reason, " ration=", state.ration_level, " year=", state.current_year)
	check(not SaveGame.valid_campaign(data.campaign), "invalid ration enum is rejected before touching state")
	check(reason == "" and state.ration_level == GameState.Ration.NORMAL and state.current_year == 2 and state.current_plot_index == 4, "invalid ration main recovers the valid backup")
	var safe_campaign: Dictionary = state.to_dict().duplicate(true)
	for entry in [["current_year", 2.5], ["current_plot_index", 1.5], ["ration_level", -1], ["ration_level", 3], ["ration_level", 0.5], ["blade_upgrade_level", -1], ["blade_upgrade_level", 4], ["blade_upgrade_level", 1.5], ["sprayer_upgrade_level", -1], ["sprayer_upgrade_level", 4], ["sprayer_upgrade_level", 1.5], ["favours", [-1]], ["favours", [3]], ["favours", [1.5]]]:
		var invalid = safe_campaign.duplicate(true)
		invalid[entry[0]] = entry[1]
		check(not SaveGame.valid_campaign(invalid), "invalid %s=%s rejected" % entry)
		write_fixture(campaign_path + ".bak", {"version": SaveGame.VERSION, "campaign": safe_campaign})
		write_fixture(campaign_path, {"version": SaveGame.VERSION, "campaign": invalid})
		state.reset_campaign()
		check(SaveGame.load_into(state) == "" and JSON.stringify(state.to_dict()) == JSON.stringify(safe_campaign), "invalid %s=%s restores the exact valid backup" % entry)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign_path + ".bak"))
		state.reset_campaign()
		var untouched = state.to_dict().duplicate(true)
		check(SaveGame.load_into(state) == "corrupt" and state.to_dict() == untouched, "invalid %s=%s with no backup never partially mutates state" % entry)
	for ration in [0, 1, 2]:
		var valid = safe_campaign.duplicate(true)
		valid.ration_level = ration
		valid.blade_upgrade_level = 3
		valid.sprayer_upgrade_level = 3
		valid.favours = [0, 1, 2]
		check(SaveGame.valid_campaign(valid), "legitimate ration %d with maximum upgrades/all favours accepted" % ration)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign_path + ".bak"))
	write_fixture(campaign_path, data)
	state.reset_campaign()
	var unchanged = state.to_dict().duplicate(true)
	check(SaveGame.load_into(state) == "corrupt" and state.to_dict() == unchanged, "invalid ration without backup rejects atomically without partially loading state")
	# Unsupported or malformed versions must preserve the live state and both
	# source files. Deliberately never downgrade to an older backup on "version".
	for version in [{}, [], "1", null, true, 1.5, 2, 0]:
		write_fixture(campaign_path + ".bak", {"version": SaveGame.VERSION, "campaign": safe_campaign})
		write_fixture(campaign_path, {"version": version, "campaign": safe_campaign})
		var main_before = FileAccess.get_file_as_string(campaign_path)
		var backup_before = FileAccess.get_file_as_string(campaign_path + ".bak")
		state.reset_campaign()
		var untouched = state.to_dict().duplicate(true)
		check(SaveGame.load_into(state) == "version" and state.to_dict() == untouched, "version %s refuses load/fallback without live-state mutation" % str(version))
		check(FileAccess.get_file_as_string(campaign_path) == main_before and FileAccess.get_file_as_string(campaign_path + ".bak") == backup_before, "version %s preserves both save files" % str(version))
	for version in [1, 1.0]:
		write_fixture(campaign_path, {"version": version, "campaign": safe_campaign})
		state.reset_campaign()
		check(SaveGame.load_into(state) == "" and JSON.stringify(state.to_dict()) == JSON.stringify(safe_campaign), "ordinary numeric version %s reloads the exact campaign" % str(version))
	# In-memory non-finite values cannot be emitted as standard JSON. Validate
	# them directly, then exercise disk recovery with legal JSON exponent overflow.
	for value in [INF, -INF, NAN]:
		var invalid = safe_campaign.duplicate(true)
		invalid.rice_barn = value
		check(not SaveGame.valid_campaign(invalid), "non-finite rice %s rejected" % str(value))
	for entry in [["season_yields", [INF]], ["stats", {"ash_sum": NAN}], ["favours", [INF]]]:
		var invalid = safe_campaign.duplicate(true)
		invalid[entry[0]] = entry[1]
		check(not SaveGame.valid_campaign(invalid), "non-finite nested %s rejected" % entry[0])
	for entry in [["rice_barn", "overflow"], ["season_yields", ["overflow"]], ["stats", {"ash_sum": "overflow"}]]:
		var invalid = safe_campaign.duplicate(true)
		invalid[entry[0]] = entry[1]
		var overflow_json = JSON.stringify({"version": SaveGame.VERSION, "campaign": invalid}).replace('"overflow"', "1e999")
		write_fixture(campaign_path + ".bak", {"version": SaveGame.VERSION, "campaign": safe_campaign})
		file = FileAccess.open(campaign_path, FileAccess.WRITE)
		file.store_string(overflow_json)
		file.close()
		state.reset_campaign()
		check(SaveGame.load_into(state) == "" and JSON.stringify(state.to_dict()) == JSON.stringify(safe_campaign), "overflow %s recovers the exact finite backup" % entry[0])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign_path + ".bak"))
		state.reset_campaign()
		var untouched = state.to_dict().duplicate(true)
		check(SaveGame.load_into(state) == "corrupt" and state.to_dict() == untouched, "overflow %s without backup rejects atomically" % entry[0])
	# Truncated JSON is quietly rejected and still follows ordinary backup rules.
	write_fixture(campaign_path + ".bak", {"version": SaveGame.VERSION, "campaign": safe_campaign})
	file = FileAccess.open(campaign_path, FileAccess.WRITE)
	file.store_string('{"version":1,"campaign":')
	file.close()
	state.reset_campaign()
	check(SaveGame.load_into(state) == "" and JSON.stringify(state.to_dict()) == JSON.stringify(safe_campaign), "truncated campaign JSON recovers finite backup without script error")
	# The board uses the same atomic writer, so a crash between its two renames leaves .bak.
	state.reset_campaign()
	state.stats.campaign_id = "board-original"
	state.stats.plots_completed = 12
	state.stats.ash_sum = 960.0
	SaveGame.submit_record(state)
	state.stats.campaign_id = "board-second"
	state.stats.plots_completed = 4
	SaveGame.submit_record(state)
	var records_path = sandbox.path_join(SaveGame.RECORDS_FILE)
	check(FileAccess.file_exists(records_path + ".bak"), "board writer retains a valid backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(records_path))
	var recovered = SaveGame.runs()
	print("BOARD_BACKUP_RECOVERY rows=", recovered.size())
	check(not recovered.is_empty() and recovered[0].campaign_id == "board-original", "interrupted board rename recovers previous records from .bak")
	file = FileAccess.open(records_path, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	recovered = SaveGame.runs()
	check(not recovered.is_empty() and recovered[0].campaign_id == "board-original", "wrong-shaped records main recovers valid board backup")
	file = FileAccess.open(records_path, FileAccess.WRITE)
	file.store_string('{"runs":')
	file.close()
	recovered = SaveGame.runs()
	check(not recovered.is_empty() and recovered[0].campaign_id == "board-original", "truncated records JSON recovers board backup without script error")
	file = FileAccess.open(records_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveGame.RECORDS_VERSION, "runs": []}))
	file.close()
	check(SaveGame.runs().is_empty(), "valid empty board does not resurrect old backup records")
	# Legacy v1 best-run records still migrate on first read.
	file = FileAccess.open(records_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"plots_completed": 7, "year": 2, "avg_ash": 82.0, "cause": "famine", "date": "2026-10-01"}))
	file.close()
	var legacy = SaveGame.runs()
	check(legacy.size() == 1 and legacy[0].plots == 7 and legacy[0].year == 2 and legacy[0].name == SaveGame.DEFAULT_NAME, "supported v1 record migrates with its historical score/name")
	var migrated = JSON.parse_string(FileAccess.get_file_as_string(records_path))
	check(migrated.version == SaveGame.RECORDS_VERSION and migrated.runs.size() == 1, "v1 migration writes a durable v2 records table")
	check(SaveGame.runs().size() == 1 and SaveGame.runs()[0].plots == 7, "repeat reads do not duplicate the migrated record")
	root.get_node("AudioManager").stop_all_loops()
	for filename in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	print("Save recovery tests: %d passed, %d failures" % [passes, failures])
	quit(1 if failures else 0)
