extends SceneTree

## First-run persistence, replay isolation, navigation, localization and audio.
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()
	create_timer(45.0).timeout.connect(func():
		push_error("Opening test watchdog: unfinished test")
		quit(1))

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS  " if ok else "FAIL  ", label)

func settle() -> void:
	for i in 8:
		await process_frame

func inside(control: Control) -> bool:
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(control.get_global_rect())

func _run() -> void:
	await process_frame
	var settings_dir = GameSettings.dir
	var save_dir = SaveGame.dir
	var sandbox = "user://opening_test_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sandbox))
	GameSettings.dir = sandbox
	SaveGame.dir = sandbox
	GameSettings.load_settings()
	root.size = Vector2i(1280, 720)
	var state = root.get_node("GameState")
	var old_state: Dictionary = state.to_dict().duplicate(true)
	var audio = root.get_node("AudioManager")
	check(not GameSettings.intro_seen, "fresh profile has unseen introduction")
	var opener = Button.new()
	root.add_child(opener)
	opener.grab_focus()
	var film = OpeningFilm.new()
	film.remember_completion = true
	root.add_child(film)
	await settle()
	check(film.voice.bus == "RadioVoice" and film.music.bus == "Music" and film.scan_music.bus == "Music" and film.ambience.bus == "Ambience" and film.insects.bus == "Ambience", "all introduction layers respect existing volume buses")
	check(film.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and film.scan_music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and film.ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and film.insects.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music, wind and forest insects loop across the film")
	check(audio.process_mode == Node.PROCESS_MODE_DISABLED and opener.focus_mode == Control.FOCUS_NONE, "film suspends underlying scene audio and focus")
	var voice_gain = film.voice.volume_db
	film._mix_background(3.0)
	var ducked_music = film.music.volume_db
	check(ducked_music > -12 and ducked_music < -10 and film.ambience.volume_db > -12, "background is audible and restrained beneath narration")
	film.voice.stop()
	film._mix_background(3.0)
	check(film.music.volume_db > ducked_music + 3 and film.voice.volume_db == voice_gain, "music rises between sentences without processing the dry voice")
	film._start_cue(6)
	film._mix_background(3.0)
	check(film.scan_music.volume_db > -14 and film.music.volume_db < -45 and film.insects.volume_db < -45, "satellite scan replaces warm music and insects with a restrained pulse")
	film._start_cue(0)
	film._mix_background(3.0)
	check(film.music.volume_db > -12 and film.scan_music.volume_db < -45 and film.insects.volume_db > -13, "warm mountain background returns after the scan")
	for locale in ["th", "en"]:
		root.get_node("Localization").set_language(locale)
		for cue in film.story.cues.size():
			film._start_cue(cue)
			check(film.voice.stream != null and film.voice.stream.get_length() > 1.0, "%s cue %d has recorded narration" % [locale, cue])
			check(film.cue_duration >= film.voice.stream.get_length() + 0.6, "%s cue %d cannot truncate narration" % [locale, cue])
			check(film.subtitle.tr(film.subtitle.text) == film.story.cues[cue][locale], "%s cue %d subtitle matches spoken script" % [locale, cue])
	check(film.work_sound.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and (load("res://assets/audio/sfxloop_spray.wav") as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "work sound loops without changing the shared source resource")
	film.toggle_pause()
	var seconds = film.cue_seconds
	var paused_music_gain = film.music.volume_db
	film._process(5.0)
	check(film.cue_seconds == seconds and film.voice.stream_paused and film.work_sound.stream_paused and film.music.stream_paused and film.scan_music.stream_paused and film.ambience.stream_paused and film.insects.stream_paused and film.music.volume_db == paused_music_gain, "pause freezes animation, narration and every background layer")
	root.get_node("Localization").set_language("th")
	check(film.film_paused and film.cue_seconds == 0 and film.voice.stream_paused, "language change restarts just the sentence and preserves pause")
	check(state.to_dict() == old_state, "watching and changing language never changes campaign state")
	film.close()
	check(film.music.stream == null and film.scan_music.stream == null and film.ambience.stream == null and film.insects.stream == null, "closing releases every background stream")
	film.close()
	await settle()
	check(GameSettings.intro_seen, "skipping records introduction as seen")
	GameSettings.load_settings()
	check(GameSettings.intro_seen, "seen state survives settings reload")
	state.reset_campaign()
	check(GameSettings.intro_seen, "new campaign preserves profile seen state")
	check(opener.focus_mode != Control.FOCUS_NONE and root.gui_get_focus_owner() == opener, "closing film restores original focus")
	check(audio.process_mode != Node.PROCESS_MODE_DISABLED, "closing film restores audio manager")
	var guide = HowToPlay.new()
	root.add_child(guide)
	await settle()
	guide.replay_button.grab_focus()
	var before: Dictionary = state.to_dict().duplicate(true)
	# The same guide also lives inside the game's paused menu.
	guide.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	guide._replay_opening()
	await settle()
	var replay: OpeningFilm = guide._opening
	check(replay != null and not replay.remember_completion, "Help replays introduction without first-run persistence")
	var cancel = InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await settle()
	check(guide._opening == null and is_instance_valid(guide), "Escape closes replay exactly one level")
	check(root.gui_get_focus_owner() == guide.replay_button, "replay restores Help button focus")
	check(state.to_dict() == before, "replay leaves campaign unchanged")
	check(paused, "closing replay preserves an already paused game")
	guide.close()
	await settle()
	paused = false
	var unfinished = OpeningFilm.new()
	root.add_child(unfinished)
	await settle()
	GameSettings.intro_seen = false
	unfinished.queue_free()
	await settle()
	check(not GameSettings.intro_seen, "external scene teardown does not claim film was seen")
	check(audio.process_mode != Node.PROCESS_MODE_DISABLED, "external teardown restores scene audio")
	var layout = OpeningFilm.new()
	layout.remember_completion = true
	root.add_child(layout)
	await settle()
	layout.toggle_pause()
	for area in [Vector2i(1280, 720), Vector2i(985, 554), Vector2i(800, 450)]:
		root.size = area
		for locale in ["th", "en"]:
			root.get_node("Localization").set_language(locale)
			layout._start_cue(3)
			await settle()
			check(inside(layout.top_panel) and inside(layout.caption_card) and inside(layout.skip_button), "%s %s subtitle and Skip stay on screen" % [locale, area])
			check(layout.top_panel.get_global_rect().end.y < layout.caption_card.get_global_rect().position.y, "%s %s teaching image has space between controls and captions" % [locale, area])
	layout._finish()
	await settle()
	check(inside(layout.continue_button) and inside(layout.caption_card), "compact final goals and Continue remain visible")
	check(GameSettings.intro_seen, "finishing persists seen state before the final Continue button")
	layout.close()
	await settle()
	root.size = Vector2i(1280, 720)
	# Exercise the real title transition, not only a standalone film fixture.
	GameSettings.intro_seen = false
	GameSettings.save_settings()
	var title = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await settle()
	title._on_new_game()
	await settle()
	check(title._overlay is OpeningFilm and title._overlay.remember_completion and paused, "first New Game opens film before preparation and pauses the background")
	var opening = title._overlay
	title._on_new_game()
	check(title._overlay == opening, "repeated New Game cannot stack films or reset the campaign")
	# A direct close missed the detached-viewport regression on first-run Back.
	Input.parse_input_event(cancel)
	await settle()
	var hearth = current_scene
	check(hearth.get_script() == load("res://scripts/VillageHearth.gd") and hearth.how_to_play == null and not paused, "Skip proceeds to preparation without a second mandatory rules screen")
	check(FirstBurnTips.wanted(state), "contextual first-burn guidance remains available after Skip")
	hearth.queue_free()
	await settle()
	title = load("res://scenes/Title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await settle()
	title._start_new_campaign()
	await settle()
	check(current_scene.get_script() == load("res://scripts/VillageHearth.gd") and not paused, "next New Game goes straight to preparation after introduction was seen")
	current_scene.queue_free()
	await settle()
	opener.queue_free()
	state.from_dict(old_state)
	GameSettings.dir = settings_dir
	SaveGame.dir = save_dir
	GameSettings.load_settings()
	# Restore presentation without writing the owner's settings during QA cleanup.
	L10n.set_locale(GameSettings.locale)
	audio.stop_all_loops()
	for file in DirAccess.get_files_at(sandbox):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox))
	await settle()
	print("Opening: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
