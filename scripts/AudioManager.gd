extends Node

## Procedural sound & music synthesis (PRD §9.2) — zero audio files required.
## One-shot SFX play through a small voice pool; loops (fire, drone, siren,
## radio) and the three music layers fade toward target volumes every frame.

static var instance: Node

## Source captions are emitted only for recordings that actually start playback.
signal voice_caption_changed(speaker: String, text: String, duration: float)
const VOICE_CAPTION_PATH = "res://localization/voice_subtitles.json"
var voice_captions: Dictionary = {}
var _caption_player: Node
var _caption_stream: AudioStream
var subtitle_overlay: CanvasLayer

const RATE: int = 44100
const SFX_VOICES: int = 24
const MUSIC_LOOP_SECONDS: float = 16.0
const SILENT_DB: float = -60.0

## Optional recorded voice lines (OmniVoice-Thai, see ASSETS.md A1–A3).
## Drop-in wavs; every missing file falls back to synthesis.
##   tapoh_wind_warning.wav, tapoh_wind_warning_2.wav, ...  Ta-poh wind warnings
##   radio_ch1_NN.wav ...   FM 88.5 forestry / ranger chatter
##   radio_ch2_NN.wav ...   FM 94.2 hill weather forecast
const AUDIO_DIR := "res://assets/audio"
const ENGLISH_VOICE_DIR := "res://assets/audio/en"
var _english_voices: Dictionary = {}
var _voice_locale: String = ""
const TAPOH_VOICE_PATH = "res://assets/audio/tapoh_wind_warning.wav"
const RADIO_VOICE_BUS := "RadioVoice"
const RADIO_FILTER_BUS := "RadioFilter"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const AMBIENCE_BUS := "Ambience"
const UI_BUS := "UI"

var _sfx: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}

# Voice management: per-slot metadata and per-event rate limiting
var _voice_priority: Array = []
var _voice_started: Array = []
var _last_played: Dictionary = {}

# Sustained held-work loops: spray hiss, torch roar, rake scrape, refill gurgle
var held_players: Dictionary = {}
const HELD_LEVELS := {"spray": 0.32, "ignite": 0.32, "rake": 0.28, "refill": 0.3}

# Ambience bed (wind + cicadas), muffled by the 18:00 inversion
var ambience_players: Dictionary = {}
var _ambience_targets: Dictionary = {"wind": 0.0, "cicada": 0.0}
var _ambience_lpf: AudioEffectLowPassFilter
var _inversion: float = 0.0

# Ducking state
var _static_level: float = 0.0
var _siren_on: bool = false

# Spatial audio: shared drone-hum loop stream, canopy occlusion, 3D one-shot pool
var drone_hum_stream: AudioStreamWAV
var _drone_lpf: AudioEffectLowPassFilter
var _occlusion: float = 0.0
var _sfx3d: Array[AudioStreamPlayer3D] = []
const SFX3D_VOICES: int = 6

# Recorded voice pools loaded from AUDIO_DIR at startup (empty = pure synthesis)
var _tapoh_voices: Array = []
var _radio_voices: Dictionary = {}
var _bark_voices: Dictionary = {}  # kind -> Array[AudioStream] (crew barks)
var _voice_last: Dictionary = {}   # pool key -> last index played
var radio_player: AudioStreamPlayer
var speech_player: AudioStreamPlayer
var speech_player_3d: AudioStreamPlayer3D
var _speech_priority: int = 0
var _speech_last: Dictionary = {}
const FIRE_WARNING_INTERVAL_MS := 8000
var _speech_kind := ""
var _fire_voice_last := -100000
var _fire_voice_severity := 0
var _fire_alarm_last := -100000
## Opt-in temporary diagnostics, bounded to prevent production growth.
var fire_diagnostics := false
var fire_warning_log: Array[Dictionary] = []
func _log_fire(kind: String, accepted: bool, pos: Vector3) -> void:
	if fire_diagnostics:
		fire_warning_log.append({"kind": kind, "accepted": accepted, "position": pos, "time_ms": Time.get_ticks_msec()})
		if fire_warning_log.size() > 128: fire_warning_log.pop_front()
var _scene_audio_epoch: int = 0
var _variant_streams: Dictionary = {}
var _variant_last: Dictionary = {}
var _music_state: int = 0
var _state_music: bool = false

# Loop players and their target linear volumes
var crackle_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var music_players: Array[AudioStreamPlayer] = []
var _targets: Dictionary = {}

# Music is rendered at startup in small main-thread jobs (a few ms per frame),
# so there is no hitch and no GDScript running on worker threads
const MUSIC_FRAME_BUDGET_MS: int = 3
var _music_streams: Array = []
var _music_jobs: Array[Callable] = []
var _music_layers: Array = []
var music_ready: bool = false
var _music_layer_targets: Array = [0.0, 0.0, 0.0]

func _init() -> void:
	instance = self

func _ready() -> void:
	get_tree().node_added.connect(_on_ui_node_added)
	_ensure_buses()
	for i in SFX_VOICES:
		var p = AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx.append(p)
		_voice_priority.append(0)
		_voice_started.append(0)
	for i in SFX3D_VOICES:
		var p3 = AudioStreamPlayer3D.new()
		p3.bus = SFX_BUS
		p3.max_distance = 80.0
		p3.unit_size = 8.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		_sfx3d.append(p3)

	crackle_player = _make_loop_player(_loop_stream("crackle", _crackle_loop), AMBIENCE_BUS)
	drone_hum_stream = _loop_stream("drone_hum", _drone_hum_loop)
	siren_player = _make_loop_player(_loop_stream("siren", _siren_loop), SFX_BUS)
	static_player = _make_loop_player(_loop_stream("static", _radio_static_loop), AMBIENCE_BUS)
	ambience_players["wind"] = _make_loop_player(_loop_stream("wind", _wind_bed_loop), AMBIENCE_BUS)
	ambience_players["cicada"] = _make_loop_player(_loop_stream("cicada", _cicada_bed_loop), AMBIENCE_BUS)
	# Ambience beds fade on their own targets; keep them out of the generic loop
	_targets.erase(ambience_players["wind"])
	_targets.erase(ambience_players["cicada"])
	if ResourceLoader.exists(AUDIO_DIR + "/sfxloop_evening.wav"):
		ambience_players["evening"] = _make_loop_player(_loop_stream("evening", _wind_bed_loop), AMBIENCE_BUS)
		_targets.erase(ambience_players["evening"])
	_ensure_radio_bus()
	radio_player = AudioStreamPlayer.new()
	radio_player.bus = RADIO_FILTER_BUS
	add_child(radio_player)
	speech_player = AudioStreamPlayer.new()
	speech_player.bus = RADIO_VOICE_BUS
	add_child(speech_player)
	speech_player_3d = AudioStreamPlayer3D.new()
	speech_player_3d.bus = RADIO_FILTER_BUS
	speech_player_3d.unit_size = 12.0
	speech_player_3d.max_distance = 100.0
	add_child(speech_player_3d)
	_voice_locale = TranslationServer.get_locale().get_slice("_", 0)
	var localization = get_node_or_null("/root/Localization")
	if localization:
		localization.language_changed.connect(_on_voice_language_changed)
	_load_voice_captions()
	_load_recorded_voices()
	for voice_player in [radio_player, speech_player, speech_player_3d]:
		voice_player.finished.connect(_on_caption_finished.bind(voice_player))
	subtitle_overlay = load("res://scripts/VoiceSubtitles.gd").new()
	add_child(subtitle_overlay)
	for i in 3:
		var mp = AudioStreamPlayer.new()
		mp.volume_db = SILENT_DB
		mp.bus = MUSIC_BUS
		add_child(mp)
		music_players.append(mp)

	_queue_music_jobs()

func _exit_tree() -> void:
	# Release playbacks so nothing is left referenced at shutdown
	for p in _sfx + music_players + [radio_player, speech_player] + ambience_players.values():
		p.stop()
		p.stream = null
	if speech_player_3d:
		speech_player_3d.stop()
		speech_player_3d.stream = null
	for p in _targets.keys():
		p.stop()
		p.stream = null
	for p in _sfx3d:
		p.stop()
		p.stream = null
	drone_hum_stream = null
	_music_jobs.clear()
	_music_streams.clear()
	_music_layers.clear()
	_variant_streams.clear()
	_bark_voices.clear()
	_cache.clear()
	_tapoh_voices.clear()
	_radio_voices.clear()
	_english_voices.clear()
	_voice_last.clear()

