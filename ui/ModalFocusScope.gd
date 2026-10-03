class_name ModalFocusScope
extends Node

## Keep keyboard/controller focus inside an overlay. Mouse input is blocked by
## its full-screen dimmer; focus needs its own boundary in Godot's Control tree.
## Nested overlays restore the outer scope, then the screen's original opener.
var _modal: Control
var _previous: WeakRef
var _saved: Array[Dictionary] = []
var _released: bool = false
var _captions: WeakRef

static func begin(modal: Control) -> ModalFocusScope:
	var scope = ModalFocusScope.new()
	scope._modal = modal
	modal.add_child(scope)
	return scope

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var owner = _modal.get_viewport().gui_get_focus_owner()
	if owner:
		_previous = weakref(owner)
	_suspend(_modal.get_viewport())
	# Speech remains paused/playing under its existing audio rules. Its caption
	# surface must not cover settings or confirmations on a higher CanvasLayer.
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		var captions = audio.get("subtitle_overlay")
		if is_instance_valid(captions) and is_instance_valid(captions.card) and captions.card.get_viewport() == _modal.get_viewport() and captions.has_method("push_modal"):
			_captions = weakref(captions)
			captions.push_modal()

func _suspend(node: Node) -> void:
	if node == _modal:
		return
	# A native popup or 3D SubViewport owns a different focus tree.
	if node is Viewport and node != _modal.get_viewport():
		return
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		_saved.append({"control": weakref(node), "mode": node.focus_mode})
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_suspend(child)

func _exit_tree() -> void:
	release()

## Release before emitting closed: callers can synchronously replace Settings
## with a sibling guide, before queue_free removes the old overlay next frame.
func release() -> void:
	if _released:
		return
	_released = true
	if _captions:
		var captions = _captions.get_ref()
		if is_instance_valid(captions):
			captions.pop_modal()
	for entry in _saved:
		var control = entry.control.get_ref()
		if is_instance_valid(control) and not control.is_queued_for_deletion():
			control.focus_mode = entry.mode
	_saved.clear()
	if _previous:
		var control = _previous.get_ref()
		if is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			control.grab_focus()
