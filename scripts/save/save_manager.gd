extends Node
## Sauvegarde locale de la progression (autoload « SaveManager »).
## - fichier JSON versionné dans user:// ; écriture ATOMIQUE (fichier temporaire puis renommage) ;
##   copie de secours .bak du dernier fichier valide ; valeurs par défaut si tout est invalide ;
## - pièces, améliorations permanentes, records et statistiques ;
## - la publicité n'intervient jamais ici (cahier des charges §12).
## Une partie est « versée » UNE fois (drapeau sur RunContext) : les pièces non dépensées sont
## conservées, les statistiques et records mis à jour.

signal changed

const DEFAULT_PATH: String = "user://save.json"
## Une partie plus courte n'est pas comptée (redémarrage immédiat, test).
const MIN_COUNTED_RUN: float = 3.0

## Chemin de remplacement (tests) ; vide = DEFAULT_PATH.
var path_override: String = ""
var data: SaveData = SaveData.new()
## Diagnostic : d'où viennent les données chargées ("absent", "principal", "secours", "invalide").
var load_source: String = "absent"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from_disk()


func _path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH


# --- Disque --------------------------------------------------------------------------------------


func load_from_disk() -> void:
	var main: Variant = _read_json(_path())
	if main != null:
		data = SaveData.from_variant(main)
		load_source = "principal"
		return
	var backup: Variant = _read_json(_path() + ".bak")
	if backup != null:
		data = SaveData.from_variant(backup)
		load_source = "secours"
		return
	data = SaveData.new()
	load_source = "invalide" if FileAccess.file_exists(_path()) else "absent"


## Écrit la sauvegarde. Retourne vrai si le fichier final a été remplacé correctement.
func save() -> bool:
	var tmp: String = _path() + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[save] écriture impossible : %s" % tmp)
		return false
	f.store_string(JSON.stringify(data.to_dict()))
	f.close()
	# Un fichier principal VALIDE devient la copie de secours avant d'être remplacé.
	if _read_json(_path()) != null:
		DirAccess.copy_absolute(_path(), _path() + ".bak")
	var err: Error = DirAccess.rename_absolute(tmp, _path())
	if err != OK:
		push_warning("[save] renommage impossible (%d)" % err)
		return false
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


## Remet tout à zéro (outil de test / « effacer la progression »).
func reset_all() -> void:
	data = SaveData.new()
	save()
	changed.emit()


# --- Pièces et améliorations permanentes ---------------------------------------------------------


func coins() -> int:
	return data.coins


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	data.coins += amount
	save()
	changed.emit()


func perm_level(index: int) -> int:
	return data.perm_levels[index]


func perm_cost(index: int) -> int:
	return PermanentUpgrades.cost(index, data.perm_levels[index])


func can_buy(index: int) -> bool:
	var c: int = perm_cost(index)
	return c >= 0 and data.coins >= c


## Achat atomique : pièces débitées ET niveau augmenté, puis sauvegarde immédiate (cahier §10.3).
func buy_permanent(index: int) -> bool:
	var c: int = perm_cost(index)
	if c < 0 or data.coins < c:
		return false
	data.coins -= c
	data.perm_levels[index] += 1
	save()
	changed.emit()
	return true


func bonuses() -> PermanentBonuses:
	return PermanentUpgrades.bonuses(data.perm_levels)


# --- Fin de partie ---


## Verse une partie (idempotent par partie). Retourne {counted, new_best_time, new_best_wave,
## banked, earned}. Les pièces NON dépensées rejoignent le solde permanent.
func record_run(ctx: RunContext) -> Dictionary:
	var result: Dictionary = {
		"counted": false, "new_best_time": false, "new_best_wave": false, "banked": 0, "earned": 0
	}
	if ctx == null or ctx.run_recorded:
		return result
	ctx.run_recorded = true
	var earned: int = ctx.coins + ctx.coins_spent
	result["earned"] = earned
	var banked: int = maxi(ctx.coins, 0)
	data.coins += banked
	result["banked"] = banked
	if ctx.time >= MIN_COUNTED_RUN:
		result["counted"] = true
		data.games_played += 1
		data.total_kills += ctx.kills
		data.total_coins_earned += earned
		data.bosses_defeated += ctx.bosses_defeated
		data.total_play_time += ctx.time
		if ctx.time > data.best_time:
			data.best_time = ctx.time
			result["new_best_time"] = true
		if ctx.wave > data.best_wave:
			data.best_wave = ctx.wave
			result["new_best_wave"] = true
	save()
	changed.emit()
	return result
