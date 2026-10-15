class_name HowToPlay
extends Control

## Full-screen "how to play" card: the two goals that decide every burn, the
## ember-cooling rule, a four-step plan and the controls. Opens automatically on
## a fresh campaign and from the hearth's วิธีเล่น button.
## Touch devices read it as four pages (owner-approved V1, 2026-10-13) with a
## Previous / Next pager and an "n / 4" indicator; every page fits 1280x720 and
## the acknowledge button stays on screen. Desktop keeps the single scrolling
## layout, its two reading columns and keyboard scrolling.

signal closed

## In-game clock time after which new embers can no longer cool on their own
## before 20:00 (see FireGrid.smolder_duration_ticks)
const SELF_COOL_DEADLINE = "17:16"

var close_button: Button
var replay_button: Button
var _opening: OpeningFilm
var guide_card: FacetCard
var guide_scroll: ScrollContainer
var guide_columns: GridContainer
var controls_grid: GridContainer
var _focus_scope: ModalFocusScope

## Touch pager (V1). Empty / null on desktop.
var pages: Array = []
var pages_stack: VBoxContainer
var page_indicator: Label
var prev_button: Button
var next_button: Button
var _page_index: int = 0
var _swipe_start_x: float = 0.0

## The controls card swaps its table on touch devices (rows are built in
## _ready, where the OS-dependent keyboard row can be evaluated).
const KEYBOARD_HEADER = "ปุ่มควบคุม (คีย์บอร์ด / จอย)"
const TOUCH_HEADER = "ปุ่มควบคุม (หน้าจอสัมผัส)"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.78)
	add_child(dim)

	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.STRAW, 401)
	guide_card = card
	card.padding = Vector4(26, 20, 26, 22)
	card.chamfer = 16.0
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(1160, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var shell = UITheme.vbox(12)
	card.add_child(shell)
	if UITheme.is_mobile():
		_build_touch_pages(shell)
	else:
		# Longer English instructions scroll without pushing the close button off screen.
		_build_desktop_body(shell)

	var foot = UITheme.hbox(0)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(foot)
	replay_button = Button.new()
	replay_button.text = "ดูเรื่องราวก่อนลงไร่อีกครั้ง"
	replay_button.custom_minimum_size = Vector2(0, 48)
	replay_button.pressed.connect(_replay_opening)
	foot.add_child(replay_button)
	close_button = Button.new()
	close_button.theme_type_variation = "PrimaryButton"
	close_button.text = "เข้าใจแล้ว"
	close_button.custom_minimum_size = Vector2(320, 48)
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	if UITheme.is_mobile():
		# The pager joins the footer cycle: prev -> next -> close -> replay.
		prev_button.focus_next = prev_button.get_path_to(next_button)
		prev_button.focus_previous = prev_button.get_path_to(replay_button)
		next_button.focus_next = next_button.get_path_to(close_button)
		next_button.focus_previous = next_button.get_path_to(prev_button)
		close_button.focus_next = close_button.get_path_to(replay_button)
		close_button.focus_previous = close_button.get_path_to(next_button)
		replay_button.focus_next = replay_button.get_path_to(prev_button)
		replay_button.focus_previous = replay_button.get_path_to(close_button)
	else:
		guide_scroll.focus_next = guide_scroll.get_path_to(close_button)
		guide_scroll.focus_previous = guide_scroll.get_path_to(replay_button)
		close_button.focus_next = close_button.get_path_to(replay_button)
		close_button.focus_previous = close_button.get_path_to(guide_scroll)
		replay_button.focus_next = replay_button.get_path_to(guide_scroll)
		replay_button.focus_previous = replay_button.get_path_to(close_button)
	get_viewport().size_changed.connect(_fit_layout)
	if UITheme.is_mobile() and get_tree() != null:
		# A page's wrapped text only resolves its minimum height once the
		# layout pass has given it a width, so keep re-hugging the canvas.
		get_tree().process_frame.connect(_fit_layout)
	UITheme.apply_safe_area(self)
	_fit_layout()
	UITheme.apply_touch_targets(self)
	_focus_scope = ModalFocusScope.begin(self)
	close_button.grab_focus()

## Title + lead line; the touch pager keeps it above the pages, desktop scrolls
## it with the rest of the card.
func _build_head() -> HBoxContainer:
	var head = UITheme.hbox(14)
	var title = UITheme.label("วิธีเล่น", "Title", UITheme.STRAW)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", UITheme.fs(30))
	head.add_child(title)
	var lead = UITheme.wrap(UITheme.label("เผาไร่ให้เป็นเถ้าระหว่าง 14:00–20:00 แล้วดับถ่านให้หมด ก่อนดาวเทียม VIIRS โคจรผ่านตอน 20:00 ทุกแปลงถูกตัดสินจากสองอย่างนี้เท่านั้น", "Body"))
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(lead)
	return head

## Desktop: the original scroll region, two reading columns and card order.
func _build_desktop_body(shell: VBoxContainer) -> void:
	var scroll = ScrollContainer.new()
	guide_scroll = scroll
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_on_scroll_input)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = minf(560.0, get_viewport().get_visible_rect().size.y - 156.0)
	shell.add_child(scroll)
	var page = UITheme.vbox(12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	page.add_child(_build_head())

	var cols = GridContainer.new()
	guide_columns = cols
	cols.columns = 2
	cols.add_theme_constant_override("h_separation", 16)
	cols.add_theme_constant_override("v_separation", 16)
	page.add_child(cols)
	var left = UITheme.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right = UITheme.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)

	# Left: the two goals, the ember rule, how the campaign ends
	left.add_child(_build_goals())
	left.add_child(_build_rule_card())
	left.add_child(_build_lose_card())

	# Right: plan and controls
	right.add_child(_build_plan_card())
	right.add_child(_build_keys_card())

