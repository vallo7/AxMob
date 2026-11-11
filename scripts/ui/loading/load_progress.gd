class_name LoadProgress
extends RefCounted
## Progression d'un chargement par GROUPES pondérés (scène, modèles 3D, sons, interface) : la barre
## avance avec ce qui est RÉELLEMENT chargé, pas avec un minuteur. Logique pure (testée).
## L'affichage est lissé et ne recule jamais.

var displayed: float = 0.0
var _paths: Dictionary = {}  # groupe -> Array[String]
var _done: Dictionary = {}  # groupe -> int
var _weights: Dictionary = {}  # groupe -> float


func add_group(group: String, weight: float, paths: Array[String]) -> void:
	_paths[group] = paths
	_done[group] = 0
	_weights[group] = maxf(weight, 0.0)


func groups() -> Array:
	return _paths.keys()


func paths_of(group: String) -> Array[String]:
	return _paths.get(group, [] as Array[String]) as Array[String]


func set_done(group: String, count: int) -> void:
	_done[group] = clampi(count, 0, paths_of(group).size())


func total_items() -> int:
	var n: int = 0
	for g: Variant in _paths.keys():
		n += (_paths[g] as Array).size()
	return n


## Avancement réel 0..1 (un groupe vide compte pour terminé).
func ratio() -> float:
	var total_w: float = 0.0
	var acc: float = 0.0
	for g: Variant in _paths.keys():
		var w: float = float(_weights[g])
		var n: int = (_paths[g] as Array).size()
		total_w += w
		acc += w * (1.0 if n == 0 else float(_done[g]) / float(n))
	return 1.0 if total_w <= 0.0 else clampf(acc / total_w, 0.0, 1.0)


func complete() -> bool:
	return ratio() >= 0.9999


## Valeur affichée : rattrape `ratio()` à vitesse limitée, ne recule jamais.
func step_display(delta: float, speed: float = 1.4) -> float:
	displayed = maxf(displayed, move_toward(displayed, ratio(), speed * delta))
	return displayed
