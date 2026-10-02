extends Node3D
## C5 asset playback and prop sockets only. Patrol/vision/escort logic belongs to GAME.
@export var autoplay_idle := true
@export var show_equipment := true
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var _tablet: Node3D
var _flashlight: Node3D

func _ready() -> void:
	skeleton=find_children("*","Skeleton3D",true,false)[0]
	animation_player=find_children("*","AnimationPlayer",true,false)[0]
	for clip in ["Idle","Walk","Run","Scan","Escort"]:
		animation_player.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	# Props are aligned in the authored rest pose, then follow each hand bone.
	var flashlight_basis:=Basis(Vector3.RIGHT,Vector3(0,0,1),Vector3.DOWN)
	_flashlight=_attach("Hand.L","T6",flashlight_basis,Vector3(0,-.06,.03),Vector3(0,.08,0))
	var tablet_basis:=Basis(Vector3.LEFT,Vector3(0,0,1),Vector3.UP)
	_tablet=_attach("Hand.R","T7",tablet_basis,Vector3(0,-.035,.03),Vector3(.08,.02,0))
	_tablet.visible=false
	_flashlight.visible=show_equipment
	if autoplay_idle: play_clip("Idle",0)

func _attach(bone: String,id: String,basis: Basis,palm_offset: Vector3,grip: Vector3) -> Node3D:
	var socket:=BoneAttachment3D.new()
	socket.name=id+"Socket"
	socket.bone_name=bone
	skeleton.add_child(socket)
	var prop:=MeshInstance3D.new()
	prop.mesh=AssetLibrary.mesh_or(id,null)
	assert(prop.mesh!=null,"Missing Ranger prop "+id)
	socket.add_child(prop)
	var rest:=skeleton.get_bone_global_rest(skeleton.find_bone(bone))
	prop.transform=rest.affine_inverse()*Transform3D(basis,rest.origin+palm_offset-basis*grip)
	return prop

func play_clip(clip: String,blend: float=.15) -> void:
	assert(animation_player.has_animation(clip),"Unknown Ranger clip "+clip)
	_tablet.visible=show_equipment and clip=="Photograph"
	_flashlight.visible=show_equipment and clip!="Photograph" and clip!="RadioTalk"
	animation_player.play(clip,blend)
