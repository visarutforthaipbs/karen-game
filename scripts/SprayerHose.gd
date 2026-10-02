extends MeshInstance3D
## Visual-only tube, attached to the actual tank and wand fittings every frame.
## Keep these points in each prop's local metres (asset polish handoff).
var tank: Node3D
var wand: Node3D
var tank_outlet := Vector3(0.150, 0.055, -0.096750)
var wand_inlet := Vector3(0, 0.024533, -0.075990)
var active := false
var centreline := PackedVector3Array()
const SEGMENTS := 24
const SIDES := 6
const RADIUS := 0.008

func _ready() -> void:
	mesh = ImmediateMesh.new()
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.055, 0.048, 0.043)
	rubber.roughness = 0.95
	material_override = rubber
	process_priority = 100
	visible = false

func _process(_delta: float) -> void:
	update_hose()

func update_hose() -> void:
	visible = active and is_instance_valid(tank) and is_instance_valid(wand) and wand.is_visible_in_tree()
	if not visible:
		return
	var tube := mesh as ImmediateMesh
	tube.clear_surfaces()
	centreline.clear()
	var start := tank.to_global(tank_outlet)
	var finish := wand.to_global(wand_inlet)
	# Exit below the tank and bow around the right hip, clear of the torso.
	var back := -tank.global_basis.z.normalized()
	var right := -tank.global_basis.x.normalized()
	var control_a := start + back * 0.14 + Vector3.DOWN * 0.24
	var control_b := finish + right * 0.20 + Vector3.DOWN * 0.22 + back * 0.12
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		centreline.append(to_local(start.bezier_interpolate(control_a, control_b, finish, t)))
	tube.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i in centreline.size():
		var axis := (centreline[mini(i+1,SEGMENTS)]-centreline[maxi(i-1,0)]).normalized()
		var reference := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var across := axis.cross(reference).normalized() * RADIUS
		var up := axis.cross(across).normalized() * RADIUS
		var ring := PackedVector3Array()
		for side in SIDES:
			var a := TAU * side / SIDES
			ring.append(across*cos(a)+up*sin(a))
		rings.append(ring)
	for i in SEGMENTS:
		for side in SIDES:
			var next := (side+1)%SIDES
			for corner in [Vector2i(i,side),Vector2i(i+1,side),Vector2i(i+1,next),Vector2i(i,side),Vector2i(i+1,next),Vector2i(i,next)]:
				tube.surface_set_normal(rings[corner.x][corner.y].normalized())
				tube.surface_add_vertex(centreline[corner.x]+rings[corner.x][corner.y])
	tube.surface_end()
