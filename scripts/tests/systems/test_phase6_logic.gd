# gdlint: disable=max-public-methods
extends RefCounted
## Phase 6 : sauvegarde, améliorations permanentes, garde anti-plantage, qualité, traductions,
## progression du chargement, éléments d'interface. Logique pure + widgets (sans rendu).

const TMP_SAVE: String = "user://test_save_p6.json"
const TMP_GUARD: String = "user://test_guard_p6.json"
const SAVE_SCRIPT: GDScript = preload("res://scripts/save/save_manager.gd")

var t: Object


func _cleanup(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


# --- Améliorations permanentes -----------------------------------------------------------------


func test_permanent_costs_grow_and_stop_at_max() -> void:
	for i: int in PermanentUpgrades.count():
		var previous: int = 0
		for level: int in PermanentUpgrades.MAX_LEVEL:
			var c: int = PermanentUpgrades.cost(i, level)
			t.call(
				"check",
				c > previous,
				"%s : coût croissant au niveau %d" % [PermanentUpgrades.id_of(i), level]
			)
			previous = c
		t.call(
			"check",
			PermanentUpgrades.cost(i, PermanentUpgrades.MAX_LEVEL) == -1,
			"plus d'achat au niveau max"
		)
	t.call("check", PermanentUpgrades.cost(0, 0) == 60, "premier niveau = coût de base")


func test_permanent_bonuses_values() -> void:
	var b: PermanentBonuses = PermanentUpgrades.bonuses(PackedInt32Array([3, 2, 5, 10, 4]))
	t.call("check", is_equal_approx(b.hp_add, 24.0), "PV : +8 par niveau")
	t.call("check", is_equal_approx(b.power_mult, 1.12), "puissance : +6 % par niveau")
	t.call("check", is_equal_approx(b.rate_mult, 1.20), "cadence : +4 % par niveau")
	t.call("check", is_equal_approx(b.coin_mult, 1.50), "pièces : +5 % par niveau")
	t.call("check", is_equal_approx(b.speed_mult, 1.10), "vitesse : +2,5 % par niveau")
	var n: PermanentBonuses = PermanentUpgrades.bonuses(PackedInt32Array())
	t.call(
		"check",
		n.hp_add == 0.0 and n.power_mult == 1.0 and n.coin_mult == 1.0,
		"tableau vide = neutre"
	)


func test_bonuses_scale_turret_tables_without_touching_the_resource() -> void:
	var neutral: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	neutral.set_turrets(DataRegistry.turrets())
	var boosted: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	boosted.bonuses = PermanentUpgrades.bonuses(PackedInt32Array([0, 5, 5, 0, 0]))
	boosted.set_turrets(DataRegistry.turrets())
	for i: int in neutral.turret_data.size():
		var a: TurretLevelData = neutral.turret_stats(i, 1)
		var b: TurretLevelData = boosted.turret_stats(i, 1)
		t.call("check", is_equal_approx(b.damage, a.damage * 1.30), "%d : dégâts +30 %%" % i)
		t.call("check", is_equal_approx(b.fire_rate, a.fire_rate * 1.20), "%d : cadence +20 %%" % i)
	# La ressource partagée reste intacte : une autre partie sans bonus retrouve les valeurs d'origine.
	var again: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	again.set_turrets(DataRegistry.turrets())
	t.call(
		"check",
		is_equal_approx(again.turret_stats(0, 1).damage, neutral.turret_stats(0, 1).damage),
		"table d'origine intacte"
	)


# --- Sauvegarde -----------------------------------------------------------------------------------


func test_save_data_sanitizes_garbage() -> void:
	var d: SaveData = SaveData.from_variant(
		{
			"coins": -50,
			"best_time": "x",
			"perm_levels": [99, -3, "a", 2.0],
			"best_wave": 7.9,
			"version": 0
		}
	)
	t.call("check", d.coins == 0, "pièces négatives -> 0")
	t.call("check", d.best_time == 0.0, "texte -> 0")
	t.call("check", d.perm_levels[0] == PermanentUpgrades.MAX_LEVEL, "niveau plafonné")
	t.call("check", d.perm_levels[1] == 0 and d.perm_levels[2] == 0, "niveau invalide -> 0")
	t.call("check", d.perm_levels[3] == 2, "niveau flottant accepté")
	t.call("check", d.best_wave == 7, "entier tronqué")
	t.call(
		"check", SaveData.from_variant("pas un dictionnaire").coins == 0, "mauvais type -> défauts"
	)
	t.call("check", SaveData.from_variant({"best_time": INF}).best_time == 0.0, "infini refusé")


func test_save_roundtrip_backup_and_corruption() -> void:
	_cleanup(TMP_SAVE)
	var sm: Node = SAVE_SCRIPT.new() as Node
	sm.path_override = TMP_SAVE
	sm.load_from_disk()
	t.call("check", sm.load_source == "absent", "pas de fichier : valeurs par défaut")
	sm.data.coins = 321
	sm.data.best_wave = 9
	t.call("check", sm.save(), "écriture réussie")
	t.call(
		"check", not FileAccess.file_exists(TMP_SAVE + ".tmp"), "aucun fichier temporaire restant"
	)
	sm.data.coins = 400
	sm.save()
	t.call(
		"check",
		FileAccess.file_exists(TMP_SAVE + ".bak"),
		"copie de secours créée au 2e enregistrement"
	)
	var fresh: Node = SAVE_SCRIPT.new() as Node
	fresh.path_override = TMP_SAVE
	fresh.load_from_disk()
	t.call("check", fresh.data.coins == 400 and fresh.data.best_wave == 9, "relecture identique")
	# Fichier principal corrompu : on retombe sur la copie de secours (le DERNIER état valide avant).
	var f: FileAccess = FileAccess.open(TMP_SAVE, FileAccess.WRITE)
	f.store_string("{ pas du json")
	f.close()
	fresh.load_from_disk()
	t.call("check", fresh.load_source == "secours", "principal corrompu -> secours")
	t.call("check", fresh.data.coins == 321, "la copie de secours a le dernier état valide")
	_cleanup(TMP_SAVE)
	fresh.load_from_disk()
	t.call("check", fresh.data.coins == 0, "tout absent -> défauts")
	sm.free()
	fresh.free()


func test_buy_permanent_is_atomic_and_persistent() -> void:
	_cleanup(TMP_SAVE)
	var sm: Node = SAVE_SCRIPT.new() as Node
	sm.path_override = TMP_SAVE
	sm.load_from_disk()
	t.call("check", not sm.buy_permanent(0), "refus sans pièces")
	t.call("check", sm.perm_level(0) == 0 and sm.coins() == 0, "rien n'a bougé")
	sm.data.coins = 200
	t.call("check", sm.buy_permanent(0), "achat réussi")
	t.call("check", sm.coins() == 140 and sm.perm_level(0) == 1, "pièces débitées et niveau +1")
	var again: Node = SAVE_SCRIPT.new() as Node
	again.path_override = TMP_SAVE
	again.load_from_disk()
	t.call("check", again.coins() == 140 and again.perm_level(0) == 1, "sauvegardé immédiatement")
	sm.data.perm_levels[1] = PermanentUpgrades.MAX_LEVEL
	sm.data.coins = 99999
	t.call("check", not sm.buy_permanent(1), "refus au niveau maximal")
	_cleanup(TMP_SAVE)
	sm.free()
	again.free()


func test_record_run_banks_coins_once_and_updates_records() -> void:
	_cleanup(TMP_SAVE)
	var sm: Node = SAVE_SCRIPT.new() as Node
	sm.path_override = TMP_SAVE
	sm.load_from_disk()
	var ctx: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	ctx.coins = 75
	ctx.coins_spent = 25
	ctx.time = 95.0
	ctx.wave = 6
	ctx.kills = 40
	ctx.bosses_defeated = 1
	var r: Dictionary = sm.record_run(ctx)
	t.call(
		"check", int(r["banked"]) == 75 and int(r["earned"]) == 100, "75 conservées, 100 gagnées"
	)
	t.call("check", bool(r["new_best_wave"]) and bool(r["new_best_time"]), "premiers records")
	t.call("check", sm.coins() == 75 and sm.data.games_played == 1, "solde et parties")
	t.call(
		"check",
		(
			sm.data.total_kills == 40
			and sm.data.bosses_defeated == 1
			and sm.data.total_coins_earned == 100
		),
		"statistiques cumulées"
	)
	var twice: Dictionary = sm.record_run(ctx)
	t.call(
		"check",
		not bool(twice["counted"]) and sm.coins() == 75 and sm.data.games_played == 1,
		"jamais versée deux fois"
	)
	var short: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	short.coins = 10
	short.time = 1.0
	sm.record_run(short)
	t.call(
		"check",
		sm.coins() == 85 and sm.data.games_played == 1,
		"partie trop courte : pièces gardées, partie non comptée"
	)
	var worse: RunContext = RunContext.new(DataRegistry.config(), DataRegistry.balance())
	worse.time = 30.0
	worse.wave = 2
	var wr: Dictionary = sm.record_run(worse)
	t.call(
		"check",
		not bool(wr["new_best_wave"]) and sm.data.best_wave == 6,
		"un moins bon score ne remplace pas le record"
	)
	_cleanup(TMP_SAVE)
	sm.free()


# --- Garde anti-plantage -------------------------------------------------------------------------


func _reboot(guard: CrashGuard) -> CrashGuard:
	## Simule un relancement : on repart de l'état écrit sur le disque.
	var next: CrashGuard = CrashGuard.new()
	next.state = CrashGuard.sanitize(JSON.parse_string(JSON.stringify(guard.state)))
	return next


func test_crash_guard_detects_crash_and_bans_the_tier() -> void:
	var g: CrashGuard = CrashGuard.new()
	g.detect()
	g.start(2, 0)  # session en ÉLEVÉ
	var g2: CrashGuard = _reboot(g)  # pas de stop() : plantage
	var info: Dictionary = g2.detect()
	t.call(
		"check", bool(info["crashed"]) and int(info["tier"]) == 2, "plantage détecté, profil ÉLEVÉ"
	)
	t.call("check", g2.ceiling() == 1, "plafond = MOYEN")
	t.call("check", g2.is_banned(2) and not g2.is_banned(1), "ÉLEVÉ interdit, MOYEN permis")
	g2.start(1, 0)
	g2.stop()
	var g3: CrashGuard = _reboot(g2)
	t.call("check", not bool(g3.detect()["crashed"]), "fermeture propre : pas de plantage")
	t.call("check", g3.ceiling() == 1, "interdiction maintenue")


func test_crash_guard_background_is_not_a_crash() -> void:
	var g: CrashGuard = CrashGuard.new()
	g.detect()
	g.start(2, 0)
	g.set_foreground(false)  # le système peut tuer l'appli en arrière-plan
	var g2: CrashGuard = _reboot(g)
	t.call("check", not bool(g2.detect()["crashed"]), "arrière-plan = pas un plantage")
	g2.start(2, 0)
	g2.set_foreground(false)
	g2.set_foreground(true)  # retour au premier plan : témoin reposé
	t.call("check", bool(_reboot(g2).detect()["crashed"]), "plantage après retour au premier plan")


func test_crash_guard_forgives_once_then_locks() -> void:
	var g: CrashGuard = CrashGuard.new()
	g.detect()
	g.start(2, 0)
	g = _reboot(g)
	g.detect()
	t.call("check", g.ceiling() == 1, "premier plantage : plafond MOYEN")
	for i: int in CrashGuard.FORGIVE_AFTER_CLEAN:
		g.start(1, 0)
		g.stop()
		g = _reboot(g)
		g.detect()
	t.call(
		"check",
		g.ceiling() == 2,
		"pardon après %d lancements stables" % CrashGuard.FORGIVE_AFTER_CLEAN
	)
	g.start(2, 3)
	g = _reboot(g)
	g.detect()  # deuxième plantage au même profil
	t.call(
		"check",
		bool(g.state["locked"]) and g.ceiling() == 1,
		"deuxième plantage : interdit pour de bon"
	)
	for i: int in 20:
		g.start(1, 0)
		g.stop()
		g = _reboot(g)
		g.detect()
	t.call("check", g.ceiling() == 1, "jamais pardonné une fois verrouillé")


func test_crash_guard_low_tier_crash_keeps_low_available() -> void:
	var g: CrashGuard = CrashGuard.new()
	g.detect()
	g.start(0, 0)
	g = _reboot(g)
	g.detect()
	t.call("check", g.ceiling() == 2 and not g.is_banned(0), "BAS ne s'interdit jamais lui-même")
	t.call("check", int(g.state["crashes"]) == 1, "plantage compté")


func test_crash_guard_survives_garbage_and_writes_atomically() -> void:
	t.call("check", CrashGuard.sanitize("n'importe quoi")["tier"] == 1, "mauvais type -> défauts")
	var dirty: Dictionary = CrashGuard.sanitize(
		{"tier": 99, "mode": -4, "banned_tier": 7, "crashes": "x", "running": "oui"}
	)
	t.call(
		"check",
		dirty["tier"] == 2 and dirty["mode"] == 0 and dirty["banned_tier"] == 2,
		"valeurs bornées"
	)
	t.call("check", dirty["crashes"] == 0 and dirty["running"] == false, "types invalides ignorés")
	_cleanup(TMP_GUARD)
	var g: CrashGuard = CrashGuard.new()
	g.start(2, 3)
	t.call("check", g.save_to(TMP_GUARD), "écriture")
	t.call("check", not FileAccess.file_exists(TMP_GUARD + ".tmp"), "pas de fichier temporaire")
	var back: CrashGuard = CrashGuard.load_from(TMP_GUARD)
	t.call("check", bool(back.state["running"]) and back.state["tier"] == 2, "relecture")
	_cleanup(TMP_GUARD)


# --- Qualité ---


func test_msaa_never_applied_on_mobile() -> void:
	for tier: QualityProfile.Tier in [
		QualityProfile.Tier.LOW, QualityProfile.Tier.MEDIUM, QualityProfile.Tier.HIGH
	]:
		var p: QualityProfile = QualityProfile.for_tier(tier)
		t.call(
			"check",
			p.effective_msaa(true) == Viewport.MSAA_DISABLED,
			"MSAA jamais sur mobile (profil %d)" % tier
		)
	t.call(
		"check",
		QualityProfile.for_tier(QualityProfile.Tier.HIGH).effective_msaa(false) == Viewport.MSAA_2X,
		"MSAA permis sur ordinateur"
	)


func test_quality_profiles_phase6_budgets() -> void:
	var low: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.LOW)
	var mid: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.MEDIUM)
	var high: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.HIGH)
	t.call("check", not low.outlines and mid.outlines and high.outlines, "contours : pas sur BAS")
	t.call(
		"check",
		low.outline_px <= mid.outline_px and mid.outline_px <= high.outline_px,
		"contours de plus en plus épais"
	)
	t.call(
		"check",
		low.video_budget_mb < mid.video_budget_mb and mid.video_budget_mb < high.video_budget_mb,
		"budget mémoire croissant"
	)
	t.call(
		"check", high.water_sparkles and not low.water_sparkles, "scintillements : ÉLEVÉ seulement"
	)