func _make_loop_player(stream: AudioStreamWAV, bus: String = SFX_BUS) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = SILENT_DB
	add_child(p)
	_targets[p] = 0.0
	return p

func _process(delta: float) -> void:
	# Direct stop() calls and scene changes must never leave stale dialogue.
	if _caption_player and (not _caption_player.playing or _caption_player.stream != _caption_stream):
		_clear_voice_caption()
	if not music_ready:
		_run_music_jobs()

	# Ducking: radio static sits under the broadcast voice; music under the siren
	if static_player:
		_targets[static_player] = _static_level * (0.30 if radio_player and radio_player.playing else 1.0)
	for p in _targets.keys():
		var rate := 2.5 if held_players.values().has(p) else 0.8
		_fade_player(p, _targets[p], delta, rate)
	var music_duck := 0.45 if _siren_on else 1.0
	if _speech_active():
		music_duck *= 0.5
	if music_ready:
		for i in 3:
			_fade_player(music_players[i], _music_layer_targets[i] * music_duck, delta, 0.16 if _state_music else 0.8)
	for key in ambience_players:
		_fade_player(ambience_players[key], _ambience_targets.get(key, 0.0), delta)
	if _ambience_lpf:
		_ambience_lpf.cutoff_hz = lerpf(20000.0, 1400.0, _inversion)
	# Canopy occlusion: hiding under bamboo muffles the drones (LPF + level duck)
	_occlusion = move_toward(_occlusion, _occlusion_target, delta * 3.0)
	if _drone_lpf:
		_drone_lpf.cutoff_hz = lerpf(20000.0, 700.0, _occlusion)
		var bus := AudioServer.get_bus_index("Drones")
		if bus != -1:
			AudioServer.set_bus_volume_db(bus, linear_to_db(lerpf(1.0, 0.35, _occlusion)))

## Shared menu sound policy, including dynamically built pause/settings buttons.
func _on_ui_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_connected"):
		node.set_meta("audio_connected", true)
		node.pressed.connect(play_ui_click)
		node.focus_entered.connect(play_ui_focus)

## Fades a looping player toward a linear volume, starting / stopping it as needed
func _fade_player(p: AudioStreamPlayer, target: float, delta: float, rate: float = 0.8) -> void:
	var current = db_to_linear(p.volume_db) if p.playing else 0.0
	var next = move_toward(current, target, delta * rate)
	if next <= 0.001:
		if p.playing:
			p.stop()
		p.volume_db = SILENT_DB
		return
	p.volume_db = linear_to_db(next)
	if not p.playing and p.stream:
		p.play()

# ---------------------------------------------------------------------------
# Public controls
# ---------------------------------------------------------------------------

## 0..1 from the number of burning cells
func set_fire_intensity(level: float) -> void:
	_targets[crackle_player] = clampf(level, 0.0, 1.0) * 0.35

## 0..1: how occluded the player is from the drones (under bamboo canopy)
var _occlusion_target: float = 0.0
func set_canopy_occlusion(level: float) -> void:
	_occlusion_target = clampf(level, 0.0, 1.0)

func set_siren(on: bool) -> void:
	_siren_on = on
	_targets[siren_player] = 0.30 if on else 0.0

func set_radio_static(level: float) -> void:
	_static_level = clampf(level, 0.0, 1.0) * 0.22

## 0 calm .. 3 satellite countdown: layers come in as the deadline approaches
func set_music_intensity(level: int) -> void:
	_music_state = clampi(level, 0, 3)
	if _state_music:
		_set_state_music()
		return
	match level:
		0: _music_layer_targets = [0.30, 0.0, 0.0]
		1: _music_layer_targets = [0.30, 0.24, 0.0]
		2: _music_layer_targets = [0.28, 0.26, 0.22]
		_: _music_layer_targets = [0.28, 0.34, 0.42]

## Quiet harp-and-khaen bed for the hearth / folk radio
func play_hearth_music(on: bool) -> void:
	if radio_player:
		radio_player.stop()
		if _caption_player == radio_player:
			_clear_voice_caption()
	_music_state = 0
	_music_layer_targets = [0.28, 0.0, 0.0] if on else [0.0, 0.0, 0.0]

func _set_state_music() -> void:
	_music_layer_targets = [0.0, 0.0, 0.0]
	var track := 0 if _music_state == 0 else (2 if _music_state == 3 else 1)
	_music_layer_targets[track] = 0.28 if _music_state < 2 else 0.32

func stop_all_loops() -> void:
	_clear_voice_caption()
	_scene_audio_epoch += 1
	_static_level = 0.0
	_siren_on = false
	_inversion = 0.0
	_occlusion_target = 0.0
	_speech_priority = 0
	_speech_last.clear()
	_speech_kind = ""
	_fire_voice_last = -100000
	_fire_voice_severity = 0
	_fire_alarm_last = -100000
	_step_pos.clear()
	_step_dist.clear()
	for p in [radio_player, speech_player, speech_player_3d]:
		if p:
			p.stop()
	for p in _sfx:
		p.stop()
	for p in _sfx3d:
		p.stop()
	for p in _targets.keys():
		_targets[p] = 0.0
	for key in ambience_players:
		_ambience_targets[key] = 0.0
	_music_layer_targets = [0.0, 0.0, 0.0]

# ---------------------------------------------------------------------------
# Buses, user volume and sustained held-work loops
# ---------------------------------------------------------------------------

## Master -> Music / SFX / Ambience / UI (+ RadioVoice) with a soft limiter on
## Master so summed voices cannot clip (standard game-audio bus layout).
func _ensure_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS, AMBIENCE_BUS, UI_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	_ambience_lpf = AudioEffectLowPassFilter.new()
	_ambience_lpf.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(AMBIENCE_BUS), _ambience_lpf)
	if AudioServer.get_bus_index("Drones") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Drones")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Drones"), SFX_BUS)
	AudioServer.set_bus_send(AudioServer.get_bus_index(UI_BUS), SFX_BUS)
	_drone_lpf = AudioEffectLowPassFilter.new()
	_drone_lpf.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Drones"), _drone_lpf)

## Master/Music/SFX/Ambience/UI volume, 0..1 linear (settings menu)
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, clampf(linear, 0.0, 2.0))))

func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(idx)) if idx != -1 else 1.0

## Ambience bed levels (0..1 wind/cicada) and inversion muffle (0..1)
func set_ambience(wind: float, cicada: float, inversion: float, evening: float = 0.0) -> void:
	_ambience_targets["wind"] = clampf(wind, 0.0, 1.0)
	_ambience_targets["cicada"] = clampf(cicada, 0.0, 1.0)
	_inversion = clampf(inversion, 0.0, 1.0)
	_ambience_targets["evening"] = clampf(evening, 0.0, 1.0)

## Sustained held-work loops (spray / ignite / rake / refill): one loop per
## verb with fast fades, instead of retriggering a one-shot every game tick
func set_held_loop(loop_name: String, on: bool) -> void:
	if not held_players.has(loop_name):
		held_players[loop_name] = _make_loop_player(_held_loop_stream(loop_name), SFX_BUS)
	var was_on: bool = _targets[held_players[loop_name]] > 0.0
	if loop_name == "spray" and was_on != on:
		_play("tool_start" if on else "tool_stop", _tool_clack, 1.0, -5.0, SFX_BUS, 120, 0)
	_targets[held_players[loop_name]] = HELD_LEVELS.get(loop_name, 0.5) if on else 0.0

func _held_loop_stream(loop_name: String) -> AudioStreamWAV:
	match loop_name:
		"spray":
			return _loop_stream("spray", _water_spray_loop)
		"ignite":
			return _loop_stream("torch", _torch_loop)
		"rake":
			return _loop_stream("rake", _rake_loop)
		_:
			return _loop_stream("refill", _refill_loop)

