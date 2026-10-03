class_name OpeningFilm
extends Control

## A roughly one-minute, bilingual context film. First-run callers opt into
## profile persistence; replay never changes campaigns or tutorial progress.
signal closed
const STORY_PATH = "res://localization/opening.json"
const AUDIO_PATH = "res://assets/audio/opening/"
var remember_completion := false
var story: Dictionary
var cue_index := 0
var cue_seconds := 0.0
var cue_duration := 1.0
var film_paused := false
var finished := false
var skip_button: Button
var pause_button: Button
var language_button: Button
var continue_button: Button
var subtitle: Label
var heading: Label
var term: Label
var progress_bar: ProgressBar
var summary: VBoxContainer
var caption_card: PanelContainer
var top_panel: PanelContainer
var diorama: OpeningDiorama
var voice: AudioStreamPlayer
var music: AudioStreamPlayer
var scan_music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var insects: AudioStreamPlayer
var effects: AudioStreamPlayer
var work_sound: AudioStreamPlayer
var _scope: ModalFocusScope
var _streams: Dictionary = {}
var _closed := false
var _audio: Node
var _audio_mode: int
var _audio_players: Array[Dictionary] = []
var _language := "th"
var _transition: ColorRect
var _tree_was_paused := false
var _owns_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.get_theme()
	story = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))
	for cue in story.cues:
		L10n.register_message(cue.th, cue.en)
	for chapter in story.chapters:
		L10n.register_message(chapter.title.th, chapter.title.en)
		L10n.register_message(chapter.term.th, chapter.term.en)
	L10n.register_message(story.title.th, story.title.en)
	_build_world()
	_build_controls()
	_scope = ModalFocusScope.begin(self)
	_tree_was_paused = get_tree().paused
	_owns_pause = true
	get_tree().paused = true
	_suspend_scene_audio()
	_build_audio()
	_language = GameSettings.locale
	get_node("/root/Localization").language_changed.connect(_on_language_changed)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_start_cue(0)
	skip_button.grab_focus()

func _build_world() -> void:
	var container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	diorama = OpeningDiorama.new()
	viewport.add_child(diorama)
	_transition = ColorRect.new()
	_transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition.color = UITheme.INK
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_transition)

func _button(text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(action)
	return button

func _build_controls() -> void:
	top_panel = PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", UITheme.slab(Color(UITheme.INK, 0.9)))
	add_child(top_panel)
	var column = UITheme.vbox(3)
	top_panel.add_child(column)
	var row = UITheme.hbox(10)
	column.add_child(row)
	heading = UITheme.label(story.title.th, "Title", UITheme.STRAW)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	language_button = _button("English", _toggle_language)
	language_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(language_button)
	pause_button = _button("หยุดภาพ", toggle_pause)
	row.add_child(pause_button)
	skip_button = _button("ข้าม", close)
	row.add_child(skip_button)
	term = UITheme.label("", "Kicker", UITheme.EMERALD)
	column.add_child(term)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 3
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_bar)
	caption_card = PanelContainer.new()
	caption_card.add_theme_stylebox_override("panel", UITheme.slab(Color(UITheme.INK, 0.96)))
	add_child(caption_card)
	var captions = UITheme.vbox(4)
	caption_card.add_child(captions)
	captions.add_child(UITheme.label("ตาโพ · ผู้เฒ่าของหมู่บ้าน", "Kicker", UITheme.STRAW))
	subtitle = UITheme.wrap(UITheme.label("", "Body", UITheme.CREAM))
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	captions.add_child(subtitle)
	summary = UITheme.vbox(8)
	summary.visible = false
	captions.add_child(summary)
	summary.add_child(UITheme.wrap(UITheme.label("เตรียมแนว · คุมไฟ · ดับความร้อน", "Title", UITheme.STRAW)))
	summary.add_child(UITheme.wrap(UITheme.label("ในเกมนี้: เถ้าที่เย็นแล้ว ≥75% · จุดร้อน 0 จุดก่อน 20:00", "Body")))
	summary.add_child(UITheme.wrap(UITheme.label("เริ่มจากกวาดแนวรอบแปลง เคล็ดลับในไร่จะแนะนำเครื่องมือทีละขั้น", "Small")))
	continue_button = _button("เตรียมแปลงแรก", close)
	continue_button.theme_type_variation = "PrimaryButton"
	summary.add_child(continue_button)
	caption_card.minimum_size_changed.connect(_fit_layout)
	top_panel.minimum_size_changed.connect(_fit_layout)

