extends SceneTree
## Runner headless : godot --headless --script res://scripts/tests/run_tests.gd
## Charge scripts/tests/systems/test_*.gd, exécute les méthodes test_*, sort en code 1 si échec.

var _failures: int = 0
var _passed: int = 0
var _current: String = ""


func _initialize() -> void:
	var dir: DirAccess = DirAccess.open("res://scripts/tests/systems")
	var files: PackedStringArray = PackedStringArray()
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f: String in files:
		var script: GDScript = load("res://scripts/tests/systems/" + f) as GDScript
		var inst: RefCounted = script.new() as RefCounted
		inst.set("t", self)
		for m: Dictionary in script.get_script_method_list():
			var name: String = m["name"]
			if name.begins_with("test_"):
				_current = "%s::%s" % [f, name]
				inst.call(name)
	print("[tests] %d assertions ok, %d echecs" % [_passed, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failures += 1
		printerr("[FAIL] %s %s" % [_current, msg])
