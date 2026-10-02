extends "res://scripts/SkeletalChibiAnimator.gd"
## Village gestures are visual only; ration accounting remains in VillageHearth.
var _gesture_time := 0.0

func _process(delta: float) -> void:
	if _gesture_time > 0:
		_gesture_time -= delta
		skeleton.reset_bone_poses()
		animation_player.advance(delta)
	else:
		update_animation(delta, Vector3.ZERO)

func gesture(clip: String = "Talk") -> void:
	if clip not in ["Talk", "Granary"] or not animation_player.has_animation(clip): return
	_gesture_time = animation_player.get_animation(clip).length
	animation_player.play(clip, 0.15)
