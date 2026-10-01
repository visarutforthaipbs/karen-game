class_name CompanionController
extends CharacterBody3D

## Mutual-aid crew AI (PRD §5.2). Companions work autonomously so the player never
## micromanages: Ta-poh cuts firebreaks on the downwind side, Mu-naw hunts embers and
## pulses his Thermal Eye. Both choke in smoke and flee it if it gets too thick.

signal status_changed(companion: CompanionController, text: String)
signal started_coughing(companion: CompanionController)

enum Role { ELDER, YOUTH }
enum State { IDLE_FOLLOW, AUTONOMOUS_WORK, MOVING_TO_TASK, PERFORMING_TASK, FLEEING }

@export var role: Role = Role.YOUTH
@export var player: Node3D
@export var fire_grid: FireGrid

var move_speed: float = 4.5
var work_efficiency: float = 1.0
## Granary rations: full bellies walk faster, lean ones slower
var speed_multiplier: float = 1.0
## Ta-poh carries a borrowed backpack sprayer (mutual aid exchange)
var can_douse: bool = false

var current_state: State = State.IDLE_FOLLOW
var target_coord: Vector2i = Vector2i(-1, -1)
var target_world_pos: Vector3 = Vector3.ZERO
var task_progress: float = 0.0
const REQUIRED_TASK_WORK: float = 1.4

# Smoke asphyxiation (PRD §4.3)
const COUGH_THRESHOLD: float = 4.0
const FLEE_DENSITY: float = 0.75
var smoke_exposure: float = 0.0
var is_coughing: bool = false

# Mu-naw's Thermal Eye (PRD §5.2): pulse highlights embers within 12 m
const THERMAL_EYE_RADIUS_M: float = 12.0
const THERMAL_EYE_PERIOD: float = 4.0
var _eye_timer: float = 0.0

var auto_search_timer: float = 0.0
var animator: Node3D
var status_text: String = ""
var _borrowed_equipment: Node3D
var _borrowed_wand: MeshInstance3D

func configure_borrowed_sprayer(enabled: bool) -> void:
	can_douse = enabled
	if not animator or not animator.has_method("get_hand_socket"):
		return
	if _borrowed_equipment:
		_borrowed_equipment.queue_free()
		_borrowed_wand.queue_free()
		_borrowed_equipment = null
		_borrowed_wand = null
	if not enabled:
		return
	var tank := MeshInstance3D.new()
	tank.mesh = AssetLibrary.mesh_or("T4", LowPoly.sprayer_tank())
	animator.get_back_socket().add_child(tank)
	tank.scale = Vector3.ONE / animator.base_scale
	_borrowed_equipment = tank
	_borrowed_wand = MeshInstance3D.new()
	_borrowed_wand.mesh = AssetLibrary.mesh_or("T5", LowPoly.tool_mesh("wand"))
	animator.get_left_hand_socket().add_child(_borrowed_wand)
	_borrowed_wand.scale = Vector3.ONE / animator.base_scale
	_borrowed_wand.visible = false

func cancel_animation_work() -> void:
	if animator and animator.has_method("cancel_work"):
		animator.cancel_work()


func _ready() -> void:
	for child in get_children():
		if child.has_method("update_animation"):
			animator = child
			break
	apply_role(role)

## Sets role-specific stats; MainController calls this after assigning the role
func apply_role(new_role: Role) -> void:
	role = new_role
	if role == Role.ELDER:
		move_speed = 3.6
		work_efficiency = 1.6 # Clears firebreaks faster
	elif role == Role.YOUTH:
		move_speed = 5.2
		work_efficiency = 1.3 # Fast runner and ember douser

func display_name() -> String:
	return "ตาโพ" if role == Role.ELDER else "มูนอ"

func _physics_process(delta: float) -> void:
	_update_smoke(delta)
	match current_state:
		State.IDLE_FOLLOW:
			_process_idle_follow(delta)
		State.AUTONOMOUS_WORK:
			_process_autonomous_work(delta)
		State.MOVING_TO_TASK:
			_process_move_to_task(delta)
		State.PERFORMING_TASK:
			_process_perform_task(delta)
		State.FLEEING:
			_process_flee(delta)
	if role == Role.YOUTH:
		_update_thermal_eye(delta)
	_follow_terrain(delta)
	if animator:
		var facing := Vector3.ZERO
		if animator.has_method("set_work"):
			var working := current_state == State.PERFORMING_TASK and fire_grid != null and fire_grid.is_valid_coord(target_coord.x, target_coord.y)
			var kind: StringName = &"spray"
			if working:
				var type: int = fire_grid.cell_types[fire_grid._coord_to_index(target_coord.x, target_coord.y)]
				kind = &"rake" if type in [FireGrid.CellType.VEGETATION, FireGrid.CellType.BAMBOO] else &"spray"
				working = type in [FireGrid.CellType.VEGETATION, FireGrid.CellType.BAMBOO, FireGrid.CellType.BURNING, FireGrid.CellType.SMOLDERING]
				facing = target_world_pos - global_position
				facing.y = 0
			animator.set_work(kind, working)
			animator.set_environment(fire_grid, is_coughing)
			if _borrowed_wand:
				_borrowed_wand.visible = working and kind == &"spray"
		animator.update_animation(delta, velocity, facing)