## Touch: four pages, one per screen, none of them scrolled. The pages stay in
## the tree together so hidden sections (and the controls table) remain
## reachable while only the current one shows.
func _build_touch_pages(shell: VBoxContainer) -> void:
	shell.add_child(_build_head())
	var area = UITheme.safe_area_rect().size
	var stack = UITheme.vbox(12)
	pages_stack = stack
	stack.name = "Pages"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size.y = maxf(220.0, area.y - 340.0)
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.gui_input.connect(_on_page_swipe)
	shell.add_child(stack)
	for i in 4:
		var page = UITheme.vbox(12)
		page.name = "Page%d" % (i + 1)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		pages.append(page)

	# Page 1: the two goals. Page 2: the ember rule and when you lose.
	# Page 3: the plan that works. Page 4: the controls.
	pages[0].add_child(_build_goals())
	var ember_row = UITheme.hbox(16)
	ember_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ember_row.add_child(_build_rule_card())
	ember_row.add_child(_build_lose_card())
	pages[1].add_child(ember_row)
	pages[2].add_child(_build_plan_card())
	pages[3].add_child(_build_keys_card())

	var pager = UITheme.hbox(10)
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_button = Button.new()
	prev_button.name = "PrevButton"
	prev_button.text = "ก่อนหน้า"
	prev_button.custom_minimum_size = Vector2(200, UITheme.TOUCH_MIN)
	prev_button.pressed.connect(func(): _show_page(_page_index - 1))
	pager.add_child(prev_button)
	page_indicator = UITheme.label("1 / 4", "Body", UITheme.STRAW)
	page_indicator.name = "PageIndicator"
	page_indicator.custom_minimum_size = Vector2(80, 0)
	page_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_indicator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pager.add_child(page_indicator)
	next_button = Button.new()
	next_button.name = "NextButton"
	next_button.text = "ถัดไป"
	next_button.custom_minimum_size = Vector2(200, UITheme.TOUCH_MIN)
	next_button.pressed.connect(func(): _show_page(_page_index + 1))
	pager.add_child(next_button)
	shell.add_child(pager)
	_show_page(0)

func _show_page(index: int) -> void:
	if pages.is_empty():
		return
	_page_index = posmod(index, pages.size())
	for i in pages.size():
		pages[i].visible = i == _page_index
	page_indicator.text = "%d / %d" % [_page_index + 1, pages.size()]

