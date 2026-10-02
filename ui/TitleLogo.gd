class_name TitleLogo
extends VBoxContainer

## "Under Two Skies" title, built like the rest of the game: faceted low-poly 3D
## letters (coarse curves, flat facets, straw-to-clay gradient, dark extruded
## underside like the UI slabs) under a floating hill island, the game in
## miniature (Meshy model: swidden plots, field hut, bamboo, pines). Lit by two
## skies: the warm sun is the sky that shelters; the cold ambient sky is the one
## that watches, so anything the sun misses turns blue. The satellite (V3) glides
## over the island and its real shadow sweeps across the fields.
##   full:    live 3D title + Thai subtitle (title screen); drive `phase` 0..1
##   compact: the exported static wordmark PNG (Hearth header)
## tools/export_logo.gd renders the PNGs in assets/ui/logo/ from build_scene().

const SUBTITLE = "ไร่หมุนเวียนใต้เงาดาวเทียม"
const WORDMARK = "res://assets/ui/logo/under_two_skies_wordmark.png"
const ISLAND = "res://assets/ui/logo/island.glb"
const SUN_FROM = Vector3(6, 5, 6)           # Warm key light, upper right
const STATIC_PHASE = 0.62                   # Shadow on the fields, for stills
const VIEW_ASPECT = 1.8                     # Width / height of the 3D view
const ISLAND_POS = Vector3(0.9, 0.85, -2.4)
const ISLAND_WIDTH = 3.3
static var _field_y: float = 2.15           # Island ground height, set by build_scene

