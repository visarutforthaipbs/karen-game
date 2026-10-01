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
		check(animator.skeleton.get_bone_count() == 19, actor.name + " has 19 calibrated joints")
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
	game._on_satellite_pass()
	for actor in actors:
		check(not actor.animator.work_active and actor.animator.work_blend == 0, actor.name + " stops work for satellite pass")
	game.queue_free()
	await process_frame
	print("MOTION RESULT: ", failures, " failures")
	quit(1 if failures else 0)
