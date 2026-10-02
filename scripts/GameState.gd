extends Node

static var instance: Node

const PLOTS_PER_YEAR: int = 5
const FAMINE_THRESHOLD: float = 20.0
# Scrutiny relief (balance pass 2026-10-02, campaign Monte Carlo): attention drifts
# after every plot, faster after a clean one, and the monsoon washes more away
const PLOT_SCRUTINY_DECAY: int = 10
const CLEAN_BURN_BONUS: int = 10
## A clean burn must be a real burn: giving up a plot unburned (or barely lit)
## is not "unseen", it is a lost field (audit finding 4)
const CLEAN_BURN_MIN_YIELD: float = 60.0
const MONSOON_SCRUTINY_RELIEF: int = 45
const UPGRADE_RICE_COST: float = 10.0

# Granary rations (PRD §7.2): rice spent on the crew before a burn
enum Ration { LEAN, NORMAL, FULL }
const RATION_COST = {Ration.LEAN: 0.0, Ration.NORMAL: 3.0, Ration.FULL: 7.0}
const RATION_NAMES = {Ration.LEAN: "กินน้อย", Ration.NORMAL: "กินปกติ", Ration.FULL: "กินอิ่ม"}

# Mutual aid exchange (PRD §7.3): lend labour to a neighbouring hamlet for a favour.
# Each favour costs burn-window time the next day (you spent the morning helping).
enum Favour { SPRAYER, WATER, SEEDS }
const FAVOUR_MINUTES: int = 20
const CHECKPOINT_FAVOUR_MINUTES: int = 30

var current_year: int = 1
var current_plot_index: int = 1
var rice_barn: float = 100.0
var state_scrutiny: int = 0

# Workshop upgrades
var blade_upgrade_level: int = 0   # Sharper knives: faster firebreak clearing (player + Ta-poh)
var sprayer_upgrade_level: int = 0 # New rubber seals: more water pressure, less water per douse

# Choices made at the hearth for the next plot
var ration_level: int = Ration.NORMAL
var favours: Dictionary = {} # Favour -> true, cleared after each burn

# Forecast wind for the next plot (the radio reports it; the plot uses it)
var forecast_wind_angle: float = -PI * 0.25

# Season bookkeeping
var season_yields: Array[float] = []
var hotspot_log: Array[Dictionary] = [] # {year, plot, cell, lat, lon, heat}
var pending_harvest: Dictionary = {}    # Filled when a year completes; shown by the hearth

# Stats from last burn
var last_burn_yield: float = 0.0
var last_burn_hotspots: int = 0
var last_burn_escaped: bool = false
var last_rice_change: float = 0.0
var last_barn_target: float = 75.0
## Scrutiny the rangers let go after the last plot (shown in the report)
var last_scrutiny_relief: int = 0

# The how-to-play card opens by itself once per campaign start
var seen_how_to_play: bool = false

## Whole-campaign tallies for the run summary, records and playtest log
var stats: Dictionary = {}
## Scrutiny gained in the last plot, by source (satellite, drone, camera, escape, ranger)
var last_breakdown: Dictionary = {}

func _init() -> void:
	instance = self

func reset_campaign() -> void:
	current_year = 1
	current_plot_index = 1
	rice_barn = 100.0
	state_scrutiny = 0
	blade_upgrade_level = 0
	sprayer_upgrade_level = 0
	ration_level = Ration.NORMAL
	favours.clear()
	season_yields.clear()
	hotspot_log.clear()
	pending_harvest = {}
	last_breakdown = {}
	stats = new_stats()
	roll_forecast()

static func new_stats() -> Dictionary:
	return {
		"campaign_id": str(int(Time.get_unix_time_from_system())),
		"plots_completed": 0,
		"ash_sum": 0.0,
		"hotspots_detected": 0,
		"escapes": 0,
		"drone_photos": 0,
		"camera_trips": 0,
		"ranger_sightings": 0,
		"spot_fires": 0,
		"spot_fires_doused": 0,
	}

func rules() -> Escalation.YearRules:
	return Escalation.rules_for_year(current_year)

func plot_config() -> PlotGenerator.PlotConfig:
	return PlotGenerator.get_plot_config(current_year, current_plot_index)

func roll_forecast() -> void:
	forecast_wind_angle = randf_range(0.0, TAU)

func forecast_wind_direction() -> Vector2:
	return Vector2(cos(forecast_wind_angle), sin(forecast_wind_angle))

