class_name CameraRig
extends Node

## Burn-day camera: follows the player at a fixed isometric pitch, leans a little
## toward the mouse aim so corners can be inspected, zooms (wheel, +/-, R3) and
## turns in 90-degree steps (Z / C, D-pad down). MainController switches it off
## for the 20:00 satellite view, which animates the camera itself.

const PITCH_DEG: float = 38.5      # Matches the original Main.tscn framing
const OVERVIEW_PITCH_DEG: float = 52.0 # Zoomed right out the view tips toward top-down
const ZOOM_MIN: float = 22.0
const ZOOM_DEFAULT: float = 44.0
const FIT_MARGIN: float = 0.9      # Overview keeps the plot inside 90% of the screen
const SCENIC_ZOOM: float = 1.9     # Past the plot fit, keep pulling back to see the valley
const SCENIC_PITCH_DEG: float = 20.0 # ...and lower toward the horizon to show the ridges
const ZOOM_STEP: float = 5.0
const AIM_LEAN: float = 0.3         # Share of the way from player to cursor the view drifts
const FOLLOW_SHARPNESS: float = 5.0

var camera: Camera3D
var target: PlayerController
## Half-extent of the playable ground; the focus point never leaves it
var bounds: float = 30.0
## Plot corners (ground and treetop height) that the widest zoom must frame
var plot_points: PackedVector3Array = PackedVector3Array()
var active: bool = true

## Widest zoom and its centre, solved for the current turn and window shape
var zoom_max: float = 72.0
var _fit_focus: Vector3 = Vector3.ZERO

var focus: Vector3 = Vector3.ZERO
var distance: float = ZOOM_DEFAULT
var yaw: float = PI * 0.25          # Camera sits on the +X/+Z diagonal, as before
var _target_distance: float = ZOOM_DEFAULT
var _target_yaw: float = PI * 0.25

func _ready() -> void:
	if target:
		focus = _ground_point(target.global_position)
	_fit_overview()
	get_viewport().size_changed.connect(_fit_overview)
	_apply(true)

func _ground_point(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -bounds, bounds), p.y, clampf(p.z, -bounds, bounds))

func _desired_focus() -> Vector3:
	if not target:
		return focus
	var p = target.global_position
	if not target.using_gamepad_aim and target.is_targeting_valid_cell:
		p = p.lerp(target.target_cell_pos, AIM_LEAN)
	# Zooming out slides the view to the fitted centre, so the widest view frames it all
	p = p.lerp(_fit_focus, _overview())
	return _ground_point(p)

## 0 at the default zoom, 1 fully zoomed out
func _overview() -> float:
	return clampf(inverse_lerp(ZOOM_DEFAULT, zoom_max, distance), 0.0, 1.0)

func _process(delta: float) -> void:
	if not active or not camera:
		return
	var k = 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	focus = focus.lerp(_desired_focus(), k)
	distance = lerpf(distance, _target_distance, 1.0 - exp(-10.0 * delta))
	yaw = lerp_angle(yaw, _target_yaw, 1.0 - exp(-9.0 * delta))
	_apply()

func _apply(_snap: bool = false) -> void:
	if not camera:
		return
	# Tipping toward top-down when zoomed out keeps the near corner on screen;
	# pulling back further turns it into a landscape view toward the horizon
	var scenic = clampf(inverse_lerp(zoom_max, zoom_max * SCENIC_ZOOM, distance), 0.0, 1.0)
	var pitch = deg_to_rad(lerpf(lerpf(PITCH_DEG, OVERVIEW_PITCH_DEG, _overview()), SCENIC_PITCH_DEG, scenic))
	var offset = Vector3(sin(yaw), 0.0, cos(yaw)) * cos(pitch) * distance
	offset.y = sin(pitch) * distance
	camera.global_position = focus + offset
	camera.look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("cam_zoom_in"):
		zoom_by(-ZOOM_STEP)
	elif event.is_action_pressed("cam_zoom_out"):
		zoom_by(ZOOM_STEP)
	elif event.is_action_pressed("cam_zoom_cycle"):
		cycle_zoom()
	elif event.is_action_pressed("cam_rotate_left"):
		rotate_view(-1)
	elif event.is_action_pressed("cam_rotate_right"):
		rotate_view(1)
	else:
		return
	get_viewport().set_input_as_handled()

