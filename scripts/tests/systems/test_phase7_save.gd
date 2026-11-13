extends RefCounted
## Phase 7 : sauvegarde v2 — migration v1, somme de contrôle, historique, records d'une partie,
## persistance après fermeture/redémarrage (nouvelle instance qui relit le disque), point de reprise
## d'une partie interrompue, fichiers corrompus. Aucun test ne touche à la vraie sauvegarde.

const DIR: String = "user://phase7_tests"
const SAVE_SCRIPT: GDScript = preload("res://scripts/save/save_manager.gd")

var t: Object


func _path(name: String) -> String:
	return "%s/%s.json" % [DIR, name]


func _fresh(name: String) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	for ext: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(_path(name) + ext)
	DirAccess.remove_absolute(DIR + "/" + SAVE_SCRIPT.CHECKPOINT_NAME)
	var sm: Node = SAVE_SCRIPT.new()
	sm.path_override = _path(name)
	return sm


## Simule un redémarrage de l'application : nouvelle instance, mêmes fichiers.
func _restart(name: String) -> Node:
	var sm: Node = SAVE_SCRIPT.new()
	sm.path_override = _path(name)
	sm.load_from_disk()
	return sm


func _run_ctx(coins: int, spent: int, time: float, kills: int, wave: int, boss: int) -> RunContext:
	var ctx: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	ctx.coins = coins
	ctx.coins_spent = spent
	ctx.time = time
	ctx.kills = kills
	ctx.wave = wave
	ctx.bosses_defeated = boss
	return ctx


