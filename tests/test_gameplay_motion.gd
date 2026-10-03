extends SceneTree
## Semantic work, locomotion, aiming, equipment and interruptions in the real scene.
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.fire_grid.simulation_paused = true
	var actors := [game.player, game.elder, game.youth]
	for actor in actors:
		actor.set_physics_process(false)
		var animator = actor.animator
		check(animator.has_method("set_work"), actor.name + " has skeletal gameplay animator")
		if not animator.has_method("set_work"):
			continue
		check(animator.skeleton.get_bone_count() == (21 if animator.character_profile == "munaw" else 19), actor.name + " has calibrated core and garment joints")
		for mesh in animator.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null: continue # attached rigid tools
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				check(weights.size() == vertices.size() * 4, actor.name + " has four skin influences")
		animator.set_work(&"spray", true)
		for i in 30: animator.update_animation(1.0/60.0, Vector3(4, 0, 0), Vector3(0, 0, 1))
		check(animator.animation_player.current_animation == "Walk", actor.name + " keeps gait during work")
		check(absf(animator.rotation.y) < 0.05, actor.name + " faces work independently of travel")
		var thigh_id: int = animator.skeleton.find_bone("Thigh.L")
		var before: Quaternion = animator.skeleton.get_bone_pose_rotation(thigh_id)
		for i in 7: animator.update_animation(1.0/60.0, Vector3(4, 0, 0), Vector3(0, 0, 1))
		check(not before.is_equal_approx(animator.skeleton.get_bone_pose_rotation(thigh_id)), actor.name + " legs continue articulating")
		animator.update_animation(0.1, Vector3(0, 0, 6), Vector3(0, 0, 1))
		check(animator.animation_player.current_animation == "Run", actor.name + " selects run at gameplay speed")
		var phase: float = animator.work_phase
		animator.set_work(&"spray", true)
		check(is_equal_approx(animator.work_phase, phase), actor.name + " held work does not restart wind-up")
		animator.cancel_work()
		animator.update_animation(0.1, Vector3.ZERO)
		check(animator.work_blend == 0 and animator.animation_player.current_animation == "Idle", actor.name + " cancels work immediately")
		# Same time/pose must not accumulate overlays on constant animation tracks.
		animator.set_work(&"rake", true)
		for i in 30: animator.update_animation(1.0/60.0, Vector3.ZERO, Vector3(0, 0, 1))
		var pose: Transform3D = animator.skeleton.get_bone_global_pose(animator.skeleton.find_bone("Hand.R"))
		for i in 60: animator.update_animation(0.0, Vector3.ZERO, Vector3(0, 0, 1))
		check(pose.is_equal_approx(animator.skeleton.get_bone_global_pose(animator.skeleton.find_bone("Hand.R"))), actor.name + " layers do not accumulate")
	game.elder.configure_borrowed_sprayer(true)
	check(game.elder._borrowed_wand != null and game.elder._borrowed_equipment != null, "borrowed sprayer has visible equipment")
	game.elder.rally_to_player()
	check(not game.elder.animator.work_active, "rally cancels work")
	game.youth.animator.set_work(&"spray", true)
	game.youth.receive_ping_order(Vector2i(20, 20), Vector3.ZERO)
	check(not game.youth.animator.work_active, "new order cancels old work")
	game.player._select_tool(game.player.ToolType.WATER_SPRAYER)
	game.player.animator.set_work(&"spray", true)
	game.player._select_tool(game.player.ToolType.FIREBREAK_BLADE)
	check(not game.player.animator.work_active, "tool switch cancels previous action")
	# Actual movement and held-tool controller paths retain their gameplay effects.
	var player = game.player
	var coord := Vector2i(20, 20)
	var index: int = game.fire_grid._coord_to_index(coord.x, coord.y)
	player.global_position = game.fire_grid.get_cell_world_pos(20, 21)
	player.using_gamepad_aim = true
	player.target_cell_coord = coord
	player.target_cell_pos = game.fire_grid.get_cell_world_pos(20, 20)
	player.is_targeting_valid_cell = true
	player._select_tool(player.ToolType.WATER_SPRAYER)
	player.water = 2.0
	player._tool_cooldown_left = 0.0
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.SMOLDERING
	Input.action_press("use_tool")
	Input.action_press("move_right")
	var start: Vector3 = player.global_position
	player._handle_movement(1.0/60.0)
	player._update_work_animation()
	player._handle_held_actions(1.0/60.0)
	player.animator.update_animation(1.0/60.0, player.velocity, player.target_cell_pos-player.global_position)
	check(player.global_position.distance_to(start) > 0.01, "player actually moves while using tool")
	check(game.fire_grid.cell_types[index] == game.fire_grid.CellType.ASH and is_equal_approx(player.water, 1.0), "moving spray cools cell and consumes exactly one dose")
	player._handle_held_actions(1.0/60.0)
	check(is_equal_approx(player.water, 1.0), "animation does not duplicate gameplay water use")
	Input.action_release("use_tool")
	Input.action_release("move_right")
	player._update_work_animation()
	check(not player.animator.work_active, "released input stops sustained tool state")
	# Companion completes a real ordered douse with the new animator enabled.
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.SMOLDERING
	game.youth.global_position = player.global_position
	game.youth.receive_ping_order(coord, player.target_cell_pos)
	for i in 90:
		game.youth._physics_process(1.0/60.0)
		if game.fire_grid.cell_types[index] == game.fire_grid.CellType.ASH: break
	check(game.fire_grid.cell_types[index] == game.fire_grid.CellType.ASH, "rigged companion completes ordered douse")
	# Sustained jet follows the production nozzle and authoritative grid target.
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.SMOLDERING
	game.youth.current_state = game.youth.State.PERFORMING_TASK
	game.youth.target_coord = coord
	game.youth.target_world_pos = Vector3(999,999,999)
	game.youth._update_spray_cue()
	var cue = game.youth._spray_cue
	check(cue != null and cue.origin.distance_to(game.youth.animator.get_embedded_tool_tip()) < 0.001, "spray originates at production nozzle")
	check(cue.destination.distance_to(game.fire_grid.get_cell_world_pos(coord.x, coord.y) + Vector3.UP * 0.08) < 0.001, "jet ignores stale task position")
	game.youth._update_spray_cue()
	check(game.youth._spray_cue == cue, "held spray reuses emitter")
	game.youth.rally_to_player()
	check(game.youth._spray_cue == null and not cue.visible, "rally immediately hides and frees jet")
	game.youth.current_state = game.youth.State.PERFORMING_TASK
	game.youth.target_coord = coord
	game.youth._update_spray_cue()
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.ASH
	game.youth._update_spray_cue()
	check(game.youth._spray_cue == null, "completed or invalid cell stops jet")
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.SMOLDERING
	game.youth._update_spray_cue()
	game.youth.current_state = game.youth.State.FLEEING
	game.youth._update_spray_cue()
	check(game.youth._spray_cue == null, "fleeing cancels spray")
	game.youth.current_state = game.youth.State.PERFORMING_TASK
	game.youth.target_coord = Vector2i(-1,-1)
	game.youth._update_spray_cue()
	check(game.youth._spray_cue == null, "invalid target cannot show success or held jet")
	game.youth._assign_task(coord)
	game.youth.global_position = game.fire_grid.get_cell_world_pos(coord.x,coord.y + 1)
	game.youth.task_progress = 0.0
	var autonomous_jet := false
	for frame in 120:
		game.youth._physics_process(1.0/60.0)
		autonomous_jet = autonomous_jet or game.youth._spray_cue != null
		if game.fire_grid.cell_types[index] == game.fire_grid.CellType.ASH: break
	check(autonomous_jet and game.fire_grid.cell_types[index] == game.fire_grid.CellType.ASH and game.youth._spray_cue == null, "autonomous task shows jet and clears it after authoritative success")
	game.fire_grid.cell_types[index] = game.fire_grid.CellType.SMOLDERING
	game.youth.current_state = game.youth.State.PERFORMING_TASK
	game.youth.target_coord = coord
	game.youth._update_spray_cue()
	game._on_satellite_pass()
	check(game.youth._spray_cue == null, "satellite transition cancels jet")
	for actor in actors:
		check(not actor.animator.work_active and actor.animator.work_blend == 0, actor.name + " stops work for satellite pass")
	game.queue_free()
	await process_frame
	print("MOTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