## scrutiny_gain is everything the burn added (drone photos, ground cameras,
## forest escape, satellite hotspots) as tallied live by MainController, so the
## in-burn HUD, the report and the campaign all agree.
## `breakdown` carries the burn's surveillance tallies from MainController:
## scrutiny by source plus counts (drone_photos, camera_trips, spot_fires, ...)
func record_plot_results(burn_yield: float, hotspots: int, escaped: bool, scrutiny_gain: int, breakdown: Dictionary = {}) -> void:
	if stats.is_empty():
		stats = new_stats()
	last_breakdown = breakdown.duplicate()
	stats.plots_completed += 1
	stats.ash_sum += burn_yield
	stats.hotspots_detected += hotspots
	stats.escapes += 1 if escaped else 0
	for key in ["drone_photos", "camera_trips", "ranger_sightings", "spot_fires", "spot_fires_doused"]:
		stats[key] += int(breakdown.get(key, 0))
	last_burn_yield = burn_yield
	last_burn_hotspots = hotspots
	last_burn_escaped = escaped
	season_yields.append(burn_yield)

	# Read before favours clear: indigenous seeds change both numbers
	last_barn_target = barn_target()
	last_rice_change = rice_change_for_yield(burn_yield)
	state_scrutiny = min(100, state_scrutiny + scrutiny_gain)
	# A crackdown stands; otherwise the rangers' attention drifts to other villages
	last_scrutiny_relief = 0
	if state_scrutiny < 100:
		var clean = scrutiny_gain == 0 and burn_yield >= CLEAN_BURN_MIN_YIELD
		var relief = PLOT_SCRUTINY_DECAY + (CLEAN_BURN_BONUS if clean else 0)
		last_scrutiny_relief = mini(relief, state_scrutiny)
		state_scrutiny -= last_scrutiny_relief
	rice_barn = clampf(rice_barn + last_rice_change, 0.0, 100.0)
	favours.clear()

## Ash-bed share that fills the barn (indigenous seeds lower it)
func barn_target() -> float:
	return 65.0 if has_favour(Favour.SEEDS) else 75.0

## Good ash beds feed the barn; poor ones mean hunger. Indigenous seeds lower the bar.
func rice_change_for_yield(burn_yield: float) -> float:
	var seeds = has_favour(Favour.SEEDS)
	if burn_yield >= barn_target():
		return 15.0 if seeds else 10.0
	elif burn_yield < 60.0:
		return -25.0
	return 0.0

func log_hotspots(cells: Array, heats: Array) -> void:
	for i in cells.size():
		var c: Vector2i = cells[i]
		var geo = cell_to_latlon(c)
		hotspot_log.append({"year": current_year, "plot": current_plot_index, "cell": c, "lat": geo.x, "lon": geo.y, "heat": heats[i]})

## Fictional plot coordinates in the Mae Chaem watershed (each cell is 1.5 m)
func cell_to_latlon(cell: Vector2i) -> Vector2:
	var base_lat = 18.4950 + current_plot_index * 0.0041 + current_year * 0.0007
	var base_lon = 98.3520 + current_plot_index * 0.0053
	return Vector2(base_lat - cell.y * 0.0000135, base_lon + cell.x * 0.0000142)

func advance_to_next_plot() -> void:
	current_plot_index += 1
	if current_plot_index > PLOTS_PER_YEAR:
		_complete_year()
	roll_forecast()

## Annual monsoon harvest (PRD §2.1): the season's ash beds decide the rice crop,
## the rains wash some scrutiny away, and next year's surveillance is announced.
func _complete_year() -> void:
	var total = 0.0
	for y in season_yields:
		total += y
	var avg = total / maxf(1.0, float(season_yields.size()))
	var rice_delta = 15.0 if avg >= 70.0 else (5.0 if avg >= 50.0 else -10.0)
	var relief = mini(MONSOON_SCRUTINY_RELIEF, state_scrutiny)
	rice_barn = clampf(rice_barn + rice_delta, 0.0, 100.0)
	state_scrutiny = maxi(0, state_scrutiny - MONSOON_SCRUTINY_RELIEF)

	pending_harvest = {
		"year": current_year,
		"yields": season_yields.duplicate(),
		"average": avg,
		"rice_delta": rice_delta,
		"scrutiny_relief": relief,
		"next_year": current_year + 1,
		"next_rules": Escalation.rules_for_year(current_year + 1).headlines(),
	}
	current_year += 1
	current_plot_index = 1
	season_yields.clear()

func is_famine() -> bool:
	return rice_barn <= FAMINE_THRESHOLD

func is_crackdown() -> bool:
	return state_scrutiny >= 100

func is_game_over() -> bool:
	return is_famine() or is_crackdown()

## "crackdown", "famine" or "" (crackdown wins if both happen at once)
func end_cause() -> String:
	if is_crackdown():
		return "crackdown"
	if is_famine():
		return "famine"
	return ""

