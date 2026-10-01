extends ChibiAnimator
## Same controller interface as ChibiAnimator, with actual skinned animation.

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var hand_socket: Node3D
var back_socket: Node3D
var left_hand_socket: Node3D
@export_enum("khanae", "tapoh", "munaw") var character_profile: String = "khanae"
var _action_playing := false
var work_kind: StringName = &""
var work_active := false
var work_phase := 0.0
var work_blend := 0.0
var coughing := false
var terrain: Node3D
var _motion_time := 0.0
var _work_hold := 0.0
var _last_face := Vector3.ZERO
var _bone_ids: Dictionary = {}
var _rest_axes: Dictionary = {}


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
	if animation_player.has_animation("Run"):
		animation_player.get_animation("Run").loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	hand_socket = _make_socket("Hand.R", "ToolGrip", Vector3(-0.023, -0.017, 0.015))
	left_hand_socket = _make_socket("Hand.L", "LeftGrip", Vector3.ZERO)
	back_socket = _make_socket("Chest", "Backpack", Vector3(0, -0.05, -0.13))
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in skeleton.get_bone_count():
		_bone_ids[skeleton.get_bone_name(i)] = i
		_rest_axes[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i).basis.get_rotation_quaternion()
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

func get_left_hand_socket() -> Node3D:
	return left_hand_socket

func get_back_socket() -> Node3D:
	return back_socket

## Controllers send semantic state, not a new swing on each successful cell.
func set_work(kind: StringName, active: bool) -> void:
	if kind != work_kind:
		work_blend = 0.0
		work_phase = 0.0
	work_kind = kind
	work_active = active
	if active:
		_work_hold = 0.12
		_action_playing = false

func cancel_work() -> void:
	work_active = false
	_work_hold = 0.0
	work_blend = 0.0
	_action_playing = false
	_last_face = Vector3.ZERO
	animation_player.play("Idle", 0)
	skeleton.reset_bone_poses()
	animation_player.advance(0)

func set_environment(grid: Node3D, smoke: bool) -> void:
	terrain = grid
	coughing = smoke

func update_animation(delta: float, velocity: Vector3, face_dir: Vector3 = Vector3.ZERO) -> void:
	_motion_time += delta
	_work_hold = maxf(0, _work_hold - delta)
	var working := work_active or _work_hold > 0
	work_blend = move_toward(work_blend, 1.0 if working else 0.0, delta * 9.0)
	if work_blend > 0:
		work_phase += delta
	var speed := Vector2(velocity.x, velocity.z).length()
	_is_moving = speed > 0.2
	var facing := face_dir if face_dir != Vector3.ZERO else Vector3(velocity.x, 0, velocity.z)
	if facing.length_squared() > 0.001:
		_last_face = facing
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(delta * 12.0, 1.0))
	if not _action_playing:
		var next := ("Run" if speed >= 4.6 and animation_player.has_animation("Run") else "Walk") if _is_moving else "Idle"
		if animation_player.current_animation != next:
			animation_player.play(next, 0.15)
		animation_player.speed_scale = clampf(speed / (2.8 if next == "Run" else 2.0), 0.65, 3.2) if _is_moving else 1.0
	skeleton.reset_bone_poses()
	animation_player.advance(delta)
	# Base clips re-key all bones each frame; the following layers cannot accumulate.
	if not _action_playing:
		_apply_motion_layers(velocity)

func _rotate_bone(bone: StringName, axis: Vector3, radians: float) -> void:
	var id: int = _bone_ids[bone]
	var rest: Quaternion = _rest_axes[bone]
	var q := rest.inverse() * Quaternion(axis, radians) * rest
	skeleton.set_bone_pose_rotation(id, skeleton.get_bone_pose_rotation(id) * q)

