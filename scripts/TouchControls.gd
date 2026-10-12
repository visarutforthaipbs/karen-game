extends CanvasLayer

## Explicit touch controls for the iPhone / iPad landscape port.
##
## Two-thumb play: a dynamic joystick appears where the left thumb lands and
## drives the move_* actions; any other free touch on the world aims the tool
## and holds use_tool (dragging rakes a line); a bottom-right cluster of
## buttons selects tools and fires whistle / ping / zoom / rotate / pause.
## Built at runtime by PlayerController._ready() only on touch devices (or with
## --touch for the headless tests); when it is absent, desktop input is
## completely unchanged. Touches are handled in _input by finger index, never
## through mouse emulation (project.godot: emulate_mouse_from_touch=false, which
## only follows finger #0 and would break two-thumb play).

const LAYER: int = 60                # above the HUD (layer 1)
const JOY_ZONE_RATIO: float = 0.40   # left share of the safe field = joystick zone
const JOY_RADIUS: float = 110.0      # px at the 1280x720 base canvas
const JOY_DEADZONE: float = 0.2
const BUTTON_SIZE: Vector2 = Vector2(96, 96)  # >= UITheme.TOUCH_MIN (44 pt)
const BUTTON_MIN: float = 88.0       # shrink floor when the right edge is short (4:3 iPad)
const BUTTON_GAP: float = 12.0
const BUTTON_MARGIN: float = 16.0
const BUTTON_COLS: int = 2           # right-edge stack: 2 columns x 4 rows
## Fallback bands (canvas px) when the HUD cards cannot be measured: keep the
## stack clear of the top-right state card and the bottom-right vitals card.
const STACK_TOP_FALLBACK: float = 72.0
const STACK_BOTTOM_FALLBACK: float = 112.0
## One-shot actions must stay pressed long enough for the next physics frame to
## poll the just_pressed edge (measured in Godot 4.7: the edge lives one frame).
const ONE_SHOT_FRAMES: int = 2

## id -> action / icon / short label. Labels reuse Thai literals that already
## exist in the UI catalog (HowToPlay control rows, HUD hint, PauseMenu).
## Order = bottom row first (nearest the resting right thumb): tools lowest,
## pause highest.
const BUTTON_DEFS: Array = [
	{"id": "torch", "action": &"tool_torch", "icon": "flame", "label": "จุดไฟ"},
	{"id": "blade", "action": &"tool_blade", "icon": "blade", "label": "ถางแนว"},
	{"id": "sprayer", "action": &"tool_sprayer", "icon": "drop", "label": "พ่นน้ำ"},
	{"id": "whistle", "action": &"rally_whistle", "icon": "whistle", "label": "นกหวีด"},
	{"id": "ping", "action": &"", "icon": "crew", "label": "สั่งสหาย"},  # toggle: next world tap pings
	{"id": "zoom", "action": &"cam_zoom_cycle", "icon": "eye", "label": "ซูม"},
	{"id": "rotate", "action": &"cam_rotate_right", "icon": "mountain", "label": "หมุน"},
	{"id": "pause", "action": &"pause", "icon": "clock", "label": "หยุด"},
]
const TOOL_BUTTON_IDS: Array = ["torch", "blade", "sprayer"]
const MOVE_ACTIONS: Array = ["move_left", "move_right", "move_up", "move_down"]

## Static activation guard (also used by tests/test_touch_controls.gd).
## `UITheme.is_mobile()` is the same condition; the injectable arguments let
## the headless test prove each branch without a device.
static func should_activate(cmdline: PackedStringArray = OS.get_cmdline_user_args(),
		touchscreen: bool = DisplayServer.is_touchscreen_available(),
		mobile: bool = OS.has_feature("mobile")) -> bool:
	return touchscreen or mobile or cmdline.has("--touch")

var _root: Control
var _field: Rect2 = Rect2()
var _buttons: Dictionary = {}          # id -> {"rect", "panel", "action", "fires", "style"}
var _joy_zone: Rect2 = Rect2()
var _joy_finger: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_knob_pos: Vector2 = Vector2.ZERO
var _joy_base: Panel
var _joy_knob: Panel
var _aim_finger: int = -1
var _button_fingers: Dictionary = {}   # finger index -> button id
var _ping_armed: bool = false
var _one_shots: Array = []             # [[action: StringName, frames_left: int], ...]
var _player: Node = null               # PlayerController, written via set()/get()
var _last_tool: int = -1
var _button_side: float = BUTTON_SIZE.x
var _stack_rect: Rect2 = Rect2()
var _layout_frames: int = 0            # HUD cards settle a few frames after _ready

