class_name PlayerController
extends CharacterBody3D

signal tool_changed(tool_name: String)
signal order_pinged(cell_coord: Vector2i, cell_world_pos: Vector3)
signal whistle_blown()
signal stamina_changed(current: float, max_stamina: float)
signal smoke_exposure_changed(exposure_level: float)
signal water_changed(current: float, capacity: float)
signal tank_empty()

enum ToolType {
	DRIP_TORCH,      # 1: Ignites vegetation
	FIREBREAK_BLADE, # 2: Clears firebreak
	WATER_SPRAYER    # 3: Douses hot embers and flames
}
const TOOL_LABELS = {
	ToolType.DRIP_TORCH: "ถังหยดไฟ · จุดไฟ",
	ToolType.FIREBREAK_BLADE: "มีดพร้าและคราด · ถางแนวกันไฟ",
	ToolType.WATER_SPRAYER: "ถังพ่นน้ำสะพายหลัง · ดับไฟ",
}

@export var base_move_speed: float = 6.0
@export var interaction_range: float = 4.0 # Horizontal reach in metres
@export var tool_cooldown: float = 0.15
@export var fire_grid: FireGrid

## Turned off by MainController once the 20:00 pass begins
var input_enabled: bool = true
var _tool_cooldown_left: float = 0.0

var current_tool: ToolType = ToolType.DRIP_TORCH
var target_cell_coord: Vector2i = Vector2i(-1, -1)
var target_cell_pos: Vector3 = Vector3.ZERO
var is_targeting_valid_cell: bool = false

# Stamina & Smoke Asphyxiation (PRD §4.3: >4 s in dense smoke -> coughing)
var max_stamina: float = 100.0
var current_stamina: float = 100.0
var stamina_regen_multiplier: float = 1.0
var speed_multiplier: float = 1.0
var smoke_exposure: float = 0.0
const SMOKE_COUGH_THRESHOLD: float = 4.0
var _cough_timer: float = 0.0

# 15 L backpack sprayer (PRD §5.1); refilled at the field hut barrels
const REFILL_RADIUS: float = 3.5
const REFILL_RATE: float = 5.0 # Litres per second
var water_capacity: float = 15.0
var water: float = 15.0
var water_per_douse: float = 1.0
var refill_point: Vector3 = Vector3.INF
var _empty_warned: bool = false
## Sharper knives clear brush faster
var blade_cooldown_multiplier: float = 1.0
## Cutting a firebreak cell down to mineral soil takes a held half-second of work
const CLEAR_SECONDS: float = 0.5
var _clear_cell: Vector2i = Vector2i(-1, -1)
var _clear_progress: float = 0.0

# Gamepad aim: a virtual cursor offset around the player's screen position
const GAMEPAD_AIM_SPEED: float = 650.0
const GAMEPAD_AIM_RADIUS: float = 360.0
var using_gamepad_aim: bool = false
var gamepad_aim_offset: Vector2 = Vector2(0, -140)

# Visual indicator for targeted grid cell
var target_indicator: MeshInstance3D
var animator: Node3D
var _tool_rig: Node3D
var _tool_prop: MeshInstance3D
var _torch_light: OmniLight3D

func _ready() -> void:
	for child in get_children():
		if child.has_method("update_animation"):
			animator = child
			break
	_create_target_indicator()
	_create_tool_rig()
	_select_tool(ToolType.DRIP_TORCH)

func _create_target_indicator() -> void:
	target_indicator = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.5, 0.1, 1.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	target_indicator.mesh = box
	# Child of the player (so it is freed with the scene) but positioned in world space
	target_indicator.top_level = true
	add_child(target_indicator)

## Hand tool + backpack sprayer tank, turned to face where the player walks
func _create_tool_rig() -> void:
	_tool_rig = Node3D.new()
	add_child(_tool_rig)
	var tank = MeshInstance3D.new()
	tank.mesh = AssetLibrary.mesh_or("T4", LowPoly.sprayer_tank())
	tank.position = Vector3(0, 0.85, -0.3)
	_tool_rig.add_child(tank)
	_tool_prop = MeshInstance3D.new()
	_tool_prop.position = Vector3(0.38, 0.45, 0.18)
	_tool_rig.add_child(_tool_prop)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.6, 0.2)
	_torch_light.omni_range = 4.0
	_torch_light.light_energy = 0.9
	_torch_light.position = Vector3(0.38, 1.4, 0.18)
	_tool_rig.add_child(_torch_light)
	if animator and animator.has_method("get_hand_socket"):
		_tool_prop.reparent(animator.get_hand_socket(), false)
		_tool_prop.position = Vector3.ZERO
		_tool_prop.scale = Vector3.ONE / animator.base_scale
		_torch_light.reparent(_tool_prop, false)
		_torch_light.position = Vector3(0, 0.9, 0)
		tank.reparent(animator.get_back_socket(), false)
		tank.position = Vector3.ZERO
		tank.scale = Vector3.ONE / animator.base_scale

