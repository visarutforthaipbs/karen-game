extends SceneTree
## Validate production particle atlas dimensions, neutral channels and frame padding.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	var results:Array=[]
	var failures:Array=[]
	for spec in [["flame_sheet.png",512,4],["mist_sheet.png",512,2],["ash_flake.png",64,1]]:
		var img:=Image.load_from_file(args[0].path_join(spec[0]))
		if img==null or img.get_size()!=Vector2i(spec[1],spec[1]):
			failures.append("Wrong size: "+spec[0]);continue
		var count:int=spec[2];var cell:int=spec[1]/count
		var coverage:Array=[]
		var border:int=0;var non_neutral:int=0
		var frames:Array[Image]=[]
		for i in count*count:
			var frame:=img.get_region(Rect2i(i%count*cell,i/count*cell,cell,cell))
			frames.append(frame)
			var visible:int=0
			for y in cell:
				for x in cell:
					var c:=frame.get_pixel(x,y)
					if c.a>.05: visible+=1
					if c.a>.05 and (absf(c.r-c.g)>.005 or absf(c.r-c.b)>.005):non_neutral+=1
					if c.a>.01 and (x<2 or y<2 or x>=cell-2 or y>=cell-2):border+=1
			coverage.append(float(visible)/(cell*cell))
			if visible==0:failures.append(spec[0]+" blank frame "+str(i))
		if border>0 or non_neutral>0: failures.append(spec[0]+" padding or colour mismatch")
		var transitions:Array=[]
		if count==4:
			for i in frames.size():
				var difference:float=0
				for y in cell:
					for x in cell:
						difference+=absf(frames[i].get_pixel(x,y).a-frames[(i+1)%frames.size()].get_pixel(x,y).a)
				transitions.append(difference/(cell*cell))
		results.append({"file":spec[0],"size":spec[1],"grid":count,"frame_coverage":coverage,"border_pixels":border,"non_neutral_pixels":non_neutral,"alpha_transition_mae_including_wrap":transitions})
	var report={"passed":failures.is_empty(),"failures":failures,"images":results}
	FileAccess.open(args[1],FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