func _ready() -> void:
	layer = LAYER
	# Keep firing (especially the pause button) while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # we hit-test touches ourselves
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_build_joystick_visual()
	_build_buttons()
	_layout()
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_layout):
		vp.size_changed.connect(_layout)

func _exit_tree() -> void:
	_release_all_actions()
	_set_caption_inset(0.0)

## Gameplay controls own the screen only during a live burn: not under the pause
## menu / settings, not over the 20:00 report, not during the satellite pass
## (iPhone playtest P2: the cluster overlapped the report's Return button).
func gameplay_controls_wanted() -> bool:
	if get_tree().paused:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.get("pass_started") == true:
		return false
	var hud = _resolve_hud()
	if hud != null:
		var report = hud.get("report_modal")
		if report is CanvasItem and report.visible:
			return false
	return true

# ---------------------------------------------------------------- public API

func is_active() -> bool:
	return is_inside_tree()

## Current joystick output, in the same space as Input.get_vector(move_*).
func get_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func get_field_rect() -> Rect2:
	return _field

func get_joystick_zone_rect() -> Rect2:
	return _joy_zone

func get_button_rect(id: String) -> Rect2:
	if _buttons.has(id):
		return _buttons[id]["rect"]
	return Rect2()

func is_ping_armed() -> bool:
	return _ping_armed

## How many times a button has been activated (tests use this for actions
## whose only observable is the action itself, e.g. zoom / rotate).
func fire_count(id: String) -> int:
	if _buttons.has(id):
		return _buttons[id]["fires"]
	return -1

func is_over_button(pos: Vector2) -> bool:
	return _button_at(pos) != ""

# -------------------------------------------------------------------- layout

func _layout() -> void:
	# Field = visible canvas minus display cutout / home indicator (zero headless).
	_field = UITheme.safe_area_rect()
	if _field.size.x <= 0.0 or _field.size.y <= 0.0:
		_field = Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_joy_zone = Rect2(_field.position, Vector2(_field.size.x * JOY_ZONE_RATIO, _field.size.y))
	# Right-edge stack between the HUD's top-right state card and bottom-right
	# vitals card (water / breath must stay readable: iPhone playtest P1).
	var band_top: float = _field.position.y + STACK_TOP_FALLBACK
	var band_bottom: float = _field.end.y - STACK_BOTTOM_FALLBACK
	var hud = _resolve_hud()
	if hud != null:
		var state_card = hud.get("state_card")
		var vitals_card = hud.get("vitals_card")
		if state_card is Control and state_card.is_inside_tree():
			band_top = maxf(band_top, state_card.get_global_rect().end.y + BUTTON_GAP)
		if vitals_card is Control and vitals_card.is_inside_tree():
			band_bottom = minf(band_bottom, vitals_card.get_global_rect().position.y - BUTTON_GAP)
	var rows: int = ceili(float(BUTTON_DEFS.size()) / BUTTON_COLS)
	var band: float = band_bottom - band_top
	var side: float = BUTTON_SIZE.y
	if rows * side + (rows - 1) * BUTTON_GAP > band:
		side = maxf(BUTTON_MIN, (band - (rows - 1) * BUTTON_GAP) / rows)
	_button_side = side
	var stack_w: float = BUTTON_COLS * side + (BUTTON_COLS - 1) * BUTTON_GAP
	var stack_h: float = rows * side + (rows - 1) * BUTTON_GAP
	var start_x: float = _field.end.x - BUTTON_MARGIN - stack_w
	var stack_top: float = band_top + maxf(0.0, (band - stack_h) * 0.5)
	var base_y: float = stack_top + stack_h - side   # bottom row first (thumb rest)
	var i: int = 0
	for def in BUTTON_DEFS:
		var col: int = i % BUTTON_COLS
		var row: int = i / BUTTON_COLS
		var rect := Rect2(
				Vector2(start_x + col * (side + BUTTON_GAP), base_y - row * (side + BUTTON_GAP)),
				Vector2(side, side))
		_buttons[def.id]["rect"] = rect
		var panel: Panel = _buttons[def.id]["panel"]
		panel.position = rect.position
		panel.size = rect.size
		i += 1
	_stack_rect = Rect2(Vector2(start_x, stack_top), Vector2(stack_w, stack_h))
	_arrange_button_children()
	_update_joystick_visual()
	# Voice captions are centred at the bottom; keep them clear of the stack.
	_set_caption_inset(_field.end.x - start_x + BUTTON_MARGIN)

