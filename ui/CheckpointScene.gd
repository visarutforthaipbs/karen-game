class_name CheckpointScene
extends Control

## Year 4+ road checkpoint on the march to a plot (PRD_UPDATE_v1.1 P1-3).
## Plays between the Hearth and the burn: the crew is stopped, checked and
## waved through. Skippable after 1.5 s. The real cost is already in the rules
## (lending labour costs 30 instead of 20 minutes, see GameState.favour_minutes).

const MAIN_SCENE = "res://scenes/Main.tscn"
const SKIP_AFTER: float = 1.5
const LENGTH: float = 10.0

var _t: float = 0.0
var _done: bool = false
var _caption: Label
var _hint: Label
var _fade: ColorRect
var _camera: Camera3D
var _vp: SubViewport
var _crew: Array[Node3D] = []
var _barrier: Node3D
var _guard: Node3D
var _cued: Dictionary = {}

func _ready() -> void:
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
		AudioManager.instance.set_ambience(0.25, 0.20, 0.0)
	theme = UITheme.get_theme()
	_build_stage()
	_build_overlay()

func _build_stage() -> void:
	var container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	container.add_child(_vp)

	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.5, 0.72)
	sky_mat.sky_horizon_color = Color(0.86, 0.8, 0.68)
	var sky = Sky.new()
	sky.sky_material = sky_mat
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.76, 0.66)
	env.fog_density = 0.015
	var we = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_vp.add_child(sun)

	var ground = PlaneMesh.new()
	ground.size = Vector2(120, 120)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.5, 0.46, 0.32)
	ground.material = gmat
	var g = MeshInstance3D.new()
	g.mesh = ground
	_vp.add_child(g)
	var road = PlaneMesh.new()
	road.size = Vector2(4.0, 120.0)
	var rmat = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.62, 0.56, 0.44)
	road.material = rmat
	var r = MeshInstance3D.new()
	r.mesh = road
	r.position.y = 0.02
	_vp.add_child(r)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9
	for i in 30:
		var tree = MeshInstance3D.new()
		tree.mesh = Landscape.lean_pine() if i % 3 else Landscape.lean_broadleaf()
		var side = -1.0 if i % 2 == 0 else 1.0
		tree.position = Vector3(side * rng.randf_range(5.0, 20.0), 0, rng.randf_range(-40.0, 30.0))
		tree.scale = Vector3.ONE * rng.randf_range(1.3, 2.0)
		_vp.add_child(tree)

	# Roadblock: the S5 asset (sign and sandbags) at the roadside, or the procedural
	# booth; the lifting arm across the road is always the animated one below
	var block = MeshInstance3D.new()
	block.mesh = AssetLibrary.mesh_or("S5", roadblock_mesh())
	if AssetLibrary.has_asset("S5"):
		block.position = Vector3(4.2, 0, -0.4)
		block.rotation.y = -PI * 0.5
	_vp.add_child(block)
	_barrier = MeshInstance3D.new()
	_barrier.mesh = barrier_arm_mesh()
	_barrier.position = Vector3(-1.9, 1.0, 0.0)
	_vp.add_child(_barrier)
	_guard = RangerFigure.create(false, true)
	_guard.position = Vector3(2.6, 0, 0.8)
	_guard.rotation.y = PI * 0.5 + 0.4
	_vp.add_child(_guard)

	# The crew walking up the road from the village
	var cloths = [Color(0.2, 0.3, 0.5), Color(0.86, 0.82, 0.74), Color(0.25, 0.42, 0.3)]
	for i in 3:
		var v = EndingScene.villager_node(i, cloths[i])
		v.position = Vector3(-0.4 + i * 0.6, 0, -9.0 - i * 1.2)
		_vp.add_child(v)
		_crew.append(v)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.position = Vector3(6.5, 3.2, 7.5)
	_vp.add_child(_camera)
	_camera.look_at(Vector3(0, 0.8, -1.5), Vector3.UP)