## sfxloop_<key>.wav drop-in for a recorded seamless loop (whole file loops);
## falls back to the synthesized recipe
func _loop_stream(key: String, builder: Callable) -> AudioStreamWAV:
	var path := AUDIO_DIR + "/sfxloop_%s.wav" % key
	if ResourceLoader.exists(path):
		var s := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStreamWAV
		if s:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			var bytes_per_sample := 2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1
			s.loop_end = s.data.size() / (bytes_per_sample * (2 if s.stereo else 1))
			return s
	return builder.call()

## Shared one-shot cache lookup: sfx_<key>.wav drop-in beats the synthesized recipe
func _stream_for(key: String, builder: Callable) -> AudioStream:
	if _variant_streams.has(key):
		var pool: Array = _variant_streams[key]
		var pick := randi() % pool.size()
		if pool.size() > 1 and pick == _variant_last.get(key, -1):
			pick = (pick + 1) % pool.size()
		_variant_last[key] = pick
		_cache[key] = pool[pick]
		return pool[pick]
	if not _cache.has(key):
		var override_path := AUDIO_DIR + "/sfx_%s.wav" % key
		if ResourceLoader.exists(override_path):
			_cache[key] = ResourceLoader.load(override_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		else:
			_cache[key] = builder.call()
	return _cache[key]

# ---------------------------------------------------------------------------
# Recorded voices (drop-in wavs in assets/audio/, OmniVoice-Thai)
# ---------------------------------------------------------------------------

## Speech slider controls the dry parent; only radio speech gets band limiting.
func _ensure_radio_bus() -> void:
	if AudioServer.get_bus_index(RADIO_VOICE_BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, RADIO_VOICE_BUS)
	if AudioServer.get_bus_index(RADIO_FILTER_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, RADIO_FILTER_BUS)
	AudioServer.set_bus_send(idx, RADIO_VOICE_BUS)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 250.0
	AudioServer.add_bus_effect(idx, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3800.0
	AudioServer.add_bus_effect(idx, lp)

## Scans AUDIO_DIR once at startup; missing files simply leave pools empty.
## Conventions: tapoh_wind_warning*.wav (wind warnings), radio_ch<N>_*.wav
## (broadcast lines), ta_poh_call*.wav + bark_<kind>*.wav (crew barks),
## sfx_<key>.wav (overrides any synthesized one-shot with that cache key).
func _load_recorded_voices() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return
	for f in wav_names(dir.get_files()):
		if not (f.begins_with("tapoh_wind_warning") or f.begins_with("radio_ch") or f.begins_with("ta_poh_call") or f.begins_with("bark_") or f.begins_with("sfx_step_")):
			continue
		var stream = ResourceLoader.load(AUDIO_DIR + "/" + f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if stream == null:
			continue
		if f.begins_with("sfx_step_") and f.get_basename().get_slice("_", 3).is_valid_int():
			var key := "step_" + f.get_slice("_", 2)
			if not _variant_streams.has(key):
				_variant_streams[key] = []
			_variant_streams[key].append(stream)
		elif f.begins_with("tapoh_wind_warning"):
			_tapoh_voices.append(stream)
		elif f.begins_with("radio_ch"):
			var channel := int(f.get_slice("_", 1).trim_prefix("ch"))
			if channel > 0:
				if not _radio_voices.has(channel):
					_radio_voices[channel] = []
				_radio_voices[channel].append(stream)
		elif f.begins_with("ta_poh_call"):
			_add_bark("tapoh", stream)
		elif f.begins_with("bark_"):
			var kind := f.trim_prefix("bark_").get_slice(".", 0)
			# bark_maelu_2.wav -> "maelu": numeric take suffixes share a pool.
			var suffix := kind.get_slice("_", kind.get_slice_count("_") - 1)
			if suffix.is_valid_int():
				kind = kind.trim_suffix("_" + suffix)
			_add_bark(kind, stream)
	var radio_lines := 0
	for ch in _radio_voices:
		radio_lines += _radio_voices[ch].size()
	print_verbose("AudioManager voices: tapoh=%d radio=%d barks=%s" % [_tapoh_voices.size(), radio_lines, str(_bark_voices.keys())])

## Exported builds don't ship the source .wav files: the folder lists only
## "x.wav.import" (sometimes ".remap"); the audio lives in the pack under the
## original path. Normalise and de-duplicate, as AssetLibrary does. (Beta 1
## shipped with no voices because the loader only accepted bare ".wav" names.)
static func wav_names(files: PackedStringArray) -> Array[String]:
	var names: Array[String] = []
	for raw in files:
		var f: String = raw.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with(".wav") and not names.has(f):
			names.append(f)
	names.sort()
	return names

func _add_bark(kind: String, stream: AudioStream) -> void:
	if not _bark_voices.has(kind):
		_bark_voices[kind] = []
	_bark_voices[kind].append(stream)

func has_radio_voice(channel: int) -> bool:
	return _radio_voices.has(channel) and not _radio_voices[channel].is_empty()

## Snapshot of original recordings whose claims apply to this plot/season.
## Resolve the campaign only for radio broadcasts; crew events keep their pools.
func eligible_radio_voices(channel: int) -> Array:
	var originals: Array = _radio_voices.get(channel, [])
	if originals.is_empty() or channel not in [1, 2]:
		return originals.duplicate()
	var state = GameState.instance
	var cfg = state.plot_config() if is_instance_valid(state) else null
	var eligible: Array = []
	for stream in originals:
		var allowed := true
		match stream.resource_path.get_file():
			"radio_ch1_02.wav": allowed = cfg != null and cfg.rules.ranger_count > 0
			"radio_ch1_04.wav": allowed = cfg != null and cfg.drone_count > 0
			"radio_ch1_05.wav": allowed = cfg != null and cfg.rules.checkpoints
			"radio_ch2_03.wav": allowed = cfg != null and cfg.storm_front
			"radio_ch2_06.wav": allowed = cfg == null or not cfg.storm_front
		if allowed:
			eligible.append(stream)
	return eligible

## Crew bark (recorded drop-in: ta_poh_call*.wav or bark_<kind>*.wav).
## Kinds: "tapoh", "embers", "rally_reply", "cough". Silent if no recording.
func play_bark(kind: String, volume_db: float = -2.0, pos: Vector3 = Vector3.INF) -> void:
	if not has_bark(kind):
		return
	var pool: Array = _bark_voices[kind]
	var pick := _pick_voice("bark_" + kind, pool.size())
	var urgent := kind in ["embers", "spot_fire"]
	_play_speech(kind, pool[pick], pos, volume_db, 3 if urgent else (1 if kind == "maelu" else 2), kind.begins_with("report_"))

func _speech_active() -> bool:
	return (speech_player and speech_player.playing) or (speech_player_3d and speech_player_3d.playing) or (radio_player and radio_player.playing)

## A dedicated speech pool protects dialogue from footsteps. Expired warnings
## are dropped instead of queued; urgent lines may interrupt nonurgent speech.
func _play_speech(kind: String, stream: AudioStream, pos: Vector3, volume_db: float, priority: int, filtered: bool = false) -> void:
	var now := Time.get_ticks_msec()
	# Explicit semantic severity: forest ignition may supersede generic flying embers once.
	var severity := 2 if kind == "spot_fire" else (1 if kind == "embers" else 0)
	if severity > 0 and now - _fire_voice_last < FIRE_WARNING_INTERVAL_MS and severity <= _fire_voice_severity:
		_log_fire(kind, false, pos)
		return
	if now - int(_speech_last.get(kind, -100000)) < 4000:
		return
	var crew_busy := speech_player.playing or speech_player_3d.playing
	var escalating := severity > _fire_voice_severity and severity > 0 and now - _fire_voice_last < FIRE_WARNING_INTERVAL_MS
	if crew_busy and priority <= _speech_priority and not (escalating and _speech_kind == "embers"):
		_log_fire(kind, false, pos)
		return
	if severity > 0:
		_fire_voice_last = now
		_fire_voice_severity = severity
		_log_fire(kind, true, pos)
	stream = voice_for_locale(stream)
	_speech_kind = kind
	_speech_last[kind] = now
	_speech_priority = priority
	speech_player.stop()
	speech_player_3d.stop()
	radio_player.stop()
	_clear_voice_caption()
	if pos == Vector3.INF:
		speech_player.stream = stream
		speech_player.bus = RADIO_FILTER_BUS if filtered else RADIO_VOICE_BUS
		speech_player.volume_db = volume_db
		speech_player.play()
		_publish_voice_caption(speech_player, stream)
	else:
		speech_player_3d.stream = stream
		speech_player_3d.bus = RADIO_FILTER_BUS if filtered else RADIO_VOICE_BUS
		speech_player_3d.global_position = pos
		speech_player_3d.volume_db = volume_db
		speech_player_3d.play()
		_publish_voice_caption(speech_player_3d, stream)

func has_bark(kind: String) -> bool:
	return _bark_voices.has(kind) and not _bark_voices[kind].is_empty()

## Plays a random recorded broadcast line for a radio channel (skips the last one)
func play_radio_voice(channel: int) -> void:
	if not has_radio_voice(channel) or speech_player.playing or speech_player_3d.playing:
		return
	var pool := eligible_radio_voices(channel)
	if pool.is_empty():
		return
	# An index belongs to this ordered pool, not every pool for the channel.
	# Changing year/plot must not reinterpret the previous pool's last index.
	var names := PackedStringArray()
	for original in pool:
		names.append(original.resource_path.get_file())
	var pick := _pick_voice("ch%d:%s" % [channel, ",".join(names)], pool.size())
	_clear_voice_caption()
	var stream = voice_for_locale(pool[pick])
	radio_player.stream = stream
	radio_player.pitch_scale = 1.0
	radio_player.play()
	_publish_voice_caption(radio_player, stream)


## Production transcripts mirror voice_plan.json + approved revision_plan.json.
## Missing metadata remains silent rather than inventing a subtitle.
func _load_voice_captions() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(VOICE_CAPTION_PATH))
	if not parsed is Dictionary:
		push_warning("Recorded voice subtitle catalog could not be loaded")
		return
	voice_captions = parsed
	L10n.initialize()
	for caption in voice_captions.values():
		L10n.register_message(caption.th, caption.en)
		L10n.register_message(caption.speaker, caption.speaker_en)

func _publish_voice_caption(player: Node, stream: AudioStream) -> void:
	if not player.playing:
		return
	var filename = stream.resource_path.get_file()
	if not voice_captions.has(filename):
		return
	var caption: Dictionary = voice_captions[filename]
	_caption_player = player
	_caption_stream = stream
	voice_caption_changed.emit(caption.speaker, caption.th, stream.get_length())

func _clear_voice_caption() -> void:
	if _caption_player == null:
		return
	_caption_player = null
	_caption_stream = null
	voice_caption_changed.emit("", "", 0.0)

func _on_caption_finished(player: Node) -> void:
	if _caption_player == player:
		_clear_voice_caption()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		_on_voice_language_changed(TranslationServer.get_locale())

func _on_voice_language_changed(locale: String) -> void:
	var language = locale.get_slice("_", 0)
	if language == _voice_locale:
		return
	_voice_locale = language
	# Discard the old-language line immediately, including during paused Settings.
	# These are exclusively speech players; music, work, coughs and ambience keep going.
	for player in [radio_player, speech_player, speech_player_3d]:
		if player:
			player.stop()
	_clear_voice_caption()
	_speech_priority = 0
	_speech_last.clear()
	_speech_kind = ""
	_fire_voice_last = -100000
	_fire_voice_severity = 0

## Keep original pools/identities, selecting the locale only after a line is accepted.
## ResourceLoader resolves .wav.import/.remap names inside exported PCKs as usual.
## A missing English recording falls back independently to its Thai recording.
func voice_for_locale(original: AudioStream, locale: String = "") -> AudioStream:
	var language = (TranslationServer.get_locale() if locale.is_empty() else locale).get_slice("_", 0)
	if language != "en":
		return original
	var filename = original.resource_path.get_file()
	if _english_voices.has(filename):
		return _english_voices[filename]
	var path = ENGLISH_VOICE_DIR.path_join(filename)
	if not ResourceLoader.exists(path):
		return original
	var translated = ResourceLoader.load(path, "AudioStream")
	if not translated is AudioStream:
		return original
	_english_voices[filename] = translated
	return translated

func _pick_voice(key: String, size: int) -> int:
	var pick := randi() % size
	if size > 1 and pick == _voice_last.get(key, -1):
		pick = (pick + 1) % size
	_voice_last[key] = pick
	return pick

# ---------------------------------------------------------------------------
# One-shot SFX
# ---------------------------------------------------------------------------

## One-shot with per-event rate limiting and priority voice allocation. A busy
## voice is stolen only from equal-or-lower priority events (soft-steal: the new
## event lands on the oldest slot); lower-priority sounds are dropped instead of
## cutting a more important cue.
func _play(key: String, builder: Callable, pitch: float = 1.0, volume_db: float = 0.0, bus: String = SFX_BUS, min_interval_ms: int = 70, priority: int = 1, stream_key: String = "") -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -100000)) < min_interval_ms:
		return
	_last_played[key] = now
	var stream := _stream_for(stream_key if stream_key != "" else key, builder)
	var slot := _alloc_voice(priority)
	if slot < 0:
		return
	var p := _sfx[slot]
	p.bus = bus
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	_voice_priority[slot] = priority
	_voice_started[slot] = now
	p.play()

