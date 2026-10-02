extends SubViewportContainer
## Small live portrait for the granary card, using the same reviewed game rig.
var character: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(110, 125)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	var view := SubViewport.new()
	view.size = Vector2i(220, 250)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	add_child(view)
	character = load("res://scenes/characters/MaeluChibi.tscn").instantiate()
	view.add_child(character)
	character.rotation.y = -0.15
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.8
	view.add_child(camera)
	camera.position = Vector3(0, 0.90, 3)
	camera.look_at(Vector3(0, 0.80, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = 1.0
	view.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.environment.ambient_light_energy = 0.7
	view.add_child(world)

func granary_gesture() -> void:
	if character: character.gesture("Granary")
