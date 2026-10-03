extends SceneTree
## Run this external script against an exported PCK from an empty directory.
## It never writes player settings or campaign data.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ok := FileAccess.file_exists("res://localization/messages.json") and FileAccess.file_exists("res://localization/voice_subtitles.json")
	var helper = load("res://scripts/L10n.gd")
	helper.set_locale("en")
	ok = ok and str(TranslationServer.translate("ตั้งค่า")) == "Settings"
	var audio = root.get_node("AudioManager")
	ok = ok and audio.voice_captions.size() == 30 and not audio._radio_voices.is_empty()
	# Prove English resources resolve from the pack, including .import/remap assets.
	for filename in audio.voice_captions:
		var thai = load("res://assets/audio/" + filename)
		var english = audio.voice_for_locale(thai, "en")
		ok = ok and english.resource_path == "res://assets/audio/en/" + filename and english.get_length() > 0.0
	audio.play_radio_voice(1)
	ok = ok and audio.radio_player.playing and audio.radio_player.stream.resource_path.begins_with("res://assets/audio/en/")
	audio.stop_all_loops()
	var settings = load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await process_frame
	ok = ok and settings.language_picker.item_count == 2
	print("EXPORTED PACK LOCALIZATION: ", "PASS" if ok else "FAIL")
	settings.queue_free()
	await process_frame
	# Give the audio thread time to retire the stopped export-probe playback.
	await create_timer(0.2).timeout
	quit(0 if ok else 1)