func _apply_motion_layers(velocity: Vector3) -> void:
	# Turn the pelvis/legs toward travel while chest and tools keep their aim.
	if _is_moving and work_blend > 0.0:
		var travel := wrapf(atan2(velocity.x, velocity.z) - rotation.y, -PI, PI)
		for side in ["L", "R"]:
			var foot := StringName("Foot." + side)
			var rest := skeleton.get_bone_global_rest(_bone_ids[foot]).origin
			var offset := skeleton.get_bone_global_pose(_bone_ids[foot]).origin - rest
			var target := rest + Basis(Vector3.UP, travel) * offset
			_solve_chain(StringName("Thigh." + side), StringName("Shin." + side), foot, target, work_blend)
	if character_profile == "munaw":
		# His fused wand, fingers and hose were authored in a two-hand hold.
		# Preserve that hold rather than swinging the arms through rigid equipment.
		for bone in [&"UpperArm.L", &"UpperArm.R", &"Forearm.L", &"Forearm.R"]:
			skeleton.set_bone_pose_rotation(_bone_ids[bone], skeleton.get_bone_rest(_bone_ids[bone]).basis.get_rotation_quaternion())
	if work_blend <= 0.001:
		hand_socket.basis = skeleton.get_bone_global_rest(_bone_ids[&"Hand.R"]).basis.inverse()
	if work_blend > 0.001:
		_apply_work_pose()
	if coughing:
		var cough := pow(maxf(0, sin(_motion_time * 7.0)), 4) * 0.07
		_rotate_bone(&"Chest", Vector3.RIGHT, cough)
		_rotate_bone(&"Head", Vector3.RIGHT, cough * 0.5)
	skeleton.force_update_all_bone_transforms()
	_place_feet()

func _apply_work_pose() -> void:
	var cycle := sin(work_phase * TAU / 0.8)
	if character_profile == "munaw":
		_rotate_bone(&"Chest", Vector3.UP, work_blend * 0.12 * sin(work_phase * 1.5))
		return
	if character_profile == "tapoh" and work_kind == &"spray":
		_rotate_bone(&"UpperArm.L", Vector3.RIGHT, work_blend * -0.35)
		_rotate_bone(&"Forearm.L", Vector3.RIGHT, work_blend * -0.15)
		return
	if character_profile == "tapoh":
		# Existing blade remains on the right hand; modest bends protect fused sleeve.
		_rotate_bone(&"UpperArm.R", Vector3.RIGHT, work_blend * (-0.25 - 0.22 * cycle))
		_rotate_bone(&"Forearm.R", Vector3.RIGHT, work_blend * -0.10)
		_rotate_bone(&"Chest", Vector3.RIGHT, work_blend * -0.035 * cycle)
		return
	# Explicit hand targets produce distinct holds without replacing the gait.
	var right := Vector3(-0.22, 0.46, 0.18)
	var direction := Vector3(0, -0.4, 0.9).normalized()
	match work_kind:
		&"rake":
			right = Vector3(0.0, 0.52 + 0.006 * cycle, 0.025 + 0.018 * cycle)
			direction = Vector3(0.02, -0.60, 0.80).normalized()
		&"spray":
			right = Vector3(-0.22, 0.50, 0.22)
			direction = Vector3(0, -0.10, 1).normalized()
		&"ignite":
			right = Vector3(-0.25, 0.39, 0.14)
			direction = Vector3(-0.10, -0.42, 0.9).normalized()
	_solve_chain(&"UpperArm.R", &"Forearm.R", &"Hand.R", right, work_blend)
	skeleton.force_update_all_bone_transforms()
	# Align tool +Y to its working direction in character space, independent of wrist rest basis.
	var hand: Transform3D = skeleton.get_bone_global_pose(_bone_ids[&"Hand.R"])
	var desired := Quaternion(Vector3.UP, direction)
	hand_socket.basis = Basis(hand.basis.get_rotation_quaternion().inverse() * desired)
	if work_kind == &"rake":
		var grip: Vector3 = (hand * hand_socket.position) + direction * (0.14 / base_scale) - Vector3(0.023, -0.017, 0.015)
		_solve_chain(&"UpperArm.L", &"Forearm.L", &"Hand.L", grip, work_blend)

