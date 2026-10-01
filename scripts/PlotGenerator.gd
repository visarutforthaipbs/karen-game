class_name PlotGenerator
extends RefCounted

enum TerrainStyle { GENTLE, GROVE, RIDGE, PARK_EDGE, TERRACE, HIGH_RIDGE }

# Configuration for a specific hillside plot in a season
class PlotConfig:
	var name: String = "ไร่ต่ำ"
	var description: String = "ลาดชันน้อย พุ่มไม้เบาบาง การเฝ้าระวังน้อย"
	var slope_intensity: float = 1.0
	var bamboo_ratio: float = 0.15
	var wind_base_speed: float = 1.0
	var has_drone: bool = false # Plot is on a drone route (actual count comes from the year rules)
	var national_park_strictness: float = 1.0 # Multiplier for forest border penalties

	# Procedural hillside shape
	var terrain_style: int = TerrainStyle.GENTLE
	var terrain_seed: int = 0
	var border_depth: Dictionary = {"north": 2, "east": 2, "south": 2, "west": 2}
	var wind_shift_interval: Vector2 = Vector2(50.0, 85.0) # Real seconds between valley wind shifts
	var storm_front: bool = false

	# Year escalation
	var rules: Escalation.YearRules
	var drone_count: int = 0

	## Total uphill rise of the hillside in metres
	func terrain_rise() -> float:
		return 4.0 + 2.5 * slope_intensity

	## Typical uphill spread multiplier (matches FireGrid's slope factor on the average grade)
	func uphill_spread_factor() -> float:
		var grade = terrain_rise() / 60.0
		return clampf(1.0 + grade * FireGrid.SLOPE_GRADE_GAIN, 0.4, FireGrid.MAX_SLOPE_FACTOR)

static func get_plot_config(year: int, plot_index: int) -> PlotConfig:
	var config = PlotConfig.new()
	var escalation = float(year - 1) * 0.2
	config.terrain_seed = year * 101 + plot_index * 7

	match plot_index:
		1:
			config.name = "แปลงที่ 1: ไร่ต่ำ"
			config.description = "ลาดชันน้อย พุ่มไม้เบาบาง ลมหุบเขาอ่อน ยังไม่มีรายงานโดรนลาดตระเวน"
			config.slope_intensity = 0.8 + escalation
			config.bamboo_ratio = 0.12
			config.wind_base_speed = 1.0
			config.has_drone = (year >= 2) # Drones appear on plot 1 only in Year 2+
			config.national_park_strictness = 1.0
			config.terrain_style = TerrainStyle.GENTLE
		2:
			config.name = "แปลงที่ 2: ป่าไผ่ซาง"
			config.description = "กอไผ่หนาแน่น ปล้องไผ่อัดไอน้ำพร้อมระเบิด เสี่ยงลูกไฟกระเด็นสูง"
			config.slope_intensity = 1.3 + escalation
			config.bamboo_ratio = 0.45
			config.wind_base_speed = 1.2
			config.has_drone = true
			config.national_park_strictness = 1.1
			config.terrain_style = TerrainStyle.GROVE
		3:
			config.name = "แปลงที่ 3: สันดอยลมแรง"
			config.description = "สันดอยชันรับลมภูเขาที่แปรปรวน ไฟวิ่งขึ้นเนินเร็วมาก"
			config.slope_intensity = 2.0 + escalation
			config.bamboo_ratio = 0.20
			config.wind_base_speed = 1.6 + escalation
			config.has_drone = true
			config.national_park_strictness = 1.2
			config.terrain_style = TerrainStyle.RIDGE
			config.wind_shift_interval = Vector2(30.0, 55.0)
		4:
			config.name = "แปลงที่ 4: แนวป่าอุทยาน"
			config.description = "ติดป่าอนุรักษ์โดยตรง ลูกไฟหลุดเข้าไปแม้ลูกเดียว เจ้าหน้าที่บุกทันที"
			config.slope_intensity = 2.2 + escalation
			config.bamboo_ratio = 0.25
			config.wind_base_speed = 1.3
			config.has_drone = true
			config.national_park_strictness = 2.0 # Double penalty!
			config.terrain_style = TerrainStyle.PARK_EDGE
			# The protected forest covers the whole upper slope
			config.border_depth = {"north": 7, "east": 2, "south": 2, "west": 3}
		5:
			config.name = "แปลงที่ 5: โค้งสุดท้ายก่อนมรสุม"
			config.description = "แปลงสุดท้ายของฤดู ลาดชันสุดขีด เมฆฝนตั้งเค้า เผาให้สะอาด ไม่อย่างนั้นอดตาย"
			config.slope_intensity = 2.6 + escalation
			config.bamboo_ratio = 0.30
			config.wind_base_speed = 1.8 + escalation
			config.has_drone = true
			config.national_park_strictness = 1.5
			config.terrain_style = TerrainStyle.TERRACE
			config.wind_shift_interval = Vector2(35.0, 60.0)
			config.storm_front = true
		_:
			config.name = "ดอยสูงนิรันดร์"
			config.description = "ดินแดนแห่งการเอาชีวิตรอด ภูมิอากาศสุดขั้วและเครือข่ายเซนเซอร์ดาวเทียมครบชุด"
			config.slope_intensity = 2.5 + escalation
			config.bamboo_ratio = 0.35
			config.wind_base_speed = 1.8 + escalation
			config.has_drone = true
			config.national_park_strictness = 2.0
			config.terrain_style = TerrainStyle.HIGH_RIDGE
			config.border_depth = {"north": 4, "east": 3, "south": 2, "west": 3}
			config.wind_shift_interval = Vector2(30.0, 55.0)

	config.rules = Escalation.rules_for_year(year)
	config.drone_count = config.rules.drone_count if config.has_drone else 0
	return config
