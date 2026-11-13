class_name Platform
extends RefCounted
## The single place for platform-specific decisions (Android now, iOS later).


## Apple's guidelines discourage quitting an app programmatically; web builds cannot quit.
static func can_quit_app() -> bool:
	return not OS.has_feature("ios") and not OS.has_feature("web")


static func is_mobile() -> bool:
	return OS.has_feature("mobile")
