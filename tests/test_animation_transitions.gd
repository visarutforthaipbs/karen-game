extends SceneTree
## Gait changes preserve phase, avoid speed-boundary flicker and keep gestures timed.
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	for scene in ["KhanaeChibi","TapohChibi","MunawChibi","MaeluChibi"]:
		var actor=load("res://scenes/characters/"+scene+".tscn").instantiate()
		root.add_child(actor)
		actor.set_process(false)
		await process_frame
		var player:AnimationPlayer=actor.animation_player
		actor.update_animation(.2,Vector3(0,0,6))
		check(player.current_animation=="Run",scene+" does not run at gameplay speed")
		player.seek(.21,true)
		var phase:=player.current_animation_position/player.get_animation("Run").length
		actor.update_animation(0,Vector3(0,0,4.4))
		check(player.current_animation=="Run",scene+" flickers to Walk near the speed boundary")
		actor.update_animation(0,Vector3(0,0,4.1))
		check(player.current_animation=="Walk",scene+" does not settle to Walk")
		check(absf(player.current_animation_position/player.get_animation("Walk").length-phase)<.001,scene+" gait change restarts the footstep")
		actor.update_animation(0,Vector3(0,0,4.4))
		check(player.current_animation=="Walk",scene+" flickers to Run near the speed boundary")
		actor.set_work(&"spray",true)
		actor.update_animation(.2,Vector3(0,0,6))
		actor.cancel_work()
		actor.update_animation(.1,Vector3.ZERO)
		check(player.current_animation=="Idle" and actor.work_blend==0,scene+" stops in a working gait")
		actor.queue_free()
		await process_frame
	for scene in ["RangerChibi","RangerSlateChibi"]:
		var ranger=load("res://scenes/characters/"+scene+".tscn").instantiate()
		root.add_child(ranger)
		await process_frame
		var player:AnimationPlayer=ranger.animation_player
		ranger.update_animation(.1,Vector3(0,0,6))
		check(player.current_animation=="Run" and player.speed_scale>1,scene+" does not match running cadence")
		ranger.play_clip("RadioTalk",0)
		check(player.speed_scale==1 and not ranger._flashlight.visible,scene+" radio inherits running playback or torch")
		ranger.play_clip("Photograph",0)
		check(ranger._tablet.visible and not ranger._flashlight.visible,scene+" photograph has wrong equipment")
		ranger.play_clip("Escort",0)
		ranger.update_animation(.1,Vector3(0,0,.8))
		check(player.current_animation=="Escort" and player.speed_scale<1,scene+" escort ignores gait speed")
		ranger.queue_free()
		await process_frame
	print("ANIMATION TRANSITIONS: ",failures," failures")
	quit(1 if failures else 0)
