extends SceneTree

## Real root canvas scale, isolated saves/settings, no public HTTP requests.
class ClockFixture extends Node:
	func get_hours() -> float:
		return 16.5

class BurnFixture extends Node:
	var pass_started = false
	var hud: Node
	var game_clock: Node
	var scans = 0
	func _on_satellite_pass() -> void:
		scans += 1
		pass_started = true

var checks = 0
var failures = 0
var delete_completion: Callable

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for i in 6:
		await process_frame

func inside(control: Control) -> bool:
	return Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect())

func controls(node: Node, result: Array) -> void:
	if node is Control:
		result.append(node)
	for child in node.get_children():
		controls(child, result)

func focus_stays(modal: Control) -> bool:
	var items=[]
	controls(modal, items)
	for control in items:
		if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree() or (control is BaseButton and control.disabled):
			continue
		for neighbor in [control.find_next_valid_focus(), control.find_prev_valid_focus(), control.find_valid_focus_neighbor(SIDE_TOP), control.find_valid_focus_neighbor(SIDE_BOTTOM), control.find_valid_focus_neighbor(SIDE_LEFT), control.find_valid_focus_neighbor(SIDE_RIGHT)]:
			if neighbor and neighbor != modal and not modal.is_ancestor_of(neighbor):
				return false
	return true

func button_with(node: Node, text: String) -> Button:
	var items=[]
	controls(node, items)
	for control in items:
		if control is Button and control.text == text:
			return control
	return null

func cancel_event() -> InputEventAction:
	var event = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event

func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var dir = "res://artifacts/ui_audit_20261003"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_texture().get_image().save_png(dir + "/menu_" + name + ".png")

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)

