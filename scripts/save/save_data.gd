class_name SaveData
extends RefCounted
## Données de progression sauvegardées (cahier des charges §12). Version du format + migrations ;
## toute valeur absente ou invalide retombe sur la valeur par défaut (jamais de plantage au
## chargement).
## v1 (phase 6) : pièces, niveaux permanents, records et statistiques.
## v2 (phase 7) : + meilleures pièces / éliminations en UNE partie, historique des 10 dernières
## parties, somme de contrôle (détecte un fichier tronqué ou altéré : on retombe alors sur la copie
##   de secours). Un fichier v1 se charge sans perte (migration).

const VERSION: int = 2
## Nombre de parties conservées dans l'historique.
const HISTORY_SIZE: int = 10

var coins: int = 0
var perm_levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var best_time: float = 0.0
var best_wave: int = 0
var total_kills: int = 0
var total_coins_earned: int = 0
var bosses_defeated: int = 0
var games_played: int = 0
var total_play_time: float = 0.0
var best_coins_run: int = 0
var best_kills_run: int = 0
## Dernières parties, la plus récente en premier : {wave, time, kills, coins, boss}.
var recent_runs: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"coins": coins,
		"perm_levels": Array(perm_levels),
		"best_time": best_time,
		"best_wave": best_wave,
		"total_kills": total_kills,
		"total_coins_earned": total_coins_earned,
		"bosses_defeated": bosses_defeated,
		"games_played": games_played,
		"total_play_time": total_play_time,
		"best_coins_run": best_coins_run,
		"best_kills_run": best_kills_run,
		"recent_runs": recent_runs,
	}


## Ajoute une partie à l'historique (la plus récente d'abord, taille bornée).
func push_run(wave: int, time: float, kills: int, coins: int, bosses: int) -> void:
	recent_runs.push_front(
		{"wave": wave, "time": snappedf(time, 0.1), "kills": kills, "coins": coins, "boss": bosses}
	)
	while recent_runs.size() > HISTORY_SIZE:
		recent_runs.pop_back()


## Somme de contrôle d'un dictionnaire (sans le champ « check ») : détecte une écriture tronquée.
static func checksum(d: Dictionary) -> int:
	var copy: Dictionary = d.duplicate()
	copy.erase("check")
	# Aller-retour JSON : un entier écrit puis relu devient un flottant ; le calcul doit donner la même
	# somme avant l'écriture et après la lecture.
	var canonical: Variant = JSON.parse_string(JSON.stringify(copy, "", true))
	return JSON.stringify(canonical, "", true).hash()


## Vrai si le dictionnaire porte une somme de contrôle valide, ou n'en porte pas (anciens formats).
static func is_intact(d: Dictionary) -> bool:
	if not d.has("check"):
		return true
	return int(d["check"]) == checksum(d)


## Reconstruit depuis un dictionnaire (JSON). Retourne toujours un objet valide.
static func from_variant(raw: Variant) -> SaveData:
	var out: SaveData = SaveData.new()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = migrate(raw as Dictionary)
	out.coins = _int(d, "coins", 0)
	var levels: Variant = d.get("perm_levels", [])
	if typeof(levels) == TYPE_ARRAY:
		var arr: Array = levels as Array
		for i: int in out.perm_levels.size():
			if i < arr.size() and (typeof(arr[i]) == TYPE_INT or typeof(arr[i]) == TYPE_FLOAT):
				out.perm_levels[i] = clampi(int(arr[i]), 0, PermanentUpgrades.MAX_LEVEL)
	out.best_time = _float(d, "best_time")
	out.best_wave = _int(d, "best_wave", 0)
	out.total_kills = _int(d, "total_kills", 0)
	out.total_coins_earned = _int(d, "total_coins_earned", 0)
	out.bosses_defeated = _int(d, "bosses_defeated", 0)
	out.games_played = _int(d, "games_played", 0)
	out.total_play_time = _float(d, "total_play_time")
	out.best_coins_run = _int(d, "best_coins_run", 0)
	out.best_kills_run = _int(d, "best_kills_run", 0)
	var runs: Variant = d.get("recent_runs", [])
	if typeof(runs) == TYPE_ARRAY:
		for item: Variant in runs as Array:
			if typeof(item) != TYPE_DICTIONARY or out.recent_runs.size() >= HISTORY_SIZE:
				continue
			var r: Dictionary = item as Dictionary
			(
				out
				. recent_runs
				. append(
					{
						"wave": _int(r, "wave", 0),
						"time": _float(r, "time"),
						"kills": _int(r, "kills", 0),
						"coins": _int(r, "coins", 0),
						"boss": _int(r, "boss", 0),
					}
				)
			)
	return out


## Migrations successives d'un ancien format vers VERSION : chaque étape ne fait que COMPLÉTER
## (jamais perdre) les données existantes.
static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	var out: Dictionary = d.duplicate()
	if v < 1:
		out["version"] = 1
	if int(out["version"]) < 2:
		# v1 -> v2 : records d'une partie et historique, initialisés à vide (les cumuls restent).
		out["best_coins_run"] = int(out.get("best_coins_run", 0))
		out["best_kills_run"] = int(out.get("best_kills_run", 0))
		out["recent_runs"] = out.get("recent_runs", [])
		out["version"] = 2
	return out


static func _int(d: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return maxi(int(v), 0)
	return fallback


static func _float(d: Dictionary, key: String) -> float:
	var v: Variant = d.get(key, 0.0)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		var f: float = float(v)
		return f if is_finite(f) and f >= 0.0 else 0.0
	return 0.0
