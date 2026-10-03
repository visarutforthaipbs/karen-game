extends Node

## Registers gameplay actions for keyboard/mouse and gamepad / Steam Deck (PRD §5.1, M5).
## Autoload (no class_name, per AGENT.md). Runs before any scene reads the actions.
##
##   Move ............ WASD / arrows ............ left stick / D-pad (in burn)
##   Aim ............. mouse .................... right stick (cursor around the player)
##   Use tool ........ left click ............... RT / A
##   Ping companion .. right click .............. LT / X
##   Rally whistle ... Space / Q ................ LB / RB
##   Tools ........... 1 / 2 / 3 ................ D-pad left / up / right, Y cycles
##   Hide HUD ........ Tab ...................... Select / Back
##   Pause ........... Esc ...................... Start
##   Camera zoom ..... wheel / + - .............. R3 cycles
##   Camera turn ..... Z / C (90 degrees) ....... D-pad down

const STICK_DEADZONE: float = 0.25

func _ready() -> void:
	# Desktop close commands must remain available in paused menus and text fields.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_exit)
	# Godot's project input defaults are keyboard-only here. Menus use the
	# standard GUI actions, separate from the in-world tool bindings below.
	_action("ui_accept", [_joy(JOY_BUTTON_A)])
	_action("ui_cancel", [_joy(JOY_BUTTON_B)])
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action("move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action("move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])

	_action("aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action("aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action("aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action("aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	_action("use_tool", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _joy(JOY_BUTTON_A)])
	_action("ping_companion", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _joy(JOY_BUTTON_X)])
	_action("rally_whistle", [_key(KEY_SPACE), _key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER), _joy(JOY_BUTTON_RIGHT_SHOULDER)])

	_action("tool_torch", [_key(KEY_1), _joy(JOY_BUTTON_DPAD_LEFT)])
	_action("tool_blade", [_key(KEY_2), _joy(JOY_BUTTON_DPAD_UP)])
	_action("tool_sprayer", [_key(KEY_3), _joy(JOY_BUTTON_DPAD_RIGHT)])
	_action("tool_cycle", [_joy(JOY_BUTTON_Y)])
	_action("toggle_hud", [_key(KEY_TAB), _joy(JOY_BUTTON_BACK)])
	_action("pause", [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)])

	_action("cam_zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_EQUAL), _key(KEY_KP_ADD)])
	_action("cam_zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_MINUS), _key(KEY_KP_SUBTRACT)])
	_action("cam_zoom_cycle", [_joy(JOY_BUTTON_RIGHT_STICK)])
	_action("cam_rotate_left", [_key(KEY_Z)])
	_action("cam_rotate_right", [_key(KEY_C), _joy(JOY_BUTTON_DPAD_DOWN)])

func _action(name: StringName, events: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, STICK_DEADZONE)
	for e in events:
		InputMap.action_add_event(name, e)

func _key(code: Key) -> InputEventKey:
	var e = InputEventKey.new()
	e.physical_keycode = code
	return e

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e = InputEventMouseButton.new()
	e.button_index = button
	return e

func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e = InputEventJoypadButton.new()
	e.button_index = button
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e = InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

## Standard platform shortcuts, separate from gameplay's unmodified W/Q actions.
static func is_exit_shortcut(event: InputEvent, platform: String) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if platform == "macOS":
		return event.meta_pressed and not event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed and code in [KEY_W, KEY_Q]
	if platform in ["Windows", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		return event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed and not event.shift_pressed and code == KEY_F4
	return false

func _input(event: InputEvent) -> void:
	if is_exit_shortcut(event, OS.get_name()):
		get_viewport().set_input_as_handled()
		request_exit()

func request_exit() -> void:
	# Keep the existing Hearth autosave. A partial burn is not a completed plot.
	var audio := get_node_or_null("/root/AudioManager")
	if audio:
		audio.stop_all_loops()
	get_tree().quit()
