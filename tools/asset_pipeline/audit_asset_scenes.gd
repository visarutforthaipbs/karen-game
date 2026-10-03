extends SceneTree
## Read-only visual audit with isolated save/settings paths. No production edits.
var output: String
var view: SubViewport
func _initialize() -> void: call_deferred("run")
func snap(name: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)
func run() -> void:
	var args = OS.get_cmdline_user_args()
	output = args[1]
	DirAccess.make_dir_recursive_absolute(output)
	var save_dir = ProjectSettings.globalize_path(output.path_join("audit_save"))
	DirAccess.make_dir_recursive_absolute(save_dir)
	SaveGame.dir = save_dir
	GameSettings.dir = save_dir
	PlaytestLog.dir = save_dir
	GameSettings.ensure_loaded()
	GameSettings.landscape_detail = "high"
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.current_year = 3
	state.current_plot_index = 5
	state.seen_how_to_play = true
	state.rice_barn = 0 if args[0] == "famine" else 100
	state.state_scrutiny = 100 if args[0] == "crackdown" else 0
	view = SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game: Node
	match args[0]:
		"main": game = load("res://scenes/Main.tscn").instantiate()
		"title": game = load("res://scenes/Title.tscn").instantiate()
		"hearth", "village": game = load("res://scenes/VillageHearth.tscn").instantiate()
		"checkpoint": game = load("res://ui/CheckpointScene.gd").new()
		_: game = load("res://ui/EndingScene.gd").new()
	view.add_child(game)
	if game is Control: game.set_deferred("size", Vector2(view.size))
	for i in 45: await process_frame
	if args[0]=="checkpoint" and args.size()>2:
		var doc:=GLTFDocument.new()
		var gltf_state:=GLTFState.new()
		assert(doc.append_from_file(args[2],gltf_state)==OK)
		var imported:=doc.generate_scene(gltf_state)
		var mesh:=ArrayMesh.new()
		assert(AssetLibrary._append_meshes(imported,Transform3D.IDENTITY,mesh))
		imported.free()
		var replaced:=false
		for node in game.find_children("*","MeshInstance3D",true,false):
			if node.position.distance_to(Vector3(4.2,0,-.4))<.001:
				node.mesh=mesh
				replaced=true
		assert(replaced,"Missing S5 checkpoint hook")
	if args[0] == "title":
		game.set_process(false)
		game._pass_t = 5.0
		game._update_satellite(0)
	elif args[0]=="checkpoint":
		game.set_process(false)
		game._t=0.0
		for i in 330: game._process(1.0/60.0)
	elif args[0] in ["famine","crackdown"]:
		game.set_process(false)
		game._t=0.0
		for i in 330:game._process(1.0/60.0)
	await snap(args[0])
	if args[0]=="village":
		game.show_village()
		await snap("village_overview")
		for station in ["S8","S3","S9"]:
			game.village_diorama.focus_station(station)
			await snap("village_"+station)
	if args[0]=="checkpoint":
		for i in 180: game._process(1.0/60.0)
		await snap("checkpoint_open")
	if args[0] == "hearth":
		view.size = Vector2i(960,720)
		game.size = view.size
		await snap("hearth_4x3")
	if args[0] == "main":
		game.set_process(false)
		var grid = game.fire_grid
		for x in range(17,24):
			for y in range(18,22): grid.ignite_cell(x,y)
		for i in 80: grid._simulation_step()
		for i in 45: await process_frame
		await snap("main_burn")
		game.cam_rig.active = false
		game.hud.hide()
		var center = grid.get_cell_world_pos(20,20)
		game.camera.look_at_from_position(center+Vector3(8,12,16),center)
		await snap("burn_close")
	view.queue_free()
	for i in 3: await process_frame
	quit()
