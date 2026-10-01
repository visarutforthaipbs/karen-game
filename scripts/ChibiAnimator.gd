class_name ChibiAnimator
extends Node3D

## Visual-only scale so the chibi silhouette reads clearly in the isometric camera.
## Pipeline assets are authored at spec height (1.10–1.20 m); this multiplies that.
@export var base_scale: float = 1.35

@export var walk_bob_speed: float = 14.0
@export var walk_bob_height: float = 0.12
@export var waddle_tilt_angle: float = 0.12
@export var idle_breath_speed: float = 3.0
@export var idle_breath_amount: float = 0.03

var _anim_phase: float = 0.0
var _is_moving: bool = false
var _action_timer: float = 0.0
var _action_duration: float = 0.35

func _ready() -> void:
	_setup_meshes(self)
	scale = Vector3.ONE * base_scale

func _setup_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_apply_toon_vertex_material(child)
		_setup_meshes(child)

func _apply_toon_vertex_material(mesh_node: MeshInstance3D) -> void:
	if mesh_node.mesh == null:
		return
	for surface in mesh_node.mesh.get_surface_count():
		var imported = mesh_node.get_active_material(surface)
		# Keep textured and solid imported materials. Only vertex-coloured surfaces
		# need the legacy toon override; otherwise it erases fabric or solid hair.
		var has_vertex_colors = mesh_node.mesh is ArrayMesh and (mesh_node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0
		if imported is BaseMaterial3D and (imported.albedo_texture != null or not has_vertex_colors):
			continue
		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.65
		mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.rim_enabled = true
		mat.rim = 0.55
		mat.rim_tint = 0.5
		mesh_node.set_surface_override_material(surface, mat)

func _set_squash_scale(factors: Vector3) -> void:
	scale = Vector3.ONE * base_scale * factors

func update_animation(delta: float, velocity: Vector3, face_dir: Vector3 = Vector3.ZERO) -> void:
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	_is_moving = horizontal_speed > 0.2
	
	# Face movement direction smoothly if moving
	if face_dir != Vector3.ZERO:
		var target_rot = atan2(face_dir.x, face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 12.0)
	elif _is_moving:
		var target_rot = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 12.0)
		
	# Action animation override (swing / strike)
	if _action_timer > 0.0:
		_action_timer -= delta
		var t = 1.0 - (_action_timer / _action_duration)
		# Quick anticipatory wind-up and decisive forward swing
		var swing_pitch = sin(t * PI) * 0.45
		rotation.x = swing_pitch
		_set_squash_scale(Vector3(1.0 + sin(t * PI) * 0.1, 1.0 - sin(t * PI) * 0.1, 1.0))
		return
	else:
		rotation.x = lerp(rotation.x, 0.0, delta * 10.0)

	if _is_moving:
		_anim_phase += delta * walk_bob_speed * (horizontal_speed / 4.0)
		# Bouncy step bob (hops twice per full cycle)
		position.y = abs(sin(_anim_phase)) * walk_bob_height
		# Cute side-to-side waddle tilt
		rotation.z = sin(_anim_phase) * waddle_tilt_angle
		# Squash and stretch on footsteps
		var squash = sin(_anim_phase * 2.0) * 0.05
		_set_squash_scale(Vector3(1.0 + squash, 1.0 - squash, 1.0 + squash))
	else:
		_anim_phase += delta * idle_breath_speed
		# Gentle idle breathing bob
		position.y = lerp(position.y, sin(_anim_phase) * idle_breath_amount, delta * 6.0)
		rotation.z = lerp(rotation.z, 0.0, delta * 8.0)
		var breath = sin(_anim_phase) * 0.02
		_set_squash_scale(Vector3(1.0 - breath, 1.0 + breath, 1.0 - breath))

func trigger_action() -> void:
	_action_timer = _action_duration