func get_stack_rect() -> Rect2:
	return _stack_rect

func _set_caption_inset(px: float) -> void:
	var audio = get_tree().root.get_node_or_null("AudioManager")
	if audio == null:
		return
	var subs = audio.get("subtitle_overlay")
	if subs != null and is_instance_valid(subs) and subs.has_method("set_gameplay_side_inset"):
		subs.set_gameplay_side_inset(px)

func _resolve_hud() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var hud = scene.get("hud")
	if hud is Node and is_instance_valid(hud):
		return hud
	return scene.get_node_or_null("HUD")

# ------------------------------------------------------------------- widgets

func _round_style(color: Color, alpha: float, radius: float, border_alpha: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, alpha)
	sb.set_corner_radius_all(int(radius))
	if border_alpha > 0.0:
		sb.border_color = Color(UITheme.CREAM, border_alpha)
		sb.set_border_width_all(2)
	return sb

func _build_joystick_visual() -> void:
	_joy_base = Panel.new()
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_theme_stylebox_override("panel", _round_style(UITheme.PANEL, 0.4, JOY_RADIUS, 0.4))
	_joy_base.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_joy_base.modulate.a = 0.0
	_root.add_child(_joy_base)
	_joy_knob = Panel.new()
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.add_theme_stylebox_override("panel", _round_style(UITheme.STRAW, 0.6, 36.0))
	_joy_knob.size = Vector2(72.0, 72.0)
	_joy_knob.modulate.a = 0.0
	_root.add_child(_joy_knob)

func _build_buttons() -> void:
	for def in BUTTON_DEFS:
		var panel := Panel.new()
		panel.name = "Btn_%s" % def.id
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := UITheme.slab(UITheme.PANEL_HI, 3)
		panel.add_theme_stylebox_override("panel", sb)
		_root.add_child(panel)
		var icon := UITheme.icon(def.icon, UITheme.STRAW, 30.0)
		panel.add_child(icon)
		var caption := UITheme.label(def.label, "Small", UITheme.CREAM)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(caption)
		_buttons[def.id] = {"rect": Rect2(), "panel": panel, "action": def.action,
				"fires": 0, "style": sb, "icon": icon, "caption": caption}

func _arrange_button_children() -> void:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var w: float = _button_side
		var icon: Control = b["icon"]
		icon.position = Vector2((w - 30.0) / 2.0, 10.0)
		icon.size = Vector2(30.0, 30.0)
		var caption: Label = b["caption"]
		var ch: float = caption.get_minimum_size().y
		caption.position = Vector2(0, w - ch - 6.0)
		caption.size = Vector2(w, ch)

func _refresh_button_visuals() -> void:
	var tool_idx := -1
	if _player != null and is_instance_valid(_player):
		tool_idx = int(_player.get("current_tool"))
	for i in TOOL_BUTTON_IDS.size():
		var id: String = TOOL_BUTTON_IDS[i]
		var sb: StyleBoxFlat = _buttons[id]["style"]
		sb.border_color = UITheme.STRAW if i == tool_idx else Color(UITheme.CREAM, 0.25)
		sb.set_border_width_all(2 if i == tool_idx else 1)
	var ping_sb: StyleBoxFlat = _buttons["ping"]["style"]
	ping_sb.border_color = UITheme.EMERALD if _ping_armed else Color(UITheme.CREAM, 0.25)
	ping_sb.set_border_width_all(3 if _ping_armed else 1)

# -------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not visible:
		return  # a modal / report / pause menu owns the touches
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_press(event.index, event.position)
		else:
			_on_touch_release(event.index)
	elif event is InputEventScreenDrag:
		_on_touch_drag(event.index, event.position)

func _on_touch_press(index: int, pos: Vector2) -> void:
	var id := _button_at(pos)
	if id != "":
		_button_fingers[index] = id   # a finger that starts on a button stays on it
		_press_button(id)
		return
	if _joy_zone.has_point(pos):
		_joy_finger = index
		_joy_origin = pos
		_joy_knob_pos = pos
		_update_joystick_visual()
		return
	# World touch: aim + hold use tool (or ping the companion when armed).
	_aim_finger = index
	_resolve_player()
	if _player != null:
		_player.set("touch_aim_active", true)
		_player.set("touch_aim_position", pos)
	if _ping_armed:
		_ping_armed = false
		_fire_action(&"ping_companion")
		_refresh_button_visuals()
	else:
		Input.action_press("use_tool")

