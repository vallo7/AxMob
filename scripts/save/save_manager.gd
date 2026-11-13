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
## Nom du fichier de point de reprise (partie interrompue), à côté de la sauvegarde.
const CHECKPOINT_NAME: String = "run_checkpoint.json"

## Chemin de remplacement (tests) ; vide = DEFAULT_PATH.
var path_override: String = ""
var data: SaveData = SaveData.new()
## Diagnostic : d'où viennent les données chargées ("absent", "principal", "secours", "invalide").
var load_source: String = "absent"
## Partie en cours (renseignée par Gameplay) : sert au point de reprise si l'application est tuée.
var active_ctx: RunContext
## Résumé de la partie interrompue récupérée au dernier lancement ({} si aucune) : le menu
## l'annonce.
var recovered_run: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_from_disk()
	recover_checkpoint()


func _path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH


# --- Disque --------------------------------------------------------------------------------------


func load_from_disk() -> void:
	var main: Variant = _read_json(_path())
	if main != null and SaveData.is_intact(main as Dictionary):
		data = SaveData.from_variant(main)
		load_source = "principal"
		return
	var backup: Variant = _read_json(_path() + ".bak")
	if backup != null and SaveData.is_intact(backup as Dictionary):
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
	var payload: Dictionary = data.to_dict()
	payload["check"] = SaveData.checksum(payload)
	f.store_string(JSON.stringify(payload))
	f.close()
	# Un fichier principal VALIDE devient la copie de secours avant d'être remplacé.
	var current: Variant = _read_json(_path())
	if current != null and SaveData.is_intact(current as Dictionary):
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
## new_best_coins, new_best_kills, banked, earned}. Les pièces NON dépensées rejoignent le solde
## permanent.
func record_run(ctx: RunContext) -> Dictionary:
	if ctx == null or ctx.run_recorded:
		return _empty_result()
	ctx.run_recorded = true
	if active_ctx == ctx:
		active_ctx = null
	var result: Dictionary = _apply_run(_summary_of(ctx))
	clear_checkpoint()
	save()
	changed.emit()
	return result


func _empty_result() -> Dictionary:
	return {
		"counted": false,
		"new_best_time": false,
		"new_best_wave": false,
		"new_best_coins": false,
		"new_best_kills": false,
		"banked": 0,
		"earned": 0,
	}


static func _summary_of(ctx: RunContext) -> Dictionary:
	return {
		"coins": maxi(ctx.coins, 0),
		"spent": ctx.coins_spent,
		"time": ctx.time,
		"kills": ctx.kills,
		"wave": ctx.wave,
		"boss": ctx.bosses_defeated,
	}


## Applique un résumé de partie aux données (sans écrire sur disque).
func _apply_run(sm: Dictionary) -> Dictionary:
	var result: Dictionary = _empty_result()
	var banked: int = maxi(int(sm.get("coins", 0)), 0)
	var earned: int = banked + maxi(int(sm.get("spent", 0)), 0)
	var time: float = float(sm.get("time", 0.0))
	var kills: int = maxi(int(sm.get("kills", 0)), 0)
	var wave: int = maxi(int(sm.get("wave", 0)), 0)
	var bosses: int = maxi(int(sm.get("boss", 0)), 0)
	result["earned"] = earned
	result["banked"] = banked
	data.coins += banked
	if time >= MIN_COUNTED_RUN:
		result["counted"] = true
		data.games_played += 1
		data.total_kills += kills
		data.total_coins_earned += earned
		data.bosses_defeated += bosses
		data.total_play_time += time
		if time > data.best_time:
			data.best_time = time
			result["new_best_time"] = true
		if wave > data.best_wave:
			data.best_wave = wave
			result["new_best_wave"] = true
		if earned > data.best_coins_run:
			data.best_coins_run = earned
			result["new_best_coins"] = true
		if kills > data.best_kills_run:
			data.best_kills_run = kills
			result["new_best_kills"] = true
		data.push_run(wave, time, kills, earned, bosses)
	return result


# --- Point de reprise (application tuée en arrière-plan) ------------------------------------------


func _checkpoint_path() -> String:
	return _path().get_base_dir().path_join(CHECKPOINT_NAME)


## Écrit l'état de la partie en cours (appelé quand l'application passe en arrière-plan) : si le
## système tue l'application, les pièces et statistiques de la partie ne sont pas perdues.
func write_checkpoint(ctx: RunContext) -> bool:
	if ctx == null or ctx.run_recorded:
		return false
	var f: FileAccess = FileAccess.open(_checkpoint_path() + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	var payload: Dictionary = _summary_of(ctx)
	payload["check"] = SaveData.checksum(payload)
	f.store_string(JSON.stringify(payload))
	f.close()
	return DirAccess.rename_absolute(_checkpoint_path() + ".tmp", _checkpoint_path()) == OK


func has_checkpoint() -> bool:
	return FileAccess.file_exists(_checkpoint_path())


func clear_checkpoint() -> void:
	if has_checkpoint():
		DirAccess.remove_absolute(_checkpoint_path())


## Au lancement : si une partie a été interrompue (application tuée), la verse UNE fois. Un point de
## reprise illisible ou altéré est ignoré (et supprimé). Retourne le résultat, ou {} s'il n'y en
## avait pas.
func recover_checkpoint() -> Dictionary:
	if not has_checkpoint():
		return {}
	var parsed: Variant = _read_json(_checkpoint_path())
	clear_checkpoint()
	if parsed == null or not SaveData.is_intact(parsed as Dictionary):
		return {}
	var summary: Dictionary = parsed as Dictionary
	var result: Dictionary = _apply_run(summary)
	save()
	changed.emit()
	recovered_run = {"summary": summary, "result": result}
	return recovered_run


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if active_ctx != null:
			write_checkpoint(active_ctx)