func test_device_profile_suggestions() -> void:
	t.call(
		"check",
		DeviceProfile.suggest("Mali-T830", 4096, 2_000_000) == QualityProfile.Tier.LOW,
		"GPU d'entrée -> BAS"
	)
	t.call(
		"check",
		DeviceProfile.suggest("Adreno (TM) 640", 6144, 2_500_000) == QualityProfile.Tier.MEDIUM,
		"premier lancement : prudent"
	)
	t.call(
		"check",
		DeviceProfile.suggest("Adreno (TM) 640", 2048, 2_000_000) == QualityProfile.Tier.LOW,
		"peu de RAM -> BAS"
	)
	t.call(
		"check", DeviceProfile.suggest("", -1, 0) == QualityProfile.Tier.MEDIUM, "inconnu -> MOYEN"
	)


# --- Traductions ---


func test_every_string_has_both_languages_and_matching_placeholders() -> void:
	for key: String in LocStrings.STRINGS.keys():
		var row: Dictionary = LocStrings.STRINGS[key] as Dictionary
		t.call(
			"check",
			str(row.get("fr", "")) != "" and str(row.get("en", "")) != "",
			"%s : FR et EN présents" % key
		)
		var fr_n: int = str(row.get("fr", "")).count("%") - 2 * str(row.get("fr", "")).count("%%")
		var en_n: int = str(row.get("en", "")).count("%") - 2 * str(row.get("en", "")).count("%%")
		t.call("check", fr_n == en_n, "%s : mêmes paramètres dans les deux langues" % key)


