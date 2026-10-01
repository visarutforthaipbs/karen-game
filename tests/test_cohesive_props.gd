extends SceneTree
## Installed-set integration: variants, colour materials, and animated rotor attachment.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(AssetLibrary.new().get_script().resource_path == "res://scripts/AssetLibrary.gd",
		"A historical snapshot shadowed the live asset loader")
	AssetLibrary.reload()
	for id in {"E1": 3, "E2": 3, "E3": 4, "S2": 1, "V1": 1}:
		var expected: int = {"E1": 3, "E2": 3, "E3": 4, "S2": 1, "V1": 1}[id]
		var meshes := AssetLibrary.meshes(id)
		check(meshes.size() == expected, id + " installed variant count is wrong")
		for mesh: Mesh in meshes:
			check(mesh.get_surface_count() == 1, id + " should use one material surface")
			var material: BaseMaterial3D = mesh.surface_get_material(0)
			check(material.vertex_color_use_as_albedo, id + " vertex palette is disabled")
			check(material.roughness >= 0.8, id + " material is too glossy")
			var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			check(not colors.is_empty() and colors[0] != Color.WHITE, id + " palette missing")
	var drone := ForestryDrone.new()
	drone._build_drone_visuals()
	check(drone._rotors.size() == 4, "Drone requires four separate animated rotors")
	var mounts: Array[Vector3] = []
	for rotor in drone._rotors:
		mounts.append(rotor.position)
		check(is_equal_approx(absf(rotor.position.x), .48) and is_equal_approx(absf(rotor.position.z), .48),
			"Rotor is not aligned to the V1 motor center")
		check(is_equal_approx(rotor.position.y - .015, drone.drone_body.mesh.get_aabb().end.y),
			"Rotor floats above or intersects the motor hub")
		check(rotor.get_parent() == drone.drone_body, "Rotor detached from body transforms")
	drone.is_active_patrol = true
	drone.is_hovering = true
	drone.hover_timer = 1.0
	drone._physics_process(.05)
	for i in drone._rotors.size():
		check(is_equal_approx(drone._rotors[i].rotation.y, 2.0), "Rotor animation stopped")
		check(drone._rotors[i].position.is_equal_approx(mounts[i]), "Spinning rotor moved off its mount")
	drone.free()
	AssetLibrary.reload()
	print("Cohesive prop integration: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
