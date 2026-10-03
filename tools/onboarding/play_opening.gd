extends SceneTree

## Standalone playback/review, never touches the player's settings or saves.
## godot --path . --script res://tools/onboarding/play_opening.gd -- --en
## Add --write-movie artifacts/opening_20261003/opening_th.avi --fixed-fps 30
## before `--` for a native engine recording with narration and music.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	GameSettings.dir = "user://opening_standalone/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GameSettings.dir))
	GameSettings.load_settings()
	root.size = Vector2i(1280, 720)
	GameSettings.apply(self)
	if OS.has_feature("movie"):
		# Keep the review canvas fixed if the desktop window manager tiles it.
		root.min_size = Vector2i(1280, 720)
		root.max_size = Vector2i(1280, 720)
		root.size = Vector2i(1280, 720)
	root.get_node("Localization").set_language("en" if OS.get_cmdline_user_args().has("--en") else "th")
	var film = OpeningFilm.new()
	root.add_child(film)
	film.closed.connect(func(): quit())
	if OS.has_feature("movie"):
		var duration = 4.0
		for i in film.story.cues.size():
			var stream = film._voice_stream(i)
			duration += maxf(float(film.story.cues[i].min_seconds), stream.get_length() + 0.65)
		create_timer(duration).timeout.connect(func():
			film.close())
