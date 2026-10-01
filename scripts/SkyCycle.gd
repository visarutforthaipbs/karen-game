class_name SkyCycle
extends Node

## Afternoon -> sunset -> blue hour lighting for the 14:00-20:00 burn (PRD §3.1, §9.1),
## plus the 18:00 inversion fog that shrinks draw distance (PRD §4.3) and an
## optional pre-monsoon storm front (plot 5).

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

## 0..1, eased in by MainController when the inversion layer forms at 18:00
var inversion_strength: float = 0.0
var storm_front: bool = false
## Height (m) below which inversion smoke pools; set from the hillside
var inversion_ceiling: float = 6.0

var _flash: float = 0.0
var _keys: Array[Dictionary] = []

func _ready() -> void:
	var env = world_environment.environment if world_environment else null
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial if env and env.sky else null
	# 14:00 uses whatever the scene is tuned to; later keys are absolute moods
	var base_energy = sun.light_energy if sun else 1.25
	# Thinner haze, less flat ambient and no bloom keep the low-poly silhouettes crisp
	var base_ambient = (env.ambient_light_energy if env else 0.85) * 0.7
	var base_fog = (env.fog_density if env else 0.005) * 0.4
	if env:
		env.glow_bloom = 0.0
	var base_top = sky_mat.sky_top_color if sky_mat else Color(0.24, 0.48, 0.78)
	var base_horizon = sky_mat.sky_horizon_color if sky_mat else Color(0.88, 0.76, 0.62)
	var base_fog_color = env.fog_light_color if env else Color(0.78, 0.72, 0.65)
	var base_light = sun.light_color if sun else Color(1, 0.94, 0.82)

	_keys = [
		{"h": 14.0, "pitch": -55.0, "yaw": -55.0, "energy": base_energy, "light": base_light, "top": base_top, "horizon": base_horizon, "ambient": base_ambient, "fog_color": base_fog_color, "fog": base_fog},
		{"h": 16.5, "pitch": -36.0, "yaw": -65.0, "energy": base_energy * 0.95, "light": Color(1.0, 0.88, 0.7), "top": Color(0.3, 0.45, 0.7), "horizon": Color(0.92, 0.72, 0.5), "ambient": base_ambient * 0.95, "fog_color": Color(0.8, 0.7, 0.58), "fog": base_fog * 1.4},
		{"h": 18.0, "pitch": -12.0, "yaw": -75.0, "energy": base_energy * 0.7, "light": Color(1.0, 0.6, 0.3), "top": Color(0.42, 0.36, 0.45), "horizon": Color(0.96, 0.55, 0.26), "ambient": base_ambient * 0.75, "fog_color": Color(0.72, 0.52, 0.32), "fog": base_fog * 2.5},
		{"h": 19.5, "pitch": -1.0, "yaw": -82.0, "energy": base_energy * 0.18, "light": Color(0.6, 0.62, 0.95), "top": Color(0.08, 0.12, 0.3), "horizon": Color(0.32, 0.32, 0.52), "ambient": base_ambient * 0.45, "fog_color": Color(0.32, 0.32, 0.42), "fog": base_fog * 3.0},
		{"h": 20.0, "pitch": 4.0, "yaw": -85.0, "energy": base_energy * 0.1, "light": Color(0.5, 0.55, 0.9), "top": Color(0.05, 0.08, 0.22), "horizon": Color(0.22, 0.24, 0.42), "ambient": base_ambient * 0.38, "fog_color": Color(0.25, 0.26, 0.36), "fog": base_fog * 3.0},
	]

## Flash of lightning (storm front)
func flash() -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)

## Apply the lighting for an in-game time, in hours (e.g. 18.25 = 18:15)
func apply_time(hours: float) -> void:
	if _keys.is_empty():
		return
	var a = _keys[0]
	var b = _keys[_keys.size() - 1]
	for i in range(_keys.size() - 1):
		if hours >= _keys[i].h and hours <= _keys[i + 1].h:
			a = _keys[i]
			b = _keys[i + 1]
			break
	var span = maxf(b.h - a.h, 0.001)
	var t = clampf((hours - a.h) / span, 0.0, 1.0)
	if hours >= b.h:
		t = 1.0

	var storm_dim = 0.7 if storm_front else 1.0
	if sun:
		sun.rotation_degrees = Vector3(lerpf(a.pitch, b.pitch, t), lerpf(a.yaw, b.yaw, t), 0.0)
		sun.light_energy = lerpf(a.energy, b.energy, t) * storm_dim + _flash * 4.0
		sun.light_color = (a.light as Color).lerp(b.light, t)

	var env = world_environment.environment if world_environment else null
	if not env:
		return
	env.ambient_light_energy = lerpf(a.ambient, b.ambient, t) * storm_dim + _flash * 1.5
	var fog_color = (a.fog_color as Color).lerp(b.fog_color, t)
	var sepia = Color(0.62, 0.46, 0.28)
	env.fog_light_color = fog_color.lerp(sepia, inversion_strength * 0.6)
	# Inversion: thick, ground-hugging haze that cuts visibility
	env.fog_density = lerpf(a.fog, b.fog, t) + inversion_strength * 0.02 + (0.002 if storm_front else 0.0)
	env.fog_height = inversion_ceiling
	env.fog_height_density = inversion_strength * 0.25

	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	if sky_mat:
		var top = (a.top as Color).lerp(b.top, t)
		var horizon = (a.horizon as Color).lerp(b.horizon, t)
		if storm_front:
			top = top.lerp(Color(0.2, 0.22, 0.26), 0.55)
			horizon = horizon.lerp(Color(0.4, 0.4, 0.42), 0.4)
		sky_mat.sky_top_color = top
		sky_mat.sky_horizon_color = horizon.lerp(sepia, inversion_strength * 0.35)
