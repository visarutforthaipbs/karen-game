extends SceneTree

## Renders the Under Two Skies 3D title (ui/TitleLogo.gd) to PNGs in assets/ui/logo/:
##   under_two_skies_logo.png       island + title + satellite shadow, transparent, cropped
##   under_two_skies_logo_dark.png  same on the game's ink background (README, light pages)
##   under_two_skies_wordmark.png   "UNDER TWO SKIES" on one line, no satellite (Hearth header)
##   under_two_skies_icon.png       the island under the satellite's shadow, 1024 px (app icon)
## Needs a window (not --headless):
##   godot --path . --resolution 640x360 --script res://tools/export_logo.gd

const OUT = "res://assets/ui/logo/"
const INK = Color("101318")

func _initialize() -> void:
	_run()

func _viewport(size: Vector2i) -> SubViewport:
	var vp = SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp

func _save(vp: SubViewport, file: String, crop: bool, plate: Color = Color(0, 0, 0, 0)) -> void:
	for i in 10:
		await process_frame
	var img = vp.get_texture().get_image()
	if crop:
		img = img.get_region(img.get_used_rect().grow(40).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	if plate.a > 0.0:
		var bg = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(plate)
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		img = bg
	img.save_png(ProjectSettings.globalize_path(OUT + file))
	print("wrote ", OUT + file, " ", img.get_size())
	vp.queue_free()
	await process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for variant in [["under_two_skies_logo.png", Color(0, 0, 0, 0)], ["under_two_skies_logo_dark.png", INK]]:
		var vp = _viewport(Vector2i(2030, 1400))
		TitleLogo.place_satellite(TitleLogo.build_scene(vp), TitleLogo.STATIC_PHASE)
		await _save(vp, variant[0], true, variant[1])
	var wm = _viewport(Vector2i(2400, 600))
	TitleLogo.build_scene(wm, false, true)
	await _save(wm, "under_two_skies_wordmark.png", true)
	# App icon: the island under the satellite's shadow, no letters, on the ink tile
	var ic = _viewport(Vector2i(1024, 1024))
	TitleLogo.place_satellite(TitleLogo.build_scene(ic, true, false, false), 0.55)
	await _save(ic, "under_two_skies_icon.png", false, INK)
	quit()
