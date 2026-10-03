class_name VillageDiorama
extends SubViewportContainer
## The real village assets, presented above the existing Hearth management controls.
var viewport_3d: SubViewport
var camera: Camera3D
var world: Node3D
var reserve_props: Array[MeshInstance3D] = []
var fire_light: OmniLight3D
var _time := 0.0
var villagers: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _station := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(1280, 240)
	viewport_3d.own_world_3d = true
	viewport_3d.msaa_3d = Viewport.MSAA_2X
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport_3d)
	world = Node3D.new()
	viewport_3d.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("172132")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("9aabc7")
	env.environment.ambient_light_energy = .65
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42,-28,0)
	moon.light_color = Color("b6c7ef")
	moon.light_energy = .7
	moon.shadow_enabled = true
	world.add_child(moon)
	var ground := CylinderMesh.new()
	ground.top_radius = 12
	ground.bottom_radius = 12.5
	ground.height = .25
	ground.radial_segments = 18
	ground.rings = 0
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("58503c")
	earth.roughness = 1
	ground.material = earth
	var base := MeshInstance3D.new()
	base.mesh = ground
	base.position.y = -.125
	world.add_child(base)
	_prop("S4", Vector3(-5.1,0,-2.0), .22, 0)
	_prop("S4", Vector3(5.8,0,-2.5), -.22, 1)
	_prop("S3", Vector3(2.2,0,-.3), -.12)
	var bench := _prop("S9", Vector3(-2.6,0,1.7), .12)
	if bench:
		# Table top is lower than the stone/tool tray's overall bounding-box maximum.
		var radio := _prop("S8", Vector3.ZERO)
		if radio:
			radio.reparent(bench,false)
			radio.position = Vector3(-.38,.741,.03)
		var supplies := _prop("S16", Vector3.ZERO)
		if supplies:
			supplies.reparent(bench,false)
			supplies.position = Vector3(0,.741,-.03)
	_prop("S10", Vector3(2.4,0,1.6))
	_prop("S15", Vector3(3.8,0,1.1))
	_prop("S14", Vector3(-3,0,2.5), PI*.5)
	for i in 4:
		_prop("S13", Vector3(-1.9+i*1.25,0,3.8), .2*i)
	for i in 5:
		var sack := _prop("S12", Vector3(2.1+(i%3)*.48,0,-.25-(i/3)*.5))
		if sack: reserve_props.append(sack)
	_rng.seed = 5917
	for i in 12:
		var a := TAU*i/12
		_prop("E1", Vector3(-10+i*1.8,0,-6.2),a,i%3)
	for i in 7:
		var a := TAU*i/7
		var rock := _prop("E6",Vector3(sin(a)*.5,.025,cos(a)*.5+1.2),a,i%4)
		if rock: rock.scale *= .5
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = .035
	cone.bottom_radius = .19
	cone.height = .45
	cone.radial_segments = 5
	cone.rings = 0
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color("e89a3e")
	ember.emission_enabled = true
	ember.emission = Color("e68c26")
	cone.material = ember
	flame.mesh = cone
	flame.position = Vector3(0,.23,1.2)
	world.add_child(flame)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0,1.0,1.2)
	fire_light.light_color = Color("ffbb70")
	fire_light.omni_range = 9
	fire_light.light_energy = 3
	fire_light.shadow_enabled = true
	world.add_child(fire_light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 30
	camera.position = Vector3(3,7,18)
	camera.look_at_from_position(camera.position, Vector3(0,1.6,0))
	world.add_child(camera)
	for row in [["Khanae",Vector3(-1.4,0,1.9)],["Tapoh",Vector3(-.7,0,2.0)],["Munaw",Vector3(.8,0,2.2)],["Maelu",Vector3(1.4,0,1.7)]]:
		var actor:Node3D=load("res://scenes/characters/"+row[0]+"Chibi.tscn").instantiate()
		world.add_child(actor)
		actor.position=row[1]
		actor.rotation.y=-.5 if actor.position.x>0 else .5
		villagers.append(actor)
	resized.connect(_frame_village.call_deferred)
	_frame_village.call_deferred()
	set_reserve(GameState.instance.rice_barn)

func _frame_village() -> void:
	if not camera or size.y<1: return
	if _station!="":
		focus_station(_station)
		return
	var lo:=Vector2(INF,INF)
	var hi:=Vector2(-INF,-INF)
	var inverse:=camera.global_transform.affine_inverse()
	for prop in world.get_children():
		if not prop is MeshInstance3D or not prop.name.begins_with("S"):continue
		var bounds: AABB=prop.mesh.get_aabb()
		for i in 8:
			var point:Vector3=inverse*(prop.global_transform*bounds.get_endpoint(i))
			lo=lo.min(Vector2(point.x,point.y))
			hi=hi.max(Vector2(point.x,point.y))
	if not lo.is_finite():return
	camera.size=maxf((hi.x-lo.x)*1.12,(hi.y-lo.y)*size.x/size.y*1.12)
	camera.h_offset=(lo.x+hi.x)*.5
	camera.v_offset=(lo.y+hi.y)*.5

func focus_station(id: String) -> void:
	_station=id
	if id=="":
		camera.position=Vector3(3,7,18)
		camera.look_at(Vector3(0,1.6,0))
		_frame_village.call_deferred()
		return
	var stations=world.find_children(id+"_VillageProp*","MeshInstance3D",true,false)
	if stations.is_empty():return
	var prop:MeshInstance3D=stations[0]
	var centre:Vector3=prop.global_transform*prop.mesh.get_aabb().get_center()
	camera.look_at_from_position(centre+Vector3(2.5,2.2,4.2),centre)
	camera.h_offset=0
	camera.v_offset=0
	camera.size=9.0 if id=="S3" else (1.2 if id=="S8" else 3.5)

func _prop(id: String, at: Vector3, yaw: float = 0, variant: int = 0) -> MeshInstance3D:
	var meshes := AssetLibrary.meshes(id)
	if meshes.is_empty(): return null
	var prop := MeshInstance3D.new()
	prop.name = id + "_VillageProp_" + str(world.get_child_count())
	prop.mesh = meshes[variant % meshes.size()]
	prop.position = at
	prop.rotation.y = yaw
	world.add_child(prop)
	return prop

func set_reserve(percent: float) -> void:
	var count := clampi(int(ceil(percent/20.0)),0,reserve_props.size())
	for i in reserve_props.size(): reserve_props[i].visible = i<count

func _process(delta: float) -> void:
	_time += delta
	for actor in villagers:
		if actor.character_profile != "maelu":actor.update_animation(delta,Vector3.ZERO)
	if fire_light: fire_light.light_energy = 2.8+.15*sin(_time*4.2)+.08*sin(_time*7.1)
