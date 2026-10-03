extends SceneTree
## Regression coverage for visible hose continuity, separated rake grips and belt carry.
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	SaveGame.dir = "user://equipment_motion_test"
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	root.get_node("GameState").reset_campaign()
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var actor = game.player
	var animator = actor.animator
	var hose = actor._sprayer_hose
	actor._select_tool(actor.ToolType.WATER_SPRAYER)
	animator.set_work(&"spray", true)
	var largest_endpoint_error := 0.0
	for i in 90:
		actor.position += Vector3(.02, 0, -.01)
		animator.update_animation(1.0/60.0, Vector3(0,0,6), Vector3(sin(i*.08),0,cos(i*.08)))
		animator.skeleton.force_update_all_bone_transforms()
		await process_frame # BoneAttachment3D applies the skeleton update before measuring the prop.
		hose.update_hose()
		check(hose.visible and hose.centreline.size()==25, "Sprayer hose disappeared during moving aim")
		largest_endpoint_error=maxf(largest_endpoint_error,hose.to_global(hose.centreline[0]).distance_to(hose.tank.to_global(hose.tank_outlet)))
		largest_endpoint_error=maxf(largest_endpoint_error,hose.to_global(hose.centreline[-1]).distance_to(hose.wand.to_global(hose.wand_inlet)))
		for point in hose.centreline:check(point.is_finite(),"Hose produced non-finite geometry")
	check(largest_endpoint_error<.0001,"Hose detached from a fitting")
	actor._select_tool(actor.ToolType.DRIP_TORCH)
	check(not hose.visible,"Hose connects to the torch after switching tools")
	actor._select_tool(actor.ToolType.FIREBREAK_BLADE)
	check(not hose.visible,"Hose connects to the rake after switching tools")
	animator.set_work(&"rake",true)
	var min_separation := INF
	var max_shaft_error := 0.0
	for i in 150:
		animator.update_animation(1.0/60.0, Vector3.ZERO if i<80 else Vector3(2,0,0), Vector3(0,0,1))
		animator.skeleton.force_update_all_bone_transforms()
		await process_frame # BoneAttachment3D applies the skeleton update before measuring the prop.
		if i<20:continue # blend into contact
		var sk:Skeleton3D=animator.skeleton
		var right:Vector3=sk.get_bone_global_pose(sk.find_bone("Hand.R"))*animator._palm_offset("R")
		var left:Vector3=sk.get_bone_global_pose(sk.find_bone("Hand.L"))*animator._palm_offset("L")
		min_separation=minf(min_separation,right.distance_to(left)*animator.base_scale)
		check(left.x>right.x+.08,"Rake hands cross to the same side")
		check(sk.get_bone_global_pose(sk.find_bone("Forearm.L")).origin.x>0,"Left elbow folds across torso")
		check(sk.get_bone_global_pose(sk.find_bone("Forearm.R")).origin.x<0,"Right elbow folds across torso")
		var left_world:=sk.to_global(left)
		var shaft_origin:Vector3=actor._tool_prop.to_global(Vector3(0,.22,0))
		var shaft_axis:Vector3=actor._tool_prop.global_basis.y.normalized()
		var offset:=left_world-shaft_origin
		max_shaft_error=maxf(max_shaft_error,(offset-shaft_axis*offset.dot(shaft_axis)).length())
	check(min_separation>.22,"Rake palm separation collapsed during stroke")
	check(max_shaft_error<.025,"Supporting palm leaves the rake shaft")
	var elder=game.elder.animator
	elder.cancel_work()
	for velocity in [Vector3.ZERO,Vector3(0,0,2),Vector3(0,0,6)]:
		elder.update_animation(.1,velocity,Vector3(1,0,0))
		check(elder._carried_tool.get_parent()==elder.belt_socket,"Knife not belted during locomotion")
	elder.set_work(&"rake",true)
	elder.update_animation(.15,Vector3.ZERO)
	check(elder._carried_tool.get_parent()==elder.get_hand_socket(),"Knife not drawn for vegetation clearing")
	elder.cancel_work()
	check(elder._carried_tool.get_parent()==elder.belt_socket,"Knife not sheathed after cancellation")
	elder.set_work(&"spray",true)
	elder.update_animation(.15,Vector3.ZERO)
	check(elder._carried_tool.get_parent()==elder.belt_socket,"Knife is held during borrowed-sprayer work")
	var knives:=0
	for n in elder.find_children("*","MeshInstance3D",true,false):
		if n==elder._carried_tool:knives+=1
	check(knives==1,"Knife duplicated during carry transitions")
	# Mutual-aid sprayer follows its own animated fittings, not the player's hose.
	var companion = game.elder
	companion.configure_borrowed_sprayer(true)
	var borrowed = companion._borrowed_hose
	companion._borrowed_wand.visible = true
	for i in 60:
		elder.update_animation(1.0/60.0,Vector3(2,0,0),Vector3(sin(i*.1),0,cos(i*.1)))
		elder.skeleton.force_update_all_bone_transforms()
		await process_frame
		borrowed.update_hose()
		check(borrowed.visible and borrowed.centreline.size()==25,"Borrowed sprayer hose disappeared")
		check(borrowed.to_global(borrowed.centreline[0]).distance_to(borrowed.tank.to_global(borrowed.tank_outlet))<.0001,"Borrowed hose leaves tank fitting")
		check(borrowed.to_global(borrowed.centreline[-1]).distance_to(borrowed.wand.to_global(borrowed.wand_inlet))<.0001,"Borrowed hose leaves wand fitting")
	companion._borrowed_wand.visible = false
	borrowed.update_hose()
	check(not borrowed.visible,"Borrowed hose remains visible with wand stowed")
	companion.configure_borrowed_sprayer(false)
	await process_frame
	check(companion._borrowed_hose==null and not is_instance_valid(borrowed),"Disabling mutual aid leaves a hose behind")
	print("EQUIPMENT METRICS: endpoint error=",largest_endpoint_error,"; min palm separation=",min_separation,"; max shaft error=",max_shaft_error)
	game.queue_free()
	await process_frame
	print("EQUIPMENT RESULT: ",failures," failures")
	quit(1 if failures else 0)
