extends Node
## Phone/tablet runtime policy (autoload). Desktop is untouched.
##
## Frame cap: ProMotion iPhones/iPads refresh at 120 Hz. The burn is vertex-bound
## (docs/IOS_PORT.md), so chasing 120 only heats the phone and drains the battery
## for frames nobody can see. 60 matches the fixed 60 Hz simulation step.
const MOBILE_MAX_FPS := 60

func _init() -> void:
	if UITheme.is_mobile() and Engine.max_fps == 0:
		Engine.max_fps = MOBILE_MAX_FPS
