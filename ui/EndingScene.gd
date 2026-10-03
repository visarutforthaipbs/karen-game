class_name EndingScene
extends Control

## Endings and run summary (PRD_UPDATE_v1.1 P0-5). The report's continue button
## brings a finished campaign here: a short in-engine vignette for the cause
## (crackdown raid at night / famine exodus at dawn), skippable after 2 s,
## then the run summary with the best record.

const HEARTH_SCENE = "res://scenes/VillageHearth.tscn"
const TITLE_SCENE = "res://scenes/Title.tscn"
const SKIP_AFTER: float = 2.0

var cause: String = "crackdown"
var summary_card: Control
var new_record: bool = false
var _vp: SubViewport
var _camera: Camera3D
var _caption: Label
var _skip_hint: Label
var _fade: ColorRect
var _t: float = 0.0
var _beats: Array = []      # [[time, caption]]
var _actors: Array = []     # [{node, from, to, start, end}]
var _taken: Array = []      # tools carried off in the raid
var _cues: Array = []       # [[time, node, clip]] ranger gestures, played once
var _length: float = 20.0
var _finished: bool = false

func _ready() -> void:
	theme = UITheme.get_theme()
	var state = GameState.instance
	cause = state.end_cause() if state.end_cause() != "" else "crackdown"
	# A finished campaign can't be continued; keep only the record
	new_record = SaveGame.submit_record(state)
	SaveGame.delete()
	_build_viewport()
	if cause == "famine":
		_stage_famine()
	else:
		_stage_crackdown()
	_build_overlay()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
		# The vignette gets its own sound: the ending stinger + quiet air
		AudioManager.instance.play_ending_stinger(cause)
		if cause == "crackdown":
			AudioManager.instance.play_truck_arrive()
		AudioManager.instance.set_ambience(0.35, 0.15 if cause == "famine" else 0.0, 0.0)

# ---------------------------------------------------------------------------
# Stage
# ---------------------------------------------------------------------------

func _build_viewport() -> void:
	var container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	container.add_child(_vp)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_vp.add_child(_camera)

func _environment(top: Color, horizon: Color, ambient: float, fog: Color) -> void:
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.4)
	sky_mat.ground_bottom_color = top.darkened(0.5)
	var sky = Sky.new()
	sky.sky_material = sky_mat
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.02
	var we = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

func _ground(color: Color) -> void:
	var plane = PlaneMesh.new()
	plane.size = Vector2(160, 160)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	plane.material = mat
	var g = MeshInstance3D.new()
	g.mesh = plane
	_vp.add_child(g)
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	for i in 40:
		var a = rng.randf() * TAU
		var r = rng.randf_range(16.0, 46.0)
		var tree = MeshInstance3D.new()
		tree.mesh = Landscape.lean_pine() if i % 2 == 0 else Landscape.lean_broadleaf()
		tree.position = Vector3(cos(a) * r, 0, sin(a) * r - 6.0)
		var s = rng.randf_range(1.2, 2.0)
		tree.scale = Vector3(s, s, s)
		_vp.add_child(tree)

func _prop(mesh: Mesh, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation.y = yaw
	m.scale = Vector3(s, s, s)
	_vp.add_child(m)
	return m

func _actor(node: Node3D, from: Vector3, to: Vector3, start: float, end: float) -> void:
	_vp.add_child(node)
	node.position = from
	_actors.append({"node": node, "from": from, "to": to, "start": start, "end": end})

static func truck_mesh() -> ArrayMesh:
	var cab = BoxMesh.new()
	cab.size = Vector3(1.9, 1.5, 1.6)
	var bed = BoxMesh.new()
	bed.size = Vector3(1.9, 0.9, 2.6)
	var canopy = BoxMesh.new()
	canopy.size = Vector3(1.95, 1.0, 2.6)
	var wheel = CylinderMesh.new()
	wheel.top_radius = 0.42
	wheel.bottom_radius = 0.42
	wheel.height = 0.3
	wheel.radial_segments = 8
	wheel.rings = 0
	var parts = [
		[cab, Transform3D(Basis(), Vector3(0, 1.15, 1.5)), Color(0.82, 0.84, 0.82)],
		[bed, Transform3D(Basis(), Vector3(0, 0.85, -0.6)), Color(0.3, 0.36, 0.32)],
		[canopy, Transform3D(Basis(), Vector3(0, 1.8, -0.6)), Color(0.36, 0.42, 0.37)],
	]
	for p in [Vector3(-0.95, 0.42, 1.4), Vector3(0.95, 0.42, 1.4), Vector3(-0.95, 0.42, -1.2), Vector3(0.95, 0.42, -1.2)]:
		parts.append([wheel, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p), Color(0.08, 0.08, 0.09)])
	var mesh = LowPoly.compose(parts)
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh

