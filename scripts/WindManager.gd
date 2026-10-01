class_name WindManager
extends Node

signal wind_shift_warning(new_direction: Vector2, new_speed: float, time_until_shift: float)
signal wind_shifted(direction: Vector2, speed: float)

@export var fire_grid: FireGrid
@export var min_interval_between_shifts: float = 50.0
@export var max_interval_between_shifts: float = 85.0
@export var warning_lead_time: float = 10.0
## Plot's typical valley draft; shifts roll between 70% and 140% of it
@export var base_speed: float = 1.3

var current_direction: Vector2 = Vector2(0.707, -0.707).normalized()
var current_speed: float = 1.3
var next_direction: Vector2 = Vector2.ZERO
var next_speed: float = 1.0

var time_to_next_shift: float = 60.0
var warning_given: bool = false

func _ready() -> void:
	current_speed = base_speed
	time_to_next_shift = randf_range(min_interval_between_shifts, max_interval_between_shifts)
	_pick_next_wind()

## Called by MainController once the plot config is known (after _ready)
func set_base_speed(speed: float) -> void:
	base_speed = speed
	current_speed = speed
	_pick_next_wind()
	if fire_grid:
		fire_grid.set_wind(current_direction, current_speed)

## Plot setup: forecast starting wind and how erratic the valley drafts are
func configure(start_direction: Vector2, speed: float, shift_interval: Vector2) -> void:
	current_direction = start_direction.normalized()
	min_interval_between_shifts = shift_interval.x
	max_interval_between_shifts = shift_interval.y
	time_to_next_shift = randf_range(min_interval_between_shifts, max_interval_between_shifts)
	set_base_speed(speed)

func _pick_next_wind() -> void:
	# Random angle across mountain valley corridor
	var angle = randf_range(0, TAU)
	next_direction = Vector2(cos(angle), sin(angle)).normalized()
	next_speed = randf_range(0.7, 1.4) * base_speed
	warning_given = false

func _process(delta: float) -> void:
	time_to_next_shift -= delta
	
	# 10-Second Elder Wind Intuition Warning
	if time_to_next_shift <= warning_lead_time and not warning_given:
		warning_given = true
		wind_shift_warning.emit(next_direction, next_speed, time_to_next_shift)
		
	# Execute Shift
	if time_to_next_shift <= 0.0:
		current_direction = next_direction
		current_speed = next_speed
		if fire_grid:
			fire_grid.set_wind(current_direction, current_speed)
		wind_shifted.emit(current_direction, current_speed)
		
		# Reset for next shift cycle
		time_to_next_shift = randf_range(min_interval_between_shifts, max_interval_between_shifts)
		_pick_next_wind()
