extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ",text)
	if not ok: failures += 1
func key(code: int, meta := false, alt := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.meta_pressed = meta
	e.alt_pressed = alt
	return e
func run() -> void:
	var bindings = root.get_node("InputBindings")
	check(bindings.process_mode == Node.PROCESS_MODE_ALWAYS,"shortcuts process while paused")
	check(root.close_requested.is_connected(bindings.request_exit),"window close uses common graceful exit")
	for code in [KEY_W,KEY_Q]:
		check(bindings.is_exit_shortcut(key(code,true),"macOS"),"Mac Command+%s exits" % OS.get_keycode_string(code))
		check(not bindings.is_exit_shortcut(key(code),"macOS"),"plain W/Q remains gameplay input")
		check(not bindings.is_exit_shortcut(key(code,true),"Windows"),"Mac shortcut not imposed on Windows")
	for platform in ["Windows","Linux"]:
		check(bindings.is_exit_shortcut(key(KEY_F4,false,true),platform),platform + " Alt+F4 exits")
		check(not bindings.is_exit_shortcut(key(KEY_F4),platform),platform + " plain F4 does not exit")
	var e := key(KEY_W,true)
	e.pressed = false
	check(not bindings.is_exit_shortcut(e,"macOS"),"key release ignored")
	e.pressed = true
	e.echo = true
	check(not bindings.is_exit_shortcut(e,"macOS"),"repeat ignored")
	e.echo = false
	e.shift_pressed = true
	check(not bindings.is_exit_shortcut(e,"macOS"),"extra modifiers do not trigger close")
	e = key(KEY_W,true)
	e.keycode = 0
	e.physical_keycode = KEY_W
	check(bindings.is_exit_shortcut(e,"macOS"),"physical key fallback works")
	check(not bindings.is_exit_shortcut(InputEventMouseButton.new(),"macOS"),"non-key input ignored")
	print("SHORTCUT RESULT: ",failures)
	quit(1 if failures else 0)