func _alloc_voice(priority: int) -> int:
	for i in _sfx.size():
		if not _sfx[i].playing:
			return i
	var best := 0
	for i in _sfx.size():
		if _voice_priority[i] < _voice_priority[best] \
				or (_voice_priority[i] == _voice_priority[best] and _voice_started[i] < _voice_started[best]):
			best = i
	return best if priority >= _voice_priority[best] else -1

func play_bamboo_pop() -> void:
	_play("pop", _bamboo_pop, randf_range(0.85, 1.3), -3.0)

func play_whistle() -> void:
	# whistle_alt.wav is a second take; both fall back to the synth
	_play("whistle_alt" if randf() < 0.35 else "whistle", _whistle)

func play_water_spray() -> void:
	_play("spray", _water_spray, randf_range(0.9, 1.1), -4.0)

func play_satellite_ping() -> void:
	_play("ping", _satellite_ping, 1.0, -2.0)

func play_cough() -> void:
	_play("cough_khanae", _cough, randf_range(0.96, 1.04), -4.0, SFX_BUS, 1500)

func play_tapoh_warning() -> void:
	if not _tapoh_voices.is_empty():
		var pick := _pick_voice("tapoh", _tapoh_voices.size())
		_play_speech("wind_warning", _tapoh_voices[pick], Vector3.INF, -2.0, 3)
	elif has_bark("tapoh"):
		play_bark("tapoh", -3.0)
	else:
		_play("tapoh_call", _tapoh_call)

func play_camera_alarm() -> void:
	_play("camera", _camera_alarm, 1.0, -4.0)

func play_countdown_beep() -> void:
	_play("beep", _beep, 1.0, -6.0)

func play_thunder() -> void:
	_play("thunder", _thunder, randf_range(0.8, 1.05), -3.0)

func play_ember_jump() -> void:
	_play("ember", _ember_crackle, randf_range(0.9, 1.4), -6.0)

func play_radio_tune() -> void:
	_play("tune", _radio_tune)

func play_harvest_chime() -> void:
	_play("chime", _harvest_chime)

# ---------------------------------------------------------------------------
# SFX added by the 2026-10-02 audio audit (see artifacts/audio_sfx_audit_20261002)
# ---------------------------------------------------------------------------

## Footsteps on a distance cadence; duller on bare/ashed ground
func play_footstep(ash: bool = false) -> void:
	if ash:
		_play("step_ash", _step_ash, randf_range(0.9, 1.15), -7.0, SFX_BUS, 110, 0)
	else:
		_play("step_brush", _step_brush, randf_range(0.88, 1.16), -6.0, SFX_BUS, 110, 0)

func play_ui_click() -> void:
	_play("ui_click", _ui_click, randf_range(0.96, 1.04), -6.0, UI_BUS, 50, 2)

