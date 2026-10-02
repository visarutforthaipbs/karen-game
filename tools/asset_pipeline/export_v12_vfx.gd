extends SceneTree
## Technical atlas packing: retain generated art, normalize channels/padding/size.
## Args: flame original, smoke original, ember original, candidate output folder.
func _initialize() -> void: call_deferred("run")
func pack(path: String, side: int, grid: int, flame: bool) -> Image:
	var source := Image.load_from_file(path)
	assert(source != null and source.detect_alpha() != Image.ALPHA_NONE)
	var result := Image.create(side, side, false, Image.FORMAT_RGBA8)
	result.fill(Color(1,1,1,0))
	var cell := side / grid
	for i in grid * grid:
		var x0 := roundi(float(i % grid) * source.get_width() / grid)
		var y0 := roundi(float(i / grid) * source.get_height() / grid)
		var x1 := roundi(float(i % grid + 1) * source.get_width() / grid)
		var y1 := roundi(float(i / grid + 1) * source.get_height() / grid)
		var frame := source.get_region(Rect2i(x0,y0,x1-x0,y1-y0))
		# Atlas import strips imperceptible alpha speckles and enforces neutral RGB.
		for y in frame.get_height():
			for x in frame.get_width():
				var c := frame.get_pixel(x,y)
				var grey := (c.r+c.g+c.b)/3.0
				frame.set_pixel(x,y,Color(grey,grey,grey,c.a if c.a > .08 else 0.0))
		frame = frame.get_region(frame.get_used_rect())
		var available := Vector2(cell*.78,cell*.84 if flame else cell*.78)
		var scale_factor := minf(available.x/frame.get_width(), available.y/frame.get_height())
		frame.resize(maxi(1,roundi(frame.get_width()*scale_factor)),maxi(1,roundi(frame.get_height()*scale_factor)),Image.INTERPOLATE_LANCZOS)
		var px := i % grid * cell + (cell-frame.get_width())/2
		var py := i / grid * cell + (cell-frame.get_height())/2
		if flame: py = i / grid * cell + cell - 8 - frame.get_height()
		result.blit_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i(px,py))
	return result
func run() -> void:
	var a := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(a[3])
	assert(pack(a[0],512,4,true).save_png(a[3].path_join("flame_sheet.png")) == OK)
	assert(pack(a[1],512,2,false).save_png(a[3].path_join("smoke_sheet.png")) == OK)
	assert(pack(a[2],64,1,false).save_png(a[3].path_join("ember.png")) == OK)
	quit()
