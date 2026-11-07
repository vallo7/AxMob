extends RefCounted
## Phase 3 : coûts, niveaux de tourelles, niveaux d'ennemis, rythme adaptatif, phases du boss,
## table de vagues. Logique pure : aucune scène.

var t: Object


func _balance() -> BalanceConfig:
	return DataRegistry.balance()


func test_cost_curve_matches_formula() -> void:
	t.call("check", CostCurve.cost(14.0, 1.5, 1) == 14, "niveau 1 -> 2 = base")
	t.call("check", CostCurve.cost(14.0, 1.5, 2) == 21, "niveau 2 -> 3 = base × 1,5")
	t.call("check", CostCurve.cost(10.0, 2.0, 4) == 80, "10 × 2^3")
	t.call("check", CostCurve.cost(10.0, 2.0, 1, 1.5) == 15, "facteur de catégorie")
	t.call("check", CostCurve.cost(0.0, 1.5, 1) == 1, "jamais gratuit")
	var previous: int = 0
	for level: int in range(1, 10):
		var c: int = CostCurve.cost(14.0, 1.5, level)
		t.call("check", c > previous, "coût strictement croissant au niveau %d" % level)
		previous = c
	t.call("check", CostCurve.total_to(14.0, 1.5, 1) == 0)
	t.call("check", CostCurve.total_to(14.0, 1.5, 3) == 14 + 21)


func test_every_turret_has_ten_monotonic_levels() -> void:
	for data: TurretData in DataRegistry.turrets():
		var table: Array[TurretLevelData] = TurretLeveling.build(data)
		t.call("check", table.size() == 10, "%s : 10 niveaux (%d)" % [data.id, table.size()])
		t.call(
			"check", is_equal_approx(table[0].damage, data.damage), "%s : niveau 1 = base" % data.id
		)
		t.call("check", is_equal_approx(table[0].attack_range, data.attack_range))
		for i: int in range(1, table.size()):
			var a: TurretLevelData = table[i - 1]
			var b: TurretLevelData = table[i]
			t.call("check", b.level == i + 1, "numérotation")
			t.call(
				"check", b.damage > a.damage, "%s : dégâts croissants niv %d" % [data.id, b.level]
			)
			t.call("check", b.fire_rate >= a.fire_rate, "%s : cadence" % data.id)
			t.call("check", b.attack_range >= a.attack_range, "%s : portée" % data.id)
			t.call("check", b.rotation_speed >= a.rotation_speed, "%s : rotation" % data.id)
			t.call("check", b.axe_count >= a.axe_count, "%s : nombre de haches" % data.id)
			t.call("check", b.pierce >= a.pierce, "%s : perforation" % data.id)
			t.call("check", b.visual_tier >= a.visual_tier, "%s : palier visuel" % data.id)
		var dps_1: float = table[0].damage * table[0].fire_rate * float(table[0].axe_count)
		var dps_10: float = table[9].damage * table[9].fire_rate * float(table[9].axe_count)
		t.call(
			"check", dps_10 >= dps_1 * 3.0, "%s : le niveau 10 est nettement plus fort" % data.id
		)


func test_visual_tiers_follow_levels() -> void:
	var data: TurretData = DataRegistry.turrets()[0]
	var expected: Array[int] = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3]
	for level: int in range(1, 11):
		t.call(
			"check",
			TurretLeveling.tier_of(data, level) == expected[level - 1],
			"palier niv %d" % level
		)


func test_category_specific_progressions() -> void:
	var by_id: Dictionary = {}
	for data: TurretData in DataRegistry.turrets():
		by_id[data.id] = TurretLeveling.build(data)
	var multi: Array = by_id[&"multi"] as Array
	var pierce: Array = by_id[&"pierce"] as Array
	t.call(
		"check",
		(multi[0] as TurretLevelData).axe_count >= 3,
		"la multiple lance plusieurs haches dès le niveau 1"
	)
	t.call(
		"check", (multi[9] as TurretLevelData).axe_count > (multi[0] as TurretLevelData).axe_count
	)
	t.call(
		"check",
		(multi[9] as TurretLevelData).fan_angle_deg > (multi[0] as TurretLevelData).fan_angle_deg,
		"l'éventail s'ouvre"
	)
	t.call(
		"check",
		(pierce[9] as TurretLevelData).pierce > (pierce[0] as TurretLevelData).pierce,
		"la perforation progresse"
	)


func test_hand_written_levels_override_curves() -> void:
	var data: TurretData = TurretData.new()
	var row: TurretLevelData = TurretLevelData.new()
	row.level = 1
	row.damage = 99.0
	data.levels = [row]
	var table: Array[TurretLevelData] = TurretLeveling.build(data)
	t.call("check", table.size() == 1 and table[0].damage == 99.0, "table manuelle prioritaire")


