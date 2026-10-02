extends SceneTree
## Export the generated title art through the game's 1920x1080 canvas.
## Preserve the generator's original file; no painting or content changes here.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var view:=SubViewport.new()
	view.size=Vector2i(1920,1080)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var art:=TextureRect.new()
	art.texture=ImageTexture.create_from_image(Image.load_from_file(args[0]))
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size=Vector2(1920,1080)
	view.add_child(art)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	assert(view.get_texture().get_image().save_png(args[1])==OK)
	quit()
