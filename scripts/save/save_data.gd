class_name SaveData
extends RefCounted
## Données de progression sauvegardées (cahier des charges §12). Version du format + migrations ;
## toute valeur absente ou invalide retombe sur la valeur par défaut (jamais de plantage au
## chargement).

const VERSION: int = 1

var coins: int = 0
var perm_levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var best_time: float = 0.0
var best_wave: int = 0
var total_kills: int = 0
var total_coins_earned: int = 0
var bosses_defeated: int = 0
var games_played: int = 0
var total_play_time: float = 0.0


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
	}


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
	return out


## Migrations successives d'un ancien format vers VERSION. Aucune pour l'instant (v1 = première) :
## le point d'extension est là pour la phase 7 et les futures évolutions.
static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	var out: Dictionary = d.duplicate()
	if v < 1:
		out["version"] = 1
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
