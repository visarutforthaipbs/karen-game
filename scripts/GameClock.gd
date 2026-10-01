class_name GameClock
extends Node

## Signals
signal time_ticked(display_str: String, hour: int, minute: int)
signal satellite_window_closing(minutes_remaining: int)
signal satellite_pass_triggered()

@export var start_hour: int = 14
@export var start_minute: int = 0
@export var satellite_pass_hour: int = 20
@export var satellite_pass_minute: int = 0

## Real seconds required for 1 in-game hour (90s = 9 min full match)
@export var real_seconds_per_hour: float = 90.0

var current_sim_time_seconds: float = 0.0
var is_running: bool = true
var has_triggered_pass: bool = false
var _last_emitted_minute: int = -1

func _ready() -> void:
	# Convert start time to total seconds from midnight
	current_sim_time_seconds = (start_hour * 3600.0) + (start_minute * 60.0)

func _process(delta: float) -> void:
	if not is_running:
		return
		
	# Time progression rate
	var sim_seconds_per_real_second = 3600.0 / real_seconds_per_hour
	current_sim_time_seconds += delta * sim_seconds_per_real_second
	
	var total_seconds = int(current_sim_time_seconds)
	var total_minutes = total_seconds / 60
	
	# Signals fire once per in-game minute, not once per frame
	if total_minutes != _last_emitted_minute:
		_last_emitted_minute = total_minutes
		var current_hour = (total_minutes / 60) % 24
		var current_minute = total_minutes % 60
		var time_str = "%02d:%02d" % [current_hour, current_minute]
		time_ticked.emit(time_str, current_hour, current_minute)
		
		var sat_total_minutes = (satellite_pass_hour * 60) + satellite_pass_minute
		var minutes_left = sat_total_minutes - total_minutes
		if minutes_left > 0 and minutes_left <= 30: # Within 30 in-game minutes
			satellite_window_closing.emit(minutes_left)
	
	# Check distance to satellite pass
	var sat_total_seconds = (satellite_pass_hour * 3600) + (satellite_pass_minute * 60)
	var seconds_left = sat_total_seconds - total_seconds
	
	if seconds_left <= 0 and not has_triggered_pass:
		has_triggered_pass = true
		satellite_pass_triggered.emit()

## Late start after lending labour to a neighbouring hamlet (mutual aid exchange)
func set_start_time(hour: int, minute: int) -> void:
	start_hour = hour + minute / 60
	start_minute = minute % 60
	current_sim_time_seconds = (start_hour * 3600.0) + (start_minute * 60.0)
	_last_emitted_minute = -1

## Current in-game time in fractional hours (e.g. 18.5 = 18:30)
func get_hours() -> float:
	return current_sim_time_seconds / 3600.0

func pause_clock() -> void:
	is_running = false

func resume_clock() -> void:
	is_running = true
