extends SceneTree
## Loads every script and scene of the game so parse errors show up at once.
##   godot --headless --script res://scripts/tests/check_scripts.gd


func _initialize() -> void:
	var failed := 0
	for path in _walk("res://scripts") + _walk("res://scenes"):
		if path.ends_with(".gd") or path.ends_with(".tscn"):
			if load(path) == null:
				failed += 1
				print("FAILED ", path)
	print("check done, %d failed" % failed)
	quit(failed)


func _walk(dir: String) -> Array:
	var out := []
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with("/"):
			out.append_array(_walk(dir + "/" + file.trim_suffix("/")))
		else:
			out.append(dir + "/" + file)
	return out
