extends HSlider

## Settings-only touch input. Gameplay deliberately disables mouse emulation for
## two-thumb play; native HSlider handles mouse but not raw screen touches.
## Keep mouse/keyboard behaviour in HSlider and map only one owned finger here.
var _finger := -1

func _gui_input(event: InputEvent) -> void:
	if not UITheme.is_mobile() or not editable:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			_finger = event.index
			grab_focus()
			_set_from_touch(event.position.x)
			accept_event()
		elif event.index == _finger:
			if not event.canceled:
				_set_from_touch(event.position.x)
			_finger = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _finger:
		_set_from_touch(event.position.x)
		accept_event()

func _set_from_touch(x: float) -> void:
	# Match the native track: the grabber centre travels inside its half-width.
	var grabber := get_theme_icon("grabber")
	var inset := float(grabber.get_width()) * 0.5 if grabber else 0.0
	var fraction := clampf((x - inset) / maxf(1.0, size.x - inset * 2.0), 0.0, 1.0)
	if is_layout_rtl():
		fraction = 1.0 - fraction
	ratio = fraction

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_finger = -1
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_finger = -1
