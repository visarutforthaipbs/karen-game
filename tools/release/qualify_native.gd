extends SceneTree
## Run this external probe with the exported executable, from an empty directory.
## All settings/saves/logs and optional rendered captures use the supplied scratch
## output folder. It does not submit online scores or modify a player's profile.
var output: String
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func frames(count := 8) -> void:
	for i in count:
		await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	check(error == OK, "rendered " + name)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		push_error("Supply an absolute scratch output directory")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var saves = load("res://scripts/SaveGame.gd")
	var settings = load("res://scripts/GameSettings.gd")
	var logs = load("res://scripts/PlaytestLog.gd")
	saves.dir = output.path_join("profile")
	settings.dir = saves.dir
	logs.dir = saves.dir
	DirAccess.make_dir_recursive_absolute(saves.dir)
	saves.delete()
	settings.load_settings()
	settings.online_board = false
	settings.intro_seen = false
	settings.player_name = "Release QA"
	var locale = root.get_node("Localization")
	locale.set_language("th")
	var state = root.get_node("GameState")
	var audio = root.get_node("AudioManager")
	check(ProjectSettings.get_setting("application/config/version") == "0.3.0", "export version is 0.3.0")
	check(not OS.has_feature("editor"), "running exported executable")
	change_scene_to_file("res://scenes/Title.tscn")
	await frames(20)
	check(current_scene.name == "Title", "export boots title")
	await capture("01-title-th")
	current_scene._on_settings()
	await frames()
	var panel = current_scene._overlay
	check(panel.language_picker.item_count == 2, "both language choices available")
	panel.language_picker.select(1)
	panel.language_picker.item_selected.emit(1)
	await frames()
	check(settings.locale == "en" and TranslationServer.translate("ตั้งค่า") == "Settings", "English picker translates live UI")
	await capture("02-settings-en")
	panel.close()
	panel = null
	await frames()
	current_scene._on_new_game()
	await frames(15)
	var film = current_scene._overlay
	check(film != null and film.get("voice") != null, "first new game opens film")
	check(film.voice.playing and film.voice.stream.resource_path.contains("/en/"), "opening uses English recording")
	check(film.music.playing and film.ambience.playing, "film background layers resolve")
	await capture("03-opening-en")
	film.toggle_pause()
	check(film.film_paused and film.voice.stream_paused and film.music.stream_paused, "film pause stops audio layers")
	film.toggle_pause()
	var cancel = InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await frames(15)
	cancel.pressed = false
	Input.parse_input_event(cancel)
	film = null
	check(current_scene.name == "VillageHearth" and not paused, "real Back skips film into unpaused preparation")
	check(settings.intro_seen and saves.exists(), "film completion preference and campaign persist")
	check(current_scene.how_to_play == null, "preparation has no compulsory guide after film")
	current_scene._tune_radio(1)
	await frames(3)
	check(audio.radio_player.playing and audio.radio_player.stream.resource_path.contains("/en/"), "English radio works in exported preparation")
	await capture("04-preparation-en")
	current_scene._on_launch_pressed()
	await frames(20)
	check(current_scene.name == "Main", "preparation launches gameplay")
	var main = current_scene
	check(main.player != null and main.elder != null and main.youth != null, "cast and gameplay resources resolve")
	await capture("05-gameplay-en")
	var pause_menu = main.hud.pause_menu
	pause_menu.open()
	await frames()
	var time_before: float = main.game_clock.current_sim_time_seconds
	await create_timer(0.2).timeout
	check(paused and is_equal_approx(time_before, main.game_clock.current_sim_time_seconds), "pause freezes gameplay clock")
	pause_menu._open_settings()
	await frames()
	panel = pause_menu._sub
	panel.language_picker.select(0)
	panel.language_picker.item_selected.emit(0)
	await frames()
	check(settings.locale == "th" and paused, "language switches safely inside pause")
	await capture("06-paused-settings-th")
	panel.close()
	panel = null
	await frames()
	pause_menu.resume()
	await frames(10)
	check(not paused and main.game_clock.current_sim_time_seconds > time_before, "resume advances the clock")
	audio.stop_all_loops()
	change_scene_to_file("res://scenes/Title.tscn")
	main = null
	pause_menu = null
	await frames(15)
	current_scene._on_continue()
	await frames(15)
	check(current_scene.name == "VillageHearth", "continue restores saved preparation without film")
	settings.load_settings()
	check(settings.locale == "th" and settings.intro_seen, "profile preferences survive reload")
	audio.stop_all_loops()
	print("NATIVE RELEASE QA: ", checks, " checks; ", failures, " failures; renderer ", DisplayServer.get_name())
	current_scene.queue_free()
	await frames(3)
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)
