extends Node
# يحمّل كل سكريبت في المشروع (والـ Autoloads شغالة) ويطبع اللي يفشل في الكومبايل.
func _ready() -> void:
	var failed: Array = []
	var total: int = 0
	for dir in ["res://scripts", "res://tests", "res://tools"]:
		for path in _gd_files(dir):
			total += 1
			var res = load(path)
			if res == null:
				failed.append(path)
	print("LOAD_ALL: %d scripts, %d failed" % [total, failed.size()])
	for f in failed:
		print("LOAD_FAIL: ", f)
	get_tree().quit()

func _gd_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_gd_files(dir.path_join(sub)))
	return out