## Two joint CCD in skeleton coordinates. Targets are clamped by chain geometry.
func _solve_chain(upper: StringName, lower: StringName, end: StringName, target: Vector3, amount: float) -> void:
	var end_id: int = _bone_ids[end]
	var end_rotation := skeleton.get_bone_global_pose(end_id).basis.get_rotation_quaternion()
	var original: Vector3 = skeleton.get_bone_global_pose(end_id).origin
	var goal := original.lerp(target, amount)
	if String(upper).begins_with("UpperArm."):
		_solve_arm(upper, lower, end, goal)
		return
	for iteration in 5:
		for bone in [lower, upper]:
			var id: int = _bone_ids[bone]
			skeleton.force_update_all_bone_transforms()
			var pose := skeleton.get_bone_global_pose(id)
			var from := skeleton.get_bone_global_pose(end_id).origin - pose.origin
			var to := goal - pose.origin
			if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
				continue
			var world_delta := Quaternion(from.normalized(), to.normalized())
			var basis := pose.basis.get_rotation_quaternion()
			var local_delta := basis.inverse() * world_delta * basis
			skeleton.set_bone_pose_rotation(id, skeleton.get_bone_pose_rotation(id) * local_delta)
		skeleton.force_update_all_bone_transforms()

	if String(end).begins_with("Foot."):
		var solved := skeleton.get_bone_global_pose(end_id).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(end_id, skeleton.get_bone_pose_rotation(end_id) * solved.inverse() * end_rotation)
		skeleton.force_update_all_bone_transforms()

func _aim_segment(bone: StringName, end: StringName, target: Vector3) -> void:
	var id: int = _bone_ids[bone]
	var pose := skeleton.get_bone_global_pose(id)
	var from := skeleton.get_bone_global_pose(_bone_ids[end]).origin - pose.origin
	var to := target - pose.origin
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001: return
	var basis := pose.basis.get_rotation_quaternion()
	var delta := basis.inverse() * Quaternion(from.normalized(), to.normalized()) * basis
	skeleton.set_bone_pose_rotation(id, skeleton.get_bone_pose_rotation(id) * delta)
	skeleton.force_update_all_bone_transforms()

func _solve_arm(upper: StringName, lower: StringName, end: StringName, target: Vector3) -> void:
	# Analytic bend with an outward/downward elbow pole avoids CCD folding the
	# elbow through the torso when the two hands meet in front of the chest.
	var a := skeleton.get_bone_global_pose(_bone_ids[upper]).origin
	var b := skeleton.get_bone_global_pose(_bone_ids[lower]).origin
	var c := skeleton.get_bone_global_pose(_bone_ids[end]).origin
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var direction := (target - a).normalized()
	var distance := clampf(a.distance_to(target), absf(first-second)+0.001, first+second-0.001)
	var along := (first*first + distance*distance - second*second)/(2*distance)
	var height := sqrt(maxf(0, first*first - along*along))
	var pole := Vector3(1 if String(upper).ends_with("L") else -1, -1, -0.25)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var elbow := a + direction * along + pole * height
	_aim_segment(upper, lower, elbow)
	_aim_segment(lower, end, a + direction * distance)

func _place_feet() -> void:
	if terrain == null:
		return
	for side in ["L", "R"]:
		var foot := StringName("Foot." + side)
		var pose := skeleton.get_bone_global_pose(_bone_ids[foot])
		var world := skeleton.to_global(pose.origin)
		var ground: float = terrain.get_ground_height_at_world_pos(world)
		var sole: float = skeleton.get_bone_global_rest(_bone_ids[foot]).origin.y * base_scale
		# Only correct terrain penetration/near-ground contact. Preserve lifted swing feet.
		var correction := ground + sole - world.y
		if correction > 0 or absf(correction) < 0.035:
			world.y += clampf(correction, -0.04, 0.10)
			_solve_chain(StringName("Thigh." + side), StringName("Shin." + side), foot, skeleton.to_local(world), 1.0)

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
