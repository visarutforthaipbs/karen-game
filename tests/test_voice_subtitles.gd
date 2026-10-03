extends SceneTree

## Checks exact recorded speech captions, suppression, preemption and live locale.
## godot --headless --path . --script res://tests/test_voice_subtitles.gd
var failures: int = 0
var events: Array[Dictionary] = []

func check(condition: bool, message: String) -> void:
	print("PASS  " if condition else "FAIL  ", message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _capture(speaker: String, text: String, duration: float) -> void:
	events.append({"speaker": speaker, "text": text, "duration": duration})

func _run() -> void:
	await process_frame
	var audio = root.get_node("AudioManager")
	var original_locale = TranslationServer.get_locale()
	audio.stop_all_loops()
	audio.voice_caption_changed.connect(_capture)
	L10n.set_locale("en")
	check(audio.voice_captions.size() == 30, "all 30 current production speech transcripts available")
	var streams: Array = audio._tapoh_voices.duplicate()
	for pool in audio._radio_voices.values(): streams.append_array(pool)
	for pool in audio._bark_voices.values(): streams.append_array(pool)
	for stream in streams:
		check(audio.voice_captions.has(stream.resource_path.get_file()), "recorded clip has exact subtitle: " + stream.resource_path.get_file())

	audio.play_radio_voice(1)
	check(events.size() == 1 and audio.radio_player.playing, "radio caption emitted when recorded line plays")
	var chosen: Dictionary = audio.voice_captions[audio.radio_player.stream.resource_path.get_file()]
	check(events[-1].text == chosen.th and is_equal_approx(events[-1].duration, audio.radio_player.stream.get_length()), "caption and duration match chosen random radio recording")
	check(audio.subtitle_overlay.line_label.tr(audio.subtitle_overlay.line_label.text) == chosen.en, "overlay presents English transcript")
	L10n.set_locale("th")
	await process_frame
	check(not audio.radio_player.playing and not audio.subtitle_overlay.card.visible and events[-1].text.is_empty(), "live language switch stops the old-language line and clears its caption")
	audio.play_radio_voice(1)
	chosen = audio.voice_captions[audio.radio_player.stream.resource_path.get_file()]
	check(audio.subtitle_overlay.line_label.tr(audio.subtitle_overlay.line_label.text) == chosen.th, "next recorded line presents Thai transcript")
	L10n.set_locale("en")
	audio.play_hearth_music(true)
	check(events[-1].text.is_empty() and not audio.subtitle_overlay.card.visible, "tuning away clears interrupted radio caption")

	audio.play_radio_voice(2)
	var before: int = events.size()
	audio.play_bark("spot_fire")
	check(events.size() == before + 2 and events[before].text.is_empty() and not events[-1].text.is_empty(), "urgent crew speech clears and replaces radio caption")
	chosen = audio.voice_captions[audio.speech_player.stream.resource_path.get_file()]
	check(events[-1].text == chosen.th and events[-1].speaker == chosen.speaker, "urgent caption follows exact chosen speaker and clip")
	before = events.size()
	audio.play_bark("maelu")
	audio.play_radio_voice(1)
	check(events.size() == before, "suppressed low-priority speech and busy-radio calls emit no captions")
	audio.play_bark("spot_fire")
	check(events.size() == before, "rate-limited repeat emits no duplicate subtitle")
	audio.set_held_loop("spray", true)
	var held_target = audio._targets[audio.held_players["spray"]]
	paused = true
	L10n.set_locale("th")
	check(not audio.speech_player.playing and not audio.subtitle_overlay.card.visible, "paused language switch immediately clears accepted crew speech")
	check(audio._targets[audio.held_players["spray"]] == held_target, "language change preserves held spray loop")
	paused = false
	audio.play_bark("spot_fire")
	check(audio.speech_player.playing and not events[-1].text.is_empty(), "language switch resets speech cooldown for immediate matching-language reply")
	L10n.set_locale("en")

	audio.stop_all_loops()
	check(events[-1].text.is_empty() and not audio.subtitle_overlay.card.visible, "scene audio reset immediately clears dialogue")
	audio.play_bark("report_flame", -2.0, Vector3.ZERO)
	check(audio.speech_player_3d.playing and not events[-1].text.is_empty(), "spatial ranger recording produces matching caption")
	chosen = audio.voice_captions[audio.speech_player_3d.stream.resource_path.get_file()]
	check(events[-1].text == chosen.th, "spatial ranger transcript matches played recording")
	audio.speech_player_3d.stop()
	await process_frame
	await process_frame
	check(events[-1].text.is_empty(), "direct playback stop clears caption on next frame")

	audio.stop_all_loops()
	audio.play_bark("fire_out")
	## Audio playback runs on wall time; do not accelerate this test with --fixed-fps.
	var duration: float = audio.speech_player.stream.get_length()
	await create_timer(duration + 0.25).timeout
	check(events[-1].text.is_empty() and not audio.subtitle_overlay.card.visible, "natural recording completion clears caption")
	L10n.set_locale(original_locale)
	audio.stop_all_loops()
	print("Voice subtitle failures: ", failures)
	quit(1 if failures else 0)
