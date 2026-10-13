extends Node3D

## Doisaket Game Lab studio ident: the Meshy-generated white low-poly mark
## (assets/ui/logo/dgl_mark.glb, 636 triangles) assembles facet by facet, the sun
## lands last, the wordmark fades in, then the game continues to the title.
## Monochrome by design: white facets on the UI ink. Any tap / key skips.
## Runs as the boot scene; tests load Title.tscn directly and never see it.

const MARK := "res://assets/ui/logo/dgl_mark.glb"
const NEXT := "res://scenes/Title.tscn"
const ASSEMBLE := 1.4      # seconds for all facets to land
const HOLD := 1.3          # seconds the finished mark holds
const FADE := 0.45

var _t := 0.0
var _done := false
var _mat: ShaderMaterial
var _wordmark: Control
var _veil: ColorRect
var _rig: Node3D
var _sun: MeshInstance3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = UITheme.INK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -38, 0)
	key.light_energy = 1.25
	key.shadow_enabled = false
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 142, 0)
	fill.light_energy = 0.35
	add_child(fill)

	_rig = Node3D.new()
	add_child(_rig)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _faceted(MARK)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader()
	_mat.set_shader_parameter("t", 0.0)
	mesh_inst.material_override = _mat
	_rig.add_child(mesh_inst)
	# Clean flat sun disc where Meshy's ball was (lands with the last facets)
	_sun = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.radial_segments = 10
	disc.top_radius = 0.052
	disc.bottom_radius = 0.052
	disc.height = 0.012
	_sun.mesh = disc
	_sun.rotation_degrees = Vector3(90, 0, 0)
	_sun.position = Vector3(-0.162, 0.40, 0.012)
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(0.97, 0.95, 0.90)
	sun_mat.roughness = 1.0
	_sun.material_override = sun_mat
	_sun.scale = Vector3(0.001, 0.001, 0.001)
	_rig.add_child(_sun)
	_rig.position = Vector3(0, 0.08, 0)
	_rig.rotation_degrees = Vector3(0, 28, 0)

	var cam := Camera3D.new()
	cam.fov = 26
	cam.position = Vector3(0.8, 0.62, 3.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.06, 0), Vector3.UP)

	# Wordmark (2D) under the mark
	var layer := CanvasLayer.new()
	add_child(layer)
	_wordmark = UITheme.vbox(2)
	_wordmark.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_wordmark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_wordmark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_wordmark.offset_bottom = -56.0
	_wordmark.alignment = BoxContainer.ALIGNMENT_CENTER
	_wordmark.modulate.a = 0.0
	_wordmark.theme = UITheme.get_theme()
	layer.add_child(_wordmark)
	var name_label := Label.new()
	name_label.text = "DOISAKET"
	name_label.add_theme_font_override("font", UITheme.font("state_bold"))
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", UITheme.CREAM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wordmark.add_child(name_label)
	var sub := Label.new()
	sub.text = "GAME LAB · ดอยสะเก็ด"
	sub.add_theme_font_override("font", UITheme.font("medium"))
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(UITheme.CREAM, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wordmark.add_child(sub)
	# Fade-out veil
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = UITheme.INK
	_veil.modulate.a = 0.0
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)
	if OS.get_cmdline_user_args().has("--no-ident"):
		_finish()

## Re-triangulate with flat normals and per-face custom data:
## CUSTOM0 = face centroid (xyz) + landing delay (w, 0..1)
func _faceted(path: String) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_warning("StudioIdent: cannot load %s" % path)
		return ArrayMesh.new()
	var scene := doc.generate_scene(state)
	var src: Mesh = null
	var stack: Array = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and src == null:
			src = n.mesh
		for k in n.get_children():
			stack.append(k)
	scene.free()
	var out := ArrayMesh.new()
	if src == null:
		return out
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# Model spans y -0.41..0.41: sort faces bottom-up so the mountain grows upward.
	var faces: Array = []
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var count := idx.size() if idx.size() > 0 else verts.size()
		for i in range(0, count - 2, 3):
			var a := verts[idx[i]] if idx.size() > 0 else verts[i]
			var b := verts[idx[i + 1]] if idx.size() > 0 else verts[i + 1]
			var c := verts[idx[i + 2]] if idx.size() > 0 else verts[i + 2]
			faces.append([a, b, c])
	# Meshy rendered the sun as a dense 560-triangle ball above the left peak
	# (centroid y > 0.30, x -0.21..-0.12): drop it; a crisp flat disc replaces it.
	faces = faces.filter(func(f): var cy: float = (f[0].y + f[1].y + f[2].y) / 3.0; var cx: float = (f[0].x + f[1].x + f[2].x) / 3.0; return not (cy > 0.30 and cx > -0.22 and cx < -0.11))
	faces.sort_custom(func(f, g): return (f[0].y + f[1].y + f[2].y) < (g[0].y + g[1].y + g[2].y))
	for i in faces.size():
		var f: Array = faces[i]
		var centroid: Vector3 = (f[0] + f[1] + f[2]) / 3.0
		var delay := clampf(float(i) / float(maxi(faces.size() - 1, 1)) * 0.85 + rng.randf_range(0.0, 0.12), 0.0, 0.97)
		var normal: Vector3 = (f[1] - f[0]).cross(f[2] - f[0]).normalized()
		for v in f:
			st.set_normal(normal)
			st.set_custom(0, Color(centroid.x, centroid.y, centroid.z, delay))
			st.add_vertex(v)
	st.commit(out)
	return out

func _shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float t : hint_range(0.0, 1.0) = 0.0;
void vertex() {
	vec3 centroid = CUSTOM0.xyz;
	float delay = CUSTOM0.w;
	float a = clamp((t - delay * %.2f) / %.2f, 0.0, 1.0);
	a = 1.0 - pow(1.0 - a, 3.0);               // ease-out cubic
	vec3 rest = VERTEX;
	vec3 start = centroid + vec3(0.0, -0.55, 0.0);
	VERTEX = mix(start + (rest - centroid) * 0.05, rest, a);
}
void fragment() {
	ALBEDO = vec3(0.97, 0.95, 0.90);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.12;
}
""" % [ASSEMBLE, ASSEMBLE * 0.3]
	return sh

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_mat.set_shader_parameter("t", clampf(_t / ASSEMBLE, 0.0, 1.0) * (ASSEMBLE + ASSEMBLE * 0.3) / ASSEMBLE)
	_rig.rotation_degrees.y = 28.0 - 10.0 * clampf(_t / (ASSEMBLE + HOLD), 0.0, 1.0)
	var sun_a := clampf((_t - ASSEMBLE * 0.9) / 0.35, 0.0, 1.0)
	sun_a = 1.0 - pow(1.0 - sun_a, 3.0)
	_sun.scale = Vector3.ONE * maxf(0.001, sun_a)
	_sun.position.y = 0.40 + (1.0 - sun_a) * 0.12
	_wordmark.modulate.a = clampf((_t - ASSEMBLE * 0.75) / 0.5, 0.0, 1.0)
	var total := ASSEMBLE + HOLD
	_veil.modulate.a = clampf((_t - total) / FADE, 0.0, 1.0)
	if _t >= total + FADE:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file.call_deferred(NEXT)
