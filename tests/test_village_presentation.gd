extends SceneTree
## Actual Hearth integration: delivered props, reserve state, responsive controls, camera.
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	SaveGame.dir="user://village_presentation_test"
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	GameSettings.dir=SaveGame.dir
	PlaytestLog.dir=SaveGame.dir
	var state=root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play=true
	var view:=SubViewport.new()
	view.size=Vector2i(1280,720)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var hearth=load("res://scenes/VillageHearth.tscn").instantiate()
	view.add_child(hearth)
	for i in 12:await process_frame
	var village=hearth.village_diorama
	check(village!=null and village.camera!=null,"Hearth has no 3D village")
	for id in ["S3","S4","S8","S9","S10","S12","S13","S14","S15","S16"]:
		check(AssetLibrary.has_asset(id),"Missing village asset "+id)
		check(not village.world.find_children(id+"_VillageProp*","MeshInstance3D",true,false).is_empty(),"Village does not place "+id)
	check(village.villagers.size()==4,"Village is missing an approved crew member")
	for amount in [100.0,40.0,0.0]:
		village.set_reserve(amount)
		var visible:=0
		for sack in village.reserve_props:visible+=int(sack.visible)
		check(visible==int(ceil(amount/20.0)),"Rice reserve dressing does not match state")
	hearth._tune_radio(2,false)
	check(hearth.current_radio_channel==2 and not hearth.radio_text.text.is_empty(),"Radio controls stopped working")
	for resolution in [Vector2i(1280,720),Vector2i(960,720),Vector2i(1280,600)]:
		view.size=resolution
		hearth.size=resolution
		for i in 12:await process_frame
		check(hearth.launch_button.get_global_rect().end.y<=resolution.y+.5,"Launch button falls below screen")
		check(hearth._card_columns.size.x<=resolution.x-39,"Management cards clip horizontally")
		check(hearth._card_columns.columns==(1 if resolution.x<1100 else 3),"Hearth did not adapt its card layout")
		# Every house/granary corner must fit inside the panorama.
		var size=village.viewport_3d.size
		for prop in village.world.get_children():
			if not prop is MeshInstance3D or not (prop.name.begins_with("S3_") or prop.name.begins_with("S4_")):continue
			for i in 8:
				var point:Vector3=prop.global_transform*prop.mesh.get_aabb().get_endpoint(i)
				var pixel:Vector2=village.camera.unproject_position(point)
				check(pixel.x>=0 and pixel.x<=size.x and pixel.y>=0 and pixel.y<=size.y,"Village camera crops a building at "+str(resolution))
	var village_home=village.get_parent()
	hearth.show_village()
	for i in 6:await process_frame
	check(hearth._village_overlay!=null and village.get_parent()!=village_home,"Village inspection view did not open")
	village.focus_station("S9")
	check(village.camera.size<10,"Workshop inspection did not frame the station")
	village.focus_station("S3")
	check(village.camera.size<12,"Granary inspection did not frame the station")
	for button in hearth._village_overlay.find_children("*","Button",true,false):
		if button.text=="กลับเตาไฟ":button.pressed.emit()
	for i in 6:await process_frame
	check(hearth._village_overlay==null and village.get_parent()==village_home,"Village inspection did not restore Hearth controls")
	view.queue_free()
	for i in 3:await process_frame
	print("VILLAGE RESULT: ",failures," failures")
	quit(1 if failures else 0)
