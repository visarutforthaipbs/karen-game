extends SceneTree

## Requires the complete imported English voice pack (same 30 Thai basenames).
## godot --headless --path . --script res://tests/test_voice_locales.gd
var failures: int = 0

func check(condition: bool, message: String) -> void:
	print("PASS  " if condition else "FAIL  ", message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var audio = root.get_node("AudioManager")
	var localization = root.get_node("Localization")
	var original_settings_dir = GameSettings.dir
	var original_locale: String = GameSettings.locale
	var sandbox = "user://test_voice_locales_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	GameSettings.dir = sandbox
	audio.stop_all_loops()
	var streams: Array = audio._tapoh_voices.duplicate()
	for pool in audio._radio_voices.values(): streams.append_array(pool)
	for pool in audio._bark_voices.values(): streams.append_array(pool)
	check(streams.size() == 30, "current Thai pool has all 30 known recordings")
	for stream in streams:
		var filename: String = stream.resource_path.get_file()
		var english = audio.voice_for_locale(stream, "en")
		check(english.resource_path == "res://assets/audio/en/" + filename, "English recording resolved: " + filename)
		check(audio.voice_for_locale(stream, "th").resource_path == "res://assets/audio/" + filename, "Thai recording resolved: " + filename)
		check(english.get_length() > 0.0, "English recording has valid duration: " + filename)
	# Coughs have no English dub. This models a per-clip missing-English fallback.
	var missing = load("res://assets/audio/sfx_cough_khanae.wav")
	check(not ResourceLoader.exists("res://assets/audio/en/sfx_cough_khanae.wav") and audio.voice_for_locale(missing, "en") == missing, "missing English file falls back only for that clip")
	var exported = audio.wav_names(PackedStringArray(["radio_ch1_01.wav.import", "bark_embers.wav.remap", "radio_ch1_01.wav", "README.md"]))
	check(exported == ["bark_embers.wav", "radio_ch1_01.wav"], "exported import/remap listings preserve logical recording names")
	check(ResourceLoader.exists("res://assets/audio/en/radio_ch1_01.wav"), "English voice resolves through Godot imported resource path")

	localization.set_language("en")
	audio.set_held_loop("spray", true)
	audio.set_ambience(0.5, 0.8, 0.3)
	audio.set_music_intensity(2)
	var held_target = audio._targets[audio.held_players["spray"]]
	var wind_target = audio._ambience_targets["wind"]
	var music_targets = audio._music_layer_targets.duplicate()
	audio.play_bark("rally_reply")
	check(audio.speech_player.playing and audio.speech_player.stream.resource_path.begins_with("res://assets/audio/en/"), "English locale plays English 2D crew recording")
	var english_stream = audio.speech_player.stream
	var caption: Dictionary = audio.voice_captions[english_stream.resource_path.get_file()]
	check(audio.subtitle_overlay.line_label.tr(audio.subtitle_overlay.line_label.text) == caption.en, "English voice and displayed transcript match chosen recording")
	# Settings can change language while the burn is paused; switching is synchronous.
	paused = true
	localization.set_language("th")
	check(not audio.speech_player.playing and not audio.radio_player.playing and not audio.speech_player_3d.playing and not audio.subtitle_overlay.card.visible, "paused EN-to-TH switch immediately stops only speech and captions")
	check(audio._targets[audio.held_players["spray"]] == held_target and audio._ambience_targets["wind"] == wind_target and audio._music_layer_targets == music_targets, "locale switch preserves held work, ambience and music targets")
	paused = false
	audio.play_bark("rally_reply")
	check(audio.speech_player.playing and audio.speech_player.stream.resource_path.get_base_dir() == "res://assets/audio", "same crew event can immediately replay in Thai after switch")
	caption = audio.voice_captions[audio.speech_player.stream.resource_path.get_file()]
	check(audio.subtitle_overlay.line_label.tr(audio.subtitle_overlay.line_label.text) == caption.th, "Thai voice and Thai caption match selected recording")
	localization.set_language("en")
	check(not audio.speech_player.playing and not audio.subtitle_overlay.card.visible, "TH-to-EN switch immediately clears old spoken line")
	audio.play_bark("report_flame", -2.0, Vector3.ZERO)
	check(audio.speech_player_3d.playing and audio.speech_player_3d.stream.resource_path.begins_with("res://assets/audio/en/"), "English locale plays English spatial ranger recording")
	localization.set_language("th")
	check(not audio.speech_player_3d.playing and not audio.subtitle_overlay.card.visible, "switch immediately stops spatial speech and its caption")
	audio.play_bark("report_flame", -2.0, Vector3.ZERO)
	check(audio.speech_player_3d.playing and audio.speech_player_3d.stream.resource_path.get_base_dir() == "res://assets/audio", "same spatial ranger event can immediately replay in Thai")
	audio.stop_all_loops()
	localization.set_language("en")
	audio.play_radio_voice(2)
	check(audio.radio_player.playing and audio.radio_player.stream.resource_path.begins_with("res://assets/audio/en/"), "English weather broadcast selects English recorded clip")
	localization.set_language("th")
	check(not audio.radio_player.playing and not audio.subtitle_overlay.card.visible, "locale switch immediately clears radio and caption")
	audio.play_radio_voice(2)
	check(audio.radio_player.playing and audio.radio_player.stream.resource_path.get_base_dir() == "res://assets/audio", "next weather broadcast uses Thai recording")
	audio.stop_all_loops()
	GameSettings.locale = original_locale
	L10n.set_locale(original_locale)
	GameSettings.dir = original_settings_dir
	for file in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	## Let the audio thread retire stopped playbacks before engine shutdown.
	await create_timer(0.15).timeout
	print("Voice locale failures: ", failures)
	quit(1 if failures else 0)