func _effective_speed() -> float:
	return move_speed * speed_multiplier * (0.6 if is_coughing else 1.0)

func _set_status(text: String) -> void:
	if text == status_text:
		return
	status_text = text
	status_changed.emit(self, text)

# ---------------------------------------------------------------------------
# Smoke & fleeing
# ---------------------------------------------------------------------------

func _update_smoke(delta: float) -> void:
	if not fire_grid:
		return
	var density = fire_grid.get_smoke_density_at_pos(global_position)
	if density > 0.15:
		smoke_exposure += delta * (1.0 + density * 0.5)
	else:
		smoke_exposure = maxf(0.0, smoke_exposure - delta * 1.5)

	var was_coughing = is_coughing
	is_coughing = smoke_exposure >= COUGH_THRESHOLD
	if is_coughing and not was_coughing:
		started_coughing.emit(self)

	if current_state == State.FLEEING:
		return
	var coord = fire_grid.get_cell_coord_at_world_pos(global_position)
	var standing_in_fire = fire_grid.is_valid_coord(coord.x, coord.y) and fire_grid.cell_types[fire_grid._coord_to_index(coord.x, coord.y)] == FireGrid.CellType.BURNING
	if standing_in_fire or (is_coughing and density >= FLEE_DENSITY):
		_start_flee()

func _start_flee() -> void:
	cancel_animation_work()
	var here = fire_grid.get_cell_coord_at_world_pos(global_position)
	var best = Vector2i(-1, -1)
	var best_score = INF
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var c = here + Vector2i(dx, dy)
			if not fire_grid.is_valid_coord(c.x, c.y):
				continue
			if fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)] == FireGrid.CellType.BURNING:
				continue
			var p = fire_grid.get_cell_world_pos(c.x, c.y)
			var score = fire_grid.get_smoke_density_at_pos(p) * 10.0
			if player:
				score += Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() * 0.05
			if score < best_score:
				best_score = score
				best = c
	if best.x < 0:
		return
	target_coord = best
	target_world_pos = fire_grid.get_cell_world_pos(best.x, best.y)
	current_state = State.FLEEING
	_set_status("สำลักควัน กำลังหนีออกจากควัน!")

func _process_flee(delta: float) -> void:
	if _flat_distance_to(target_world_pos) > 1.2:
		velocity = Vector3.ZERO
		_move_towards(target_world_pos, delta, move_speed * speed_multiplier)
		return
	velocity = Vector3.ZERO
	if smoke_exposure < 2.0:
		current_state = State.IDLE_FOLLOW
	elif fire_grid.get_smoke_density_at_pos(global_position) > 0.15:
		_start_flee()

# ---------------------------------------------------------------------------
# Following & autonomous work
# ---------------------------------------------------------------------------

func _process_idle_follow(delta: float) -> void:
	if not player: return
	var dist = _flat_distance_to(player.global_position)
	if dist > 6.0:
		_move_towards(player.global_position, delta)
	else:
		velocity = Vector3.ZERO
	_set_status("กำลังไอ" if is_coughing else "เดินตาม")

	# Periodic autonomous behavior when near player (Mu-naw watches for spot fires every second)
	auto_search_timer += delta
	if auto_search_timer >= (1.0 if role == Role.YOUTH else 2.0):
		auto_search_timer = 0.0
		_find_autonomous_task()

func _find_autonomous_task() -> void:
	if not fire_grid: return

	if role == Role.ELDER:
		var cut = _best_elder_firebreak()
		if cut.x >= 0:
			_assign_task(cut)
			return
		if can_douse:
			var ember = _nearest_cell_of(FireGrid.CellType.SMOLDERING, global_position, 5)
			if ember.x >= 0:
				_assign_task(ember)
	elif role == Role.YOUTH:
		# A spot fire in the park comes first: it becomes an escape within seconds
		var spot = _nearest_spot_fire(16)
		if spot.x >= 0:
			_assign_task(spot)
			return
		# Then embers near Mu-naw, then anywhere around the player
		var ember = _nearest_cell_of(FireGrid.CellType.SMOLDERING, global_position, 6)
		if ember.x < 0 and player:
			ember = _nearest_cell_of(FireGrid.CellType.SMOLDERING, player.global_position, 10)
		if ember.x >= 0:
			_assign_task(ember)
			return
		_start_patrol()

