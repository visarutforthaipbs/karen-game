extends SceneTree
## Real imported GLB: clips, bone motion, hand attachment and controller transitions.

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		push_error(message)
		quit(1)
		assert(value, message)

func run() -> void:
	var character = load("res://scenes/characters/KhanaeChibi.tscn").instantiate()
	root.add_child(character)
	await process_frame
	var player: AnimationPlayer = character.animation_player
	var skeleton: Skeleton3D = character.skeleton
	check(skeleton.get_bone_count() == 19, "Expected calibrated 19-bone rig")
	var triangles := 0
	for visual in character.find_children("*", "MeshInstance3D", true, false):
		check(visual.skin != null, "Mesh lost exported skin")
		for surface in visual.mesh.get_surface_count():
			var arrays: Array = visual.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int = weights.size() / vertices.size()
			check(stride == 4, "Expected four skin influences")
			for vertex in vertices.size():
				var total := 0.0
				for influence in stride:
					total += weights[vertex * stride + influence]
				check(absf(total - 1.0) < .0001, "Exported skin weights are not normalized")
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			var material: BaseMaterial3D = visual.get_active_material(surface)
			check(material.albedo_texture != null, "Rig export lost base-colour texture")
	check(triangles == 14394, "Rig changed the reviewed geometry budget")
	check(character.get_hand_socket() != null, "Hand socket missing")
	for clip in ["Idle", "Walk", "ToolUse"]:
		check(player.has_animation(clip), "Missing clip: " + clip)
	check(player.get_animation("Walk").loop_mode == Animation.LOOP_LINEAR, "Walk must loop")
	check(player.get_animation("ToolUse").loop_mode == Animation.LOOP_NONE, "Action must finish")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.update_animation(0.1, Vector3(0, 0, 2))
	check(player.current_animation == "Walk", "Movement did not start walk")
	player.advance(0.2) # Finish the Idle -> Walk crossfade before comparing poses.
	player.seek(0.2, true)
	skeleton.force_update_all_bone_transforms()
	var thigh := skeleton.get_bone_pose_rotation(skeleton.find_bone("Thigh.L"))
	player.seek(0.6, true)
	skeleton.force_update_all_bone_transforms()
	check(not thigh.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("Thigh.L"))), "Walk does not articulate legs")
	character.trigger_action()
	player.advance(0.2)
	var time := player.current_animation_position
	character.trigger_action()
	check(is_equal_approx(player.current_animation_position, time), "Repeated tool use restarted wind-up")
	player.seek(0.35, true)
	skeleton.force_update_all_bone_transforms()
	await process_frame
	var hand_index := skeleton.find_bone("Hand.R")
	var attachment: BoneAttachment3D = character.get_hand_socket().get_parent()
	check(attachment.global_position.distance_to((skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)).origin) < .002, "Tool socket detached from hand")
	var root_pose := skeleton.get_bone_global_pose(skeleton.find_bone("Root"))
	check(absf(root_pose.origin.x) < .001 and absf(root_pose.origin.z) < .001, "Clip introduced horizontal root motion")
	character.update_animation(0.1, Vector3.ZERO)
	player.advance(1.0)
	check(not character._action_playing, "Action never released locomotion")
	character.update_animation(0.1, Vector3.ZERO)
	check(player.current_animation == "Idle", "Stop did not restore idle")
	check(character.scale.is_equal_approx(Vector3.ONE * character.base_scale), "Legacy squash still distorts rig")
	print("PASS: rig, articulated walk, action completion, repeated input, hand socket and stationary root")
	character.queue_free()
	await process_frame
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var actor = game.get_node("Player")
	check(actor._tool_prop.get_parent() == actor.animator.get_hand_socket(), "Actual player tool is not hand-attached")
	actor._swing()
	check(actor.animator.work_active and actor.animator.work_kind == &"ignite", "Actual tool use did not trigger semantic ignition")
	print("PASS: actual player scene routes tool attachment and action to skeleton")
	game.queue_free()
	await process_frame
	quit(0)
