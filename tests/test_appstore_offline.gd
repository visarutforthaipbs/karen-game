extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func run() -> void:
	SaveGame.dir = "/tmp/uts-appstore-offline-fixture"
	GameSettings.dir = SaveGame.dir
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	GameSettings.load_settings()
	check(not OnlineBoard.available(), "offline release feature active")
	GameSettings.online_board = true
	GameSettings.client_id = ""
	GameSettings.client_secret = ""
	check(not OnlineBoard.enabled(), "legacy opt-in cannot enable networking")
	OnlineBoard.ensure_identity()
	check(GameSettings.client_id == "" and GameSettings.client_secret == "", "offline build creates no board identity")
	check(OnlineBoard._make_request(root) == null, "request factory cannot create an HTTP request")
	var panel = load("res://ui/SettingsPanel.gd").new()
	root.add_child(panel)
	for i in 8: await process_frame
	check(panel.delete_scores_button == null, "no online deletion control is built")
	check(panel.find_child("PrivacyPolicyButton", true, false) != null, "privacy policy action exists")
	check(panel.find_child("SupportButton", true, false) != null, "support action exists")
	panel.queue_free()
	root.get_node("AudioManager").stop_all_loops()
	for i in 8: await process_frame
	print("OFFLINE RESULT: ", failures)
	quit(1 if failures else 0)