func test_every_key_used_in_code_exists() -> void:
	var re: RegEx = RegEx.new()
	re.compile('Loc\\.t\\("([a-z0-9_]+)"[,)]')
	var missing: Array[String] = []
	var stack: Array[String] = ["res://scripts", "res://scenes"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub: String in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path + "/" + sub)
		for f: String in DirAccess.get_files_at(dir_path):
			if not f.ends_with(".gd") or dir_path.contains("/tests"):
				continue
			var text: String = FileAccess.get_file_as_string(dir_path + "/" + f)
			for m: RegExMatch in re.search_all(text):
				if not Loc.has_key(m.get_string(1)):
					missing.append("%s (%s)" % [m.get_string(1), f])
	t.call("check", missing.is_empty(), "clés manquantes : %s" % str(missing))
	# Clés construites dynamiquement.
	for i: int in 8:
		t.call("check", Loc.has_key("tip_%d" % (i + 1)), "astuce %d" % (i + 1))
	for i: int in 5:
		t.call("check", Loc.has_key("sens_%d" % i), "sensibilité %d" % i)
	for i: int in 4:
		t.call("check", Loc.has_key("haptics_%d" % i), "vibrations %d" % i)
	for i: int in 3:
		t.call("check", Loc.has_key("pause_mode_%d" % i), "pause %d" % i)
	for id: String in ["hp", "power", "rate", "coins", "speed"]:
		t.call(
			"check",
			Loc.has_key("perm_%s_name" % id) and Loc.has_key("perm_%s_desc" % id),
			"amélioration %s" % id
		)
	for q: String in ["AUTO", "LOW", "MEDIUM", "HIGH"]:
		t.call("check", Loc.has_key("quality_" + q), "qualité %s" % q)


