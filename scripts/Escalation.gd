class_name Escalation
extends RefCounted

## Year-over-year surveillance & climate escalation (PRD §8.2)

class YearRules:
	var year: int = 1
	var drone_count: int = 0             # Forestry quadcopters in the air on drone-eligible plots
	var drone_speed_mult: float = 1.0    # Year 4+: high-speed quadcopters
	var spread_mult: float = 1.0         # Regional drought makes fire run faster
	var satellite_threshold: float = 35.0 # VIIRS detection threshold (thermal units)
	var hotspot_penalty: int = 15        # Scrutiny when the satellite detects the burn (up to 2x for many hot cells)
	var ground_cameras: int = 0          # Thermal cameras along the National Park boundary
	var ranger_count: int = 0            # Rangers on foot around the plot, 15:30-18:30 (Year 3+)
	var checkpoints: bool = false        # Military roadblocks slow mutual-aid travel
	var curfew: bool = false             # Zero-tolerance nighttime curfew
	var penalty_mult: float = 1.0        # Ranger leniency for drone / camera / escape penalties
	var humidity_pct: int = 22           # Radio weather flavour, drops with drought

	## Short bullet lines for the radio and the harvest screen
	func headlines() -> PackedStringArray:
		var lines = PackedStringArray()
		if drone_count == 0:
			lines.append("ยังไม่มีโดรนป่าไม้ประจำลุ่มน้ำนี้")
		elif drone_count == 1:
			lines.append("โดรนป่าไม้ 1 ลำลาดตระเวนหุบเขาช่วงกลางวัน")
		else:
			lines.append("โดรนป่าไม้ %d ลำบินลาดตระเวนประสานกัน%s" % [drone_count, " ด้วยความเร็วสูง" if drone_speed_mult > 1.0 else ""])
		if spread_mult > 1.0:
			lines.append("ภัยแล้งทั้งภูมิภาค: ไฟลามเร็วขึ้น %d%% (ความชื้น %d%%)" % [roundi((spread_mult - 1.0) * 100.0), humidity_pct])
		lines.append("เกณฑ์ตรวจจับของ VIIRS: %d หน่วยความร้อน (TU)" % roundi(satellite_threshold))
		if ground_cameras > 0:
			lines.append("กล้องความร้อนภาคพื้น %d ตัวเฝ้าแนวเขตอุทยาน" % ground_cameras)
		if ranger_count > 0:
			lines.append("เจ้าหน้าที่ป่าไม้ %d นายเดินตรวจแนวป่ารอบแปลง 15:30–18:30" % ranger_count)
		if checkpoints:
			lines.append("ด่านทหารบนถนน: ไปเอาแรงต้องใช้เวลามากขึ้น")
		if curfew:
			lines.append("เคอร์ฟิวไม่ผ่อนผัน: ถ้าดาวเทียมจับได้ ความเพ่งเล็งเพิ่ม %d–%d" % [hotspot_penalty, hotspot_penalty * 2])
		if penalty_mult < 1.0:
			lines.append("ปีนี้เจ้าหน้าที่ยังผ่อนปรนอยู่")
		return lines

static func rules_for_year(year: int) -> YearRules:
	var r = YearRules.new()
	r.year = year
	match year:
		1:
			# Baseline VIIRS pass, lenient rangers, standard rainfall
			r.penalty_mult = 0.75
		2:
			# Single daytime drone, drought speeds fire by 25%; rangers still a little lenient
			r.drone_count = 1
			r.penalty_mult = 0.9
			r.spread_mult = 1.25
			r.humidity_pct = 18
		3:
			# Dual drones, park-boundary ground cameras, threshold lowered to 25
			r.drone_count = 2
			r.spread_mult = 1.30
			r.satellite_threshold = 25.0
			# A ranger on foot replaces one of two posts (campaign balance, PRD_UPDATE_v1.1 P1-2)
			r.ground_cameras = 1
			r.ranger_count = 1
			r.humidity_pct = 16
		_:
			# Year 4+: checkpoints, fast quadcopters, curfew; keeps getting harsher
			var extra = year - 4
			r.drone_count = 2
			r.drone_speed_mult = 1.6 + 0.1 * extra
			r.spread_mult = minf(1.35 + 0.05 * extra, 1.6)
			r.satellite_threshold = 25.0
			r.ground_cameras = 3
			r.ranger_count = 2
			r.checkpoints = true
			r.curfew = true
			r.hotspot_penalty = 30
			r.penalty_mult = 1.25
			r.humidity_pct = maxi(14 - extra, 9)
	return r