func zoom_by(amount: float) -> void:
	_target_distance = clampf(_target_distance + amount, ZOOM_MIN, zoom_max * SCENIC_ZOOM)

## Gamepad: close, default, whole plot
func cycle_zoom() -> void:
	for z in [30.0, ZOOM_DEFAULT, zoom_max]:
		if z > _target_distance + 0.5:
			_target_distance = z
			return
	_target_distance = 30.0

## Quarter turns around the focus point
func rotate_view(steps: int) -> void:
	var ratio = _target_distance / zoom_max
	_target_yaw = wrapf(_target_yaw + steps * PI * 0.5, -PI, PI)
	_fit_overview()
	if ratio >= 0.99:
		_target_distance = zoom_max * minf(ratio, SCENIC_ZOOM)

# ---------------------------------------------------------------------------
# Overview fit: project the plot points through a trial camera at the overview
# pitch, centre their screen box, then find the distance that fits the margin.
# ---------------------------------------------------------------------------

func _trial_view(f: Vector3, d: float) -> Transform3D:
	var pitch = deg_to_rad(OVERVIEW_PITCH_DEG)
	var offset = Vector3(sin(_target_yaw), 0.0, cos(_target_yaw)) * cos(pitch) * d
	offset.y = sin(pitch) * d
	return Transform3D(Basis(), f + offset).looking_at(f, Vector3.UP)

## Screen box of the plot points in normalised device units (-1..1)
func _ndc_box(view: Transform3D) -> Rect2:
	var tan_v = tan(deg_to_rad(camera.fov) * 0.5)
	var size = camera.get_viewport().get_visible_rect().size
	var tan_h = tan_v * size.x / maxf(size.y, 1.0)
	var inv = view.affine_inverse()
	var box = Rect2()
	for i in plot_points.size():
		var c = inv * plot_points[i]
		var depth = maxf(-c.z, 0.01)
		var p = Vector2(c.x / depth / tan_h, c.y / depth / tan_v)
		box = Rect2(p, Vector2.ZERO) if i == 0 else box.expand(p)
	return box

func _fit_overview() -> void:
	if not camera or plot_points.is_empty():
		return
	var f = Vector3.ZERO
	for p in plot_points:
		f += p
	f /= plot_points.size()
	var d = 70.0
	for _pass in 3:
		var view = _trial_view(f, d)
		var box = _ndc_box(view)
		var centre = box.get_center()
		# Slide the focus across the ground so the plot sits in the middle of the screen
		var right = Vector3(view.basis.x.x, 0.0, view.basis.x.z).normalized()
		var up_ground = Vector3(-view.basis.z.x, 0.0, -view.basis.z.z).normalized()
		var tan_v = tan(deg_to_rad(camera.fov) * 0.5)
		var size = camera.get_viewport().get_visible_rect().size
		var tan_h = tan_v * size.x / maxf(size.y, 1.0)
		f += right * centre.x * d * tan_h
		f += up_ground * centre.y * d * tan_v / sin(deg_to_rad(OVERVIEW_PITCH_DEG))
		# Distance that brings the widest half-extent to the margin
		var lo = ZOOM_DEFAULT
		var hi = 220.0
		for _i in 24:
			var mid = (lo + hi) * 0.5
			var b = _ndc_box(_trial_view(f, mid))
			if maxf(maxf(absf(b.position.x), absf(b.end.x)), maxf(absf(b.position.y), absf(b.end.y))) > FIT_MARGIN:
				lo = mid
			else:
				hi = mid
		d = hi
	zoom_max = maxf(d, ZOOM_DEFAULT + 1.0)
	_fit_focus = Vector3(f.x, focus.y, f.z)
	_target_distance = minf(_target_distance, zoom_max * SCENIC_ZOOM)

func set_active(on: bool) -> void:
	active = on
