class_name ScenePaths
extends RefCounted
## Top-level scenes and scene switching, in one place.

const MAIN_MENU: String = "res://src/ui/main_menu.tscn"
const GAME: String = "res://src/game/game.tscn"


static func go_to(tree: SceneTree, path: String) -> void:
	var error := tree.change_scene_to_file(path)
	if error != OK:
		push_error("Could not change scene to %s (error %d)" % [path, error])