func test_loc_language_switch() -> void:
	var saved: String = Loc.override_lang
	Loc.override_lang = "fr"
	t.call("check", Loc.t("play") == "JOUER", "français")
	Loc.override_lang = "en"
	t.call("check", Loc.t("play") == "PLAY", "anglais")
	t.call("check", Loc.t("wave_fmt", [7]) == "WAVE 7", "paramètre formaté")
	t.call(
		"check", Loc.t("clé_inexistante") == "clé_inexistante", "clé inconnue : la clé elle-même"
	)
	Loc.override_lang = saved


# --- Chargement ---


func test_load_progress_weights_and_monotonic_display() -> void:
	var p: LoadProgress = LoadProgress.new()
	p.add_group("a", 3.0, ["x", "y"] as Array[String])
	p.add_group("b", 1.0, ["z"] as Array[String])
	p.add_group("vide", 5.0, [] as Array[String])
	t.call("check", is_equal_approx(p.ratio(), 5.0 / 9.0), "groupe vide = terminé (5/9)")
	p.set_done("a", 1)
	t.call("check", is_equal_approx(p.ratio(), (5.0 + 1.5) / 9.0), "moitié du groupe a")
	p.set_done("a", 99)
	t.call("check", p.paths_of("a").size() == 2 and p.ratio() < 1.0, "compteur plafonné")
	p.set_done("b", 1)
	t.call("check", p.complete(), "tout chargé")
	var q: LoadProgress = LoadProgress.new()
	q.add_group("g", 1.0, ["1", "2", "3", "4"] as Array[String])
	var last: float = 0.0
	for i: int in 20:
		q.set_done("g", mini(i / 4, 4))
		var d: float = q.step_display(0.05)
		t.call("check", d >= last, "affichage jamais en arrière")
		last = d
	t.call("check", last <= q.ratio() + 0.0001, "affichage ne dépasse pas le réel")


