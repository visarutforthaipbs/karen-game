extends ChibiAnimator
## Same controller interface as ChibiAnimator, with actual skinned animation.

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var hand_socket: Node3D
var back_socket: Node3D
var _action_playing := false

func _ready() -> void:
	super._ready()
	var players := find_children("*", "AnimationPlayer", true, false)
	var skeletons := find_children("*", "Skeleton3D", true, false)
	assert(not players.is_empty() and not skeletons.is_empty(), "Rigged character needs animation and skeleton")
	animation_player = players[0]
	skeleton = skeletons[0]
	for clip in ["Idle", "Walk", "ToolUse"]:
		assert(animation_player.has_animation(clip), "Missing character animation: " + clip)
		animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip == "ToolUse" else Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	hand_socket = _make_socket("Hand.R", "ToolGrip", Vector3(-0.023, -0.017, 0.015))
	back_socket = _make_socket("Chest", "Backpack", Vector3(0, -0.05, -0.13))
	animation_player.play("Idle")

func _make_socket(bone: String, socket_name: String, rest_offset: Vector3) -> Node3D:
	var bone_id := skeleton.find_bone(bone)
	assert(bone_id >= 0, "Missing socket bone: " + bone)
	var attachment := BoneAttachment3D.new()
	attachment.name = socket_name + "Bone"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var socket := Node3D.new()
	socket.name = socket_name
	attachment.add_child(socket)
	# Tools are authored Y-up; cancel the bone's rest orientation, not its motion.
	var inverse_rest := skeleton.get_bone_global_rest(bone_id).basis.inverse()
	socket.basis = inverse_rest
	socket.position = inverse_rest * rest_offset
	return socket

func get_hand_socket() -> Node3D:
	return hand_socket

func get_back_socket() -> Node3D:
	return back_socket

func update_animation(delta: float, velocity: Vector3, face_dir: Vector3 = Vector3.ZERO) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_is_moving = speed > 0.2
	var facing := face_dir if face_dir != Vector3.ZERO else Vector3(velocity.x, 0, velocity.z)
	if facing.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(delta * 12.0, 1.0))
	if _action_playing:
		return
	var next := "Walk" if _is_moving else "Idle"
	if animation_player.current_animation != next:
		animation_player.play(next, 0.15)
	animation_player.speed_scale = clampf(speed / 2.0, 0.65, 2.5) if _is_moving else 1.0

func trigger_action() -> void:
	# Held tools may trigger every 0.15s; do not continually restart the wind-up.
	if _action_playing:
		return
	_action_playing = true
	animation_player.speed_scale = 1.0
	animation_player.play("ToolUse", 0.10)

func _on_animation_finished(clip: StringName) -> void:
	if clip == &"ToolUse":
		_action_playing = false
		animation_player.play("Walk" if _is_moving else "Idle", 0.15)
