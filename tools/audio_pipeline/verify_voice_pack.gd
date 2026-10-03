extends SceneTree

## External probe against an exported PCK, with its imported-resource hash list.
## Does not write settings or campaigns. Run from an empty working directory.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var arguments = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Supply the absolute exported-voice hash manifest path")
		quit(1)
		return
	var rows = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var failures = 0
	for row in rows:
		var stream = load("res://" + row.file) as AudioStream
		var hash = HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(FileAccess.get_file_as_bytes(row.imported_file))
		var matches = hash.finish().hex_encode() == row.imported_sha256
		if not stream or not matches or absf(stream.get_length() - float(row.seconds)) > 0.05:
			failures += 1
			print("FAIL exported recording: ", row.file)
	var audio = root.get_node("AudioManager")
	load("res://scripts/L10n.gd").set_locale("en")
	audio.play_radio_voice(1)
	if not audio.radio_player.playing or not audio.radio_player.stream.resource_path.begins_with("res://assets/audio/en/"):
		failures += 1
	audio.stop_all_loops()
	print("EXPORTED V4 VOICES: ", rows.size(), " exact imported resources; ", failures, " failures")
	await create_timer(0.2).timeout
	quit(1 if failures else 0)
