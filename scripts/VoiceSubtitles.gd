extends CanvasLayer

## Persistent captions for the exact recorded line actually accepted by audio.
## Original Thai remains the Label source, allowing native live translation.
var card: PanelContainer
var speaker_label: Label
var line_label: Label
var _gameplay_bottom_limit: float = -1.0
var _modal_depth: int = 0

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.065, 0.93)
	style.border_color = UITheme.STRAW.darkened(0.25)
	style.border_width_top = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	surface.add_child(card)
	var box = UITheme.vbox(2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	speaker_label = UITheme.label("", "Small", UITheme.STRAW)
	speaker_label.add_theme_font_size_override("font_size", 14)
	box.add_child(speaker_label)
	line_label = UITheme.wrap(UITheme.label("", "Body", UITheme.CREAM))
	line_label.add_theme_font_size_override("font_size", 18)
	box.add_child(line_label)
	card.hide()
	card.minimum_size_changed.connect(_layout_card.call_deferred)
	get_viewport().size_changed.connect(_resize)
	_resize()
	get_parent().voice_caption_changed.connect(_caption_changed)

func _resize() -> void:
	# Keep the caption above the bottom tool bar; wrap on narrow screens.
	var width = minf(1050.0, get_viewport().get_visible_rect().size.x - 48.0)
	card.offset_left = -width * 0.5
	card.offset_right = width * 0.5
	card.offset_top = -142.0
	card.offset_bottom = -62.0
	_layout_card.call_deferred()

## The burn HUD reserves its actual tool/crew/vital bounds. Other scenes retain
## the ordinary bottom margin; no voice or transcript is hidden to make space.
func set_gameplay_bottom_limit(bottom: float = -1.0) -> void:
	_gameplay_bottom_limit = bottom
	_layout_card()

## Modal UI owns the screen, while paused speech/transcript remains intact.
## Nesting Settings over Pause must not reveal the caption between overlays.
func push_modal() -> void:
	_modal_depth += 1
	card.hide()

func pop_modal() -> void:
	_modal_depth = maxi(0, _modal_depth - 1)
	card.visible = _modal_depth == 0 and not line_label.text.is_empty()
	_layout_card.call_deferred()

func _layout_card() -> void:
	if not is_instance_valid(card) or not card.is_inside_tree() or card.is_queued_for_deletion():
		return
	var area = card.get_viewport().get_visible_rect().size
	var bottom = area.y - 62.0
	if _gameplay_bottom_limit >= 0.0:
		bottom = minf(bottom, _gameplay_bottom_limit)
	card.size.y = maxf(80.0, card.get_combined_minimum_size().y)
	card.position.y = bottom - card.size.y

func _caption_changed(speaker: String, text: String, _duration: float) -> void:
	speaker_label.text = speaker
	line_label.text = text
	card.visible = _modal_depth == 0 and not text.is_empty()
	_layout_card.call_deferred()
