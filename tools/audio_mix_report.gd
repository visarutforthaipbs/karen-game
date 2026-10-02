## Loudness report for the SFX mix pass. Run:
##   godot --headless --path . --script tools/audio_mix_report.gd
## Prints peak + RMS in dBFS for every synthesized stream and the play targets.
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var am = root.get_node("AudioManager")
	am.warm_sfx_cache()
	am.set_held_loop("spray", true)
	am.set_held_loop("ignite", true)
	am.set_held_loop("rake", true)
	am.set_held_loop("refill", true)
	print(am.mix_report())
	quit(0)