func play_ui_focus() -> void:
	_play("ui_focus", _ui_focus, 1.0, -12.0, UI_BUS, 50, 0)

func play_tool_switch() -> void:
	_play("tool_clack", _tool_clack, randf_range(0.95, 1.08), -5.0, SFX_BUS, 90, 1)

## Valley wind actually turning: rising sweep + low rumble (distinct from gusts)
func play_wind_shift() -> void:
	_play("wind_shift", _wind_shift, randf_range(0.92, 1.06), -2.0, SFX_BUS, 2000, 2)

## Drone camera taking the evidence photo (pairs with the alarm)
func play_camera_shutter() -> void:
	_play("shutter", _shutter, randf_range(0.95, 1.07), -3.0, SFX_BUS, 120, 2)

## A flying spark settling somewhere it should not
func play_ember_landing() -> void:
	_play("ember_tick", _ember_tick, randf_range(0.9, 1.2), -8.0, SFX_BUS, 90, 0)

func play_day_start() -> void:
	_play("day_start", _day_start_stinger, 1.0, -5.0, SFX_BUS, 2000, 2)

## Phase changes at 15:30 / 18:00 / 19:45
func play_phase_stinger(idx: int) -> void:
	_play("sting_%d" % idx, _phase_stinger.bind(idx), 1.0, -4.0, SFX_BUS, 2000, 2)

## "famine" (descent) or "crackdown" (harsh low) year endings
func play_ending_stinger(kind: String) -> void:
	_play("end_" + kind, _ending_stinger.bind(kind), 1.0, -3.0, SFX_BUS, 2000, 2)

# ---------------------------------------------------------------------------
# Positional (3D) one-shots — world events carry their position
# ---------------------------------------------------------------------------

func _play_at(key: String, builder: Callable, pos: Vector3, pitch: float, volume_db: float, min_interval_ms: int = 90, stream_key: String = "") -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -100000)) < min_interval_ms:
		return
	_last_played[key] = now
	var stream := _stream_for(stream_key if stream_key != "" else key, builder)
	# prefer a free 3D voice; else steal the oldest (these are short one-shots)
	var slot := 0
	for i in _sfx3d.size():
		if not _sfx3d[i].playing:
			slot = i
			break
		else:
			if _sfx3d[i].get_playback_position() > _sfx3d[slot].get_playback_position():
				slot = i
	var p := _sfx3d[slot]
	p.global_position = pos
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func play_bamboo_pop_at(pos: Vector3) -> void:
	_play_at("pop", _bamboo_pop, pos, randf_range(0.85, 1.3), -3.0)

func play_ember_landing_at(pos: Vector3) -> void:
	_play_at("ember_tick", _ember_tick, pos, randf_range(0.9, 1.2), -8.0)

func play_cough_at(pos: Vector3, actor: String = "khanae") -> void:
	_play_at("cough_" + actor, _cough, pos, randf_range(0.96, 1.04), -4.0, 1500)

func play_shutter_at(pos: Vector3) -> void:
	_play_at("shutter", _shutter, pos, randf_range(0.95, 1.07), -3.0, 120)

## Ranger radios a sighting in from where he stands: squelch opens, then the report
func play_ranger_report_at(pos: Vector3, is_flame: bool) -> void:
	_play_at("squelch", _squelch, pos, 1.0, -4.0, 250)
	var epoch := _scene_audio_epoch
	var say := func():
		if epoch == _scene_audio_epoch:
			play_bark("report_flame" if is_flame else "report_crew", -2.0, pos)
	var tree := get_tree()
	if tree:
		tree.create_timer(0.3).timeout.connect(say)
	else:
		say.call()

func play_spot_fire() -> void:
	var now := Time.get_ticks_msec()
	if now - _fire_alarm_last >= FIRE_WARNING_INTERVAL_MS:
		_fire_alarm_last = now
		_play("spot_fire", _camera_alarm, 1.0, -8.0, SFX_BUS, 2000, 2)
	play_bark("spot_fire")

func play_fire_out() -> void:
	_play("extinguished", _water_spray, 1.0, -5.0, SFX_BUS, 1200, 1)
	play_bark("fire_out", -3.0)

func play_workshop() -> void:
	_play("workshop", _tool_clack, 1.0, -4.0, SFX_BUS, 400, 0)

func play_grain() -> void:
	_play("grain", _step_brush, 1.0, -6.0, SFX_BUS, 400, 0)

func play_truck_arrive() -> void:
	_play("truck_arrive", _drone_hum_loop, 1.0, -6.0, SFX_BUS, 3000, 0)

func set_hearth_ambience(on: bool) -> void:
	if not ambience_players.has("hearth"):
		ambience_players["hearth"] = _make_loop_player(_loop_stream("hearth", _crackle_loop), AMBIENCE_BUS)
		_targets.erase(ambience_players["hearth"])
	_ambience_targets["hearth"] = 0.25 if on else 0.0

## Mae-Lu at the granary
func play_maelu_line() -> void:
	play_bark("maelu", -3.0)

## Per-actor footstep cadence by distance travelled (fits any gait or speed)
var _step_pos: Dictionary = {}
var _step_dist: Dictionary = {}
func step_at(actor: String, pos: Vector3, ash: bool = false, spatial: bool = true) -> void:
	if not _step_pos.has(actor):
		_step_pos[actor] = pos
		_step_dist[actor] = 0.0
	_step_dist[actor] += pos.distance_to(_step_pos[actor])
	_step_pos[actor] = pos
	if _step_dist[actor] < 0.85:
		return
	_step_dist[actor] = 0.0
	if not spatial:
		_play("step_" + actor, _step_ash if ash else _step_brush, randf_range(0.94, 1.06), -10.0, SFX_BUS, 150, 0, "step_ash" if ash else "step_brush")
		return
	if ash:
		_play_at("step_ash_" + actor, _step_ash, pos, randf_range(0.9, 1.15), -7.0, 150, "step_ash")
	else:
		_play_at("step_brush_" + actor, _step_brush, pos, randf_range(0.88, 1.16), -6.0, 150, "step_brush")

## Walkie-talkie squelch (drop-in: sfx_squelch.wav)
func _squelch() -> AudioStreamWAV:
	var b = _buffer(0.45)
	for i in b.size():
		var t = float(i) / RATE
		var v := 0.0
		if t < 0.22:
			v = randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.5
		elif t > 0.26 and t < 0.42:
			v = sin(TAU * 1180.0 * (t - 0.26)) * 0.5 * (1.0 - (t - 0.26) / 0.16)
		b[i] = v
	return _to_wav(_normalize(b, 0.5))

# ---------------------------------------------------------------------------
# Loudness metering (the mix pass is verified with numbers, not vibes)
# ---------------------------------------------------------------------------

## Builds every one-shot stream without playing it, so levels can be measured
func warm_sfx_cache() -> void:
	for entry in [
		["pop", _bamboo_pop], ["whistle", _whistle], ["spray", _water_spray],
		["ping", _satellite_ping], ["cough", _cough],
		["tapoh_call", _tapoh_call], ["camera", _camera_alarm], ["beep", _beep],
		["thunder", _thunder], ["ember", _ember_crackle], ["tune", _radio_tune],
		["chime", _harvest_chime], ["step_ash", _step_ash], ["step_brush", _step_brush],
		["ui_click", _ui_click], ["ui_focus", _ui_focus], ["tool_clack", _tool_clack],
		["wind_shift", _wind_shift], ["shutter", _shutter], ["ember_tick", _ember_tick],
		["day_start", _day_start_stinger], ["sting_1", _phase_stinger.bind(1)],
		["end_famine", _ending_stinger.bind("famine")],
	]:
		_stream_for(entry[0], entry[1])