func _select_tool(tool: ToolType) -> void:
	current_tool = tool
	if animator and animator.has_method("cancel_work"):
		animator.cancel_work()
	match tool:
		ToolType.DRIP_TORCH:
			_tool_prop.mesh = AssetLibrary.mesh_or("T1", LowPoly.tool_mesh("torch"))
		ToolType.FIREBREAK_BLADE:
			_tool_prop.mesh = AssetLibrary.mesh_or("T3", LowPoly.tool_mesh("rake"))
		_:
			_tool_prop.mesh = AssetLibrary.mesh_or("T5", LowPoly.tool_mesh("wand"))
	_torch_light.visible = tool == ToolType.DRIP_TORCH
	if animator and animator.has_method("get_hand_socket"):
		# Pipeline tools are grounded at their base; move the handle grip to the palm.
		_tool_prop.position.y = -0.22 if AssetLibrary.has_asset(["T1", "T3", "T5"][int(tool)]) else 0.0
	tool_changed.emit(TOOL_LABELS[tool])

func _physics_process(delta: float) -> void:
	if animator and animator.has_method("set_environment"):
		animator.set_environment(fire_grid, smoke_exposure >= SMOKE_COUGH_THRESHOLD)
	_update_smoke_and_stamina(delta)
	_update_refill(delta)
	if not input_enabled:
		velocity = Vector3.ZERO
		if animator:
			animator.update_animation(delta, velocity)
		return
	_handle_movement(delta)
	_update_gamepad_aim(delta)
	_update_mouse_targeting()
	_handle_button_actions()
	_update_work_animation()
	_handle_held_actions(delta)
	if animator:
		var facing := target_cell_pos - global_position if is_targeting_valid_cell and Input.is_action_pressed("use_tool") and not _pointer_over_gui() else Vector3.ZERO
		facing.y = 0
		animator.update_animation(delta, velocity, facing)

func _update_smoke_and_stamina(delta: float) -> void:
	if not fire_grid:
		return

	var local_smoke = fire_grid.get_smoke_density_at_pos(global_position)

	if local_smoke > 0.15:
		smoke_exposure += delta * (1.0 + local_smoke * 0.5)
	else:
		smoke_exposure = max(0.0, smoke_exposure - delta * 1.5)

	smoke_exposure_changed.emit(smoke_exposure)

	# If choking in smoke, drain stamina rapidly and cough
	if smoke_exposure >= SMOKE_COUGH_THRESHOLD:
		current_stamina = max(0.0, current_stamina - delta * 18.0)
		_cough_timer -= delta
		if _cough_timer <= 0.0:
			_cough_timer = 2.5
			if AudioManager.instance:
				AudioManager.instance.play_cough()
	else:
		_cough_timer = 0.0
		current_stamina = min(max_stamina, current_stamina + delta * 12.0 * stamina_regen_multiplier)

	stamina_changed.emit(current_stamina, max_stamina)

func _update_refill(delta: float) -> void:
	if refill_point == Vector3.INF or water >= water_capacity:
		return
	if Vector2(refill_point.x - global_position.x, refill_point.z - global_position.z).length() <= REFILL_RADIUS:
		water = minf(water_capacity, water + REFILL_RATE * delta)
		_empty_warned = false
		water_changed.emit(water, water_capacity)

func set_water_capacity(capacity: float) -> void:
	water_capacity = capacity
	water = capacity
	water_changed.emit(water, water_capacity)

