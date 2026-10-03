extends SceneTree
var fails := 0
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: fails += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var a = root.get_node("AudioManager")
	a.set_process(false)
	a.set_radio_static(0.45)
	a.set_siren(true)
	a.play_radio_voice(1)
	a.stop_all_loops()
	a._process(0.016)
	check(not a.radio_player.playing and not a._siren_on and is_zero_approx(a._targets[a.static_player]), "scene reset clears broadcast, static and siren duck")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Drones")) == "SFX" and AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) == "SFX", "SFX control includes drones and UI")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("RadioFilter")) == "RadioVoice", "radio processing respects speech control")
	a.play_tapoh_warning()
	check(a.speech_player.playing and a.speech_player.bus == "RadioVoice", "Ta-poh uses protected dry speech channel")
	var first_stream_id: int = a.speech_player.stream.get_instance_id()
	a.play_bark("maelu")
	check(a.speech_player.stream.get_instance_id() == first_stream_id, "nonurgent line cannot interrupt danger warning")
	for i in 40:
		a._play_at("test_foot_%d" % i, a._step_brush, Vector3.ZERO, 1.0, -6.0, 0)
	check(a.speech_player.playing and a.speech_player.stream.get_instance_id() == first_stream_id, "footstep pool exhaustion cannot steal speech")
	a.stop_all_loops()
	a.play_bark("report_flame", -2.0, Vector3.ZERO)
	check(a.speech_player_3d.playing and a.speech_player_3d.bus == "RadioFilter", "positional ranger speech has radio filtering")
	a.stop_all_loops()
	# Delayed callbacks are invalidated across transitions.
	a.play_ranger_report_at(Vector3.ZERO, true)
	a.stop_all_loops()
	await create_timer(0.4).timeout
	check(not a.speech_player_3d.playing, "old scene's delayed ranger report stays cancelled")
	if ResourceLoader.exists("res://assets/audio/music_states.tres"):
		a._state_music = true
		a.set_music_intensity(3)
		check(a._music_layer_targets == [0.0, 0.0, 0.32], "deadline selects complete track instead of stacking independent music")
		check(a._variant_streams.get("step_brush", []).size() >= 4 and a._variant_streams.get("step_ash", []).size() >= 4, "multi-take footsteps loaded")
		var previous: int = a._stream_for("step_brush", a._step_brush).get_instance_id()
		var next: int = a._stream_for("step_brush", a._step_brush).get_instance_id()
		check(previous != next, "footstep bank avoids immediate repeats")
	var grid = FireGrid.new()
	grid.grid_width = 3
	grid.grid_height = 3
	grid.cell_types.resize(9)
	grid.cell_timers.resize(9)
	grid.cell_heat.resize(9)
	grid.cell_was_bamboo.resize(9)
	grid.cell_elevation.resize(9)
	grid.cell_elevation.fill(0.0)
	grid.cell_types.fill(FireGrid.CellType.FOREST_BORDER)
	grid.cell_timers.fill(0)
	grid.cell_heat.fill(0.0)
	grid.cell_was_bamboo.fill(false)
	grid.cell_types[0] = FireGrid.CellType.BURNING
	var events: Array = []
	grid.spot_fire_extinguished.connect(func(coord): events.append(coord))
	# Unparented grid skips display construction; the douse method remains authoritative.
	grid.douse_cell(0, 0)
	check(events == [Vector2i.ZERO] and grid.cell_types[0] == FireGrid.CellType.FOREST_BORDER, "success cue emitted once for a protected-forest spot fire")
	grid.douse_cell(0, 0)
	check(events.size() == 1, "repeat spraying an extinguished cell cannot repeat success cue")
	grid.free()
	a.stop_all_loops()
	a.fire_diagnostics = true
	a.stop_all_loops()
	a.fire_warning_log.clear()
	for i in 20: a.play_bark("embers")
	check(a.fire_warning_log.filter(func(e): return e.accepted).size() == 1, "20 ember events accept one family warning")
	var generic_id: int = a.speech_player.stream.get_instance_id()
	for i in 20: a.play_spot_fire()
	check(a.fire_warning_log.filter(func(e): return e.accepted).size() == 2 and a._fire_voice_severity == 2, "one protected-forest escalation, no repeated interruption")
	check(a.speech_player.stream.get_instance_id() != generic_id, "protected-forest warning supersedes generic ember")
	var alarm_time: int = a._fire_alarm_last
	a.play_spot_fire()
	check(a._fire_alarm_last == alarm_time, "burst alarm coalesces")
	a.speech_player.stop()
	a.play_bark("embers")
	check(not a.speech_player.playing, "family cooldown persists after clip finishes")
	a._fire_voice_last -= 8001
	a._speech_last["embers"] = -100000
	a.play_bark("embers")
	check(a.speech_player.playing, "fresh threat after interval can speak")
	a.stop_all_loops()
	check(a._fire_voice_severity == 0 and a._fire_alarm_last == -100000, "scene reset clears warning family")
	# Allow the audio thread to release stopped spatial playbacks before exit.
	OS.delay_msec(120)
	await process_frame
	print("Audio regression failures: ", fails)
	quit(1 if fails else 0)
