extends SceneTree
## Simulateur d'équilibrage headless : lanceur. La logique est dans simulation.gd, chargé après
## le démarrage (les autoloads ne sont pas encore connus à la compilation de ce script).
##
##   godot --headless --script res://scripts/tools/simulate_runs.gd -- \
##       --runs 8 --seconds 600 --seed 1000 --out reports/balance
##
## Voir simulation.gd pour les sorties (CSV) et les limites du bot.

var _started: bool = false
## Garde la simulation en vie : sans référence, l'objet serait libéré et sa coroutine abandonnée.
var _simulation: RefCounted


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var script: GDScript = load("res://scripts/tools/simulation.gd") as GDScript
		_simulation = script.new() as RefCounted
		_simulation.call("run", self)
	return false
