class_name HowToPlay
extends Control

## Full-screen "how to play" card: the two goals that decide every burn, the
## ember-cooling rule, a four-step plan and the controls. Opens automatically on
## a fresh campaign and from the hearth's วิธีเล่น button.

signal closed

## In-game clock time after which new embers can no longer cool on their own
## before 20:00 (see FireGrid.smolder_duration_ticks)
const SELF_COOL_DEADLINE = "17:16"

var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	add_child(dim)

	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.STRAW, 401)
	card.padding = Vector4(26, 20, 26, 22)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(1160, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var page = UITheme.vbox(12)
	card.add_child(page)

	var head = UITheme.hbox(14)
	page.add_child(head)
	var title = UITheme.label("วิธีเล่น", "Title", UITheme.STRAW)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 30)
	head.add_child(title)
	var lead = UITheme.wrap(UITheme.label("เผาไร่ให้เป็นเถ้าระหว่าง 14:00–20:00 แล้วดับถ่านให้หมด ก่อนดาวเทียม VIIRS โคจรผ่านตอน 20:00 ทุกแปลงถูกตัดสินจากสองอย่างนี้เท่านั้น", "Body"))
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(lead)

	var cols = UITheme.hbox(16)
	page.add_child(cols)
	var left = UITheme.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right = UITheme.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	# Left: the two goals, the ember rule, how the campaign ends
	var goals = UITheme.hbox(10)
	left.add_child(goals)
	goals.add_child(_goal_tile("rice", UITheme.EMERALD, "เป้าหมาย 1 · เถ้า", "เถ้าที่เย็นแล้ว ≥75% ของแปลง",
		"≥75% ข้าวเข้ายุ้ง +10\n60–75% ข้าวเท่าเดิม\nต่ำกว่า 60% ข้าวลด −25"))
	goals.add_child(_goal_tile("satellite", UITheme.STATE, "เป้าหมาย 2 · ความร้อน", "จุดร้อน 0 จุดตอน 20:00",
		"ถ่านที่ยังคุทุกจุด = จุดร้อน\nถูกจับได้ +15 ความเพ่งเล็ง (ร้อนมากจุด สูงสุด +30)\n(ปีหลัง ๆ โทษหนักขึ้น)"))

	var rule = UITheme.card(Color(UITheme.CLAY.darkened(0.55), 0.95), UITheme.EMBER, 402)
	rule.padding = Vector4(16, 10, 16, 12)
	left.add_child(rule)
	var rb = UITheme.vbox(4)
	rule.add_child(rb)
	rb.add_child(UITheme.header("flame", "กฎของถ่าน · สำคัญที่สุด", UITheme.EMBER))
	rb.add_child(UITheme.wrap(UITheme.label("ไฟลุกราว 6 วินาที แล้วกลายเป็นถ่านคุ ถ่านเย็นเป็นเถ้าเองต้องใช้ราว 4 นาที (2 ชม. 40 นาทีในเกม)", "Small", UITheme.CREAM)))
	rb.add_child(UITheme.wrap(UITheme.label("ไฟที่ลุกหลัง %s จะยังร้อนตอน 20:00 ต้องฉีดน้ำ" % SELF_COOL_DEADLINE, "Body", UITheme.STRAW)))
	rb.add_child(UITheme.wrap(UITheme.label("ฉีดน้ำใส่ถ่านคุ = เป็นเถ้าทันที (ได้เถ้าและไม่มีจุดร้อน)\nอย่าฉีดเปลวไฟที่เพิ่งติด ไฟจะดับกลับเป็นพุ่มไม้ ไม่ได้เถ้า\nลูกไฟตกในป่าอุทยาน = มีเวลา 8 วินาทีให้ฉีดดับ ไม่งั้นนับว่าไฟลามเข้าป่า", "Small", UITheme.CREAM)))

	var lose = UITheme.card(Color(UITheme.INK, 0.7), UITheme.RUBY, 403)
	lose.padding = Vector4(16, 10, 16, 12)
	left.add_child(lose)
	var lb = UITheme.vbox(4)
	lose.add_child(lb)
	lb.add_child(UITheme.header("eye", "แพ้เมื่อไร", UITheme.RUBY))
	lb.add_child(UITheme.wrap(UITheme.label("ข้าวในยุ้งเหลือ 20% = หมู่บ้านอดอยาก · ความเพ่งเล็งถึง 100 = รัฐบุกหมู่บ้าน\nเล่นให้รอดไปทีละปี ปีละ 5 แปลง เผาสะอาด (เถ้า ≥60% และไม่ถูกจับได้) ความเพ่งเล็งลด 20 · เผาแปลงอื่นลด 10 · ฝนมรสุมลด 45 ทุกปี", "Small", UITheme.CREAM)))

	# Right: plan and controls
	var plan = UITheme.card(Color(UITheme.PANEL_HI, 0.9), UITheme.STRAW, 404)
	plan.padding = Vector4(16, 10, 16, 12)
	right.add_child(plan)
	var pb = UITheme.vbox(6)
	plan.add_child(pb)
	pb.add_child(UITheme.header("clock", "แผนที่ได้ผล", UITheme.STRAW))
	_step(pb, "14:00–15:30", "เชื้อไฟยังชื้น ไฟลามช้า ใช้เวลานี้ถางแนวกันไฟ (ปุ่ม 2 กดค้างทีละช่อง) รอบแปลง ฝั่งใต้ลมให้หนา 2 ช่อง")
	_step(pb, "15:30–%s" % SELF_COOL_DEADLINE, "เชื้อไฟแห้งสุด จุดไฟเป็นแนวยาว (ปุ่ม 1 ลากค้าง) ที่ตีนเนิน ไฟจะวิ่งขึ้นเนินและตามลม จุดจุดเดียวไฟไม่ทั่วแปลง · ปีที่ 2 ขึ้นไปมีโดรน: บินมาราว 45 วิ ถ่ายรูปได้ครั้งเดียว แล้วกลับไปเปลี่ยนแบต ให้จุดไฟตอนโดรนไม่อยู่ และหลบใต้ร่มไผ่หรือชายป่าตอนโดรนหรือเจ้าหน้าที่มา")
	_step(pb, "18:00–20:00", "ถังพ่นน้ำ (ปุ่ม 3) ฉีดถ่านคุทุกจุด น้ำหมดให้เติมที่ถังข้างเถียงนา")
	_step(pb, "ก่อน 20:00", "ดูช่องเป้าหมายบนจอ ให้จุดร้อนเหลือ 0 และเถ้าถึง 75%")

	var keys = UITheme.card(Color(UITheme.PANEL_HI, 0.9), UITheme.CREAM, 405)
	keys.padding = Vector4(16, 10, 16, 12)
	right.add_child(keys)
	var kb = UITheme.vbox(5)
	keys.add_child(kb)
	kb.add_child(UITheme.header("crew", "ปุ่มควบคุม (คีย์บอร์ด / จอย)", UITheme.CREAM))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	kb.add_child(grid)
	for row in [
		["WASD / สติ๊กซ้าย", "เดิน"],
		["เมาส์ / สติ๊กขวา", "เล็งช่องที่จะทำงาน"],
		["คลิกซ้าย / RT, A", "ใช้เครื่องมือ"],
		["1 2 3 / ปุ่มลูกศร, Y", "จุดไฟ · ถางแนว · พ่นน้ำ"],
		["คลิกขวา / LT, X", "สั่งตาโพถางพุ่มไม้ · สั่งมูนอดับถ่าน"],
		["Space, Q / LB, RB", "เป่านกหวีดเรียกทีมหนีควัน"],
		["ล้อเมาส์, + - / R3", "ซูมกล้อง (ซูมออกสุดเห็นทั้งแปลงและหุบเขา)"],
		["Z, C / ลูกศรลง", "หมุนกล้องทีละ 90°"],
		["Tab / Select", "ซ่อน / แสดงแผงข้อมูล"],
	]:
		grid.add_child(UITheme.label(row[0], "Small", UITheme.STRAW))
		grid.add_child(UITheme.label(row[1], "Small", UITheme.CREAM))

	var foot = UITheme.hbox(0)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(foot)
	close_button = Button.new()
	close_button.theme_type_variation = "PrimaryButton"
	close_button.text = "เข้าใจแล้ว"
	close_button.custom_minimum_size = Vector2(320, 48)
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	close_button.grab_focus()

func _goal_tile(kind: String, tint: Color, kicker: String, goal: String, detail: String) -> FacetCard:
	var tile = UITheme.card(Color(UITheme.PANEL_HI, 0.92), tint, 410 + kind.length())
	tile.padding = Vector4(14, 10, 14, 12)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = UITheme.vbox(4)
	tile.add_child(b)
	b.add_child(UITheme.header(kind, kicker, tint))
	var g = UITheme.wrap(UITheme.label(goal, "Title", tint))
	g.add_theme_font_size_override("font_size", 18)
	b.add_child(g)
	b.add_child(UITheme.label(detail, "Small", UITheme.CREAM))
	return tile

func _step(parent: Control, when: String, what: String) -> void:
	var row = UITheme.hbox(12)
	parent.add_child(row)
	var t = UITheme.label(when, "Small", UITheme.STRAW)
	t.add_theme_font_override("font", UITheme.font("semibold"))
	t.custom_minimum_size = Vector2(108, 0)
	row.add_child(t)
	var d = UITheme.wrap(UITheme.label(what, "Small", UITheme.CREAM))
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(d)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	closed.emit()
	queue_free()