## A horizontal finger swipe across the page area turns the page; a plain tap
## (or a vertical drag) does nothing.
func _on_page_swipe(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var finger := event as InputEventScreenTouch
	if finger.pressed:
		_swipe_start_x = finger.position.x
	elif absf(finger.position.x - _swipe_start_x) >= 72.0:
		_show_page(_page_index + (1 if finger.position.x < _swipe_start_x else -1))

func _build_goals() -> HBoxContainer:
	var goals = UITheme.hbox(10)
	goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals.add_child(_goal_tile("rice", UITheme.EMERALD, "เป้าหมาย 1 · เถ้า", "เถ้าที่เย็นแล้ว ≥75% ของแปลง",
		"≥75% ข้าวเข้ายุ้ง +10\n60–75% ข้าวเท่าเดิม\nต่ำกว่า 60% ข้าวลด −25"))
	goals.add_child(_goal_tile("satellite", UITheme.STATE, "เป้าหมาย 2 · ความร้อน", "จุดร้อน 0 จุดตอน 20:00",
		"ถ่านที่ยังคุทุกจุด = จุดร้อน\nถูกจับได้ +15 ความเพ่งเล็ง (ร้อนมากจุด สูงสุด +30)\n(ปีหลัง ๆ โทษหนักขึ้น)"))
	return goals

func _build_rule_card() -> FacetCard:
	var rule = UITheme.card(Color(UITheme.CLAY.darkened(0.55), 0.95), UITheme.EMBER, 402)
	rule.padding = Vector4(16, 10, 16, 12)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rb = UITheme.vbox(4)
	rule.add_child(rb)
	rb.add_child(UITheme.header("flame", "กฎของถ่าน · สำคัญที่สุด", UITheme.EMBER))
	rb.add_child(UITheme.wrap(UITheme.label("ไฟลุกราว 6 วินาที แล้วกลายเป็นถ่านคุ ถ่านเย็นเป็นเถ้าเองต้องใช้ราว 4 นาที (2 ชม. 40 นาทีในเกม)", "Small", UITheme.CREAM)))
	rb.add_child(UITheme.wrap(UITheme.label(L10n.format("ไฟที่ลุกหลัง %s จะยังร้อนตอน 20:00 ต้องฉีดน้ำ", SELF_COOL_DEADLINE), "Body", UITheme.STRAW)))
	rb.add_child(UITheme.wrap(UITheme.label("ฉีดน้ำใส่ถ่านคุ = เป็นเถ้าทันที (ได้เถ้าและไม่มีจุดร้อน)\nอย่าฉีดเปลวไฟที่เพิ่งติด ไฟจะดับกลับเป็นพุ่มไม้ ไม่ได้เถ้า\nลูกไฟตกในป่าอุทยาน = มีเวลา 8 วินาทีให้ฉีดดับ ไม่งั้นนับว่าไฟลามเข้าป่า", "Small", UITheme.CREAM)))
	return rule

func _build_lose_card() -> FacetCard:
	var lose = UITheme.card(Color(UITheme.INK, 0.7), UITheme.RUBY, 403)
	lose.padding = Vector4(16, 10, 16, 12)
	lose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb = UITheme.vbox(4)
	lose.add_child(lb)
	lb.add_child(UITheme.header("eye", "แพ้เมื่อไร", UITheme.RUBY))
	lb.add_child(UITheme.wrap(UITheme.label("ข้าวในยุ้งเหลือ 20% = หมู่บ้านอดอยาก · ความเพ่งเล็งถึง 100 = รัฐบุกหมู่บ้าน\nเล่นให้รอดไปทีละปี ปีละ 5 แปลง เผาสะอาด (เถ้า ≥60% และไม่ถูกจับได้) ความเพ่งเล็งลด 20 · เผาแปลงอื่นลด 10 · ฝนมรสุมลด 45 ทุกปี", "Small", UITheme.CREAM)))
	return lose

func _build_plan_card() -> FacetCard:
	var plan = UITheme.card(Color(UITheme.PANEL_HI, 0.9), UITheme.STRAW, 404)
	plan.padding = Vector4(16, 10, 16, 12)
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pb = UITheme.vbox(6)
	plan.add_child(pb)
	pb.add_child(UITheme.header("clock", "แผนที่ได้ผล", UITheme.STRAW))
	_step(pb, "14:00–15:30", "เชื้อไฟยังชื้น ไฟลามช้า ใช้เวลานี้ถางแนวกันไฟ (ปุ่ม 2 กดค้างทีละช่อง) รอบแปลง ฝั่งใต้ลมให้หนา 2 ช่อง")
	_step(pb, "15:30–%s" % SELF_COOL_DEADLINE, "เชื้อไฟแห้งสุด จุดไฟเป็นแนวยาว (ปุ่ม 1 ลากค้าง) ที่ตีนเนิน ไฟจะวิ่งขึ้นเนินและตามลม จุดจุดเดียวไฟไม่ทั่วแปลง · ปีที่ 2 ขึ้นไปมีโดรน: บินมาราว 45 วิ ถ่ายรูปได้ครั้งเดียว แล้วกลับไปเปลี่ยนแบต ให้จุดไฟตอนโดรนไม่อยู่ และหลบใต้ร่มไผ่หรือชายป่าตอนโดรนหรือเจ้าหน้าที่มา")
	_step(pb, "18:00–20:00", "ถังพ่นน้ำ (ปุ่ม 3) ฉีดถ่านคุทุกจุด น้ำเติมที่ถังข้างเถียงนา · ลมหายใจฟื้นเมื่อออกจากควันและควันสะสมลดลง")
	_step(pb, "ก่อน 20:00", "ดูช่องเป้าหมายบนจอ ให้จุดร้อนเหลือ 0 และเถ้าถึง 75%")
	return plan

func _build_keys_card() -> FacetCard:
	var keys = UITheme.card(Color(UITheme.PANEL_HI, 0.9), UITheme.CREAM, 405)
	keys.padding = Vector4(16, 10, 16, 12)
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kb = UITheme.vbox(5)
	keys.add_child(kb)
	kb.add_child(UITheme.header("crew", TOUCH_HEADER if UITheme.is_mobile() else KEYBOARD_HEADER, UITheme.CREAM))
	var grid = GridContainer.new()
	controls_grid = grid
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	kb.add_child(grid)
	# Touch has no keyboard: left thumb walks, the field takes the tool, the
	# right-hand buttons arm the rest (one arm-then-tap pair for ping orders).
	# Names match the right-hand button captions exactly (0.3.3).
	var rows: Array = [[
		"จอยสัมผัสฝั่งซ้าย", "เดิน"], [
		"แตะ / ลากบนแปลง", "ใช้เครื่องมือที่ถืออยู่ · แตะเพื่อตัดหนึ่งช่อง ลากเพื่อถางเป็นแนว"], [
		"ปุ่ม จุดไฟ · ถางแนว · พ่นน้ำ", "เลือกเครื่องมือที่จะใช้"], [
		"ปุ่ม สั่งงาน", "แตะปุ่มก่อน แล้วแตะช่อง: พุ่มไม้ = ส่งตาโพถาง · ถ่านแดง = ส่งมูนอดับ"], [
		"ปุ่ม นกหวีด", "เป่านกหวีดเรียกทีมหนีควัน"], [
		"ปุ่ม ซูม · หมุน · หยุด", "ซูมกล้อง · หมุนกล้องทีละ 90° · หยุดเกมชั่วคราว"],
	] if UITheme.is_mobile() else [
		["WASD / สติ๊กซ้าย", "เดิน"],
		["เมาส์ / สติ๊กขวา", "เล็งช่องที่จะทำงาน"],
		["คลิกซ้าย / RT, A", "ใช้เครื่องมือ"],
		["1 2 3 / ปุ่มลูกศร, Y", "จุดไฟ · ถางแนว · พ่นน้ำ"],
		["⌘W / ⌘Q" if OS.get_name() == "macOS" else "Alt+F4", "ออกจากเกม · กลับมาเล่นจากบันทึกล่าสุด"],
		["คลิกขวา / LT, X", "สั่งตาโพถางพุ่มไม้ · สั่งมูนอดับถ่าน"],
		["Space, Q / LB, RB", "เป่านกหวีดเรียกทีมหนีควัน"],
		["ล้อเมาส์, + - / R3", "ซูมกล้อง (ซูมออกสุดเห็นทั้งแปลงและหุบเขา)"],
		["Z, C / ลูกศรลง", "หมุนกล้องทีละ 90°"],
		["Tab / Select", "ซ่อน / แสดงแผงข้อมูล"],
	]
	for row in rows:
		var key = UITheme.wrap(UITheme.label(row[0], "Small", UITheme.STRAW))
		key.custom_minimum_size.x = 270 if UITheme.is_mobile() else 140
		grid.add_child(key)
		var meaning = UITheme.wrap(UITheme.label(row[1], "Small", UITheme.CREAM))
		meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(meaning)
	return keys

func _goal_tile(kind: String, tint: Color, kicker: String, goal: String, detail: String) -> FacetCard:
	var tile = UITheme.card(Color(UITheme.PANEL_HI, 0.92), tint, 410 + kind.length())
	tile.padding = Vector4(14, 10, 14, 12)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b = UITheme.vbox(4)
	tile.add_child(b)
	b.add_child(UITheme.header(kind, kicker, tint))
	var g = UITheme.wrap(UITheme.label(goal, "Title", tint))
	g.add_theme_font_size_override("font_size", UITheme.fs(18))
	b.add_child(g)
	b.add_child(UITheme.wrap(UITheme.label(detail, "Small", UITheme.CREAM)))
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

## Larger UI text reduces the logical viewport; stack the two reading columns
## and keep the fixed footer inside the screen without shrinking the text.
## Touch pages never scroll: the card hugs the canvas instead.
func _fit_layout() -> void:
	if not is_instance_valid(guide_card):
		return
	# Centred inside the notch-safe rectangle, not the raw window.
	var area = UITheme.safe_area_rect().size
	var width = minf(1160.0, area.x - 48.0)
	guide_card.custom_minimum_size.x = width
	if UITheme.is_mobile():
		if is_instance_valid(pages_stack):
			pages_stack.custom_minimum_size.y = maxf(220.0, area.y - 340.0)
		guide_card.reset_size()
		guide_card.position = (area - guide_card.size) * 0.5
		return
	guide_columns.columns = 1 if width < 1080.0 else 2
	guide_scroll.custom_minimum_size.y = maxf(160.0, minf(560.0, area.y - 156.0))
	# Explicit bounds avoid stale center-anchor offsets when the UI scale
	# changes; the content minimum keeps a touch-sized footer inside the slab.
	guide_card.size = Vector2(width, maxf(guide_scroll.custom_minimum_size.y + 102.0, guide_card.get_combined_minimum_size().y))
	guide_card.position = (area - guide_card.size) * 0.5

## Tab/D-pad focus can enter the guide; arrows and page keys scroll its text.
func _on_scroll_input(event: InputEvent) -> void:
	var step = 0
	if event.is_action_pressed("ui_down"):
		step = 48
	elif event.is_action_pressed("ui_up"):
		step = -48
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_PAGEDOWN:
			step = int(guide_scroll.size.y * 0.8)
		elif event.keycode == KEY_PAGEUP:
			step = -int(guide_scroll.size.y * 0.8)
		elif event.keycode == KEY_END:
			step = int(guide_scroll.get_v_scroll_bar().max_value)
		elif event.keycode == KEY_HOME:
			step = -int(guide_scroll.get_v_scroll_bar().max_value)
	if step != 0:
		guide_scroll.scroll_vertical += step
		guide_scroll.accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_opening):
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if _focus_scope:
		_focus_scope.release()
	closed.emit()
	queue_free()

func _replay_opening() -> void:
	if is_instance_valid(_opening):
		return
	_opening = OpeningFilm.new()
	_opening.closed.connect(func(): _opening = null)
	add_child(_opening)