func _handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var effective_speed = base_move_speed * speed_multiplier

	# 40% movement penalty when coughing / choking in smoke or exhausted
	if smoke_exposure >= SMOKE_COUGH_THRESHOLD or current_stamina <= 10.0:
		effective_speed *= 0.60

	# Screen-relative movement: follows the camera when it is turned
	var forward = Vector3(1, 0, 1).normalized()
	var right = Vector3(1, 0, -1).normalized()
	var cam = get_viewport().get_camera_3d()
	if cam:
		var b = cam.global_basis
		var flat_right = Vector3(b.x.x, 0.0, b.x.z)
		var flat_down = Vector3(b.z.x, 0.0, b.z.z)
		if flat_right.length() > 0.01 and flat_down.length() > 0.01:
			right = flat_right.normalized()
			forward = flat_down.normalized()
	var move_vector = (right * input_dir.x + forward * input_dir.y)
	if move_vector.length() > 1.0:
		move_vector = move_vector.normalized()

	velocity.x = move_vector.x * effective_speed
	velocity.y = 0.0
	velocity.z = move_vector.z * effective_speed

	move_and_slide()
	_follow_terrain(delta)

	if move_vector.length() > 0.1:
		_tool_rig.rotation.y = lerp_angle(_tool_rig.rotation.y, atan2(move_vector.x, move_vector.z), delta * 12.0)

## No physics colliders on the terrain: stay inside the hillside and ride its surface
func _follow_terrain(delta: float) -> void:
	if not fire_grid:
		return
	global_position = fire_grid.clamp_to_grid(global_position)
	var ground_y = fire_grid.get_ground_height_at_world_pos(global_position)
	global_position.y = move_toward(global_position.y, ground_y, 6.0 * delta)

func _input(event: InputEvent) -> void:
	# Moving the mouse hands aiming back from the right stick
	if event is InputEventMouseMotion:
		using_gamepad_aim = false

func _update_gamepad_aim(delta: float) -> void:
	var stick = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.0:
		using_gamepad_aim = true
		gamepad_aim_offset += stick * GAMEPAD_AIM_SPEED * delta
		gamepad_aim_offset = gamepad_aim_offset.limit_length(GAMEPAD_AIM_RADIUS)

func _aim_screen_position(camera: Camera3D) -> Vector2:
	if using_gamepad_aim:
		return camera.unproject_position(global_position) + gamepad_aim_offset
	return get_viewport().get_mouse_position()

func _update_mouse_targeting() -> void:
	if not fire_grid:
		return

	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		return

	var aim_pos = _aim_screen_position(camera)
	var ray_origin = camera.project_ray_origin(aim_pos)
	var ray_dir = camera.project_ray_normal(aim_pos)

	# March the ray over the terraced hill so the picked cell is the one under the cursor
	target_cell_coord = fire_grid.raycast_cell(ray_origin, ray_dir)

	if fire_grid.is_valid_coord(target_cell_coord.x, target_cell_coord.y):
		is_targeting_valid_cell = true
		target_cell_pos = fire_grid.get_cell_world_pos(target_cell_coord.x, target_cell_coord.y)
		if target_indicator:
			target_indicator.visible = true
			target_indicator.global_position = target_cell_pos + Vector3(0, 0.25, 0)
			var in_reach = _flat_distance_to(target_cell_pos) <= interaction_range
			(target_indicator.mesh.material as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 0.0, 0.45) if in_reach else Color(1.0, 0.3, 0.2, 0.3)
	else:
		is_targeting_valid_cell = false
		if target_indicator:
			target_indicator.visible = false

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled and animator and animator.has_method("cancel_work"):
		animator.cancel_work()
	if not enabled and target_indicator:
		target_indicator.visible = false

## One-shot actions: tool hotkeys, rally whistle, companion pings (once per press,
## polled so gamepad triggers work like buttons)
func _handle_button_actions() -> void:
	if Input.is_action_just_pressed("tool_torch"):
		_select_tool(ToolType.DRIP_TORCH)
	elif Input.is_action_just_pressed("tool_blade"):
		_select_tool(ToolType.FIREBREAK_BLADE)
	elif Input.is_action_just_pressed("tool_sprayer"):
		_select_tool(ToolType.WATER_SPRAYER)
	elif Input.is_action_just_pressed("tool_cycle"):
		_select_tool(ToolType.values()[(current_tool + 1) % ToolType.size()])

	if Input.is_action_just_pressed("rally_whistle"):
		whistle_blown.emit()

	if Input.is_action_just_pressed("ping_companion") and is_targeting_valid_cell and not _pointer_over_gui():
		order_pinged.emit(target_cell_coord, target_cell_pos)