func test_load_manifest_lists_real_resources() -> void:
	var p: LoadProgress = LoadProgress.new()
	LoadManifest.fill(p, LoadManifest.GAMEPLAY_SCENE)
	t.call(
		"check",
		p.paths_of("scene").size() == 1 and ResourceLoader.exists(p.paths_of("scene")[0]),
		"la scène existe"
	)
	for path: String in p.paths_of("models"):
		t.call("check", ResourceLoader.exists(path), "modèle présent : " + path)
	t.call("check", p.paths_of("ui").size() > 50, "textures d'interface listées")
	t.call("check", p.paths_of("audio").size() > 50, "sons listés")
	var menu: LoadProgress = LoadProgress.new()
	LoadManifest.fill(menu, LoadManifest.MENU_SCENE)
	t.call("check", ResourceLoader.exists(menu.paths_of("scene")[0]), "scène du menu présente")


# --- Éléments d'interface -------------------------------------------------------------------------


func test_ui_art_files_exist() -> void:
	for style: String in AxButton.STYLES:
		for prefix: String in ["btn_", "btn_s_", "btn_round_"]:
			t.call("check", UiArt.has_tex("buttons/" + prefix + style), "bouton " + prefix + style)
	for p: String in [
		"panels/panel_light",
		"panels/panel_dark",
		"panels/panel_card",
		"panels/panel_gold",
		"panels/plate_dark",
		"panels/plate_light",
		"bars/bar_frame",
		"bars/bar_red",
		"bars/bar_green",
		"bars/bar_yellow",
		"bars/bar_blue",
		"bars/bar_white",
		"bars/toggle_on",
		"bars/toggle_off",
		"bars/knob_white",
		"bars/knob_yellow",
		"bars/slider_track",
		"misc/joy_base",
		"misc/joy_knob",
		"misc/badge_red",
		"misc/rays",
		"brand/logo",
		"brand/banner_blue",
		"brand/banner_red",
		"brand/banner_yellow",
		"brand/app_icon",
		"brand/splash_blank"
	]:
		t.call("check", UiArt.has_tex(p), "élément " + p)
	for icon: String in [
		"play",
		"pause",
		"back",
		"close",
		"check",
		"plus",
		"home",
		"replay",
		"lock",
		"music",
		"sound",
		"vibrate",
		"graphics",
		"chart",
		"globe",
		"video",
		"speed",
		"speed_blue",
		"heart",
		"skull",
		"skull_red",
		"clock",
		"gear",
		"axe",
		"axe_light",
		"axe_heavy",
		"axe_multi",
		"axe_pierce",
		"bolt",
		"coin",
		"coin_s",
		"coin_plus",
		"trophy",
		"trophy_s",
		"star",
		"gift",
		"shield"
	]:
		t.call("check", UiArt.has_tex("icons/" + icon), "icône " + icon)
	t.call("check", UiArt.font() != null, "police chargée")