func _assign_task(cell: Vector2i) -> void:
	target_coord = cell
	target_world_pos = fire_grid.get_cell_world_pos(cell.x, cell.y)
	current_state = State.MOVING_TO_TASK

## Ta-poh: brush next to the fire front on its downwind side first; with no fire,
## pre-cut the plot perimeter on the downwind edge
func _best_elder_firebreak() -> Vector2i:
	var here = fire_grid.get_cell_coord_at_world_pos(global_position)
	var wind = fire_grid.wind_direction
	var center = Vector2((fire_grid.grid_width - 1) * 0.5, (fire_grid.grid_height - 1) * 0.5)
	var best = Vector2i(-1, -1)
	var best_score = -0.3
	for dy in range(-7, 8):
		for dx in range(-7, 8):
			var c = here + Vector2i(dx, dy)
			if not fire_grid.is_valid_coord(c.x, c.y):
				continue
			var t = fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)]
			if t != FireGrid.CellType.VEGETATION and t != FireGrid.CellType.BAMBOO:
				continue
			var score = -INF
			# Fire within 2 cells: prefer the side the wind is pushing toward
			for fy in range(-2, 3):
				for fx in range(-2, 3):
					var f = c + Vector2i(fx, fy)
					if (fx == 0 and fy == 0) or not fire_grid.is_valid_coord(f.x, f.y):
						continue
					if fire_grid.cell_types[fire_grid._coord_to_index(f.x, f.y)] == FireGrid.CellType.BURNING:
						var away = Vector2(c - f).normalized()
						score = maxf(score, 1.0 + away.dot(wind) * 2.0)
			if score == -INF and _is_adjacent_to_border(c.x, c.y):
				var outward = (Vector2(c) - center).normalized()
				score = outward.dot(wind)
			if score == -INF:
				continue
			score -= Vector2(dx, dy).length() * 0.05
			if score > best_score:
				best_score = score
				best = c
	return best

## Burning park cell near Mu-naw (spot fires are always on the plot edge)
func _nearest_spot_fire(radius: int) -> Vector2i:
	var here = fire_grid.get_cell_coord_at_world_pos(global_position)
	var best = Vector2i(-1, -1)
	var best_d = INF
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c = here + Vector2i(dx, dy)
			if not fire_grid.is_valid_coord(c.x, c.y) or not fire_grid.is_border_coord(c.x, c.y):
				continue
			if fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)] == FireGrid.CellType.BURNING:
				var d = dx * dx + dy * dy
				if d < best_d:
					best_d = d
					best = c
	return best

func _is_adjacent_to_border(cx: int, cy: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx = cx + dx
			var ny = cy + dy
			if fire_grid.is_valid_coord(nx, ny) and fire_grid.cell_types[fire_grid._coord_to_index(nx, ny)] == FireGrid.CellType.FOREST_BORDER:
				return true
	return false

func _nearest_cell_of(type: int, around: Vector3, radius: int) -> Vector2i:
	var here = fire_grid.get_cell_coord_at_world_pos(around)
	var best = Vector2i(-1, -1)
	var best_d = INF
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var c = here + Vector2i(dx, dy)
			if fire_grid.is_valid_coord(c.x, c.y) and fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)] == type:
				var d = dx * dx + dy * dy
				if d < best_d:
					best_d = d
					best = c
	return best

## Mu-naw walks the burned ground near the player looking for hidden embers
func _start_patrol() -> void:
	if not player:
		return
	var around = fire_grid.get_cell_coord_at_world_pos(player.global_position)
	var candidates: Array[Vector2i] = []
	for dy in range(-10, 11, 2):
		for dx in range(-10, 11, 2):
			var c = around + Vector2i(dx, dy)
			if fire_grid.is_valid_coord(c.x, c.y) and fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)] == FireGrid.CellType.ASH:
				candidates.append(c)
	if candidates.is_empty():
		return
	var pick = candidates[randi() % candidates.size()]
	target_coord = pick
	target_world_pos = fire_grid.get_cell_world_pos(pick.x, pick.y)
	current_state = State.AUTONOMOUS_WORK

func _process_autonomous_work(delta: float) -> void:
	_set_status("เดินตรวจหาถ่านในกองเถ้า")
	if _flat_distance_to(target_world_pos) <= 1.5:
		velocity = Vector3.ZERO
		current_state = State.IDLE_FOLLOW
		return
	_move_towards(target_world_pos, delta)
	# Break off the patrol as soon as a spot fire or an ember shows up nearby
	auto_search_timer += delta
	if auto_search_timer >= 1.0:
		auto_search_timer = 0.0
		var spot = _nearest_spot_fire(16)
		var ember = spot if spot.x >= 0 else _nearest_cell_of(FireGrid.CellType.SMOLDERING, global_position, 6)
		if ember.x >= 0:
			_assign_task(ember)