# ---------------------------------------------------------------------------
# Save data (SaveGame writes it to user://). Only whole-campaign state at the
# Hearth is saved; a burn in progress is never saved.
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var log = []
	for e in hotspot_log:
		log.append({"year": e.year, "plot": e.plot, "cell": [e.cell.x, e.cell.y], "lat": e.lat, "lon": e.lon, "heat": e.heat})
	var harvest = pending_harvest.duplicate(true)
	if harvest.has("next_rules"):
		harvest.next_rules = Array(harvest.next_rules)
	return {
		"current_year": current_year,
		"current_plot_index": current_plot_index,
		"rice_barn": rice_barn,
		"state_scrutiny": state_scrutiny,
		"blade_upgrade_level": blade_upgrade_level,
		"sprayer_upgrade_level": sprayer_upgrade_level,
		"ration_level": ration_level,
		"favours": favours.keys(),
		"forecast_wind_angle": forecast_wind_angle,
		"season_yields": Array(season_yields),
		"hotspot_log": log,
		"pending_harvest": harvest,
		"last_burn_yield": last_burn_yield,
		"last_burn_hotspots": last_burn_hotspots,
		"last_burn_escaped": last_burn_escaped,
		"last_rice_change": last_rice_change,
		"last_barn_target": last_barn_target,
		"last_scrutiny_relief": last_scrutiny_relief,
		"seen_how_to_play": seen_how_to_play,
		"stats": stats.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	current_year = int(d.get("current_year", 1))
	current_plot_index = int(d.get("current_plot_index", 1))
	rice_barn = float(d.get("rice_barn", 100.0))
	state_scrutiny = int(d.get("state_scrutiny", 0))
	blade_upgrade_level = int(d.get("blade_upgrade_level", 0))
	sprayer_upgrade_level = int(d.get("sprayer_upgrade_level", 0))
	ration_level = int(d.get("ration_level", Ration.NORMAL))
	favours.clear()
	for f in d.get("favours", []):
		favours[int(f)] = true
	forecast_wind_angle = float(d.get("forecast_wind_angle", 0.0))
	season_yields.clear()
	for y in d.get("season_yields", []):
		season_yields.append(float(y))
	hotspot_log.clear()
	for e in d.get("hotspot_log", []):
		hotspot_log.append({"year": int(e.year), "plot": int(e.plot), "cell": Vector2i(int(e.cell[0]), int(e.cell[1])), "lat": float(e.lat), "lon": float(e.lon), "heat": float(e.heat)})
	pending_harvest = d.get("pending_harvest", {})
	if pending_harvest.has("next_rules"):
		pending_harvest.next_rules = PackedStringArray(pending_harvest.next_rules)
	for k in ["year", "next_year", "scrutiny_relief"]:
		if pending_harvest.has(k):
			pending_harvest[k] = int(pending_harvest[k])
	last_burn_yield = float(d.get("last_burn_yield", 0.0))
	last_burn_hotspots = int(d.get("last_burn_hotspots", 0))
	last_burn_escaped = bool(d.get("last_burn_escaped", false))
	last_rice_change = float(d.get("last_rice_change", 0.0))
	last_barn_target = float(d.get("last_barn_target", 75.0))
	last_scrutiny_relief = int(d.get("last_scrutiny_relief", 0))
	seen_how_to_play = bool(d.get("seen_how_to_play", true))
	stats = new_stats()
	var saved_stats: Dictionary = d.get("stats", {})
	for k in saved_stats:
		stats[k] = saved_stats[k]
	for k in stats:
		if k != "campaign_id" and k != "ash_sum":
			stats[k] = int(stats[k])

## Rice still free to spend without tipping the village into famine
func spendable_rice() -> float:
	return rice_barn - FAMINE_THRESHOLD

## Workshop purchases may not push the village into famine
func can_afford_upgrade() -> bool:
	return spendable_rice() - RATION_COST[ration_level] > UPGRADE_RICE_COST

func can_afford_ration(level: int) -> bool:
	return spendable_rice() > RATION_COST[level]

## Called when the crew marches out: eat the chosen rations
func consume_rations() -> void:
	if not can_afford_ration(ration_level):
		ration_level = Ration.LEAN
	rice_barn -= RATION_COST[ration_level]

func has_favour(f: int) -> bool:
	return favours.get(f, false)

func toggle_favour(f: int) -> void:
	if has_favour(f):
		favours.erase(f)
	else:
		favours[f] = true

func favour_minutes() -> int:
	return CHECKPOINT_FAVOUR_MINUTES if rules().checkpoints else FAVOUR_MINUTES

## In-game minutes the burn starts late because the crew lent labour
func labour_delay_minutes() -> int:
	return favours.size() * favour_minutes()