func test_upgrades_screen_buy_flow() -> void:
	var sm: Node = SaveManager
	var saved_path: String = sm.path_override
	var saved_data: SaveData = sm.data
	sm.path_override = TMP_SAVE
	_cleanup(TMP_SAVE)
	sm.data = SaveData.new()
	sm.data.coins = 100
	var screen: UpgradesScreen = UpgradesScreen.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	t.call("check", screen._rows.size() == PermanentUpgrades.count(), "une ligne par amélioration")
	var hp_buy: AxButton = screen._rows[0]["buy"] as AxButton
	var rate_buy: AxButton = screen._rows[3]["buy"] as AxButton
	t.call("check", not hp_buy.disabled and hp_buy.text == "60", "coût affiché 60")
	hp_buy.pressed.emit()
	t.call("check", sm.coins() == 40 and sm.perm_level(0) == 1, "l'achat débite et améliore")
	t.call("check", hp_buy.text == "90", "coût suivant 90")
	rate_buy.pressed.emit()
	t.call("check", sm.coins() == 40 and sm.perm_level(3) == 0, "refus : pièces insuffisantes")
	screen.queue_free()
	_cleanup(TMP_SAVE)
	sm.data = saved_data
	sm.path_override = saved_path


func test_widgets_state() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var toggle: AxToggle = AxToggle.new()
	root.add_child(toggle)
	toggle.set_on(true)
	t.call("check", toggle.button_pressed, "interrupteur allumé")
	toggle.queue_free()
	var slider: AxSlider = AxSlider.new()
	slider.steps = 10
	root.add_child(slider)
	slider.size = Vector2(430, 76)
	var changes: Array[int] = []
	slider.value_changed.connect(func(v: int) -> void: changes.append(v))
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = Vector2(430.0 - 34.0, 38.0)
	slider._gui_input(ev)
	t.call(
		"check",
		slider.value == 10 and changes == [10],
		"toucher la fin = cran maximum, un seul signal"
	)
	slider._gui_input(ev)
	t.call("check", changes.size() == 1, "même cran : pas de nouveau signal")
	slider.queue_free()
	var bar: AxBar = AxBar.new()
	root.add_child(bar)
	bar.set_ratio(0.4, false)
	t.call("check", is_equal_approx(bar.ratio, 0.4), "barre à 40 %")
	bar.set_ratio(2.0, false)
	t.call("check", bar.ratio == 1.0, "barre bornée")
	bar.queue_free()
	var seg: AxSegment = AxSegment.new()
	root.add_child(seg)
	seg.setup(["A", "B", "C"] as Array[String], 0)
	seg.set_locked(2, true)
	var picks: Array[int] = []
	seg.selected_changed.connect(func(i: int) -> void: picks.append(i))
	var locked_hits: Array[int] = []
	seg.locked_pressed.connect(func(i: int) -> void: locked_hits.append(i))
	seg._buttons[2].pressed.emit()
	seg._buttons[1].pressed.emit()
	t.call(
		"check",
		picks == [1] and locked_hits == [2] and seg.selected == 1,
		"choix verrouillé refusé, choix libre accepté"
	)
	seg.queue_free()


func test_stats_screen_values_and_time_format() -> void:
	t.call("check", StatsScreen.format_time(65.0) == "1:05", "1:05")
	t.call("check", StatsScreen.format_time(3725.0) == "1h 02m", "1h 02m")
	t.call("check", StatsScreen.format_time(0.0) == "0:00", "zéro")
