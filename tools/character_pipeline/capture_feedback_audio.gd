extends SceneTree
## Deterministic burst at real time; legacy scheduling emulated without editing production.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var a = root.get_node("AudioManager")
	a.set_process(false)
	a.fire_diagnostics = true
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recorder)
	for legacy in [true,false]:
		a.stop_all_loops()
		a.fire_warning_log.clear()
		recorder.set_recording_active(true)
		for tick in 100:
			# Several bamboo bursts, then a forest ignition, followed by related reminders.
			if tick in [0,1,2,3,4,30,45,60,75,90]:
				if legacy:
					a._fire_voice_last = -100000
					a._speech_kind = ""
				a.play_bark("embers")
			if tick in [10,11,12,13,14,35,50,65,80,95]:
				if legacy:
					a._fire_voice_last = -100000
					a._speech_kind = ""
					a._play("spot_fire", a._camera_alarm, 1.0, -3.0, a.SFX_BUS, 2000, 2)
					a.play_bark("spot_fire")
				else: a.play_spot_fire()
			await create_timer(0.1).timeout
		a.stop_all_loops()
		await create_timer(0.5).timeout
		recorder.set_recording_active(false)
		var wav := recorder.get_recording()
		wav.save_to_wav(output.path_join("fire_burst_%s.wav" % ("before" if legacy else "after")))
		var f := FileAccess.open(output.path_join("fire_burst_%s.json" % ("before" if legacy else "after")),FileAccess.WRITE)
		f.store_string(JSON.stringify(a.fire_warning_log,"\t"))
		f.close()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	quit()
