class_name FirstBurnTips
extends Node

## Contextual tips for the first burn of a campaign only (PRD_UPDATE_v1.1 P1-6).
## Turned off in settings (GameSettings.first_burn_tips) or after the first plot.

const TIPS = {
	"start": "ถางแนวกันไฟรอบแปลงก่อน · กด 2 แล้วคลิกพุ่มไม้ข้างตัว ขะแนจะคราดจนเป็นดินโล่ง",
	"dry": "เชื้อไฟแห้งแล้ว · กด 1 แล้วลากจุดไฟเป็นแนวยาวที่ตีนเนิน (ฝั่งล่างของแปลง) ไฟจะวิ่งขึ้นเนิน",
	"spot": "ลูกไฟตกในป่า! กด 3 แล้วคลิกฉีดน้ำที่ลูกไฟภายใน 8 วินาที (ถังพ่นน้ำเอื้อมได้ไกลกว่า)",
	"deadline": "เลย 17:16 แล้ว · ไฟที่ลุกจากนี้จะไม่ทันเย็นเองก่อน 20:00 ต้องฉีดน้ำทุกจุด",
	"spray": "ถึงเวลาดับถ่าน · กด 3 ฉีดน้ำถ่านคุทุกจุดให้หมดก่อน 20:00 น้ำหมดเติมที่ถังข้างเถียงนา",
}

var main: Node
var _shown: Dictionary = {}

static func wanted(state: Node) -> bool:
	GameSettings.ensure_loaded()
	return GameSettings.first_burn_tips and state.current_year == 1 and state.current_plot_index == 1 \
		and int(state.stats.get("plots_completed", 0)) == 0

func _ready() -> void:
	main.game_clock.time_ticked.connect(_on_tick)
	main.fire_grid.spot_fire_started.connect(func(_c): show_tip("spot"))
	# The burn's own intro alert comes first
	get_tree().create_timer(6.0).timeout.connect(func(): show_tip("start"))

func _on_tick(_time: String, hour: int, minute: int) -> void:
	var now = hour * 60 + minute
	if now >= 15 * 60 + 30:
		show_tip("dry")
	if now >= main.self_cool_deadline_minute():
		show_tip("deadline")
	if now >= 18 * 60 + 5:
		show_tip("spray")

func show_tip(key: String) -> void:
	if _shown.has(key) or main.get("pass_started"):
		return
	_shown[key] = true
	main.hud.show_tip(TIPS[key])