## A villager: the C6 crowd asset when installed (with an S7 travel bundle on the
## back), otherwise the faceted placeholder that already carries a bundle
static func villager_node(index: int, cloth: Color) -> Node3D:
	var variants = AssetLibrary.meshes("C6")
	var v = MeshInstance3D.new()
	if variants.is_empty():
		v.mesh = villager_mesh(cloth)
		return v
	v.mesh = variants[index % variants.size()]
	if AssetLibrary.has_asset("S7"):
		var bundle = MeshInstance3D.new()
		bundle.mesh = AssetLibrary.mesh_or("S7", null)
		bundle.position = Vector3(0, 0.40, -0.2) # Reviewed on all four C6 variants (V12 handoff)
		v.add_child(bundle)
	return v

static func villager_mesh(cloth: Color) -> ArrayMesh:
	var body = CylinderMesh.new()
	body.top_radius = 0.18
	body.bottom_radius = 0.24
	body.height = 0.75
	body.radial_segments = 6
	body.rings = 0
	var head = SphereMesh.new()
	head.radius = 0.17
	head.height = 0.3
	head.radial_segments = 6
	head.rings = 3
	var bundle = BoxMesh.new()
	bundle.size = Vector3(0.36, 0.34, 0.24)
	var mesh = LowPoly.compose([
		[body, Transform3D(Basis(), Vector3(0, 0.38, 0)), cloth],
		[head, Transform3D(Basis(), Vector3(0, 0.88, 0)), Color(0.72, 0.55, 0.42)],
		[bundle, Transform3D(Basis(), Vector3(0, 0.7, -0.24)), Color(0.75, 0.66, 0.46)],
	])
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh

func _tapoh() -> Node3D:
	var path = "res://scenes/characters/TapohChibi.tscn"
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	var n = MeshInstance3D.new()
	n.mesh = villager_mesh(Color(0.86, 0.82, 0.74))
	return n

func _stage_crackdown() -> void:
	_length = 21.0
	_environment(Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.2), 0.25, Color(0.05, 0.06, 0.12))
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 30, 0)
	moon.light_color = Color(0.55, 0.62, 0.9)
	moon.light_energy = 0.25
	_vp.add_child(moon)
	_ground(Color(0.16, 0.14, 0.12))

	var hut = _prop(AssetLibrary.mesh_or("S1", LowPoly.field_hut()), Vector3(-2.5, 0, -2.0), PI * 0.15)
	var fire = OmniLight3D.new()
	fire.light_color = Color(1.0, 0.55, 0.25)
	fire.light_energy = 1.4
	fire.omni_range = 7.0
	fire.position = hut.position + Vector3(1.6, 0.6, 1.6)
	_vp.add_child(fire)

	# The crew's tools by the hut, carried off in the raid
	var knife = AssetLibrary.mesh_or("T2", LowPoly.tool_mesh("torch"))
	for t in [[AssetLibrary.mesh_or("T3", LowPoly.tool_mesh("rake")), Vector3(-0.3, 0.05, -0.4)], [knife, Vector3(0.2, 0.05, -0.1)], [LowPoly.sprayer_tank(), Vector3(-0.8, 0.0, 0.1)]]:
		var tool = _prop(t[0], t[1], randf() * TAU)
		tool.rotation.z = PI * 0.5 if t[0] != LowPoly.sprayer_tank() else 0.0
		_taken.append(tool)

	var truck = _prop(AssetLibrary.mesh_or("S6", truck_mesh()), Vector3(9.0, 0, 6.0), -PI * 0.75)
	for x in [-0.6, 0.6]:
		var head = SpotLight3D.new()
		head.light_color = Color(0.92, 0.96, 1.0)
		head.light_energy = 9.0
		head.spot_range = 28.0
		head.spot_angle = 24.0
		head.position = Vector3(x, 1.0, 2.35)
		head.rotation_degrees = Vector3(-6, 180, 0)
		truck.add_child(head)

	var tapoh = _tapoh()
	_actor(tapoh, Vector3(-1.0, 0, 0.6), Vector3(-1.0, 0, 0.6), 0.0, 0.0)
	tapoh.rotation.y = PI * 0.8
	# Rangers walk in from the truck, then two lead Ta-poh back to it
	var r1 = RangerFigure.create(true)
	var r2 = RangerFigure.create(true, true)
	var r3 = RangerFigure.create(true)
	_actor(r1, Vector3(7.5, 0, 4.5), Vector3(0.6, 0, 1.6), 2.0, 7.5)
	_actor(r2, Vector3(8.5, 0, 3.6), Vector3(-0.2, 0, -0.9), 2.4, 8.0)
	_actor(r3, Vector3(8.0, 0, 5.4), Vector3(1.4, 0, 0.2), 2.8, 8.2)
	_actors.append({"node": tapoh, "from": Vector3(-1.0, 0, 0.6), "to": Vector3(7.0, 0, 4.6), "start": 13.0, "end": 19.5})
	_actors.append({"node": r1, "from": Vector3(0.6, 0, 1.6), "to": Vector3(7.6, 0, 5.4), "start": 13.0, "end": 19.5})
	_actors.append({"node": r3, "from": Vector3(1.4, 0, 0.2), "to": Vector3(8.0, 0, 4.0), "start": 13.3, "end": 19.8})
	# Authored gestures (C5 rig): order the search, photograph the evidence, escort
	_cues = [[7.8, r1, "Point"], [8.4, r2, "Photograph"], [8.9, r3, "Scan"], [11.0, r2, "RadioTalk"], [13.0, r1, "Escort"], [13.3, r3, "Escort"]]

	_camera.position = Vector3(-7.5, 3.4, 9.0)
	_camera.look_at(Vector3(1.5, 0.9, 1.0), Vector3.UP)
	_beats = [
		[0.3, "คืนหลังดาวเทียมโคจรผ่าน"],
		[3.0, "เจ้าหน้าที่ป่าไม้บุกหมู่บ้าน"],
		[8.5, "ยึดมีด คราด และถังพ่นน้ำ"],
		[13.0, "ตาโพถูกควบคุมตัว"],
		[18.0, "ความเพ่งเล็งของรัฐถึงขีดสุด · หมู่บ้านถูกปราบปราม"],
	]