## Peak and RMS in dBFS for every synthesized stream + the linear play targets.
## Rule of thumb (game-audio practice): ambience beds peak around -22..-18 dBFS
## and events keep >=10 dB of headroom above the bed.
func mix_report() -> String:
	var sources := {
		"LOOP crackle": crackle_player.stream, "LOOP drone_hum": drone_hum_stream,
		"LOOP siren": siren_player.stream, "LOOP radio_static": static_player.stream,
	}
	for key in ambience_players:
		sources["BED " + String(key)] = ambience_players[key].stream
	for key in held_players:
		sources["HELD " + String(key)] = held_players[key].stream
	for key in _cache:
		sources["SFX " + String(key)] = _cache[key]
	var out := PackedStringArray()
	out.append("%-22s %9s %9s" % ["stream", "peak dBFS", "rms dBFS"])
	var keys := sources.keys()
	keys.sort()
	for key in keys:
		var s = sources[key]
		if s == null or not (s is AudioStreamWAV) or s.data.is_empty():
			continue
		var peak := 0.0
		var sum := 0.0
		if s.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			continue
		var bytes := 1 if s.format == AudioStreamWAV.FORMAT_8_BITS else 2
		var count: int = s.data.size() / bytes
		for i in count:
			var v: float = (s.data.decode_u8(i) - 128) / 128.0 if s.format == AudioStreamWAV.FORMAT_8_BITS \
				else s.data.decode_s16(i * 2) / 32767.0
			peak = maxf(peak, absf(v))
			sum += v * v
		var rms := sqrt(sum / maxf(1.0, float(count)))
		out.append("%-22s %9.1f %9.1f" % [key, linear_to_db(maxf(peak, 0.0001)), linear_to_db(maxf(rms, 0.0001))])
	out.append("")
	out.append("play targets (linear): crackle<=0.35 siren=0.30 static<=0.22 (drone hum: 3D per-drone)")
	out.append("held %s" % str(HELD_LEVELS))
	out.append("music %s" % str(_music_layer_targets))
	return "\n".join(out)

# ---------------------------------------------------------------------------
# Synthesis helpers
# ---------------------------------------------------------------------------

static func _buffer(seconds: float) -> PackedFloat32Array:
	var b = PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

static func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

static func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m = 0.0001
	for v in b:
		m = maxf(m, absf(v))
	for i in b.size():
		b[i] = b[i] / m * peak
	return b

## Two-pole resonator (formant / band-pass) applied in place
static func _resonate(src: PackedFloat32Array, freq_from: float, freq_to: float, r: float) -> PackedFloat32Array:
	var out = PackedFloat32Array()
	out.resize(src.size())
	var y1 = 0.0
	var y2 = 0.0
	for i in src.size():
		var f = lerpf(freq_from, freq_to, float(i) / src.size())
		var c = 2.0 * r * cos(TAU * f / RATE)
		var y = src[i] + c * y1 - r * r * y2
		y2 = y1
		y1 = y
		out[i] = y
	return out

## Karplus-Strong plucked string (Tena harp), mixed into a looping buffer
static func _pluck(buf: PackedFloat32Array, start: int, freq: float, amp: float, seconds: float, rng: RandomNumberGenerator) -> void:
	var period = maxi(2, int(RATE / freq))
	var ring = PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = rng.randf_range(-1.0, 1.0)
	var n = int(seconds * RATE)
	var size = buf.size()
	var idx = 0
	for i in n:
		var cur = ring[idx]
		var nxt = ring[(idx + 1) % period]
		ring[idx] = 0.5 * (cur + nxt) * 0.996
		buf[(start + i) % size] += cur * amp
		idx = (idx + 1) % period

# ---------------------------------------------------------------------------
# SFX recipes
# ---------------------------------------------------------------------------

func _bamboo_pop() -> AudioStreamWAV:
	var b = _buffer(0.3)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = randf_range(-1.0, 1.0) * exp(-t * 22.0) * 0.8 + sin(TAU * 90.0 * t) * exp(-t * 30.0) * 0.6
	return _to_wav(_normalize(b, 0.9))

func _whistle() -> AudioStreamWAV:
	var b = _buffer(0.35)
	for i in b.size():
		var t = float(i) / RATE
		var f = 1450.0 if t < 0.18 else 1450.0 * 1.25
		var env = 1.0 if t < 0.3 else (1.0 - (t - 0.3) / 0.05)
		b[i] = sin(TAU * f * t) * env * 0.75
	return _to_wav(b)

func _water_spray() -> AudioStreamWAV:
	var b = _buffer(0.3)
	var lp = 0.0
	for i in b.size():
		var t = float(i) / RATE
		var n = randf_range(-1.0, 1.0)
		lp = lp * 0.4 + n * 0.6
		b[i] = (n - lp) * exp(-t * 10.0) * 0.6
	return _to_wav(_normalize(b, 0.6))

func _satellite_ping() -> AudioStreamWAV:
	var b = _buffer(0.5)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = sin(TAU * 880.0 * t) * exp(-t * 6.0) * 0.85
	return _to_wav(b)

func _cough() -> AudioStreamWAV:
	var b = _buffer(0.8)
	for burst_start in [0.0, 0.26, 0.5]:
		var s = int(burst_start * RATE)
		var lp = 0.0
		for i in int(0.22 * RATE):
			var t = float(i) / RATE
			lp = lp * 0.75 + randf_range(-1.0, 1.0) * 0.25
			var env = minf(t / 0.015, 1.0) * exp(-t * 14.0)
			b[s + i] += (lp * 2.5 + sin(TAU * 170.0 * t) * 0.3) * env
	return _to_wav(_normalize(b, 0.7))

## Synthesized "Oo-ay!" call: voiced sawtooth through two moving formants
func _tapoh_call() -> AudioStreamWAV:
	var b = _buffer(1.1)
	var phase = 0.0
	for i in b.size():
		var t = float(i) / RATE
		var f0 = lerpf(150.0, 185.0, minf(t / 0.4, 1.0)) - maxf(0.0, t - 0.6) * 40.0
		f0 *= 1.0 + 0.02 * sin(TAU * 5.5 * t)
		phase = fmod(phase + f0 / RATE, 1.0)
		var env = minf(t / 0.05, 1.0) * clampf((1.1 - t) / 0.3, 0.0, 1.0)
		b[i] = (phase * 2.0 - 1.0) * env
	var f1 = _resonate(b, 420.0, 680.0, 0.985)
	var f2 = _resonate(b, 820.0, 1750.0, 0.98)
	for i in b.size():
		b[i] = f1[i] + f2[i] * 0.6
	return _to_wav(_normalize(b, 0.8))

func _camera_alarm() -> AudioStreamWAV:
	var b = _buffer(0.64)
	for i in b.size():
		var t = float(i) / RATE
		var f = 1400.0 if int(t / 0.08) % 2 == 0 else 1000.0
		b[i] = signf(sin(TAU * f * t)) * 0.35
	return _to_wav(b)

func _beep() -> AudioStreamWAV:
	var b = _buffer(0.09)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = sin(TAU * 1000.0 * t) * 0.6 * minf(1.0, (0.09 - t) / 0.02)
	return _to_wav(b)

func _thunder() -> AudioStreamWAV:
	var b = _buffer(2.8)
	var brown = 0.0
	for i in b.size():
		var t = float(i) / RATE
		brown = clampf(brown + randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0)
		var crack = randf_range(-1.0, 1.0) * exp(-t * 18.0)
		b[i] = brown * minf(t / 0.05, 1.0) * exp(-t * 1.1) + crack * 0.5
	return _to_wav(_normalize(b, 0.9))

func _ember_crackle() -> AudioStreamWAV:
	var b = _buffer(0.25)
	for k in 5:
		var s = randi_range(0, b.size() - 400)
		for i in 300:
			b[s + i] += randf_range(-1.0, 1.0) * exp(-float(i) / 60.0)
	return _to_wav(_normalize(b, 0.6))

func _radio_tune() -> AudioStreamWAV:
	var b = _buffer(0.45)
	var phase = 0.0
	for i in b.size():
		var t = float(i) / RATE
		phase += lerpf(2200.0, 400.0, t / 0.45) / RATE
		b[i] = randf_range(-1.0, 1.0) * 0.35 + sin(TAU * phase) * 0.25
	return _to_wav(b)

