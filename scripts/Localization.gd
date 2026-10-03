extends Node

## Load translations before other autoloads construct any player-facing text.
## No class_name: this node is registered as an autoload in project.godot.
signal language_changed(locale: String)

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	L10n.initialize()
	GameSettings.ensure_loaded()
	L10n.set_locale(GameSettings.locale)

func set_language(locale: String) -> void:
	GameSettings.locale = L10n.validated_locale(locale)
	L10n.set_locale(GameSettings.locale)
	GameSettings.save_settings()
	language_changed.emit(GameSettings.locale)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		# Native Controls refresh automatically. Custom-drawn captions also need
		# a redraw; leave simulation, timers, saves and scene instances untouched.
		_redraw_tree(get_tree().root)

func _redraw_tree(node: Node) -> void:
	if node is CanvasItem:
		node.queue_redraw()
	for child in node.get_children():
		_redraw_tree(child)

func _exit_tree() -> void:
	L10n.shutdown()
