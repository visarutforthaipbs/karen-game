class_name RangerFigure
extends RefCounted

## The state's forest ranger (character C5). Until the character pipeline installs
## res://scenes/characters/RangerChibi.tscn this builds a faceted placeholder in
## the cold surveillance palette: fictional uniform, no insignia
## (PRD_UPDATE_v1.1 P1-1). Both the crackdown ending and the Year 3+ patrol
## use RangerFigure.create().

const SCENE = "res://scenes/characters/RangerChibi.tscn"
const UNIFORM = Color(0.33, 0.38, 0.34)
const UNIFORM_DARK = Color(0.2, 0.24, 0.22)
const REFLECTIVE = Color(0.86, 0.94, 1.0)
const SKIN = Color(0.78, 0.6, 0.46)

static func has_model() -> bool:
	return ResourceLoader.exists(SCENE)

## A ranger node (model or placeholder). `flashlight` adds a cold-white torch beam.
static func create(flashlight: bool = false) -> Node3D:
	var root: Node3D
	if has_model():
		root = (load(SCENE) as PackedScene).instantiate()
	else:
		root = Node3D.new()
		var body = MeshInstance3D.new()
		body.mesh = placeholder_mesh()
		body.name = "Placeholder"
		root.add_child(body)
	if flashlight:
		var beam = SpotLight3D.new()
		beam.name = "Flashlight"
		beam.light_color = REFLECTIVE
		beam.light_energy = 6.0
		beam.spot_range = 22.0
		beam.spot_angle = 18.0
		beam.position = Vector3(0.28, 1.0, 0.25)
		beam.rotation_degrees = Vector3(-12, 180, 0) # Points along +Z (the figure's front)
		root.add_child(beam)
	return root

## Drive the model's animator when one exists (same API as the crew's chibis)
static func animate(ranger: Node3D, delta: float, velocity: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	if ranger.has_method("update_animation"):
		ranger.update_animation(delta, velocity, face)
	elif velocity.length() > 0.05:
		# Placeholder walk: a little bob and sway
		var t = Time.get_ticks_msec() / 1000.0
		var body = ranger.get_node_or_null("Placeholder")
		if body:
			body.position.y = absf(sin(t * 9.0)) * 0.05
			body.rotation.z = sin(t * 9.0) * 0.05

static func placeholder_mesh() -> ArrayMesh:
	var legs = CylinderMesh.new()
	legs.top_radius = 0.17
	legs.bottom_radius = 0.15
	legs.height = 0.5
	legs.radial_segments = 6
	legs.rings = 0
	var torso = CylinderMesh.new()
	torso.top_radius = 0.24
	torso.bottom_radius = 0.2
	torso.height = 0.5
	torso.radial_segments = 6
	torso.rings = 0
	var stripe = CylinderMesh.new()
	stripe.top_radius = 0.215
	stripe.bottom_radius = 0.215
	stripe.height = 0.05
	stripe.radial_segments = 6
	stripe.rings = 0
	var head = SphereMesh.new()
	head.radius = 0.2
	head.height = 0.36
	head.radial_segments = 6
	head.rings = 3
	var cap = CylinderMesh.new()
	cap.top_radius = 0.17
	cap.bottom_radius = 0.22
	cap.height = 0.1
	cap.radial_segments = 6
	cap.rings = 0
	var brim = BoxMesh.new()
	brim.size = Vector3(0.22, 0.03, 0.16)
	var radio = BoxMesh.new()
	radio.size = Vector3(0.08, 0.14, 0.05)
	var torch = CylinderMesh.new()
	torch.top_radius = 0.035
	torch.bottom_radius = 0.035
	torch.height = 0.2
	torch.radial_segments = 5
	torch.rings = 0
	var mesh = LowPoly.compose([
		[legs, Transform3D(Basis(), Vector3(0, 0.25, 0)), UNIFORM_DARK],
		[torso, Transform3D(Basis(), Vector3(0, 0.75, 0)), UNIFORM],
		[stripe, Transform3D(Basis(), Vector3(0, 0.68, 0)), REFLECTIVE],
		[head, Transform3D(Basis(), Vector3(0, 1.17, 0)), SKIN],
		[cap, Transform3D(Basis(), Vector3(0, 1.33, 0)), UNIFORM_DARK],
		[brim, Transform3D(Basis(), Vector3(0, 1.29, 0.14)), UNIFORM_DARK],
		[radio, Transform3D(Basis(), Vector3(-0.2, 0.94, 0.12)), Color(0.1, 0.1, 0.11)],
		[torch, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.28, 0.82, 0.18)), Color(0.15, 0.15, 0.16)],
	])
	mesh.surface_set_material(0, LowPoly.vertex_color_material())
	return mesh
