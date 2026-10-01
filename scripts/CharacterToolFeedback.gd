extends Node3D
## Short, faceted feedback only after a tool successfully changes a cell.
## No gameplay effects or water accounting live in this visual node.
var start: Vector3
var target: Vector3
var elapsed := 0.0
var particles: MultiMeshInstance3D
var kind: StringName
const DURATION := 0.32

static func spawn(parent: Node3D, origin: Vector3, destination: Vector3, action: StringName) -> Node3D:
	var effect := Node3D.new()
	effect.set_script(load("res://scripts/CharacterToolFeedback.gd"))
	effect.start = origin
	effect.target = destination + Vector3.UP * 0.06
	effect.kind = action
	parent.add_child(effect)
	return effect

func _ready() -> void:
	particles = MultiMeshInstance3D.new()
	particles.multimesh = MultiMesh.new()
	particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var droplet := SphereMesh.new()
	droplet.radius = 0.025 if kind == &"spray" else 0.035
	droplet.height = droplet.radius * 2
	droplet.radial_segments = 4
	droplet.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.75, 0.95) if kind == &"spray" else (Color(0.95, 0.40, 0.10) if kind == &"ignite" else Color(0.45, 0.32, 0.16))
	material.roughness = 1.0
	droplet.material = material
	particles.multimesh.mesh = droplet
	particles.multimesh.instance_count = 8
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	_update_particles()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	_update_particles()

func _update_particles() -> void:
	for i in 8:
		var t := clampf(elapsed / DURATION + i * 0.035, 0, 1)
		var point := start.lerp(target, t) if kind == &"spray" else target
		point += Vector3(sin(i * 2.4), 0, cos(i * 2.4)) * (0.035 if kind == &"spray" else 0.15) * t
		point.y += sin(t * PI) * (0.10 if kind == &"spray" else 0.16)
		var size := 1.0 - t * 0.6
		particles.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), to_local(point)))
