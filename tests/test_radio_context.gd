extends SceneTree

## Approved broadcasts must describe the current scenario, in either language.
## Uses actual accepted playback/captions without waiting for random radio timers.
var checks := 0
var failures := 0

func _initialize() -> void:
	var scratch = "user://radio_context_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	SaveGame.dir = scratch
	PlaytestLog.dir = scratch
	GameSettings.load_settings()
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS  " if ok else "FAIL  ", label)

func names(pool: Array) -> Array[String]:
	var result: Array[String] = []
	for stream in pool:
		result.append(stream.resource_path.get_file())
	return result

func expected(channel: int, year: int, plot: int) -> Array[String]:
	var result: Array[String]
	if channel == 1:
		result = ["radio_ch1_01.wav", "radio_ch1_03.wav", "radio_ch1_06.wav", "radio_ch1_07.wav", "radio_ch1_08.wav"]
		if year >= 3: result.append("radio_ch1_02.wav")
		if year >= 2: result.append("radio_ch1_04.wav")
		if year >= 4: result.append("radio_ch1_05.wav")
	else:
		result = ["radio_ch2_01.wav", "radio_ch2_02.wav", "radio_ch2_04.wav", "radio_ch2_05.wav"]
		result.append("radio_ch2_03.wav" if plot == 5 else "radio_ch2_06.wav")
	result.sort()
	return result

func _run() -> void:
	await process_frame
	seed(742321)
	var state = root.get_node("GameState")
	var audio = root.get_node("AudioManager")
	var original_state = state.to_dict().duplicate(true)
	var original_pools = audio._radio_voices.duplicate()
	var original_names = {1: names(original_pools[1]), 2: names(original_pools[2])}
	# Load after autoloads enter the tree, as this controller references GameState.
	var main_script = load("res://scripts/MainController.gd")
	check(main_script.get_script_constant_map()["DRONE_LAUNCH_MINUTE"] == 15 * 60, "approved three-PM broadcast matches actual drone launch time")
	check(audio.eligible_radio_voices(99).is_empty(), "missing radio channel returns an empty snapshot")
	for locale in ["th", "en"]:
		L10n.set_locale(locale)
		for year in range(1, 5):
			for plot in range(1, 6):
				state.current_year = year
				state.current_plot_index = plot
				var before = state.to_dict().duplicate(true)
				for channel in [1, 2]:
					var context = "%s Y%d plot%d channel%d" % [locale, year, plot, channel]
					var pool = audio.eligible_radio_voices(channel)
					var filenames = names(pool)
					check(filenames == expected(channel, year, plot), context + " has exact eligible claims and all generic broadcasts")
					# Mutating a caller's snapshot must not edit production voice pools.
					pool.clear()
					check(names(audio._radio_voices[channel]) == original_names[channel], context + " snapshot leaves original recordings intact")
					var accepted := true
					var captions := true
					var distinct := true
					var previous := ""
					var seen := {}
					for draw in 64:
						audio.play_radio_voice(channel)
						var stream: AudioStream = audio.radio_player.stream
						if not audio.radio_player.playing or stream == null:
							accepted = false
							continue
						var filename = stream.resource_path.get_file()
						accepted = accepted and filenames.has(filename) and stream.resource_path.get_base_dir() == ("res://assets/audio/en" if locale == "en" else "res://assets/audio")
						distinct = distinct and filename != previous
						previous = filename
						seen[filename] = true
						var caption: Dictionary = audio.voice_captions[filename]
						captions = captions and audio._caption_stream == stream and audio.subtitle_overlay.line_label.text == caption.th and audio.subtitle_overlay.line_label.tr(caption.th) == caption[locale] and audio.subtitle_overlay.speaker_label.tr(caption.speaker) == caption["speaker_en" if locale == "en" else "speaker"]
					check(accepted, context + " 64 accepted plays stay eligible and use selected language")
					check(captions, context + " every accepted recording has its exact spoken caption and speaker")
					check(distinct and seen.size() == filenames.size(), context + " avoids immediate repeats and reaches every eligible recording")
				check(state.to_dict() == before, "%s Y%d plot%d broadcasts preserve campaign state" % [locale, year, plot])
	# Returning to an earlier pool resumes that pool's no-repeat history.
	L10n.set_locale("th")
	state.current_year = 1
	state.current_plot_index = 1
	audio.play_radio_voice(1)
	var first: String = audio.radio_player.stream.resource_path.get_file()
	state.current_year = 4
	audio.play_radio_voice(1)
	state.current_year = 1
	audio.play_radio_voice(1)
	check(audio.radio_player.stream.resource_path.get_file() != first, "returning to a previous eligible pool preserves its own no-repeat history")
	audio.stop_all_loops()
	audio.play_bark("rally_reply")
	var crew = audio.speech_player.stream
	audio.play_radio_voice(1)
	check(audio.speech_player.playing and audio.speech_player.stream == crew and not audio.radio_player.playing, "radio filtering preserves existing busy-crew suppression")
	audio.stop_all_loops()
	audio._radio_voices[1] = [load("res://assets/audio/radio_ch1_04.wav")]
	audio.play_radio_voice(1)
	check(audio.has_radio_voice(1) and audio.eligible_radio_voices(1).is_empty() and not audio.radio_player.playing, "a present channel with only an ineligible claim stays silent without random selection")
	audio._radio_voices[1] = []
	audio.play_radio_voice(1)
	check(not audio.radio_player.playing, "empty eligible channel never attempts random selection or starts playback")
	audio._radio_voices = original_pools
	state.from_dict(original_state)
	for file in DirAccess.get_files_at(GameSettings.dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.dir))
	await create_timer(0.2).timeout
	print("Radio context: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