func test_describe_shows_preview_and_max() -> void:
	var data: TurretData = DataRegistry.turrets()[0]
	var table: Array[TurretLevelData] = TurretLeveling.build(data)
	var lines: PackedStringArray = TurretLeveling.describe(table[0], table[1])
	t.call("check", lines.size() >= 4)
	t.call("check", lines[0].contains("→"), "aperçu du changement : « %s »" % lines[0])
	var at_max: PackedStringArray = TurretLeveling.describe(table[9], null)
	for line: String in at_max:
		t.call("check", not line.contains("→"), "pas d'aperçu au niveau max : « %s »" % line)
	var pierce: TurretData = null
	for d: TurretData in DataRegistry.turrets():
		if d.id == &"pierce":
			pierce = d
	var pierce_table: Array[TurretLevelData] = TurretLeveling.build(pierce)
	var has_pierce_line: bool = false
	for line: String in TurretLeveling.describe(pierce_table[0], pierce_table[1]):
		has_pierce_line = has_pierce_line or line.begins_with("Perforation")
	t.call("check", has_pierce_line, "la perforante affiche sa perforation")


func test_enemy_level_multipliers() -> void:
	var b: BalanceConfig = _balance()
	t.call("check", is_equal_approx(EnemyLevels.hp_mult(b, 1), 1.0))
	t.call("check", is_equal_approx(EnemyLevels.damage_mult(b, 1), 1.0))
	t.call("check", is_equal_approx(EnemyLevels.speed_mult(b, 1), 1.0))
	t.call(
		"check", is_equal_approx(EnemyLevels.hp_mult(b, 3), b.level_hp_growth * b.level_hp_growth)
	)
	for level: int in range(1, 20):
		t.call(
			"check",
			EnemyLevels.hp_mult(b, level + 1) > EnemyLevels.hp_mult(b, level),
			"PV croissants"
		)
		t.call(
			"check",
			EnemyLevels.speed_mult(b, level) <= b.level_speed_cap + 0.0001,
			"vitesse plafonnée"
		)
		t.call(
			"check",
			EnemyLevels.reward(1, b, level + 1) >= EnemyLevels.reward(1, b, level),
			"récompense croissante"
		)
	t.call("check", EnemyLevels.reward(0, b, 1) == 1, "récompense minimale 1")
	t.call("check", EnemyLevels.tint_tier(1) == 0 and EnemyLevels.tint_tier(2) == 0)
	t.call("check", EnemyLevels.tint_tier(3) == 1 and EnemyLevels.tint_tier(5) == 2)
	t.call("check", EnemyLevels.tint_tier(99) == EnemyLevels.TINT_TIERS - 1, "teinte bornée")


func test_level_for_spawn_blends_smoothly() -> void:
	var b: BalanceConfig = _balance()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	for i: int in 50:
		t.call("check", EnemyLevels.level_for_spawn(b, 1, rng) == 1, "vague 1 : toujours niveau 1")
	# Vague 4 = exactement 1 + 3/3 = niveau 2 (tous).
	for i: int in 50:
		t.call("check", EnemyLevels.level_for_spawn(b, 4, rng) == 2, "vague 4 : niveau 2")
	# Vague 2 : 1/3 de niveau 2, 2/3 de niveau 1 ; jamais d'autre valeur.
	var sum: float = 0.0
	var n: int = 6000
	for i: int in n:
		var lv: int = EnemyLevels.level_for_spawn(b, 2, rng)
		t.call("check", lv == 1 or lv == 2, "mélange limité à deux niveaux")
		sum += float(lv)
	var mean: float = sum / float(n)
	t.call(
		"check",
		absf(mean - EnemyLevels.wave_level(b, 2)) < 0.03,
		"moyenne %.3f ≈ %.3f" % [mean, EnemyLevels.wave_level(b, 2)]
	)
	for wave: int in range(1, 200, 7):
		var lv: int = EnemyLevels.level_for_spawn(b, wave, rng)
		t.call("check", lv >= 1 and lv <= b.max_enemy_level, "niveau borné")