func _fit_layout() -> void:
	if not is_instance_valid(caption_card):
		return
	var area = get_viewport().get_visible_rect().size
	var width = maxf(300.0, minf(1040.0, area.x - 32.0))
	top_panel.size = Vector2(area.x - 32, top_panel.get_combined_minimum_size().y)
	top_panel.position = Vector2(16, 16)
	subtitle.add_theme_font_size_override("font_size", 17 if area.y < 620 else 20)
	caption_card.size = Vector2(width, caption_card.get_combined_minimum_size().y)
	caption_card.position = Vector2((area.x - width) * 0.5, area.y - caption_card.size.y - 16)

func _suspend_scene_audio() -> void:
	_audio = get_node_or_null("/root/AudioManager")
	if not _audio:
		return
	_audio_mode = _audio.process_mode
	_pause_audio_tree(_audio)
	_audio.process_mode = Node.PROCESS_MODE_DISABLED

func _pause_audio_tree(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		_audio_players.append({"player": weakref(node), "paused": node.stream_paused})
		node.stream_paused = true
	for child in node.get_children():
		_pause_audio_tree(child)

func _restore_scene_audio() -> void:
	if not is_instance_valid(_audio):
		return
	_audio.process_mode = _audio_mode
	for entry in _audio_players:
		var player = entry.player.get_ref()
		if is_instance_valid(player):
			player.stream_paused = entry.paused
	_audio_players.clear()
	_audio = null

func _restore_tree_pause() -> void:
	if _owns_pause:
		get_tree().paused = _tree_was_paused
		_owns_pause = false

func _looped_stream(file: String) -> AudioStreamWAV:
	# Loop only a private copy; shared imported resources remain unchanged.
	var source = load(file) as AudioStreamWAV
	if source == null:
		return null
	var stream = source.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var bytes_per_sample = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
	stream.loop_end = stream.data.size() / (bytes_per_sample * (2 if stream.stereo else 1))
	return stream

func _player(bus: String, file: String = "", volume: float = 0, looped: bool = false) -> AudioStreamPlayer:
	var player = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = volume
	add_child(player)
	if file != "" and ResourceLoader.exists(file):
		player.stream = _looped_stream(file) if looped else load(file)
		player.play()
	return player

func _build_audio() -> void:
	voice = _player("RadioVoice")
	music = _player("Music", "res://assets/audio/sfxloop_music0.wav", -60, true)
	scan_music = _player("Music", "res://assets/audio/sfxloop_music2.wav", -60, true)
	ambience = _player("Ambience", "res://assets/audio/sfxloop_wind.wav", -60, true)
	insects = _player("Ambience", "res://assets/audio/sfxloop_cicada.wav", -60, true)
	effects = _player("SFX", "", -17)
	work_sound = _player("SFX", "", -60)

func _mix_background(delta: float) -> void:
	# The source beds are already quiet (-24 to -29 dBFS RMS). Keep them
	# audible beneath the dry narrator, then let them breathe between sentences.
	var speaking = voice.playing and not voice.stream_paused
	var music_duck = -5.0 if speaking else 0.0
	var ambience_duck = -2.0 if speaking else 0.0
	var scan = cue_index == 6 and not finished
	_fade_audio(music, -60.0 if scan else -6.0 + music_duck, delta)
	_fade_audio(scan_music, -8.0 + music_duck if scan else -60.0, delta)
	_fade_audio(ambience, -9.0 + ambience_duck - (4.0 if scan else 0.0), delta)
	_fade_audio(insects, -60.0 if scan else -10.0 + ambience_duck, delta)
	var work_level = {3: -6.0, 4: -10.0, 7: -8.0}.get(cue_index, -60.0)
	# A short tail fades the action sound before the next illustrated scene.
	if not finished and cue_seconds > cue_duration - 0.4:
		work_level = -60.0
	_fade_audio(work_sound, work_level - (3.0 if speaking else 0.0), delta)

func _fade_audio(player: AudioStreamPlayer, target_db: float, delta: float) -> void:
	# Smooth in linear amplitude so scene cuts and voice ducking cannot click.
	var current = db_to_linear(player.volume_db)
	var target = db_to_linear(target_db)
	var seconds = 0.18 if target < current else 0.8
	player.volume_db = linear_to_db(lerpf(current, target, 1.0 - exp(-delta / seconds)))

func _voice_stream(index: int) -> AudioStream:
	var path = AUDIO_PATH + _language + "/" + str(story.cues[index].audio)
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

func _start_cue(index: int) -> void:
	cue_index = index
	cue_seconds = 0.0
	voice.stop()
	work_sound.stop()
	work_sound.volume_db = -60.0
	voice.stream = _voice_stream(index)
	var cue: Dictionary = story.cues[index]
	cue_duration = maxf(float(cue.min_seconds), voice.stream.get_length() + 0.65 if voice.stream else 0.0)
	subtitle.text = cue.th
	var chapter: Dictionary = story.chapters[int(cue.chapter)]
	heading.text = chapter.title.th
	term.text = chapter.term.th
	if index == 6:
		term.text = "20:00 · รอบสแกนในเกม"
	term.add_theme_color_override("font_color", UITheme.STATE if int(cue.chapter) == 3 else UITheme.EMERALD)
	language_button.text = "ภาษาไทย" if _language == "en" else "English"
	if voice.stream:
		voice.play()
		voice.stream_paused = film_paused
	var foley = {3: "rake", 4: "crackle", 7: "spray"}.get(index, "")
	var foley_path = "res://assets/audio/sfxloop_%s.wav" % foley
	if foley != "" and ResourceLoader.exists(foley_path):
		work_sound.stream = _looped_stream(foley_path)
		work_sound.play()
		work_sound.stream_paused = film_paused
	if index == 6 and ResourceLoader.exists("res://assets/audio/sfx_ping.wav"):
		effects.stream = load("res://assets/audio/sfx_ping.wav")
		effects.play()
		effects.stream_paused = film_paused
	diorama.set_frame(cue_index, 0, 0)
	_fit_layout.call_deferred()

func _process(delta: float) -> void:
	if _closed or film_paused:
		return
	_mix_background(delta)
	if finished:
		return
	cue_seconds += delta
	var progress = clampf(cue_seconds / cue_duration, 0, 1)
	diorama.set_frame(cue_index, progress, delta)
	progress_bar.value = (cue_index + progress) / story.cues.size() * 100.0
	# Brief fade through ink at chapter cuts, rather than flashing two worlds.
	_transition.modulate.a = maxf(0, 1.0 - cue_seconds / 0.4) if cue_index in [0, 2, 3, 5] else 0.0
	if cue_seconds >= cue_duration:
		if cue_index + 1 < story.cues.size():
			_start_cue(cue_index + 1)
		else:
			_finish()

func _finish() -> void:
	finished = true
	_remember()
	voice.stop()
	work_sound.stop()
	diorama.set_frame(7, 1.0, 0.0)
	subtitle.text = "ช่วยกันดูแลแปลงข้าวและผืนป่า"
	summary.show()
	pause_button.hide()
	skip_button.text = "ปิด"
	continue_button.text = "เตรียมแปลงแรก" if remember_completion else "กลับ"
	progress_bar.value = 100
	continue_button.grab_focus()
	_fit_layout.call_deferred()

func toggle_pause() -> void:
	if finished:
		return
	film_paused = not film_paused
	for player in [voice, music, scan_music, ambience, insects, effects, work_sound]:
		player.stream_paused = film_paused
	pause_button.text = "เล่นภาพต่อ" if film_paused else "หยุดภาพ"

func _toggle_language() -> void:
	get_node("/root/Localization").set_language("th" if _language == "en" else "en")

func _on_language_changed(locale: String) -> void:
	_language = locale
	if finished:
		language_button.text = "ภาษาไทย" if locale == "en" else "English"
		return
	# Restart just this sentence in the selected voice; never overlap languages.
	_start_cue(cue_index)
	voice.stream_paused = film_paused

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# First-run completion changes scenes synchronously through closed.
		# Consume Back before the title and this overlay leave the viewport.
		close()
	elif event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _closed:
		return
	_closed = true
	_remember()
	_stop_audio()
	_restore_tree_pause()
	_restore_scene_audio()
	if _scope:
		_scope.release()
	closed.emit()
	queue_free()

func _remember() -> void:
	if remember_completion and not GameSettings.intro_seen:
		GameSettings.intro_seen = true
		GameSettings.save_settings()

func _stop_audio() -> void:
	for player in [voice, music, scan_music, ambience, insects, effects, work_sound]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()

func _exit_tree() -> void:
	# External teardown restores audio but does not falsely mark the film seen.
	_stop_audio()
	_restore_tree_pause()
	_restore_scene_audio()