const LETTER_SHADER = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 top_col : source_color;
uniform vec3 bottom_col : source_color;
uniform vec3 side_col : source_color;
uniform float y0;
uniform float y1;
varying vec3 obj;
varying vec3 onrm;
void vertex() { obj = VERTEX; onrm = NORMAL; }
void fragment() {
	float t = clamp((obj.y - y0) / (y1 - y0), 0.0, 1.0);
	vec3 face = mix(bottom_col, top_col, t);
	// Extruded sides read as the hard dark underside of a slab
	float side = 1.0 - abs(onrm.z);
	ALBEDO = mix(face, side_col, smoothstep(0.3, 0.7, side));
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX))); // Flat, un-smoothed facets
	ROUGHNESS = 1.0;
}
"""

@export var compact: bool = false
@export var size_px: float = 80.0   # Rough cap height of "TWO SKIES" on screen

## Where the satellite is on its glide across the title, 0..1 (left to right)
var phase: float = STATIC_PHASE:
	set(v):
		phase = v
		if _sat:
			place_satellite(_sat, phase)

var _sat: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(-size_px * 0.12))
	if compact:
		_build_compact()
		return
	var view = SubViewportContainer.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = size_px * 4.0
	view.custom_minimum_size = Vector2(h * VIEW_ASPECT, h)
	add_child(view)
	var vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	view.add_child(vp)
	_sat = build_scene(vp)
	place_satellite(_sat, phase)
	var sub = UITheme.outlined(UITheme.label(SUBTITLE, "Title", UITheme.CREAM), int(maxf(4.0, size_px * 0.08)))
	sub.add_theme_font_override("font", UITheme.font("medium"))
	sub.add_theme_font_size_override("font_size", int(size_px * 0.36))
	var indent = MarginContainer.new()
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_theme_constant_override("margin_left", int(h * VIEW_ASPECT * 0.1))
	indent.add_child(sub)
	add_child(indent)

func _build_compact() -> void:
	if ResourceLoader.exists(WORDMARK):
		var t = TextureRect.new()
		t.texture = load(WORDMARK)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var ts = t.texture.get_size()
		t.custom_minimum_size = Vector2(size_px * ts.x / ts.y, size_px)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
	else:
		var l = UITheme.label("UNDER TWO SKIES", "Title", UITheme.STRAW)
		l.add_theme_font_override("font", UITheme.font("bold"))
		l.add_theme_font_size_override("font_size", int(size_px * 0.8))
		add_child(l)

## Builds the lit 3D title into `vp` and returns the satellite node (or null).
## satellite: false leaves it out; one_line: "UNDER TWO SKIES" on one line with
## no island (wordmark); letters: false leaves just island + satellite (icon).
static func build_scene(vp: SubViewport, satellite: bool = true, one_line: bool = false, with_letters: bool = true) -> Node3D:
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.45, 0.72) # Cold sky: what the sun misses goes blue
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.55)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 0.4
	vp.add_child(sun)
	sun.look_at_from_position(SUN_FROM, Vector3.ZERO, Vector3.UP)

	if with_letters:
		var two = letters("UNDER TWO SKIES" if one_line else "TWO SKIES", 96, 0.5, UITheme.STRAW.lightened(0.08))
		two.position = Vector3(0, -0.3, 0)
		two.rotation = Vector3(0, -0.16, 0)
		vp.add_child(two)
		if not one_line:
			var u = letters("UNDER", 40, 0.25, UITheme.CREAM, "SemiBold")
			u.position = Vector3(-3.6, 1.55, 0.2)
			u.rotation = Vector3(0, -0.16, 0)
			vp.add_child(u)
	if not one_line and ResourceLoader.exists(ISLAND):
		vp.add_child(island())

	var cam = Camera3D.new()
	vp.add_child(cam)
	if one_line:
		cam.fov = 19.0
		cam.look_at_from_position(Vector3(-2.1, 5.95, 21.0), Vector3(0.1, 0.55, 0), Vector3.UP)
	elif with_letters:
		cam.fov = 17.5
		cam.look_at_from_position(Vector3(-2.2, 10.2, 18.2), Vector3(-0.15, 0.95, -0.8), Vector3.UP)
		cam.v_offset = 0.75 # Frame the island + letters tightly (no empty band below)
	else:
		cam.fov = 21.0
		var aim = ISLAND_POS + Vector3(0.45, 0.75, 0.3)
		cam.look_at_from_position(aim + Vector3(-3.0, 6.2, 9.4) * 1.45, aim, Vector3.UP)

	if not satellite:
		return null
	var sat = MeshInstance3D.new()
	sat.mesh = SatelliteModel.mesh()
	sat.scale = Vector3.ONE * SatelliteModel.fit_scale(sat.mesh) * 2.2 / 16.0 # ~2.2 m wingspan
	sat.position = -sat.mesh.get_aabb().get_center() * sat.scale.x
	var pivot = Node3D.new() # place_satellite moves the pivot; the mesh stays centred on it
	pivot.add_child(sat)
	vp.add_child(pivot)
	return pivot

## The floating hill island, scaled and placed above the letters
static func island() -> Node3D:
	var holder = Node3D.new()
	holder.position = ISLAND_POS
	holder.rotation = Vector3(0, 0.62, 0)
	var model = (load(ISLAND) as PackedScene).instantiate()
	var box = AABB()
	var first = true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b = mi.transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s = ISLAND_WIDTH / maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s
	holder.add_child(model)
	# Fields sit about a quarter of the way down from the tree tops
	_field_y = ISLAND_POS.y + (box.end.y - box.get_center().y) * s - 0.45
	return holder

## The satellite sits between the sun and a point gliding across the island's
## fields, so its shadow lands there: phase 0 enters at the left edge, 1 leaves right
static func place_satellite(sat: Node3D, p: float) -> void:
	var across = Vector3(1, 0, 0.35).normalized() * lerpf(-2.4, 2.4, p)
	var target = Vector3(ISLAND_POS.x + 0.3, _field_y, ISLAND_POS.z + 0.55) + across
	sat.position = target + SUN_FROM.normalized() * 1.8
	sat.rotation = Vector3(-0.35, 0.75, 0.1 + sin(p * TAU * 2.0) * 0.04) # Wings broadside to the sun

## Faceted extruded letters with the painted gradient
static func letters(text: String, px: int, depth: float, color: Color, weight: String = "Bold") -> MeshInstance3D:
	var tm = TextMesh.new()
	tm.text = text
	tm.font = load("res://assets/fonts/Kanit-%s.ttf" % weight)
	tm.font_size = px
	tm.pixel_size = 0.02
	tm.depth = depth
	tm.curve_step = 22.0 # Coarse curves: angular, low-poly letterforms
	var sh = Shader.new()
	sh.code = LETTER_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("top_col", color)
	mat.set_shader_parameter("bottom_col", color.lerp(UITheme.CLAY, 0.55))
	mat.set_shader_parameter("side_col", Color("7a3e22"))
	mat.set_shader_parameter("y0", -px * 0.02 * 0.35)
	mat.set_shader_parameter("y1", px * 0.02 * 0.4)
	tm.material = mat
	var mi = MeshInstance3D.new()
	mi.mesh = tm
	return mi
