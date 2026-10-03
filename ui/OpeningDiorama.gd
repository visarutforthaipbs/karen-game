class_name OpeningDiorama
extends Node3D

## Visual explanation only: separate world, no FireGrid, controllers or saves.
## Reuses the shipped cast, vegetation, granary and satellite without changing
## their meshes, skins or materials. Every diagram state is seekable for review.
var camera: Camera3D
var environment: Environment
var worlds: Array[Node3D] = []
var actors: Array[Node3D] = []
var regrowth: Array[Node3D] = []
var mosaic_tiles: Array[MeshInstance3D] = []
var crop_groups: Array[Node3D] = []
var plot_labels: Array[Label3D] = []
var fuel: Array[Node3D] = []
var boundary_tiles: Array[MeshInstance3D] = []
var flames: Array[Node3D] = []
var heat_tiles: Array[MeshInstance3D] = []
var coals: Array[Node3D] = []
var droplets: Array[Node3D] = []
var rake_actor: Node3D
var spray_actor: Node3D
var ember: Node3D
var satellite: Node3D
var scan: MeshInstance3D
var wind_arrow: Node3D
var _materials: Dictionary = {}
var _islands: Array[MeshInstance3D] = []
var _sun: DirectionalLight3D

func _ready() -> void:
	var world_environment = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17262b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5dfcf")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun = DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("ffdfae")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	add_child(camera)
	for i in 4:
		var world = Node3D.new()
		world.name = ["EstablishedFields", "Community", "Firebreak", "ResidualHeat"][i]
		add_child(world)
		worlds.append(world)
		_island(world)
	_build_mosaic()
	_build_community()
	_build_boundary()
	_build_heat()
	set_frame(0, 0.0, 0.0)

func _material(color: Color) -> StandardMaterial3D:
	var key = color.to_html()
	if not _materials.has(key):
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials[key] = material
	return _materials[key]

