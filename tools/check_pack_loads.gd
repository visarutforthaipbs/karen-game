## Pack sanity check: load every exported scene/model/texture/script from a built .pck
## and fail if any comes back null. Catches export exclude_filter mistakes that only
## crash on the player's phone (0.3.6: island_0.jpg was excluded as "unreferenced" but
## is the texture inside island.glb -> PackedScene::instantiate on null -> SIGSEGV at
## the title screen). Run against the PACK, not the project:
##   godot --headless --main-pack build/<id>/xcode/UnderTwoSkies.pck --script tools/check_pack_loads.gd
extends SceneTree
func _initialize() -> void:
	var bad := []; var n := 0
	for p in _all("res://"):
		var src := ""
		if p.ends_with(".remap"): src = p.trim_suffix(".remap")
		elif p.ends_with(".import"): src = p.trim_suffix(".import")
		else: continue
		if src.ends_with(".wav") or src.ends_with(".mp3") or src.ends_with(".ttf") or src.ends_with(".json"): continue
		n += 1
		var r = ResourceLoader.load(src)
		if r == null: bad.append(src)
	print("LOADALL checked %d resources, failed %d" % [n, bad.size()])
	for b in bad: print("LOADALL FAIL ", b)
	quit(1 if bad.size() > 0 else 0)
func _all(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			if f != ".godot": out.append_array(_all(p))
		else: out.append(p)
		f = d.get_next()
	return out
