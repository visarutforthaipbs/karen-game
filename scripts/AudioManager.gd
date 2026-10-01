extends Node

## Procedural sound & music synthesis (PRD §9.2) — zero audio files required.
## One-shot SFX play through a small voice pool; loops (fire, drone, siren,
## radio) and the three music layers fade toward target volumes every frame.

static var instance: Node

const RATE: int = 22050
const SFX_VOICES: int = 8
const MUSIC_LOOP_SECONDS: float = 16.0
const SILENT_DB: float = -60.0

## Optional recorded voice line; falls back to a synthesized call if missing
const TAPOH_VOICE_PATH = "res://assets/audio/tapoh_wind_warning.wav"

var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _cache: Dictionary = {}

# Loop players and their target linear volumes
var crackle_player: AudioStreamPlayer
var hum_player: AudioStreamPlayer
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
	for i in SFX_VOICES:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

	crackle_player = _make_loop_player(_crackle_loop())
	hum_player = _make_loop_player(_drone_hum_loop())
	siren_player = _make_loop_player(_siren_loop())
	static_player = _make_loop_player(_radio_static_loop())
	for i in 3:
		var mp = AudioStreamPlayer.new()
		mp.volume_db = SILENT_DB
		add_child(mp)
		music_players.append(mp)

	_queue_music_jobs()

func _exit_tree() -> void:
	# Release playbacks so nothing is left referenced at shutdown
	for p in _sfx + music_players:
		p.stop()
		p.stream = null
	for p in _targets.keys():
		p.stop()
		p.stream = null

func _make_loop_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = SILENT_DB
	add_child(p)
	_targets[p] = 0.0
	return p

func _process(delta: float) -> void:
	if not music_ready:
		_run_music_jobs()

	for p in _targets.keys():
		_fade_player(p, _targets[p], delta)
	if music_ready:
		for i in 3:
			_fade_player(music_players[i], _music_layer_targets[i], delta)

## Fades a looping player toward a linear volume, starting / stopping it as needed
func _fade_player(p: AudioStreamPlayer, target: float, delta: float) -> void:
	var current = db_to_linear(p.volume_db) if p.playing else 0.0
	var next = move_toward(current, target, delta * 0.8)
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
	_targets[crackle_player] = clampf(level, 0.0, 1.0) * 0.8

## 0..1: how close the nearest drone is to the player (rotor hum grows loud)
func set_drone_proximity(level: float) -> void:
	_targets[hum_player] = clampf(level, 0.0, 1.0) * 0.7

func set_siren(on: bool) -> void:
	_targets[siren_player] = 0.35 if on else 0.0

func set_radio_static(level: float) -> void:
	_targets[static_player] = clampf(level, 0.0, 1.0) * 0.5

## 0 calm .. 3 satellite countdown: layers come in as the deadline approaches
func set_music_intensity(level: int) -> void:
	match level:
		0: _music_layer_targets = [0.45, 0.0, 0.0]
		1: _music_layer_targets = [0.45, 0.3, 0.0]
		2: _music_layer_targets = [0.4, 0.35, 0.3]
		_: _music_layer_targets = [0.4, 0.45, 0.55]

## Quiet harp-and-khaen bed for the hearth / folk radio
func play_hearth_music(on: bool) -> void:
	_music_layer_targets = [0.4, 0.0, 0.0] if on else [0.0, 0.0, 0.0]

func stop_all_loops() -> void:
	for p in _targets.keys():
		_targets[p] = 0.0
	_music_layer_targets = [0.0, 0.0, 0.0]

# ---------------------------------------------------------------------------
# One-shot SFX
# ---------------------------------------------------------------------------

func _play(key: String, builder: Callable, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _cache.has(key):
		_cache[key] = builder.call()
	var p = _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = _cache[key]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func play_bamboo_pop() -> void:
	_play("pop", _bamboo_pop, randf_range(0.85, 1.3))

func play_whistle() -> void:
	_play("whistle", _whistle)

func play_water_spray() -> void:
	_play("spray", _water_spray, randf_range(0.9, 1.1), -4.0)

func play_satellite_ping() -> void:
	_play("ping", _satellite_ping)

func play_cough() -> void:
	_play("cough", _cough, randf_range(0.9, 1.1))

func play_wind_gust() -> void:
	_play("gust", _wind_gust, randf_range(0.9, 1.1), -3.0)

func play_tapoh_warning() -> void:
	if ResourceLoader.exists(TAPOH_VOICE_PATH):
		if not _cache.has("tapoh_voice"):
			_cache["tapoh_voice"] = load(TAPOH_VOICE_PATH)
		_play("tapoh_voice", func(): return _cache["tapoh_voice"])
	else:
		_play("tapoh_call", _tapoh_call)

func play_camera_alarm() -> void:
	_play("camera", _camera_alarm, 1.0, -4.0)

func play_countdown_beep() -> void:
	_play("beep", _beep, 1.0, -6.0)

func play_thunder() -> void:
	_play("thunder", _thunder, randf_range(0.8, 1.05))

func play_ember_jump() -> void:
	_play("ember", _ember_crackle, randf_range(0.9, 1.4), -6.0)

func play_radio_tune() -> void:
	_play("tune", _radio_tune)

func play_harvest_chime() -> void:
	_play("chime", _harvest_chime)

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

func _wind_gust() -> AudioStreamWAV:
	var b = _buffer(1.6)
	var lp = 0.0
	for i in b.size():
		var t = float(i) / RATE
		var a = 0.02 + 0.08 * sin(PI * t / 1.6)
		lp = lp * (1.0 - a) + randf_range(-1.0, 1.0) * a
		b[i] = lp * sin(PI * t / 1.6)
	return _to_wav(_normalize(b, 0.6))

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
	return _to_wav(_normalize(b, 0.8), true)

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
	return _to_wav(_normalize(b, 0.7), true)

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
	return _to_wav(_normalize(b, 0.5), true)

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
	for i in 3:
		music_players[i].stream = _music_streams[i]
	_music_layers.clear()
	music_ready = true
