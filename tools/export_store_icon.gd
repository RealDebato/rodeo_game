extends SceneTree
## Renders icon.svg to the 512 × 512 PNG required for the Google Play store listing.
##   godot --headless --path . -s res://tools/export_store_icon.gd
## Output: build/store/icon_512.png (git-ignored build output).

const SOURCE: String = "res://icon.svg"
const OUTPUT_DIR: String = "res://build/store"
const SIZE: int = 512


func _initialize() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	var image := Image.new()
	var error := image.load_svg_from_string(svg, SIZE / 128.0)  # icon.svg is 128 × 128
	if error != OK:
		push_error("Could not rasterize %s (error %d)" % [SOURCE, error])
		quit(1)
		return
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path := OUTPUT_DIR + "/icon_512.png"
	error = image.save_png(path)
	print("Saved %s (%dx%d)" % [ProjectSettings.globalize_path(path), image.get_width(), image.get_height()] if error == OK else "Save failed: %d" % error)
	quit(0 if error == OK else 1)