func _harvest_chime() -> AudioStreamWAV:
	var b = _buffer(2.2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var notes = [293.66, 349.23, 392.0, 440.0, 587.33]
	for k in notes.size():
		_pluck(b, int(k * 0.18 * RATE), notes[k], 0.5, 1.6, rng)
	return _to_wav(_normalize(b, 0.7))

# ---------------------------------------------------------------------------
# Audit-2026-10-02 recipes (steps, UI, tools, wind shift, shutter, embers, stingers)
# ---------------------------------------------------------------------------

func _step_brush() -> AudioStreamWAV:
	var b = _buffer(0.11)
	for k in 3:
		var s = randi_range(0, b.size() - 300)
		for i in 260:
			b[s + i] += randf_range(-1.0, 1.0) * exp(-float(i) / 40.0) * 0.5
	var lp = 0.0
	for i in b.size():
		lp = lp * 0.72 + randf_range(-1.0, 1.0) * 0.28
		b[i] += lp * 0.35 * exp(-float(i) / (0.03 * RATE))
	return _to_wav(_normalize(b, 0.7))

func _step_ash() -> AudioStreamWAV:
	var b = _buffer(0.13)
	var lp = 0.0
	for i in b.size():
		var t = float(i) / RATE
		lp = lp * 0.85 + randf_range(-1.0, 1.0) * 0.15
		b[i] = lp * 0.8 * exp(-t * 22.0) + sin(TAU * 70.0 * t) * exp(-t * 26.0) * 0.5
	return _to_wav(_normalize(b, 0.6))

func _ui_click() -> AudioStreamWAV:
	var b = _buffer(0.05)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = (sin(TAU * 900.0 * t) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * exp(-t * 160.0)
	return _to_wav(_normalize(b, 0.5))

func _ui_focus() -> AudioStreamWAV:
	var b = _buffer(0.035)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = sin(TAU * 2100.0 * t) * exp(-t * 220.0) * 0.5
	return _to_wav(_normalize(b, 0.35))

func _tool_clack() -> AudioStreamWAV:
	var b = _buffer(0.12)
	for i in b.size():
		var t = float(i) / RATE
		b[i] = randf_range(-1.0, 1.0) * exp(-t * 130.0) * 0.7 + sin(TAU * 320.0 * t) * exp(-t * 70.0) * 0.5
	return _to_wav(_normalize(b, 0.55))

func _wind_shift() -> AudioStreamWAV:
	var b = _buffer(1.2)
	var lp = 0.0
	for i in b.size():
		var t = float(i) / RATE
		var a = 0.05 + 0.25 * sin(PI * minf(t / 1.2, 1.0))
		lp = lp * (1.0 - a) + randf_range(-1.0, 1.0) * a
		b[i] = lp * sin(PI * pow(t / 1.2, 0.7)) * 1.2 + sin(TAU * 55.0 * t) * exp(-t * 2.2) * 0.25
	return _to_wav(_normalize(b, 0.7))

func _shutter() -> AudioStreamWAV:
	var b = _buffer(0.18)
	for burst in [0.0, 0.075]:
		var s = int(burst * RATE)
		for i in int(0.035 * RATE):
			b[s + i] += randf_range(-1.0, 1.0) * exp(-float(i) / 14.0) * 0.8
	for i in b.size():
		var t = float(i) / RATE
		b[i] += sin(TAU * 2600.0 * t) * exp(-t * 40.0) * 0.12
	return _to_wav(_normalize(b, 0.6))

func _ember_tick() -> AudioStreamWAV:
	var b = _buffer(0.22)
	for k in 3:
		var s = randi_range(0, b.size() - 800)
		for i in 600:
			b[s + i] += randf_range(-1.0, 1.0) * exp(-float(i) / 90.0) * 0.5
	return _to_wav(_normalize(b, 0.5))

## Short plucked motifs on the Tena harp scale, one per phase (3, 2, 4, 5 notes)
func _phase_stinger(idx: int) -> AudioStreamWAV:
	var b = _buffer(1.6)
	var rng = RandomNumberGenerator.new()
	rng.seed = 900 + idx
	var scale = [293.66, 349.23, 392.0, 440.0, 587.33, 698.46]
	var seq = [[2, 4], [1, 3, 5], [4, 5], [3, 5, 3]][clampi(idx, 0, 3)]
	for k in seq.size():
		_pluck(b, int(k * 0.22 * RATE), scale[seq[k]], 0.5, 1.2, rng)
	return _to_wav(_normalize(b, 0.65))

func _day_start_stinger() -> AudioStreamWAV:
	var b = _buffer(2.4)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5150
	var scale = [293.66, 349.23, 392.0, 440.0, 587.33, 698.46, 783.99]
	_pluck(b, 0, 146.83, 0.5, 2.2, rng) # low open-string root under the run
	for k in 5:
		_pluck(b, int(k * 0.18 * RATE), scale[k + 1], 0.42, 1.5, rng)
	return _to_wav(_normalize(b, 0.65))

func _ending_stinger(kind: String) -> AudioStreamWAV:
	var b = _buffer(2.6)
	var rng = RandomNumberGenerator.new()
	rng.seed = 77 if kind == "famine" else 99
	var low = [146.83, 138.59, 116.54] if kind == "famine" else [110.0, 103.83, 98.0]
	for k in 3:
		_pluck(b, int(k * 0.5 * RATE), low[k], 0.55, 1.8, rng)
	if kind == "crackdown":
		for i in int(1.2 * RATE):
			var t = float(i) / RATE
			b[i] += signf(sin(TAU * 180.0 * t)) * exp(-t * 3.0) * 0.12
	return _to_wav(_normalize(b, 0.7))

# ---------------------------------------------------------------------------
# Held-work loops (seamless: integer cycles / wrap-around writes)
# ---------------------------------------------------------------------------

func _water_spray_loop() -> AudioStreamWAV:
	var b = _buffer(2.0)
	var lp = 0.0
	for i in b.size():
		var n = randf_range(-1.0, 1.0)
		lp = lp * 0.55 + n * 0.45
		var wobble = 0.8 + 0.2 * sin(TAU * 3.0 * float(i) / b.size())
		b[i] = (n - lp) * 0.7 * wobble
	return _to_wav(_normalize(b, 0.32), true)

func _torch_loop() -> AudioStreamWAV:
	var b = _buffer(2.5)
	var size = b.size()
	var lp = 0.0
	for i in size:
		lp = lp * 0.93 + randf_range(-1.0, 1.0) * 0.07
		b[i] = lp * 2.2
	for k in 26:
		var s = randi_range(0, size - 1)
		for i in 350:
			b[(s + i) % size] += randf_range(-1.0, 1.0) * exp(-float(i) / 70.0) * 0.45
	return _to_wav(_normalize(b, 0.34), true)

func _rake_loop() -> AudioStreamWAV:
	var b = _buffer(1.8)
	var size = b.size()
	for scrape in [0.0, 0.62, 1.2]:
		var s = int(scrape / 1.8 * size)
		for i in int(0.28 * RATE):
			var t = float(i) / (0.28 * RATE)
			b[(s + i) % size] += randf_range(-1.0, 1.0) * sin(PI * t) * 0.5 * (0.6 + 0.4 * sin(TAU * 9.0 * t))
	var lp = 0.0
	for i in size:
		lp = lp * 0.8 + randf_range(-1.0, 1.0) * 0.2
		b[i] += lp * 0.15
	return _to_wav(_normalize(b, 0.28), true)

func _refill_loop() -> AudioStreamWAV:
	var b = _buffer(1.6)
	var size = b.size()
	var rng = RandomNumberGenerator.new()
	rng.seed = 31
	for k in 12:
		var s = rng.randi_range(0, size - 1)
		var f0 = rng.randf_range(300.0, 700.0)
		for i in int(0.09 * RATE):
			var t = float(i) / RATE
			b[(s + i) % size] += sin(TAU * f0 * (1.0 + t * 3.0) * t) * exp(-t * 55.0) * 0.35
	var lp = 0.0
	for i in size:
		lp = lp * 0.7 + randf_range(-1.0, 1.0) * 0.3
		b[i] += lp * 0.2
	return _to_wav(_normalize(b, 0.3), true)

# ---------------------------------------------------------------------------
# Loop recipes (seamless: integer cycles / wrap-around writes)
# ---------------------------------------------------------------------------

func _crackle_loop() -> AudioStreamWAV:
	var b = _buffer(3.0)
	var size = b.size()
	var lp = 0.0
	for i in size:
		lp = lp * 0.97 + randf_range(-1.0, 1.0) * 0.03
		b[i] = lp * 1.5
	for k in 90:
		var s = randi_range(0, size - 1)
		var amp = randf_range(0.2, 1.0)
		var decay = randf_range(30.0, 120.0)
		for i in 500:
			b[(s + i) % size] += randf_range(-1.0, 1.0) * amp * exp(-float(i) / decay)
	return _to_wav(_normalize(b, 0.35), true)

func _drone_hum_loop() -> AudioStreamWAV:
	var b = _buffer(1.0)
	var rotors = [165.0, 172.0, 180.0, 188.0]
	for i in b.size():
		var t = float(i) / RATE
		var v = 0.0
		for f in rotors:
			for h in range(1, 5):
				v += sin(TAU * f * h * t) / h
		b[i] = v * (0.85 + 0.15 * sin(TAU * 12.0 * t))
	return _to_wav(_normalize(b, 0.45), true)

func _siren_loop() -> AudioStreamWAV:
	var b = _buffer(2.0)
	var phase = 0.0
	for i in b.size():
		var t = float(i) / RATE
		var tri = 1.0 - absf(fmod(t, 2.0) - 1.0) # 0 -> 1 -> 0 over the loop
		phase += lerpf(650.0, 1150.0, tri) / RATE
		b[i] = sin(TAU * phase) * 0.7 + sin(TAU * phase * 2.0) * 0.15
	return _to_wav(b, true)

func _radio_static_loop() -> AudioStreamWAV:
	var b = _buffer(1.0)
	var lp = 0.0
	for i in b.size():
		var n = randf_range(-1.0, 1.0)
		lp = lp * 0.6 + n * 0.4
		b[i] = lp * 0.4 + (randf_range(-1.0, 1.0) if randf() < 0.002 else 0.0)
	return _to_wav(_normalize(b, 0.3), true)

# ---------------------------------------------------------------------------
# Ambience beds (seamless): valley wind and a daytime cicada chorus
# ---------------------------------------------------------------------------

func _wind_bed_loop() -> AudioStreamWAV:
	var b = _buffer(4.0)
	var size = b.size()
	var lp = 0.0
	for i in size:
		var ph = TAU * float(i) / size
		var swell = 0.6 + 0.4 * sin(ph) + 0.2 * sin(ph * 2.0)
		lp = lp * 0.965 + randf_range(-1.0, 1.0) * 0.035
		b[i] = lp * 2.0 * swell
	return _to_wav(_normalize(b, 0.22), true)

func _cicada_bed_loop() -> AudioStreamWAV:
	var b = _buffer(3.0)
	var size = b.size()
	var band = [4200.0, 5200.0, 6100.0] # integer cycles per 3 s loop: no wrap click
	for i in size:
		var ph = TAU * float(i) / size
		var chorus = 0.0
		for k in band.size():
			var gate = maxf(0.0, sin(ph * (6.0 + k * 2.0) + k * 2.1))
			chorus += (randf_range(-1.0, 1.0) * 0.5 + sin(TAU * band[k] * float(i) / RATE) * 0.5) * gate
		b[i] = chorus * 0.25
	return _to_wav(_normalize(b, 0.18), true)

# ---------------------------------------------------------------------------
# Music: Karen Tena harp + khaen-style reed drone + bamboo percussion
# ---------------------------------------------------------------------------

## Builds the job list that renders the three 16 s music loops
func _queue_music_jobs() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 2026
	var beat = MUSIC_LOOP_SECONDS / 20.0 # 75 BPM, 20 beats per loop
	# D minor pentatonic (the Tena harp is tuned pentatonically)
	var scale = [293.66, 349.23, 392.0, 440.0, 523.25, 587.33, 698.46]
	_music_layers = [_buffer(MUSIC_LOOP_SECONDS), _buffer(MUSIC_LOOP_SECONDS), _buffer(MUSIC_LOOP_SECONDS)]
	var size = _music_layers[0].size()
	const CHUNK = 16384
	
	# Layer 0: khaen-style reed drone + sparse harp phrases
	for start in range(0, size, CHUNK):
		_music_jobs.append(_job_drone.bind(start, mini(start + CHUNK, size)))
	for k in range(0, 20, 2):
		_music_jobs.append(_job_pluck.bind(0, int(k * beat * RATE), scale[rng.randi_range(0, 4)], 0.35, beat * 2.2, rng.randi()))
	
	# Layer 1: flowing harp arpeggio, an octave up, eighth notes
	var step = 0
	for k in 40:
		step = clampi(step + rng.randi_range(-2, 2), 0, scale.size() - 1)
		_music_jobs.append(_job_pluck.bind(1, int(k * beat * 0.5 * RATE), scale[step] * 2.0, 0.18, beat * 1.2, rng.randi()))
	
	# Layer 2: bamboo tube heartbeat + shaker + low tension tone
	for k in 20:
		_music_jobs.append(_job_thump.bind(int(k * beat * RATE), int(beat * 0.5 * RATE), k, rng.randi()))
	for start in range(0, size, CHUNK):
		_music_jobs.append(_job_tension.bind(start, mini(start + CHUNK, size)))
	
	# Finish: normalise and encode each layer as a seamless loop
	for layer in 3:
		_music_jobs.append(_job_normalize.bind(layer, [0.7, 0.6, 0.7][layer]))
		_music_jobs.append(_job_encode.bind(layer))
	_music_jobs.append(_job_publish)

func _run_music_jobs() -> void:
	var t0 = Time.get_ticks_msec()
	while not _music_jobs.is_empty() and Time.get_ticks_msec() - t0 < MUSIC_FRAME_BUDGET_MS:
		var job: Callable = _music_jobs.pop_front()
		job.call()

func _job_drone(from: int, to: int) -> void:
	var l0: PackedFloat32Array = _music_layers[0]
	var drone = [146.8125, 220.0, 293.6875] # snapped to 1/16 Hz for a seamless loop
	for i in range(from, to):
		var t = float(i) / RATE
		var swell = 0.6 + 0.4 * sin(TAU * t / MUSIC_LOOP_SECONDS)
		var v = 0.0
		for f in drone:
			v += sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.4 + sin(TAU * f * 3.0 * t) * 0.25
		l0[i] = v * 0.05 * swell

func _job_pluck(layer: int, start: int, freq: float, amp: float, seconds: float, seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	_pluck(_music_layers[layer], start, freq, amp, seconds, rng)

func _job_thump(start: int, offbeat: int, k: int, seed: int) -> void:
	var l2: PackedFloat32Array = _music_layers[2]
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	for i in int(0.3 * RATE):
		var t = float(i) / RATE
		l2[(start + i) % l2.size()] += sin(TAU * (60.0 + 60.0 * exp(-t * 18.0)) * t) * exp(-t * 9.0) * (0.9 if k % 2 == 0 else 0.6)
	for i in int(0.05 * RATE):
		l2[(start + offbeat + i) % l2.size()] += rng.randf_range(-1.0, 1.0) * 0.25 * exp(-float(i) / 300.0)

func _job_tension(from: int, to: int) -> void:
	var l2: PackedFloat32Array = _music_layers[2]
	for i in range(from, to):
		var t = float(i) / RATE
		l2[i] += (sin(TAU * 110.0 * t) + sin(TAU * 116.5625 * t)) * 0.04

func _job_normalize(layer: int, peak: float) -> void:
	_normalize(_music_layers[layer], peak)

func _job_encode(layer: int) -> void:
	_music_streams.append(_to_wav(_music_layers[layer], true))

func _job_publish() -> void:
	_state_music = ResourceLoader.exists(AUDIO_DIR + "/music_states.tres")
	if _state_music and _music_layer_targets != [0.0, 0.0, 0.0]:
		_set_state_music()
	for i in 3:
		music_players[i].stream = _music_stream(i)
	_music_layers.clear()
	music_ready = true

## Music layers honour sfxloop_music<0|1|2>.wav drop-ins (complete state tracks from
## ElevenLabs); synthesized layers remain the fallback
func _music_stream(i: int) -> AudioStreamWAV:
	return _loop_stream("music%d" % i, func(): return _music_streams[i])
