## Press stills: stage the player raking a firebreak and save close-up PNGs. Run:
##   godot --path . --script res://tests/press_capture.gd
## (windowed, NOT --headless — this needs real rendering; a game window flashes
## on screen for a few seconds). Stills land in the absolute OUT_DIR below.
## Never touches the player's real save/log: Save/Settings/PlaytestLog are all
## redirected to user://capture_tmp first (the Hearth autosaves on refresh).
extends SceneTree

const OUT_DIR := "/Users/lighthouse-control/Documents/Personal-Project/The Karen Game/press-exports"

func _initialize() -> void:
	_run()

func frames(n: int) -> void:
	for i in n:
		await process_frame

## Re-assert the window size and wait until the framebuffer actually matches
## (macOS animates window resizes; grabbing mid-animation yields cropped slices)
func stable_fb() -> Vector2i:
	root.size = Vector2i(1920, 1080)
	var fb := Vector2i.ZERO
	for i in 30:
		await frames(1)
		fb = root.get_texture().get_size()
		if fb.x >= 1920 and absf(float(fb.x) / float(maxi(fb.y, 1)) - 16.0 / 9.0) < 0.02:
			return fb
	return fb

func _run() -> void:
	print("press_capture: start")
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://capture_tmp"))
	SaveGame.dir = "user://capture_tmp/"
	GameSettings.dir = "user://capture_tmp/"
	PlaytestLog.dir = "user://capture_tmp/"
	GameSettings.load_settings()
	AudioServer.set_bus_mute(0, true)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.position = Vector2i(0, 0)
	var fb0: Vector2i = await stable_fb()
	print("press_capture: framebuffer ", fb0)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var gs = root.get_node("GameState")
	gs.current_year = 1
	gs.current_plot_index = 0
	change_scene_to_file("res://scenes/Main.tscn")
	print("press_capture: scene changed")
	await frames(30)
	print("press_capture: main ready")
	var main = current_scene
	var fg = main.fire_grid
	var player = main.player
	var rig = main.cam_rig

	# ---- Pick a brush cell in reach that keeps brush around it (shot context)
	var pc: Vector2i = fg.get_cell_coord_at_world_pos(player.global_position)
	var target := Vector2i(-1, -1)
	for radius in range(1, 7):
		if target.x >= 0:
			break
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := Vector2i(pc.x + dx, pc.y + dy)
				if not fg.is_valid_coord(c.x, c.y):
					continue
				if fg.cell_types[fg._coord_to_index(c.x, c.y)] != fg.CellType.VEGETATION:
					continue
				if Vector2(dx, dy).length() <= player.tool_reach() - 0.5:
					target = c
					break
	if target.x < 0:
		print("press_capture: no vegetation cell in reach")
		quit(1)
		return

	# Stand right next to the target cell so the close-up frames both
	var stand: Vector3 = fg.get_cell_world_pos(target.x, target.y) + Vector3(1.2, 0, 1.2)
	player.global_position = fg.clamp_to_grid(stand)
	player.global_position.y = fg.get_ground_height_at_world_pos(player.global_position)

	# ---- Raked strip behind the work: bare soil running away from the camera
	for i in range(1, 5):
		var c := Vector2i(target.x + i, target.y + i)
		if fg.is_valid_coord(c.x, c.y):
			fg.clear_firebreak(c.x, c.y)

	# ---- Real work path: blade out, gamepad aim on the target, hold the tool
	player._select_tool(player.ToolType.FIREBREAK_BLADE)
	player.using_gamepad_aim = true
	Input.action_press("use_tool")
	await frames(2)
	# Aim at the cell; if the ray picks a neighbouring brush cell, work there instead
	var aim: Vector2 = main.camera.unproject_position(fg.get_cell_world_pos(target.x, target.y)) \
		- main.camera.unproject_position(player.global_position)
	player.gamepad_aim_offset = aim.limit_length(player.GAMEPAD_AIM_RADIUS * 0.9)
	await frames(3)
	if player.is_targeting_valid_cell and fg.cell_types[fg._coord_to_index(player.target_cell_coord.x, player.target_cell_coord.y)] == fg.CellType.VEGETATION:
		target = player.target_cell_coord
	player._begin_cut(target)
	await frames(12)

	# ---- Hero framings, burst-captured so a rake-down frame is guaranteed
	var hud = main.hud
	hud.visible = false
	if player.target_indicator:
		player.target_indicator.visible = true
	var heroes := [
		{"name": "play_5m", "dist": 5.0, "yaw": PI * 0.25, "pitch": -1.0},
		{"name": "play_4m", "dist": 4.0, "yaw": PI * 0.25, "pitch": -1.0},
		{"name": "cine_low_b", "dist": 3.0, "yaw": PI * 0.6, "pitch": 18.0},
		{"name": "cine_low_a", "dist": 3.0, "yaw": PI * 0.25, "pitch": 18.0},
		{"name": "cine_mid", "dist": 4.5, "yaw": PI * 0.75, "pitch": 26.0},
	]
	var focus: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	for h in heroes:
		if float(h["pitch"]) < 0.0:
			# in-game framing: the camera rig follows the player
			rig.set_active(true)
			rig.yaw = h["yaw"]
			rig._target_yaw = h["yaw"]
			rig.distance = h["dist"]
			rig._target_distance = h["dist"]
			rig.focus = rig._ground_point(player.global_position)
			rig._apply(true)
		else:
			# cinematic: rig off, low pitch, character-dominant; crew out of frame
			main.elder.global_position += Vector3(24, 0, 24)
			main.youth.global_position += Vector3(-24, 0, 24)
			rig.set_active(false)
			var pitch: float = deg_to_rad(h["pitch"])
			var yaw: float = h["yaw"]
			var offset: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw)) * cos(pitch) * float(h["dist"])
			offset.y = sin(pitch) * float(h["dist"])
			main.camera.global_position = focus + offset
			main.camera.look_at(focus, Vector3.UP)
		for i in 8:
			player._begin_cut(target)
			await frames(5)
			var fb: Vector2i = await stable_fb()
			var img: Image = root.get_texture().get_image()
			img.save_png(OUT_DIR.path_join("%s_%02d.png" % [String(h["name"]), i]))
		print("press_capture: burst ", h["name"], " done")

	await frames(2)
	quit(0)