func _stage_famine() -> void:
	_length = 18.0
	_environment(Color(0.42, 0.5, 0.68), Color(0.96, 0.72, 0.5), 0.7, Color(0.85, 0.72, 0.6))
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-8, -60, 0)
	sun.light_color = Color(1.0, 0.78, 0.55)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	_vp.add_child(sun)
	_ground(Color(0.52, 0.44, 0.3))
	# The road out of the village, running away from the camera into the haze
	var road = PlaneMesh.new()
	road.size = Vector2(3.2, 70.0)
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.68, 0.58, 0.42)
	road.material = road_mat
	var road_node = MeshInstance3D.new()
	road_node.mesh = road
	road_node.position = Vector3(0, 0.02, 26.0)
	_vp.add_child(road_node)
	_prop(AssetLibrary.mesh_or("S1", LowPoly.field_hut()), Vector3(-5.2, 0, -3.0), 0.6, 1.1)
	var empty_granary := AssetLibrary.mesh_or("S11", AssetLibrary.mesh_or("S3", LowPoly.field_hut()))
	# Face the empty doorway toward the dawn camera and keep the access ladder
	# beside the exodus path; the old closed exterior was mostly out of frame.
	_prop(empty_granary, Vector3(3.4, 0, -1.4), PI+.32, 0.9 if not AssetLibrary.has_asset("S3") else 1.0)
	# Families walk down the road with what they can carry
	var cloths = [Color(0.2, 0.3, 0.5), Color(0.85, 0.82, 0.76), Color(0.55, 0.2, 0.18), Color(0.25, 0.42, 0.3), Color(0.82, 0.8, 0.72)]
	for i in cloths.size():
		var v = villager_node(i, cloths[i])
		var from = Vector3(-0.9 + (i % 3) * 0.8, 0, 1.0 + i * 1.1)
		_actor(v, from, from + Vector3(0.0, 0, 24.0), 1.5 + i * 0.5, 17.0 + i * 0.4)
		v.rotation.y = 0.0
	var tapoh = _tapoh()
	_actor(tapoh, Vector3(0.5, 0, 0.0), Vector3(0.5, 0, 20.0), 4.0, 17.5)
	# On the road behind them, looking the way they go
	_camera.position = Vector3(1.4, 2.3, -7.5)
	_camera.look_at(Vector3(0.0, 0.8, 7.0), Vector3.UP)
	_beats = [
		[0.3, "ฝนมาไม่ทัน ยุ้งข้าวว่างเปล่า"],
		[5.0, "ครอบครัวต้องทิ้งดอย"],
		[10.0, "ลงไปเป็นแรงงานขัดหนี้ในพื้นราบ"],
		[15.0, "ไร่หมุนเวียนที่ดูแลกันมาหลายชั่วคน ถูกทิ้งไว้ข้างหลัง"],
	]

# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------

func _build_overlay() -> void:
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_caption = UITheme.wrap(UITheme.outlined(UITheme.label("", "Title", UITheme.CREAM), 8))
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.anchor_left = 0.1
	_caption.anchor_right = 0.9
	_caption.anchor_top = 0.78
	_caption.anchor_bottom = 0.78
	add_child(_caption)
	_skip_hint = UITheme.outlined(UITheme.label("กดปุ่มใดก็ได้เพื่อข้าม", "Small", UITheme.MUTED), 4)
	_skip_hint.anchor_left = 1.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = -240.0
	_skip_hint.offset_top = -40.0
	_skip_hint.visible = false
	add_child(_skip_hint)

func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_fade.color.a = clampf(1.0 - _t / 1.5, 0.0, 1.0) if _t < _length - 1.5 else clampf((_t - (_length - 1.5)) / 1.5, 0.0, 1.0)
	_skip_hint.visible = _t >= SKIP_AFTER
	var text = ""
	for b in _beats:
		if _t >= b[0]:
			text = b[1]
	_caption.text = text
	for c in _cues:
		if c.size() == 3 and _t >= c[0]:
			RangerFigure.gesture(c[1], c[2])
			c.append(true) # Played
	for a in _actors:
		var node: Node3D = a.node
		var u = 0.0 if a.end <= a.start else clampf((_t - a.start) / (a.end - a.start), 0.0, 1.0)
		var moving = _t > a.start and _t < a.end and a.from != a.to
		if _t >= a.start and _t <= a.end + delta:
			node.position = a.from.lerp(a.to, u)
		var vel = (a.to - a.from) / maxf(a.end - a.start, 0.01) if moving else Vector3.ZERO
		if moving:
			if AudioManager.instance:
				AudioManager.instance.step_at("ending_%d" % node.get_instance_id(), node.global_position, false, false)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(vel.x, vel.z), delta * 6.0)
		if node.has_method("update_animation"):
			node.update_animation(delta, vel)
		else:
			RangerFigure.animate(node, delta, vel)
	# Tools are lifted away by the rangers once they reach the hut
	for i in _taken.size():
		var tool: Node3D = _taken[i]
		if _t > 8.5 + i * 0.6:
			tool.visible = false
	_camera.position += (Vector3(0.05, 0, -0.04) if cause == "crackdown" else Vector3(0.0, 0.01, 0.25)) * delta
	if _t >= _length:
		show_summary()

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _t < SKIP_AFTER:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		show_summary()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Run summary
# ---------------------------------------------------------------------------

