extends SceneTree
## Integration: must actually exit via global input or the window close handler.
var elapsed := 0.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	if mode == "close":
		print("Injecting window close request")
		root.close_requested.emit()
		return
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	if mode == "paused": paused = true
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_W if OS.get_name() == "macOS" else KEY_F4
	e.meta_pressed = OS.get_name() == "macOS"
	e.alt_pressed = OS.get_name() != "macOS"
	print("Injecting platform shortcut with text focus; paused=",paused)
	Input.parse_input_event(e)
func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 1.0:
		push_error("Exit shortcut failed to terminate the game")
		quit(1)
	return false
