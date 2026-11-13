extends SceneTree
## Runner headless : godot --headless --script res://scripts/tests/run_tests.gd
## Charge scripts/tests/{systems,gameplay}/test_*.gd et exécute les méthodes test_*.
## Code de sortie 1 si au moins un échec.

const TEST_DIRS: Array[String] = [
	"res://scripts/tests/systems",
	"res://scripts/tests/gameplay",
]

var _failures: int = 0
var _passed: int = 0
var _current: String = ""
var _started: bool = false


func _process(_delta: float) -> bool:
	# Les tests tournent à la première frame : la racine est alors prête (les _ready des scènes
	# ajoutées s'exécutent) et les scénarios peuvent attendre des frames.
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	# Les textes attendus par les tests sont en français, quelle que soit la langue de la machine.
	Loc.override_lang = "fr"
	for dir_path: String in TEST_DIRS:
		await _run_dir(dir_path)
	print("[tests] %d assertions ok, %d echecs" % [_passed, _failures])
	_silence_audio()
	# Quelques images pour que le serveur audio libère les lectures arrêtées avant la sortie.
	for i: int in 12:
		await process_frame
	quit(1 if _failures > 0 else 0)


func _run_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var files: PackedStringArray = PackedStringArray()
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and _matches(f, _file_filter()):
			files.append(f)
	files.sort()
	for f: String in files:
		var script: GDScript = load(dir_path + "/" + f) as GDScript
		var inst: RefCounted = script.new() as RefCounted
		inst.set("t", self)
		for m: Dictionary in script.get_script_method_list():
			var name: String = m["name"]
			if name.begins_with("test_") and _matches(name, _method_filter()):
				_current = "%s::%s" % [f, name]
				await inst.call(name)


## Filtres de développement : AX_TEST_FILE=phase5 AX_TEST_METHOD=splash (sous-chaînes ; vide =
## tout).
func _matches(text: String, filter: String) -> bool:
	return filter.is_empty() or text.contains(filter)


func _file_filter() -> String:
	return OS.get_environment("AX_TEST_FILE")


func _method_filter() -> String:
	return OS.get_environment("AX_TEST_METHOD")


func check(cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failures += 1
		printerr("[FAIL] %s %s" % [_current, msg])


## Libère les flux sonores avant la sortie (sinon le moteur signale des ressources « encore en
## usage » : sans conséquence, mais bruyant dans les journaux).
func _silence_audio() -> void:
	var audio: Node = root.get_node_or_null("AudioManager")
	if audio != null:
		audio.call("shutdown")