func test_adaptive_pacing_is_bounded_and_monotonic() -> void:
	var b: BalanceConfig = _balance()
	t.call("check", is_equal_approx(AdaptivePacing.factor(b, 0.5, 0.5), 1.0), "neutre au milieu")
	var low: float = 1.0 - b.pacing_max - 0.0001
	var high: float = 1.0 + b.pacing_max + 0.0001
	for hp: float in [0.0, 0.25, 0.5, 0.75, 1.0, 3.0, -1.0]:
		for ratio: float in [0.0, 0.3, 0.5, 0.8, 1.0, 2.0, -1.0]:
			var f: float = AdaptivePacing.factor(b, hp, ratio)
			t.call(
				"check", f >= low and f <= high, "borné ±%.0f %% (%.3f)" % [b.pacing_max * 100.0, f]
			)
	t.call(
		"check",
		AdaptivePacing.factor(b, 1.0, 0.5) > AdaptivePacing.factor(b, 0.2, 0.5),
		"PV hauts = plus rapide"
	)
	t.call(
		"check",
		AdaptivePacing.factor(b, 0.5, 1.0) > AdaptivePacing.factor(b, 0.5, 0.0),
		"bon taux d'élimination = plus rapide"
	)
	t.call("check", AdaptivePacing.factor(b, 1.0, 1.0) <= 1.0 + b.pacing_max + 0.0001)
	t.call("check", AdaptivePacing.factor(b, 0.0, 0.0) >= 1.0 - b.pacing_max - 0.0001)


func test_boss_phase_rules() -> void:
	var th: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
	t.call("check", BossPhases.phase_for(1.0, th) == 1)
	t.call("check", BossPhases.phase_for(0.67, th) == 1)
	t.call("check", BossPhases.phase_for(0.66, th) == 2, "seuil inclus")
	t.call("check", BossPhases.phase_for(0.5, th) == 2)
	t.call("check", BossPhases.phase_for(0.33, th) == 3)
	t.call("check", BossPhases.phase_for(0.0, th) == 3)
	t.call(
		"check",
		not BossPhases.can_charge(1) and BossPhases.can_charge(2) and BossPhases.can_charge(3)
	)
	t.call("check", not BossPhases.can_summon(2) and BossPhases.can_summon(3))
	t.call("check", BossPhases.recover_scale(1) > BossPhases.recover_scale(2))
	t.call("check", BossPhases.recover_scale(2) > BossPhases.recover_scale(3))


func test_wave_table_unlocks_and_boss_cadence() -> void:
	var table: WaveTable = DataRegistry.wave_table()
	t.call("check", table != null and table.boss is BossData, "boss chargé")
	t.call("check", table.boss_every == 10)
	for wave: int in [10, 20, 30, 100]:
		t.call("check", table.is_boss_wave(wave), "vague %d = boss" % wave)
	for wave: int in [0, 1, 9, 11, 19, 25]:
		t.call("check", not table.is_boss_wave(wave), "vague %d sans boss" % wave)
	t.call(
		"check",
		table.boss_level(10) == 1 and table.boss_level(20) == 2 and table.boss_level(30) == 3
	)
	var empty: WaveTable = WaveTable.new()
	t.call("check", not empty.is_boss_wave(10), "pas de boss défini = pas de vague de boss")
	var ids_at: Callable = func(wave: int) -> Array:
		var ids: Array = []
		for d: EnemyData in WaveBudget.available(table.enemies, wave):
			ids.append(d.id)
		return ids
	t.call("check", (ids_at.call(1) as Array) == [&"basic"], "vague 1 : basique seul")
	t.call("check", (ids_at.call(3) as Array).has(&"fast"), "rapide dès la vague 3")
	t.call("check", not (ids_at.call(4) as Array).has(&"heavy"), "pas de lourd avant 5")
	t.call("check", (ids_at.call(5) as Array).has(&"heavy"), "lourd dès la vague 5")
	t.call("check", not (ids_at.call(6) as Array).has(&"elite"), "pas d'élite avant 7")
	t.call("check", (ids_at.call(7) as Array).has(&"elite"), "élite dès la vague 7")
	t.call(
		"check",
		not (ids_at.call(50) as Array).has(&"boss"),
		"le boss n'est pas dans la composition normale"
	)


func test_boss_and_elite_data_are_coherent() -> void:
	var boss: BossData = DataRegistry.wave_table().boss
	t.call("check", boss.max_hp > 500.0 and boss.radius > 1.0, "boss grand et résistant")
	t.call(
		"check",
		boss.bar_always and boss.target_priority > 0.0,
		"barre visible et priorité de ciblage"
	)
	t.call("check", boss.stagger_scale <= 0.0, "le boss ne se laisse pas interrompre")
	t.call("check", boss.phase_thresholds.size() == 2, "trois phases")
	t.call("check", boss.summon_enemy != null, "invocation configurée")
	t.call("check", boss.warning_time >= 1.5, "avertissement d'environ 2 s")
	var elite: EnemyData = null
	for d: EnemyData in DataRegistry.enemies():
		if d.id == &"elite":
			elite = d
	t.call("check", elite != null and elite.bar_always, "élite : barre de vie toujours visible")
	t.call("check", elite.reward > DataRegistry.enemies()[2].reward, "récompense d'élite élevée")
	t.call("check", elite.target_priority > 0.0)