func _box(parent: Node3D, dimensions: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = position_value
	parent.add_child(node)
	return node

func _island(parent: Node3D) -> void:
	# Faceted cutaway island; top stays flat so the diagrams remain legible.
	var points = [Vector3(-7, 0, -4), Vector3(2, 0, -5), Vector3(7, 0, -3), Vector3(7, 0, 3), Vector3(1, 0, 5), Vector3(-7, 0, 3)]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		var base_a = a * Vector3(0.7, 1, 0.7) + Vector3(0, -2.4, 0)
		var base_b = b * Vector3(0.7, 1, 0.7) + Vector3(0, -2.4, 0)
		# Godot's front faces use clockwise winding (opposite the normal cross).
		for triangle in [[Vector3.ZERO, a, b], [a, base_b, b], [a, base_a, base_b]]:
			st.set_color(Color("657342").lightened(i * 0.016) if triangle[0] == Vector3.ZERO else Color("805946").darkened(i * 0.035))
			for point in triangle:
				st.add_vertex(point)
	st.generate_normals()
	st.set_material(LowPoly.vertex_color_material())
	var node = MeshInstance3D.new()
	node.mesh = st.commit()
	parent.add_child(node)
	_islands.append(node)

func _prop(parent: Node3D, id: String, fallback: Mesh, at: Vector3, height: float) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = AssetLibrary.mesh_or(id, fallback)
	var bounds = node.mesh.get_aabb()
	var scale_value = height / maxf(0.01, bounds.size.y)
	node.scale = Vector3.ONE * scale_value
	node.position = at - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_value
	parent.add_child(node)
	return node

func _actor(parent: Node3D, path: String, at: Vector3) -> Node3D:
	var actor = load(path).instantiate() as Node3D
	parent.add_child(actor)
	actor.position = at
	actor.scale = Vector3.ONE * 1.65
	# Cinematic sampling owns animation time, including Mae-Lu's village script.
	actor.set_process(false)
	actors.append(actor)
	return actor

func _trees(parent: Node3D) -> void:
	for i in 7:
		_prop(parent, "E1", LowPoly.pine(), Vector3(-5.5 + i * 1.7, 0.0, -3.5), 1.7 + (i % 3) * 0.35)
	_prop(parent, "E2", LowPoly.bamboo_clump(), Vector3(5.4, 0, 1.8), 2.5)

func _build_mosaic() -> void:
	var world = worlds[0]
	_trees(world)
	for i in 3:
		var x = -4.4 + i * 4.4
		mosaic_tiles.append(_box(world, Vector3(3.5, 0.06, 3.6), Vector3(x, 0.04, 0.5), Color("957144")))
		var growth = Node3D.new()
		world.add_child(growth)
		growth.position = Vector3(x, 0.1, 0.5)
		regrowth.append(growth)
		for j in 5:
			_prop(growth, "E1" if i == 2 else "E3", LowPoly.pine() if i == 2 else LowPoly.brush(), Vector3((j % 3 - 1) * 0.9, 0, (j / 3.0 - 0.5) * 1.1), 1.8 if i == 2 else 0.6)
		var crops = Node3D.new()
		world.add_child(crops)
		crops.position.x = x
		crop_groups.append(crops)
		for j in 12:
			_prop(crops, "E9", LowPoly.brush(), Vector3(-1.1 + (j % 4) * 0.7, 0.1, -0.5 + int(j / 4) * 0.7), 0.48)
		var label = Label3D.new()
		label.font = UITheme.font("medium")
		label.font_size = 36
		label.pixel_size = 0.014
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(x, 0.8, 2.9)
		label.modulate = UITheme.CREAM
		world.add_child(label)
		plot_labels.append(label)

func _build_community() -> void:
	var world = worlds[1]
	_trees(world)
	_prop(world, "S3", LowPoly.brush(), Vector3(-3.6, 0, -1.6), 3.0)
	_actor(world, "res://scenes/characters/TapohChibi.tscn", Vector3(-2.8, 0, 1.7))
	_actor(world, "res://scenes/characters/KhanaeChibi.tscn", Vector3(-0.6, 0, 1.4))
	_actor(world, "res://scenes/characters/MunawChibi.tscn", Vector3(1.5, 0, 1.4))
	_actor(world, "res://scenes/characters/MaeluChibi.tscn", Vector3(3.6, 0, 1.4))

func _flame(parent: Node3D, at: Vector3) -> Node3D:
	var root_node = Node3D.new()
	parent.add_child(root_node)
	root_node.position = at
	for i in 2:
		var cone = CylinderMesh.new()
		cone.radial_segments = 5
		cone.rings = 0
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18 if i == 0 else 0.1
		cone.height = 0.8 if i == 0 else 0.55
		var node = MeshInstance3D.new()
		node.mesh = cone
		node.position.y = cone.height * 0.5
		node.position.x = i * 0.13
		node.material_override = _material(UITheme.EMBER if i == 0 else UITheme.STRAW)
		root_node.add_child(node)
	return root_node

func _build_boundary() -> void:
	var world = worlds[2]
	_trees(world)
	for row in 4:
		for col in 6:
			var at = Vector3(-3.5 + col, 0.1, -1.5 + row)
			var edge = row == 0 or row == 3 or col == 0 or col == 5
			var tile = _box(world, Vector3(0.94, 0.08, 0.94), at, Color("6a713e"))
			if edge:
				boundary_tiles.append(tile)
				fuel.append(_prop(world, "E3", LowPoly.brush(), at, 0.45))
			else:
				_prop(world, "E3", LowPoly.brush(), at, 0.45)
				flames.append(_flame(world, at))
	rake_actor = _actor(world, "res://scenes/characters/KhanaeChibi.tscn", Vector3(-2.8, 0, 2.9))
	var rake = MeshInstance3D.new()
	rake.mesh = AssetLibrary.mesh_or("T3", LowPoly.tool_mesh("rake"))
	rake_actor.get_hand_socket().add_child(rake)
	rake.scale = Vector3.ONE / rake_actor.base_scale
	rake.position.y = -0.22 / rake_actor.base_scale
	_actor(world, "res://scenes/characters/TapohChibi.tscn", Vector3(-4.8, 0, 0.3))
	# Follow the perimeter in order so the moving rake and cleared tiles agree.
	var ordered: Array = []
	for i in boundary_tiles.size():
		ordered.append({"tile": boundary_tiles[i], "fuel": fuel[i]})
	ordered.sort_custom(func(a, b):
		return atan2(a.tile.position.z, a.tile.position.x + 1.0) < atan2(b.tile.position.z, b.tile.position.x + 1.0))
	boundary_tiles.clear()
	fuel.clear()
	for entry in ordered:
		boundary_tiles.append(entry.tile)
		fuel.append(entry.fuel)
	ember = _box(world, Vector3(0.14, 0.14, 0.14), Vector3.ZERO, UITheme.STRAW)
	_prop(world, "E1", LowPoly.pine(), Vector3(4.3, 0, 0.3), 2.1)
	wind_arrow = Node3D.new()
	world.add_child(wind_arrow)
	wind_arrow.position = Vector3(0.2, 1.4, -0.3)
	_box(wind_arrow, Vector3(1.1, 0.08, 0.12), Vector3.ZERO, UITheme.CREAM)
	var tip = CylinderMesh.new()
	tip.top_radius = 0
	tip.bottom_radius = 0.25
	tip.height = 0.45
	tip.radial_segments = 3
	var arrowhead = MeshInstance3D.new()
	arrowhead.mesh = tip
	arrowhead.material_override = _material(UITheme.CREAM)
	arrowhead.rotation.z = -PI * 0.5
	arrowhead.position.x = 0.65
	wind_arrow.add_child(arrowhead)

func _build_heat() -> void:
	var world = worlds[3]
	_trees(world)
	for row in 3:
		for col in 5:
			var at = Vector3(-2.0 + col, 0.1, -1.0 + row)
			heat_tiles.append(_box(world, Vector3(0.93, 0.08, 0.93), at, Color("555051")))
			if (row + col) % 3 == 0:
				var coal = _box(world, Vector3(0.26, 0.12, 0.35), at + Vector3(0, 0.10, 0), UITheme.EMBER)
				coal.rotation_degrees.y = col * 27
				coals.append(coal)
	spray_actor = _actor(world, "res://scenes/characters/MunawChibi.tscn", Vector3(3.6, 0, 2.2))
	for i in 14:
		droplets.append(_box(world, Vector3(0.05, 0.1, 0.05), Vector3.ZERO, UITheme.WATER))
	satellite = MeshInstance3D.new()
	(satellite as MeshInstance3D).mesh = SatelliteModel.mesh()
	satellite.scale = Vector3.ONE * SatelliteModel.fit_scale((satellite as MeshInstance3D).mesh) * 0.26
	world.add_child(satellite)
	scan = _box(world, Vector3(0.07, 0.02, 3.3), Vector3.ZERO, UITheme.STATE)

func set_frame(cue: int, progress: float, delta: float) -> void:
	var chapter = [0, 0, 1, 2, 2, 3, 3, 3][clampi(cue, 0, 7)]
	var u = clampf(progress, 0, 1)
	for i in worlds.size():
		worlds[i].visible = chapter == i
	var cold = cue >= 6
	environment.background_color = Color("0d1a2b") if cold else Color("17262b")
	environment.ambient_light_color = Color("6b9bb4") if cold else Color("d5dfcf")
	_sun.light_color = Color("7fc5e6") if cold else Color("ffdfae")
	_islands[3].material_override = _material(Color("193348")) if cold else null
	var framing = [Vector3(11, 12, 16), Vector3(8, 6, 15), Vector3(9, 10, 14), Vector3(8, 10, 14)][chapter]
	camera.position = framing + Vector3(u * 0.5, 0, -u * 0.4)
	camera.size = [17.5, 12.5, 14.0, 14.0][chapter]
	camera.look_at(Vector3(0, -0.1 if chapter == 0 else 0.4, 0), Vector3.UP)
	for actor in actors:
		if actor.is_visible_in_tree() and actor.has_method("update_animation"):
			actor.update_animation(delta, Vector3.ZERO, Vector3.FORWARD * -1)
	for i in regrowth.size():
		var growth = 0.1 if i == 0 else 0.65 if i == 1 else 1.0
		if cue == 1 and i == 0:
			growth = lerpf(0.1, 1.0, u)
		if cue == 1 and i == 1:
			growth = lerpf(0.65, 0.1, u)
		regrowth[i].scale = Vector3.ONE * growth
		crop_groups[i].visible = i == (1 if cue == 1 and u > 0.3 else 0)
		plot_labels[i].text = "ปลูกข้าวฤดูนี้" if crop_groups[i].visible else "พักแปลง" if i < 2 else "ฟื้นตัวหลายปี"
		mosaic_tiles[i].material_override = _material(Color("b49358") if i == 0 and cue == 0 else Color("69804b") if i == 2 or cue == 1 else Color("957144"))
	if chapter == 2:
		var cleared = u if cue == 3 else 1.0
		for i in fuel.size():
			var bare = float(i + 1) / fuel.size() <= cleared
			fuel[i].visible = not bare
			boundary_tiles[i].material_override = _material(Color("c18a58") if bare else Color("6a713e"))
		var cell = boundary_tiles[clampi(int(cleared * boundary_tiles.size()), 0, boundary_tiles.size() - 1)].position
		var outward = (cell - Vector3(-1.0, cell.y, 0)).normalized()
		rake_actor.position = Vector3(cell.x, 0, cell.z) + outward * 0.85
		rake_actor.set_work(&"rake", cue == 3 and u < 0.9)
		rake_actor.update_animation(delta, Vector3.ZERO, -outward)
	for i in flames.size():
		flames[i].visible = chapter == 2 and (cue == 4 or u > 0.9)
		flames[i].scale.y = 0.8 + sin(u * 30 + i * 1.7) * 0.2
	ember.visible = cue == 4 and u < 0.87
	ember.position = Vector3(1.2 + u * 3.3, 0.25 + sin(u * PI) * 1.8, 0.3)
	ember.rotation = Vector3.ONE * u * 8
	wind_arrow.visible = cue == 4
	satellite.visible = cue == 6
	satellite.position = Vector3(lerpf(-3.6, 3.6, u), 2.6, -1.4)
	satellite.rotation = Vector3(0, PI * 0.5, 0.25)
	scan.visible = cue == 6
	scan.position = Vector3(lerpf(-3.0, 3.0, u), 0.18, 0)
	for i in coals.size():
		var cooled = cue == 7 and u >= float(i + 1) / coals.size()
		coals[i].visible = not cooled
		(coals[i] as MeshInstance3D).material_override = _material(Color.WHITE if cold else UITheme.EMBER)
	for tile in heat_tiles:
		tile.material_override = _material(Color("233849") if cold else Color("555051"))
	spray_actor.set_work(&"spray", cue == 7 and u < 0.95)
	spray_actor.update_animation(delta, Vector3.ZERO, Vector3(-1, 0, -0.6))
	for i in droplets.size():
		var travel = fmod(u * 7.0 + float(i) / droplets.size(), 1.0)
		droplets[i].visible = cue == 7 and u < 0.95
		droplets[i].position = Vector3(3.3, 1.0, 1.8).lerp(Vector3(0, 0.2, 0), travel) + Vector3(0, sin(travel * PI) * 0.3, 0)