func run() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await create_timer(10).timeout
	root.size = Vector2i(1280,720)
	GameSettings.ensure_loaded()
	var old = {"settings_dir": GameSettings.dir, "save_dir": SaveGame.dir, "locale": GameSettings.locale, "scale": GameSettings.ui_scale, "board": GameSettings.online_board, "id": GameSettings.client_id, "secret": GameSettings.client_secret, "fullscreen": GameSettings.fullscreen}
	var state = root.get_node("GameState")
	var original_state: Dictionary = state.to_dict().duplicate(true)
	var scratch = "user://menu_ux_fixture_" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	GameSettings.dir = scratch
	SaveGame.dir = scratch
	GameSettings.fullscreen = false
	GameSettings.online_board = false
	GameSettings.client_id = ""
	GameSettings.client_secret = ""
	for locale in ["th", "en"]:
		for scale in [1.0,1.3]:
			GameSettings.ui_scale = scale
			GameSettings.locale = locale
			TranslationServer.set_locale(locale)
			root.content_scale_factor = scale
			var context = "%s ×%.1f" % [locale,scale]
			var background = Button.new()
			background.text = "Background opener"
			root.add_child(background)
			background.grab_focus()
			var settings = load("res://ui/SettingsPanel.gd").new()
			root.add_child(settings)
			await settle()
			check(root.size == Vector2i(1280,720), "physical root viewport remains 1280×720: " + context)
			check(focus_stays(settings) and background.focus_mode == Control.FOCUS_NONE, "settings keeps Tab and D-pad inside: " + context)
			check(inside(settings.close_button), "settings footer visible: " + context)
			var items=[]
			controls(settings,items)
			var sliders_no_wheel=true
			var focused_visible=true
			for control in items:
				if control is Slider:
					sliders_no_wheel = sliders_no_wheel and not control.scrollable
				if control.focus_mode != Control.FOCUS_NONE and settings._content_scroll.is_ancestor_of(control) and not (control is BaseButton and control.disabled):
					control.grab_focus()
					await settle()
					focused_visible = focused_visible and inside(control) and settings._content_scroll.get_global_rect().encloses(control.get_global_rect())
			check(sliders_no_wheel, "wheel scrolling cannot adjust settings sliders: " + context)
			check(focused_visible, "every enabled setting scrolls into view on focus: " + context)
			await capture("settings_bottom_%s_%d" % [locale,int(scale*100)])
			settings.close_button.grab_focus()
			settings.close()
			check(root.gui_get_focus_owner() == background, "settings restores original opener synchronously: " + context)
			var guide = load("res://ui/HowToPlay.gd").new()
			root.add_child(guide)
			await settle()
			check(focus_stays(guide) and background.focus_mode == Control.FOCUS_NONE, "new guide stays modal after replaced settings frees: " + context)
			guide.close()
			await settle()
			check(root.gui_get_focus_owner() == background, "guide restores opener: " + context)
			background.queue_free()
			await settle()

			# The actual title confirmation must never bypass saved-campaign consent.
			check(SaveGame.save(state), "isolated saved campaign exists: " + context)
			var save_path = SaveGame._path(SaveGame.CAMPAIGN_FILE)
			var saved_bytes = FileAccess.get_file_as_bytes(save_path)
			var title = load("res://scenes/Title.tscn").instantiate()
			root.add_child(title)
			await settle()
			title.new_button.grab_focus()
			title._on_new_game()
			await settle()
			check(title._confirmation_open and focus_stays(title._overlay), "new-game consent traps focus: " + context)
			check(root.gui_get_focus_owner().text == "ยกเลิก", "new-game consent defaults to Cancel: " + context)
			title._on_new_game()
			check(title._confirmation_open and FileAccess.get_file_as_bytes(save_path) == saved_bytes, "repeated new-game request cannot bypass consent: " + context)
			await capture("new_game_confirm_%s_%d" % [locale,int(scale*100)])
			title._unhandled_input(cancel_event())
			check(not title._confirmation_open and title._overlay == null and root.gui_get_focus_owner() == title.new_button, "Esc/Back cancels consent and restores New: " + context)
			await settle()
			var opener=title._menu.get_child(3)
			opener.grab_focus()
			title._on_settings()
			await settle()
			title._overlay.close()
			await settle()
			check(root.gui_get_focus_owner() == opener, "Title settings returns focus to Settings: " + context)
			title.queue_free()
			await settle()

			var fixture=BurnFixture.new()
			fixture.game_clock=ClockFixture.new()
			fixture.add_child(fixture.game_clock)
			root.add_child(fixture)
			var pause=load("res://ui/PauseMenu.gd").new()
			pause.main=fixture
			root.add_child(pause)
			pause.open()
			await settle()
			check(inside(pause._pause_card) and focus_stays(pause._panel), "pause wraps long text and stays modal: " + context)
			await capture("pause_%s_%d" % [locale,int(scale*100)])
			var give_up=button_with(pause._panel,"ยอมแพ้แปลงนี้ · ให้ดาวเทียมผ่านเลย")
			give_up.grab_focus()
			give_up.pressed.emit()
			await settle()
			check(fixture.scans == 0 and focus_stays(pause._sub) and root.gui_get_focus_owner().text == "ยกเลิก", "giving up waits for Cancel-default confirmation: " + context)
			await capture("give_up_confirm_%s_%d" % [locale,int(scale*100)])
			pause._unhandled_input(cancel_event())
			await settle()
			check(fixture.scans == 0 and pause._sub == null and paused and root.gui_get_focus_owner() == give_up, "Back cancels giving up without changing burn: " + context)
			var home=button_with(pause._panel,"ออกไปหน้าแรก (กลับไปก่อนเผาแปลงนี้)")
			home.grab_focus()
			home.pressed.emit()
			await settle()
			check(root.gui_get_focus_owner().text == "ยกเลิก" and focus_stays(pause._sub), "abandoning burn also defaults to Cancel: " + context)
			pause._unhandled_input(cancel_event())
			await settle()
			pause._unhandled_input(cancel_event())
			check(not paused and not pause.visible, "controller Back resumes plain pause menu: " + context)
			pause.open()
			await settle()
			give_up=button_with(pause._panel,"ยอมแพ้แปลงนี้ · ให้ดาวเทียมผ่านเลย")
			give_up.grab_focus()
			give_up.pressed.emit()
			await settle()
			button_with(pause._sub,"ยืนยัน ให้สแกนตอนนี้").pressed.emit()
			await settle()
			check(fixture.scans == 1 and not paused, "explicit confirmation performs exactly one scan: " + context)
			pause.queue_free()
			fixture.queue_free()
			await settle()

	# UI deletion uses a local fake completion, not a public HTTP request.
	GameSettings.client_id=""
	GameSettings.client_secret=""
	var settings=load("res://ui/SettingsPanel.gd").new()
	root.add_child(settings)
	await settle()
	check(settings.delete_scores_button.disabled, "online deletion starts disabled without anonymous identity")
	button_with(settings,"ส่งผลการเล่นขึ้นกระดานออนไลน์").button_pressed=true
	check(not settings.delete_scores_button.disabled, "opting in makes deletion available immediately")
	settings._delete_requester=func(_parent: Node, callback: Callable): delete_completion=callback
	settings._delete_scores()
	check(settings.delete_scores_button.disabled and settings.online_status.visible, "delete request disables repeats and shows pending feedback")
	delete_completion.call(-1)
	check(not settings.delete_scores_button.disabled and settings.online_status.text == "ลบคะแนนไม่สำเร็จ โปรดลองอีกครั้ง", "delete error exposes retry feedback")
	settings._delete_scores()
	delete_completion.call(3)
	check(settings.online_status.tr(settings.online_status.text) == "Deleted 3 online scores.", "delete completion shows translated actual count")
	var invalid_parent_result: Array = []
	OnlineBoard.delete_my_scores(null, func(result: int): invalid_parent_result.append(result))
	check(invalid_parent_result == [-1], "online deletion reports local request failure without network")
	settings.close()
	await settle()
	for file in DirAccess.open(scratch).get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch + "/" + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	state.from_dict(original_state)
	state.stats=original_state.stats.duplicate(true)
	GameSettings.dir=old.settings_dir
	SaveGame.dir=old.save_dir
	GameSettings.locale=old.locale
	GameSettings.ui_scale=old.scale
	GameSettings.online_board=old.board
	GameSettings.client_id=old.id
	GameSettings.client_secret=old.secret
	GameSettings.fullscreen=old.fullscreen
	TranslationServer.set_locale(old.locale)
	root.content_scale_factor=old.scale
	var audio=root.get_node_or_null("AudioManager")
	if audio:
		audio.stop_all_loops()
		audio.set_process(false)
	stop_audio(root)
	await create_timer(.1).timeout
	print("Menu UX: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