func _pointer_over_gui() -> bool:
	if using_gamepad_aim:
		return false
	var vp = get_viewport()
	return vp.has_method("gui_get_hovered_control") and vp.gui_get_hovered_control() != null

func _flat_distance_to(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()

## Use tool (hold): rate-limited so dragging paints a line
func _handle_held_actions(delta: float) -> void:
	_tool_cooldown_left = max(0.0, _tool_cooldown_left - delta)
	if _tool_cooldown_left > 0.0:
		return

	if Input.is_action_pressed("use_tool") and is_targeting_valid_cell and not _pointer_over_gui():
		if _flat_distance_to(target_cell_pos) <= interaction_range:
			if current_tool == ToolType.FIREBREAK_BLADE:
				_cut_firebreak(target_cell_coord, delta)
				return
			_apply_tool_to_cell(target_cell_coord)
			_tool_cooldown_left = tool_cooldown
			return
	_clear_progress = 0.0

## Hold on a cell to rake it down to bare soil; moving to another cell restarts the work
func _cut_firebreak(coord: Vector2i, delta: float) -> void:
	if coord != _clear_cell:
		_clear_cell = coord
		_clear_progress = 0.0
	var before = _clear_progress
	_clear_progress += delta / (CLEAR_SECONDS * blade_cooldown_multiplier)
	if fmod(before, 0.5) > fmod(_clear_progress, 0.5):
		_swing()
	if _clear_progress >= 1.0:
		_apply_tool_to_cell(coord)
		_clear_progress = 0.0
		_clear_cell = Vector2i(-1, -1)

func _apply_tool_to_cell(coord: Vector2i) -> void:
	if not fire_grid:
		return

	match current_tool:
		ToolType.DRIP_TORCH:
			if fire_grid.ignite_cell(coord.x, coord.y):
				_swing()
				_show_tool_feedback(coord)
		ToolType.FIREBREAK_BLADE:
			if fire_grid.clear_firebreak(coord.x, coord.y):
				_swing()
				_show_tool_feedback(coord)
		ToolType.WATER_SPRAYER:
			if water < water_per_douse:
				if not _empty_warned:
					_empty_warned = true
					tank_empty.emit()
				return
			if fire_grid.douse_cell(coord.x, coord.y):
				_swing()
				_show_tool_feedback(coord)
				water = maxf(0.0, water - water_per_douse)
				water_changed.emit(water, water_capacity)
				if AudioManager.instance:
					AudioManager.instance.play_water_spray()

func _work_kind() -> StringName:
	return [&"ignite", &"rake", &"spray"][int(current_tool)]

func _can_animate_work() -> bool:
	if not input_enabled or not fire_grid or not is_targeting_valid_cell or not Input.is_action_pressed("use_tool") or _pointer_over_gui():
		return false
	if _flat_distance_to(target_cell_pos) > interaction_range or not fire_grid.is_valid_coord(target_cell_coord.x, target_cell_coord.y):
		return false
	var type: int = fire_grid.cell_types[fire_grid._coord_to_index(target_cell_coord.x, target_cell_coord.y)]
	if current_tool == ToolType.WATER_SPRAYER:
		return water >= water_per_douse and type in [FireGrid.CellType.BURNING, FireGrid.CellType.SMOLDERING]
	return type in [FireGrid.CellType.VEGETATION, FireGrid.CellType.BAMBOO]

func _update_work_animation() -> void:
	if animator and animator.has_method("set_work"):
		animator.set_work(_work_kind(), _can_animate_work())

func _swing() -> void:
	if animator:
		if animator.has_method("set_work"):
			animator.set_work(_work_kind(), true)
		else:
			animator.trigger_action()
		if animator.has_method("get_hand_socket"):
			return # The hand bone drives the tool; avoid a second unrelated swing.
	var tween = _tool_prop.create_tween()
	tween.tween_property(_tool_prop, "rotation:x", 0.9, 0.08)
	tween.tween_property(_tool_prop, "rotation:x", 0.0, 0.14)

func _show_tool_feedback(coord: Vector2i) -> void:
	var origin := _tool_prop.global_position
	if current_tool == ToolType.WATER_SPRAYER:
		origin = _tool_prop.to_global(Vector3(0, 0.68, 0))
	load("res://scripts/CharacterToolFeedback.gd").spawn(get_parent(), origin, fire_grid.get_cell_world_pos(coord.x, coord.y), _work_kind())