func _update_thermal_eye(delta: float) -> void:
	_eye_timer += delta
	if _eye_timer < THERMAL_EYE_PERIOD or not fire_grid:
		return
	_eye_timer = 0.0
	var r = int(ceil(THERMAL_EYE_RADIUS_M / fire_grid.cell_size))
	var here = fire_grid.get_cell_coord_at_world_pos(global_position)
	var found: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c = here + Vector2i(dx, dy)
			if Vector2(dx, dy).length() * fire_grid.cell_size > THERMAL_EYE_RADIUS_M:
				continue
			if fire_grid.is_valid_coord(c.x, c.y) and fire_grid.cell_types[fire_grid._coord_to_index(c.x, c.y)] == FireGrid.CellType.SMOLDERING:
				found.append(c)
	if found.is_empty():
		return
	fire_grid.highlight_cells(found, THERMAL_EYE_PERIOD - 0.5)
	_spawn_pulse_ring()

## Expanding magenta ring: the visible "pulse" of the Thermal Eye
func _spawn_pulse_ring() -> void:
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(FireGrid.COLOR_THERMAL_EYE, 0.6)
	torus.material = mat
	ring.mesh = torus
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.4, 0)
	var tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * THERMAL_EYE_RADIUS_M, 0.9)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tween.chain().tween_callback(ring.queue_free)

# ---------------------------------------------------------------------------
# Tasks
# ---------------------------------------------------------------------------

func _process_move_to_task(delta: float) -> void:
	var dist = _flat_distance_to(target_world_pos)
	if dist <= 2.2:
		velocity = Vector3.ZERO
		current_state = State.PERFORMING_TASK
		task_progress = 0.0
	else:
		_set_status("กำลังไปทำงาน")
		_move_towards(target_world_pos, delta)

func _flat_distance_to(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length()

func _move_towards(pos: Vector3, _delta: float, speed: float = -1.0) -> void:
	var flat = Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z)
	velocity = flat.normalized() * (speed if speed > 0.0 else _effective_speed())
	move_and_slide()

## No physics colliders on the terrain: stay inside the hillside and ride its surface
func _follow_terrain(delta: float) -> void:
	if not fire_grid:
		return
	global_position = fire_grid.clamp_to_grid(global_position)
	var ground_y = fire_grid.get_ground_height_at_world_pos(global_position)
	global_position.y = move_toward(global_position.y, ground_y, 6.0 * delta)

func _process_perform_task(delta: float) -> void:
	if not fire_grid or not fire_grid.is_valid_coord(target_coord.x, target_coord.y):
		current_state = State.IDLE_FOLLOW
		return

	var idx = fire_grid._coord_to_index(target_coord.x, target_coord.y)
	var type = fire_grid.cell_types[idx]
	var clearing = type == FireGrid.CellType.VEGETATION or type == FireGrid.CellType.BAMBOO
	_set_status("ถางแนวกันไฟ" if clearing else "ฉีดน้ำดับถ่าน")

	if animator and not animator.has_method("set_work") and fmod(task_progress, 0.4) < delta:
		animator.trigger_action()

	task_progress += delta * work_efficiency * (0.6 if is_coughing else 1.0)
	if task_progress >= REQUIRED_TASK_WORK:
		if clearing:
			if fire_grid.clear_firebreak(target_coord.x, target_coord.y):
				_show_tool_feedback(&"rake")
		elif type == FireGrid.CellType.SMOLDERING or type == FireGrid.CellType.BURNING:
			if fire_grid.douse_cell(target_coord.x, target_coord.y):
				_show_tool_feedback(&"spray")
				if AudioManager.instance:
					AudioManager.instance.play_water_spray()

		current_state = State.IDLE_FOLLOW

func receive_ping_order(coord: Vector2i, world_pos: Vector3) -> void:
	cancel_animation_work()
	target_coord = coord
	target_world_pos = world_pos
	current_state = State.MOVING_TO_TASK

func rally_to_player() -> void:
	cancel_animation_work()
	target_coord = Vector2i(-1, -1)
	current_state = State.IDLE_FOLLOW

func _show_tool_feedback(kind: StringName) -> void:
	var origin := global_position + Vector3.UP * 0.7
	if role == Role.YOUTH:
		origin = animator.to_global(Vector3(0.29, 0.67, 0.15))
	elif _borrowed_wand and kind == &"spray":
		origin = _borrowed_wand.to_global(Vector3(0, 0.68, 0))
	load("res://scripts/CharacterToolFeedback.gd").spawn(get_parent(), origin, target_world_pos, kind)