func _on_touch_drag(index: int, pos: Vector2) -> void:
	if index == _joy_finger:
		_joy_knob_pos = pos
		_update_joystick_actions()
		_update_joystick_visual()
	elif index == _aim_finger:
		_resolve_player()
		if _player != null:
			_player.set("touch_aim_position", pos)
	# Touches that started on a button are swallowed: they never become aim.

func _on_touch_release(index: int) -> void:
	if index == _joy_finger:
		_end_joystick()
	elif index == _aim_finger:
		_aim_finger = -1
		Input.action_release("use_tool")
	elif _button_fingers.has(index):
		_button_fingers.erase(index)

func _button_at(pos: Vector2) -> String:
	for id in _buttons:
		if (_buttons[id]["rect"] as Rect2).grow(6.0).has_point(pos):
			return id
	return ""

func _press_button(id: String) -> void:
	_buttons[id]["fires"] = int(_buttons[id]["fires"]) + 1
	if id == "ping":
		_ping_armed = not _ping_armed
		_refresh_button_visuals()
		return
	_fire_action(_buttons[id]["action"])

## One-shot: press now, release a couple of frames later so a physics frame
## polls the just_pressed edge in between (see ONE_SHOT_FRAMES).
func _fire_action(action: StringName) -> void:
	if action == &"":
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	e.strength = 1.0
	Input.parse_input_event(e)
	_one_shots.append([action, ONE_SHOT_FRAMES])

func _release_one_shots() -> void:
	var keep: Array = []
	for entry in _one_shots:
		var left: int = int(entry[1]) - 1
		if left <= 0:
			Input.action_release(entry[0])
		else:
			entry[1] = left
			keep.append(entry)
	_one_shots = keep

# ----------------------------------------------------------------- joystick

func _update_joystick_actions() -> void:
	var v := _joy_output()
	_set_move_action("move_right", v.x)
	_set_move_action("move_left", -v.x)
	_set_move_action("move_down", v.y)
	_set_move_action("move_up", -v.y)

## Raw (pre-deadzone) direction from the joystick origin, clamped to the radius
func _joy_output() -> Vector2:
	if _joy_finger < 0:
		return Vector2.ZERO
	var delta := _joy_knob_pos - _joy_origin
	if delta.length() > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
	return delta / JOY_RADIUS

func _set_move_action(action: StringName, strength: float) -> void:
	if strength > JOY_DEADZONE:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)

func _end_joystick() -> void:
	_joy_finger = -1
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	_update_joystick_visual()

func _update_joystick_visual() -> void:
	if _joy_finger < 0:
		_joy_base.modulate.a = 0.0
		_joy_knob.modulate.a = 0.0
		return
	_joy_base.modulate.a = 1.0
	_joy_knob.modulate.a = 1.0
	_joy_base.position = _joy_origin - _joy_base.size * 0.5
	_joy_knob.position = _joy_origin + _joy_output() * JOY_RADIUS - _joy_knob.size * 0.5

# -------------------------------------------------------------- housekeeping

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var scene := get_tree().current_scene
	if scene:
		_player = scene.find_child("Player", true, false)

func _release_all_actions() -> void:
	for entry in _one_shots:
		Input.action_release(entry[0])
	_one_shots.clear()
	_end_joystick()
	if Input.is_action_pressed("use_tool"):
		Input.action_release("use_tool")

func _process(_delta: float) -> void:
	_release_one_shots()
	# HUD cards are laid out over the first frames; re-fit the stack to them.
	if _layout_frames < 3:
		_layout_frames += 1
		_layout()
	var wanted := gameplay_controls_wanted()
	if wanted != visible:
		visible = wanted
		if not wanted:
			_release_all_actions()
			_button_fingers.clear()
	if get_tree().paused:
		# Paused mid-touch: never leave a stuck action behind.
		if _joy_finger >= 0:
			_end_joystick()
		if _aim_finger >= 0:
			_aim_finger = -1
			Input.action_release("use_tool")
		return
	if _joy_finger >= 0:
		_update_joystick_actions()
	_resolve_player()
	if _player != null:
		var tool := int(_player.get("current_tool"))
		if tool != _last_tool:
			_last_tool = tool
			_refresh_button_visuals()