func test_v1_file_migrates_without_loss() -> void:
	var sm: Node = _fresh("v1")
	var v1: Dictionary = {
		"version": 1,
		"coins": 777,
		"perm_levels": [2, 1, 0, 3, 0],
		"best_time": 321.5,
		"best_wave": 9,
		"total_kills": 400,
		"total_coins_earned": 5000,
		"bosses_defeated": 2,
		"games_played": 12,
		"total_play_time": 4000.0,
	}
	var f: FileAccess = FileAccess.open(_path("v1"), FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	sm.load_from_disk()
	t.call(
		"check", sm.load_source == "principal", "un fichier v1 sans somme de contrôle est accepté"
	)
	t.call(
		"check", sm.data.coins == 777 and sm.data.best_wave == 9, "pièces et records v1 conservés"
	)
	t.call(
		"check",
		sm.data.perm_levels[3] == 3 and sm.data.games_played == 12,
		"niveaux et cumuls v1 conservés"
	)
	t.call(
		"check",
		sm.data.best_coins_run == 0 and sm.data.recent_runs.is_empty(),
		"champs v2 initialisés à vide"
	)
	sm.save()
	var again: Node = _restart("v1")
	t.call("check", again.data.coins == 777, "après migration puis redémarrage : rien perdu")
	var raw: Dictionary = (
		JSON.parse_string(FileAccess.get_file_as_string(_path("v1"))) as Dictionary
	)
	t.call(
		"check",
		int(raw["version"]) == SaveData.VERSION and raw.has("check"),
		"le fichier réécrit est en v2 avec somme de contrôle"
	)
	sm.free()
	again.free()


func test_persistence_after_restart_roundtrip() -> void:
	var sm: Node = _fresh("rt")
	sm.data.coins = 1234
	sm.data.perm_levels[0] = 4
	sm.record_run(_run_ctx(50, 30, 120.0, 77, 6, 1))
	var coins_after: int = sm.data.coins
	var re: Node = _restart("rt")
	t.call(
		"check",
		re.data.coins == coins_after and re.data.coins == 1284,
		"pièces identiques après redémarrage (%d)" % re.data.coins
	)
	t.call("check", re.data.perm_levels[0] == 4, "améliorations permanentes conservées")
	t.call(
		"check",
		re.data.best_wave == 6 and absf(re.data.best_time - 120.0) < 0.01,
		"records conservés"
	)
	t.call(
		"check",
		re.data.best_coins_run == 80 and re.data.best_kills_run == 77,
		"records d'une partie : 80 pièces, 77 éliminations"
	)
	t.call(
		"check",
		re.data.recent_runs.size() == 1 and int(re.data.recent_runs[0]["wave"]) == 6,
		"historique conservé"
	)
	t.call("check", re.data.games_played == 1 and re.data.bosses_defeated == 1, "cumuls conservés")
	sm.free()
	re.free()


func test_records_history_cap_and_short_runs() -> void:
	var sm: Node = _fresh("hist")
	for i: int in 14:
		sm.record_run(_run_ctx(10 + i, 0, 10.0 + float(i), 5 + i, 2 + i, 0))
	t.call(
		"check",
		sm.data.recent_runs.size() == SaveData.HISTORY_SIZE,
		"historique borné à %d parties" % SaveData.HISTORY_SIZE
	)
	t.call("check", int(sm.data.recent_runs[0]["wave"]) == 15, "la plus récente d'abord")
	t.call("check", sm.data.games_played == 14, "14 parties comptées")
	var before: int = sm.data.games_played
	var result: Dictionary = sm.record_run(_run_ctx(5, 0, 1.0, 0, 1, 0))
	t.call(
		"check",
		not bool(result["counted"]) and sm.data.games_played == before,
		"partie de moins de 3 s : pas comptée"
	)
	t.call(
		"check",
		(
			sm.data.recent_runs.size() == SaveData.HISTORY_SIZE
			and int(sm.data.recent_runs[0]["wave"]) == 15
		),
		"ni dans l'historique"
	)
	var better: Dictionary = sm.record_run(_run_ctx(999, 100, 60.0, 500, 3, 0))
	t.call(
		"check",
		bool(better["new_best_coins"]) and bool(better["new_best_kills"]),
		"nouveaux records annoncés"
	)
	t.call("check", not bool(better["new_best_wave"]), "vague 3 n'est pas un record")
	sm.free()


func test_same_run_is_recorded_once() -> void:
	var sm: Node = _fresh("once")
	var ctx: RunContext = _run_ctx(40, 10, 30.0, 12, 3, 0)
	sm.record_run(ctx)
	var coins: int = sm.data.coins
	sm.record_run(ctx)
	t.call(
		"check",
		sm.data.coins == coins and sm.data.games_played == 1,
		"une partie n'est versée qu'une fois"
	)
	sm.free()


func test_checksum_detects_tampering_and_falls_back_to_backup() -> void:
	var sm: Node = _fresh("sum")
	sm.data.coins = 100
	sm.save()
	sm.data.coins = 200
	sm.save()  # le fichier à 100 devient la copie de secours
	var text: String = FileAccess.get_file_as_string(_path("sum"))
	var altered: String = text.replace('"coins":200', '"coins":999999')
	t.call("check", altered != text, "le test altère bien le fichier")
	var f: FileAccess = FileAccess.open(_path("sum"), FileAccess.WRITE)
	f.store_string(altered)
	f.close()
	var re: Node = _restart("sum")
	t.call(
		"check",
		re.load_source == "secours",
		"fichier altéré : repli sur la copie de secours (%s)" % re.load_source
	)
	t.call("check", re.data.coins == 100, "valeurs de la copie de secours (%d)" % re.data.coins)
	sm.free()
	re.free()


func test_truncated_file_and_leftover_tmp() -> void:
	var sm: Node = _fresh("trunc")
	sm.data.coins = 55
	sm.save()
	sm.data.coins = 66
	sm.save()
	var text: String = FileAccess.get_file_as_string(_path("trunc"))
	var f: FileAccess = FileAccess.open(_path("trunc"), FileAccess.WRITE)
	f.store_string(text.substr(0, text.length() / 2))
	f.close()
	var tmp: FileAccess = FileAccess.open(_path("trunc") + ".tmp", FileAccess.WRITE)
	tmp.store_string('{"coins": 12')
	tmp.close()
	var re: Node = _restart("trunc")
	t.call(
		"check",
		re.load_source == "secours" and re.data.coins == 55,
		"écriture tronquée (crash) : on retrouve la sauvegarde précédente"
	)
	re.save()
	var again: Node = _restart("trunc")
	t.call(
		"check",
		again.load_source == "principal" and again.data.coins == 55,
		"le jeu se remet d'aplomb après réécriture"
	)
	sm.free()
	re.free()
	again.free()


func test_both_files_invalid_gives_defaults() -> void:
	var sm: Node = _fresh("bad")
	for ext: String in ["", ".bak"]:
		var f: FileAccess = FileAccess.open(_path("bad") + ext, FileAccess.WRITE)
		f.store_string("pas du json {{{")
		f.close()
	sm.load_from_disk()
	t.call(
		"check",
		sm.load_source == "invalide" and sm.data.coins == 0,
		"tout invalide : valeurs par défaut, pas de plantage"
	)
	sm.free()


func test_garbage_field_types_do_not_crash() -> void:
	var d: Dictionary = {
		"version": 2,
		"coins": "beaucoup",
		"perm_levels": "x",
		"best_time": [1],
		"recent_runs": [3, "a", {"wave": "z", "time": -5, "kills": 2.9}],
	}
	var data: SaveData = SaveData.from_variant(d)
	t.call(
		"check", data.coins == 0 and data.best_time == 0.0, "types invalides -> valeurs par défaut"
	)
	t.call(
		"check",
		data.recent_runs.size() == 1 and int(data.recent_runs[0]["kills"]) == 2,
		"historique : entrées invalides écartées, valeurs saines"
	)
	t.call("check", SaveData.from_variant(null).coins == 0, "null -> défauts")


func test_checkpoint_recovers_interrupted_run_once() -> void:
	var sm: Node = _fresh("cp")
	sm.data.coins = 100
	sm.save()
	var ctx: RunContext = _run_ctx(60, 40, 95.0, 31, 5, 0)
	t.call(
		"check",
		sm.write_checkpoint(ctx),
		"point de reprise écrit (application passée en arrière-plan)"
	)
	t.call("check", sm.has_checkpoint(), "le fichier existe")
	# L'application est tuée : redémarrage -> la partie est versée une fois.
	var re: Node = _restart("cp")
	var res: Dictionary = re.recover_checkpoint()
	t.call("check", not res.is_empty(), "partie interrompue détectée")
	t.call("check", re.data.coins == 160, "pièces non dépensées versées (+60) : %d" % re.data.coins)
	t.call(
		"check",
		re.data.games_played == 1 and re.data.best_wave == 5,
		"statistiques et records versés"
	)
	t.call("check", not re.has_checkpoint(), "point de reprise supprimé après versement")
	t.call(
		"check",
		re.recover_checkpoint().is_empty() and re.data.coins == 160,
		"jamais versé deux fois"
	)
	sm.free()
	re.free()


func test_checkpoint_cleared_by_normal_end_and_ignored_when_corrupt() -> void:
	var sm: Node = _fresh("cp2")
	var ctx: RunContext = _run_ctx(20, 0, 50.0, 10, 4, 0)
	sm.active_ctx = ctx
	sm.write_checkpoint(ctx)
	sm.record_run(ctx)
	t.call(
		"check",
		not sm.has_checkpoint() and sm.active_ctx == null,
		"fin normale : plus de point de reprise"
	)
	t.call(
		"check",
		not sm.write_checkpoint(ctx),
		"une partie déjà versée n'écrit plus de point de reprise"
	)
	var f: FileAccess = FileAccess.open(DIR + "/" + SAVE_SCRIPT.CHECKPOINT_NAME, FileAccess.WRITE)
	f.store_string('{"coins": 99999, "time": 500, "check": 12345}')
	f.close()
	var coins: int = sm.data.coins
	t.call(
		"check",
		sm.recover_checkpoint().is_empty() and sm.data.coins == coins,
		"point de reprise altéré : ignoré, aucune pièce fantôme"
	)
	t.call("check", not sm.has_checkpoint(), "et supprimé")
	sm.free()
