extends Node3D
## One reusable faceted jet per working companion. Intention only, no cell mutation.
var droplets: MultiMeshInstance3D
var origin: Vector3
var destination: Vector3
var phase := 0.0
var target_ring: MeshInstance3D
func _ready() -> void:
	droplets = MultiMeshInstance3D.new()
	droplets.multimesh = MultiMesh.new()
	droplets.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := SphereMesh.new()
	mesh.radius = 0.085
	mesh.height = 0.17
	mesh.radial_segments = 4
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.52, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	droplets.multimesh.mesh = mesh
	droplets.multimesh.instance_count = 16
	droplets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(droplets)
	target_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.82
	ring.rings = 12
	ring.ring_segments = 3
	ring.material = mat
	target_ring.mesh = ring
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(target_ring)
func update_jet(start: Vector3, end: Vector3) -> void:
	origin = start
	destination = end + Vector3.UP * 0.08
	_draw_jet()
func _process(delta: float) -> void:
	phase = fmod(phase + delta * 2.2, 1.0)
	_draw_jet()
func _draw_jet() -> void:
	if not droplets: return
	# Keep the narrow jet legible at plot overview without changing its endpoints.
	var radius := 0.085
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_behind(origin):
		var pixels := cam.unproject_position(origin).distance_to(cam.unproject_position(origin + cam.global_basis.x))
		radius = clampf(1.5 / maxf(pixels, 0.1), 0.085, 0.4)
	target_ring.position = to_local(destination)
	for i in 16:
		var t := fmod(phase + float(i) / 16.0, 1.0)
		var point := origin.lerp(destination, t)
		point += Vector3(sin(i * 2.4) * 0.10 * t, sin(t * PI) * 0.12, cos(i * 2.4) * 0.10 * t)
		droplets.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius / 0.085), to_local(point)))
