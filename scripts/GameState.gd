extends Node

static var instance: Node

const PLOTS_PER_YEAR: int = 5
const FAMINE_THRESHOLD: float = 20.0
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
	roll_forecast()

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
func record_plot_results(burn_yield: float, hotspots: int, escaped: bool, scrutiny_gain: int) -> void:
	last_burn_yield = burn_yield
	last_burn_hotspots = hotspots
	last_burn_escaped = escaped
	season_yields.append(burn_yield)

	state_scrutiny = min(100, state_scrutiny + scrutiny_gain)
	rice_barn = clampf(rice_barn + rice_change_for_yield(burn_yield), 0.0, 100.0)
	favours.clear()

## Good ash beds feed the barn; poor ones mean hunger. Indigenous seeds lower the bar.
func rice_change_for_yield(burn_yield: float) -> float:
	var seeds = has_favour(Favour.SEEDS)
	var good_threshold = 65.0 if seeds else 75.0
	if burn_yield >= good_threshold:
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
	var relief = mini(35, state_scrutiny)
	rice_barn = clampf(rice_barn + rice_delta, 0.0, 100.0)
	state_scrutiny = maxi(0, state_scrutiny - 35)

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