func show_summary() -> void:
	if _finished:
		return
	_finished = true
	_caption.text = ""
	_skip_hint.visible = false
	_fade.color = Color(0.02, 0.03, 0.06, 0.72)
	var state = GameState.instance
	var st: Dictionary = state.stats
	var plots = int(st.get("plots_completed", 0))

	summary_card = UITheme.card(Color(UITheme.PANEL, 0.97), UITheme.RUBY if cause == "crackdown" else UITheme.STRAW, 560)
	summary_card.padding = Vector4(28, 22, 28, 24)
	summary_card.chamfer = 16.0
	summary_card.set_anchors_preset(Control.PRESET_CENTER)
	summary_card.custom_minimum_size = Vector2(760, 0)
	summary_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	summary_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(summary_card)
	var box = UITheme.vbox(12)
	summary_card.add_child(box)
	box.add_child(UITheme.header("eye" if cause == "crackdown" else "rice", "สรุปการเดินทาง", UITheme.MUTED))
	var title = UITheme.wrap(UITheme.label("รัฐปราบปรามหมู่บ้าน" if cause == "crackdown" else "หมู่บ้านอดอยาก ต้องทิ้งดอย", "Title", UITheme.RUBY if cause == "crackdown" else UITheme.STRAW))
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	box.add_child(UITheme.wrap(UITheme.label("หมู่บ้านอยู่รอดมาได้ %d แปลง ถึงปีที่ %d ของการเผาใต้เงาดาวเทียม" % [plots, state.current_year], "Body")))

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var doused = int(st.get("spot_fires_doused", 0))
	var spots = int(st.get("spot_fires", 0))
	for tile in [
		["แปลงที่ผ่าน", str(plots), UITheme.STRAW],
		["เถ้าเฉลี่ย", "%.0f%%" % (st.get("ash_sum", 0.0) / maxf(1.0, plots)), UITheme.EMERALD],
		["จุดร้อนที่ถูกจับได้", str(st.get("hotspots_detected", 0)), UITheme.EMBER],
		["ไฟลามเข้าป่า", str(st.get("escapes", 0)), UITheme.RUBY],
		["ภาพถ่ายจากโดรน", str(st.get("drone_photos", 0)), UITheme.STATE],
		["กล้องความร้อนจับได้", str(st.get("camera_trips", 0)), UITheme.STATE],
		["เจ้าหน้าที่เดินตรวจพบ", str(st.get("ranger_sightings", 0)), UITheme.STATE],
		["ลูกไฟที่ดับทัน", "%d/%d" % [doused, spots], UITheme.WATER],
	]:
		grid.add_child(_tile(tile[0], tile[1], tile[2]))

	var best = SaveGame.best_record()
	var rec_text = "สถิติใหม่! รอดได้นานที่สุดเท่าที่เคยเล่นมา" if new_record else ("สถิติดีที่สุด: รอด %d แปลง (ถึงปีที่ %d)" % [int(best.get("plots_completed", 0)), int(best.get("year", 1))] if not best.is_empty() else "")
	box.add_child(UITheme.label(rec_text, "Kicker", UITheme.EMERALD if new_record else UITheme.MUTED))

	# Name on the village board, and where this run landed on it
	var campaign_id = str(st.get("campaign_id", ""))
	var name_row = UITheme.hbox(10)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(name_row)
	name_row.add_child(UITheme.label("ชื่อบนกระดานหมู่บ้าน:", "Small", UITheme.CREAM))
	var name_edit = LineEdit.new()
	name_edit.text = GameSettings.player_name
	name_edit.max_length = SaveGame.NAME_MAX
	name_edit.custom_minimum_size = Vector2(260, 40)
	name_edit.focus_mode = Control.FOCUS_ALL
	name_row.add_child(name_edit)
	var rank_label = UITheme.label("", "Small", UITheme.STRAW)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rank_label)
	var rank = 0
	if campaign_id != "":
		var rows = SaveGame.runs()
		for i in rows.size():
			if rows[i].campaign_id == campaign_id:
				rank = i + 1
				break
	rank_label.text = "ติดอันดับที่ %d ของหมู่บ้าน" % rank if rank > 0 else ""
	rank_label.visible = rank > 0
	var online_label = UITheme.label("", "Small", UITheme.STATE)
	online_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_label.visible = false
	box.add_child(online_label)
	if OnlineBoard.enabled():
		OnlineBoard.ensure_identity()
		OnlineBoard.submit(self, state, func(online_rank):
			if is_instance_valid(online_label):
				online_label.text = "อันดับออนไลน์ #%d (เบตา)" % online_rank
				online_label.visible = true)
	name_edit.text_changed.connect(func(t: String):
		GameSettings.player_name = SaveGame.sanitize_name(t)
		GameSettings.save_settings()
		SaveGame.rename_run(campaign_id, t))

	var row = UITheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var again = Button.new()
	again.text = "เริ่มแคมเปญใหม่"
	again.theme_type_variation = "PrimaryButton"
	again.custom_minimum_size = Vector2(300, 50)
	again.pressed.connect(_new_campaign)
	row.add_child(again)
	var home = Button.new()
	home.text = "กลับหน้าแรก"
	home.custom_minimum_size = Vector2(220, 50)
	home.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))
	row.add_child(home)
	again.grab_focus()

func _tile(title: String, value: String, color: Color) -> Control:
	var t = UITheme.card(UITheme.PANEL_HI, color, 570 + title.length())
	t.padding = Vector4(12, 8, 12, 10)
	t.chamfer = 8.0
	t.custom_minimum_size = Vector2(165, 0)
	var b = UITheme.vbox(0)
	t.add_child(b)
	b.add_child(UITheme.wrap(UITheme.label(title, "Small")))
	var v = UITheme.label(value, "Title", color)
	v.add_theme_font_size_override("font_size", 22)
	b.add_child(v)
	return t

func _new_campaign() -> void:
	var state = GameState.instance
	state.reset_campaign()
	state.seen_how_to_play = true
	get_tree().change_scene_to_file(HEARTH_SCENE)