static func roadblock_mesh() -> ArrayMesh:
	var booth = BoxMesh.new()
	booth.size = Vector3(1.4, 2.2, 1.4)
	var roof = BoxMesh.new()
	roof.size = Vector3(1.7, 0.12, 1.7)
	var bag = BoxMesh.new()
	bag.size = Vector3(0.7, 0.3, 0.45)
	var post = CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.1
	post.height = 1.1
	post.radial_segments = 6
	post.rings = 0
	var parts = [
		[booth, Transform3D(Basis(), Vector3(3.6, 1.1, -0.6)), Color(0.82, 0.84, 0.8)],
		[roof, Transform3D(Basis(), Vector3(3.6, 2.26, -0.6)), Color(0.3, 0.36, 0.32)],
		[post, Transform3D(Basis(), Vector3(-1.9, 0.55, 0.0)), Color(0.3, 0.32, 0.3)],
	]
	for i in 6:
		parts.append([bag, Transform3D(Basis(), Vector3(2.4 + (i % 3) * 0.72, 0.15 + (i / 3) * 0.3, 0.6)), Color(0.6, 0.55, 0.4)])
	var mesh = LowPoly.compose(parts)
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh

## Red-and-white barrier arm, pivoting at its post (origin)
static func barrier_arm_mesh() -> ArrayMesh:
	var seg = BoxMesh.new()
	seg.size = Vector3(0.6, 0.12, 0.12)
	var parts = []
	for i in 7:
		parts.append([seg, Transform3D(Basis(), Vector3(0.3 + i * 0.6, 0, 0)), Color(0.85, 0.15, 0.12) if i % 2 == 0 else Color(0.95, 0.95, 0.92)])
	var mesh = LowPoly.compose(parts)
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh

func _build_overlay() -> void:
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_caption = UITheme.wrap(UITheme.outlined(UITheme.label("", "Title", UITheme.CREAM), 8))
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.anchor_left = 0.1
	_caption.anchor_right = 0.9
	_caption.anchor_top = 0.8
	_caption.anchor_bottom = 0.8
	add_child(_caption)
	_hint = UITheme.outlined(UITheme.label("กดปุ่มใดก็ได้เพื่อข้าม", "Small", UITheme.MUTED), 4)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -240.0
	_hint.offset_top = -40.0
	_hint.visible = false
	add_child(_hint)

func caption_at(t: float) -> String:
	if t < 3.2:
		return "ด่านตรวจบนถนนขึ้นดอย"
	if t < 6.4:
		return "เจ้าหน้าที่ตรวจบัตรและค้นเครื่องมือทุกชิ้น"
	var delay = GameState.instance.labour_delay_minutes() if GameState.instance else 0
	return "ผ่านด่านได้ · เช้านี้เสียเวลาไปกับเอาแรงและด่านตรวจ %d นาที" % delay if delay > 0 else "ผ่านด่านได้ · รีบขึ้นไร่ก่อนบ่ายสอง"

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_fade.color.a = clampf(1.0 - _t / 0.8, 0.0, 1.0) if _t < LENGTH - 0.8 else clampf((_t - (LENGTH - 0.8)) / 0.8, 0.0, 1.0)
	_hint.visible = _t >= SKIP_AFTER
	_caption.text = caption_at(_t)
	# Walk up, wait at the barrier, then walk through once it lifts
	for i in _crew.size():
		var v = _crew[i]
		var z_stop = -2.0 - i * 1.0
		if _t < 3.0:
			v.position.z = move_toward(v.position.z, z_stop, delta * 2.2)
		elif _t > 6.6:
			v.position.z += delta * 2.4
	_barrier.rotation.z = lerp_angle(_barrier.rotation.z, deg_to_rad(80.0) if _t > 6.0 else 0.0, delta * 3.0)
	# The guard scans the crew, then waves them through (C5 gestures)
	for cue in [[2.6, "Scan"], [5.6, "Point"]]:
		if _t >= cue[0] and not _cued.has(cue[1]):
			_cued[cue[1]] = true
			RangerFigure.gesture(_guard, cue[1])
	if _t >= LENGTH:
		finish()

func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < SKIP_AFTER:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		finish()
		get_viewport().set_input_as_handled()

func finish() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(MAIN_SCENE)
