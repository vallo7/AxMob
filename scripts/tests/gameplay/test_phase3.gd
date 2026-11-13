extends RefCounted
## Phase 3 sur la vraie scène Gameplay : améliorations, modes de pause, boss, niveaux d'ennemis,
## navigation par le bouton retour, taille de l'arène dans le cadre de l'écran.

const DT: float = 1.0 / 60.0

var t: Object


func _make_gameplay() -> Gameplay:
	var tree: SceneTree = t as SceneTree
	var g: Gameplay = (
		(load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	)
	g.set_physics_process(false)
	g.run_seed = 4242
	tree.root.add_child(g)
	await tree.process_frame
	return g


func _free_gameplay(g: Gameplay) -> void:
	(t as SceneTree).paused = false
	(t as SceneTree).root.remove_child(g)
	g.free()


func _enemies(g: Gameplay) -> EnemyManager:
	return g.get_node("World/Enemies") as EnemyManager


func _spawn_boss(g: Gameplay, pos: Vector2, level: int = 1) -> Enemy:
	var boss: BossData = DataRegistry.wave_table().boss
	var id: int = _enemies(g).spawn(boss, pos, level)
	var e: Enemy = g.ctx.enemies.slots[id]
	e.state = Enemy.State.CHASE
	e.state_time = 0.0
	return e


func _hit(id: int, damage: float) -> void:
	EventBus.axe_hit.emit(id, damage, 0, Vector2.ZERO)


func _press_back() -> void:
	(t as SceneTree).root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)


# --- Améliorations ---


func test_upgrade_purchase_rules() -> void:
	var g: Gameplay = await _make_gameplay()
	var upgraded: Array[Vector2i] = []
	var denied: Array[int] = []
	var coins_seen: Array[int] = []
	var l1: Callable = func(id: int, lv: int) -> void: upgraded.append(Vector2i(id, lv))
	var l2: Callable = func(id: int) -> void: denied.append(id)
	var l3: Callable = func(total: int) -> void: coins_seen.append(total)
	EventBus.turret_upgraded.connect(l1)
	EventBus.upgrade_denied.connect(l2)
	EventBus.coins_changed.connect(l3)
	var ups: UpgradeManager = g._upgrades
	g.ctx.coins = 100
	t.call("check", ups.cost_to_upgrade(0) == 14, "coût niv 1 -> 2 = base")
	t.call("check", ups.try_upgrade(0), "achat accepté")
	t.call(
		"check",
		g.ctx.coins == 86 and g.ctx.coins_spent == 14,
		"14 pièces dépensées exactement une fois"
	)
	t.call("check", g.ctx.turret_levels[0] == 2, "niveau 2")
	t.call("check", upgraded == [Vector2i(0, 2)], "turret_upgraded émis une fois")
	t.call("check", coins_seen == [86], "coins_changed publie le nouveau solde")
	var turret: Turret = g._turrets.turrets[0]
	t.call(
		"check",
		turret.level == 2 and turret.stats.damage > turret.data.damage,
		"la tourelle applique le niveau"
	)
	var b: BalanceConfig = g.ctx.balance
	t.call(
		"check",
		ups.cost_to_upgrade(0) == CostCurve.cost(b.upgrade_cost_base, b.upgrade_cost_mult, 2),
		"prochain coût × multiplicateur"
	)
	t.call("check", ups.cost_to_upgrade(0) > 14, "le coût augmente")
	t.call("check", g.ctx.turret_levels[1] == 1, "les autres tourelles ne bougent pas")
	g.ctx.coins = 5
	t.call("check", not ups.try_upgrade(0), "pièces insuffisantes : refusé")
	t.call("check", g.ctx.coins == 5 and g.ctx.turret_levels[0] == 2, "rien n'a changé")
	t.call("check", denied == [0], "upgrade_denied émis")
	t.call("check", g._economy.can_afford(5) and not g._economy.can_afford(6))
	t.call("check", not g._economy.spend(-3), "dépense négative impossible")
	t.call("check", g.ctx.coins == 5)
	g.ctx.coins = 100000
	while ups.cost_to_upgrade(0) >= 0:
		t.call("check", ups.try_upgrade(0))
	t.call("check", g.ctx.turret_levels[0] == 10 and ups.is_max(0), "niveau maximal 10")
	t.call(
		"check",
		g.ctx.coins_spent == CostCurve.total_to(b.upgrade_cost_base, b.upgrade_cost_mult, 10),
		"total dépensé = somme de la courbe"
	)
	var before: int = g.ctx.coins
	t.call("check", not ups.try_upgrade(0), "au maximum : refusé")
	t.call("check", g.ctx.coins == before and g.ctx.turret_levels[0] == 10)
	EventBus.turret_upgraded.disconnect(l1)
	EventBus.upgrade_denied.disconnect(l2)
	EventBus.coins_changed.disconnect(l3)
	_free_gameplay(g)


func test_turret_visual_tiers_appear_with_levels() -> void:
	var g: Gameplay = await _make_gameplay()
	g.ctx.coins = 1000000
	var turret: Turret = g._turrets.turrets[0]
	var parts: Array[Node] = [
		turret.find_child("Tier_1", true, false),
		turret.find_child("Tier_2", true, false),
		turret.find_child("Tier_3", true, false),
	]
	t.call(
		"check",
		parts[0] != null and parts[1] != null and parts[2] != null,
		"pièces Tier_1..3 présentes"
	)
	var expected: Dictionary = {
		1: [false, false, false],
		3: [false, false, false],
		4: [true, false, false],
		6: [true, false, false],
		7: [true, true, false],
		9: [true, true, false],
		10: [true, true, true],
	}
	for level: int in range(1, 11):
		if expected.has(level):
			var want: Array = expected[level]
			for i: int in 3:
				t.call(
					"check",
					(parts[i] as Node3D).visible == want[i],
					"niv %d : palier %d" % [level, i + 1]
				)
		g._upgrades.try_upgrade(0)
	_free_gameplay(g)


func test_turret_dock_quick_buy_and_upgrade_panel() -> void:
	var g: Gameplay = await _make_gameplay()
	var panel: TurretUpgradePanel = g._panel
	var dock: TurretDock = g._hud.dock
	t.call("check", dock.slot_count() == 4, "la barre du bas contient 4 boutons de tourelle")
	g.ctx.coins = 0
	g._hud._process(DT)
	dock.refresh()
	t.call("check", dock.slot(0)._state == "stone", "sans pièces : boutons non abordables")
	g.ctx.coins = 30
	dock.refresh()
	t.call("check", dock.slot(0)._state == "gold", "avec des pièces : bouton doré (abordable)")
	# Achat rapide : un toucher sur le bouton améliore la tourelle immédiatement, sans pause.
	var before: int = g.ctx.coins
	dock.slot(0).tapped.emit()
	t.call(
		"check",
		g.ctx.turret_levels[0] == 2 and g.ctx.coins == before - 14,
		"toucher le bouton améliore et dépense (14 pièces)"
	)
	t.call("check", g.state == Gameplay.State.RUN, "achat rapide : le jeu continue")
	g.ctx.coins = 1
	var lvl: int = g.ctx.turret_levels[0]
	dock.slot(0).tapped.emit()
	t.call("check", g.ctx.turret_levels[0] == lvl, "pièces insuffisantes : rien")
	g.ctx.turret_levels[0] = 1
	g.ctx.coins = 30
	g._toggle_upgrades()
	t.call("check", g.state == Gameplay.State.UPGRADING and panel.is_open(), "le panneau s'ouvre")
	var card: TurretCard = panel._cards[0]
	t.call(
		"check",
		card._button.text.contains("14"),
		"le bouton affiche le coût (« %s »)" % card._button.text
	)
	t.call("check", card._level.text == "NIV 1/10")
	card._button.pressed.emit()
	t.call(
		"check", g.ctx.turret_levels[0] == 2 and g.ctx.coins == 16, "le bouton améliore et dépense"
	)
	t.call("check", card._level.text == "NIV 2/10", "la carte se met à jour")
	g.ctx.coins = 1
	card._button.pressed.emit()
	t.call("check", g.ctx.turret_levels[0] == 2, "pièces insuffisantes : rien")
	t.call("check", UIManager.current_toast() == "Pièces insuffisantes", "message affiché")
	g._close_upgrades()
	t.call("check", g.state == Gameplay.State.RUN and not panel.is_open())
	_free_gameplay(g)


func test_upgrade_pause_modes() -> void:
	var g: Gameplay = await _make_gameplay()
	var original: GameConfig.UpgradePause = g.ctx.config.upgrade_pause
	var expected: Dictionary = {
		GameConfig.UpgradePause.FULL_STOP: 0.0,
		GameConfig.UpgradePause.SLOW: 60.0 * DT * g.ctx.config.upgrade_slow_scale,
		GameConfig.UpgradePause.NONE: 60.0 * DT,
	}
	for mode: GameConfig.UpgradePause in expected:
		g.ctx.config.upgrade_pause = mode
		g._toggle_upgrades()
		var t0: float = g.ctx.time
		for i: int in 60:
			g._physics_process(DT)
		var elapsed: float = g.ctx.time - t0
		t.call(
			"check",
			absf(elapsed - (expected[mode] as float)) < 0.001,
			"mode %d : %.3f s simulées (attendu %.3f)" % [mode, elapsed, expected[mode]]
		)
		t.call(
			"check",
			g._joystick.enabled == (mode != GameConfig.UpgradePause.FULL_STOP),
			"mode %d : joystick" % mode
		)
		g._toggle_upgrades()
		t.call(
			"check", g.state == Gameplay.State.RUN and g._joystick.enabled, "fermé : le jeu reprend"
		)
	g.ctx.config.upgrade_pause = original
	_free_gameplay(g)


func test_joystick_ignores_touches_on_the_panel() -> void:
	var g: Gameplay = await _make_gameplay()
	var sheet: Rect2 = g._panel.sheet_rect()
	var inside: Vector2 = sheet.get_center()
	var outside: Vector2 = Vector2(500.0, 1000.0)
	t.call("check", g._joystick._in_zone(inside), "sans panneau, la zone basse démarre le joystick")
	g.ctx.config.upgrade_pause = GameConfig.UpgradePause.NONE
	g._toggle_upgrades()
	t.call("check", not g._joystick._in_zone(inside), "sur le panneau : pas de joystick")
	t.call(
		"check",
		g._joystick._in_zone(outside),
		"hors panneau : le joystick marche (mode sans pause)"
	)
	g._toggle_upgrades()
	g.ctx.config.upgrade_pause = GameConfig.UpgradePause.FULL_STOP
	_free_gameplay(g)


# --- Niveaux d'ennemis, élite ---


func test_enemy_level_stats_reward_and_tint() -> void:
	var g: Gameplay = await _make_gameplay()
	var em: EnemyManager = _enemies(g)
	var basic: EnemyData = DataRegistry.enemies()[0]
	var b: BalanceConfig = g.ctx.balance
	var id1: int = em.spawn(basic, Vector2(5.0, 0.0), 1)
	var id4: int = em.spawn(basic, Vector2(-5.0, 0.0), 4)
	var e1: Enemy = g.ctx.enemies.slots[id1]
	var e4: Enemy = g.ctx.enemies.slots[id4]
	t.call("check", is_equal_approx(e1.health.max_hp, basic.max_hp), "niveau 1 : PV de base")
	t.call(
		"check",
		is_equal_approx(e4.health.max_hp, basic.max_hp * pow(b.level_hp_growth, 3.0)),
		"niveau 4 : PV × croissance³"
	)
	t.call("check", e4.damage_mult > e1.damage_mult and e4.speed_mult >= e1.speed_mult)
	t.call(
		"check",
		e4.reward_value > e1.reward_value,
		"récompense par niveau (%d -> %d)" % [e1.reward_value, e4.reward_value]
	)
	t.call(
		"check",
		(
			e1.rig != null
			and e4.rig != null
			and not e1.rig.get_tint().is_equal_approx(e4.rig.get_tint())
		),
		"teinte (paramètre de shader) différente selon le niveau"
	)
	e4.state = Enemy.State.CHASE
	var rewards: Array[int] = []
	var l: Callable = func(_i: int, r: int, _p: Vector3) -> void: rewards.append(r)
	EventBus.enemy_died.connect(l)
	_hit(id4, 1.0e6)
	_hit(id4, 1.0e6)
	t.call("check", rewards == [e4.reward_value], "récompense du niveau attribuée une seule fois")
	EventBus.enemy_died.disconnect(l)
	_free_gameplay(g)


func test_elite_has_priority_and_visible_bar() -> void:
	var g: Gameplay = await _make_gameplay()
	var elite: EnemyData = null
	for d: EnemyData in DataRegistry.enemies():
		if d.id == &"elite":
			elite = d
	var id: int = _enemies(g).spawn(elite, Vector2(4.0, 0.0), 1)
	var e: Enemy = g.ctx.enemies.slots[id]
	e.state = Enemy.State.CHASE
	t.call("check", e.data.bar_always and e.is_hittable(), "barre toujours visible")
	var basic: Enemy = g.ctx.enemies.slots[_enemies(g).spawn(
		DataRegistry.enemies()[0], Vector2(-4.0, 0.0), 1
	)]
	basic.state = Enemy.State.CHASE
	t.call(
		"check",
		basic.bar_until < g.ctx.time,
		"barre d'un ennemi normal : cachée tant qu'il n'est pas touché"
	)
	_hit(basic.id, 1.0)
	t.call("check", basic.bar_until > g.ctx.time, "barre affichée après un impact")
	g.step(2.6)
	t.call(
		"check",
		basic.bar_until < g.ctx.time or not basic.is_hittable(),
		"barre masquée ~2,5 s plus tard"
	)
	_free_gameplay(g)


# --- Boss ---


func test_boss_wave_warning_then_spawn_then_clear() -> void:
	var g: Gameplay = await _make_gameplay()
	var warnings: Array[Dictionary] = []
	var spawned: Array[int] = []
	var completed: Array[int] = []
	var l1: Callable = func(w: int, s: float, p: Vector2) -> void:
		warnings.append({"wave": w, "s": s, "p": p, "at": g.ctx.time})
	var l2: Callable = func(id: int) -> void: spawned.append(id)
	var l3: Callable = func(w: int) -> void: completed.append(w)
	EventBus.boss_warning.connect(l1)
	EventBus.boss_spawned.connect(l2)
	EventBus.wave_completed.connect(l3)
	g.ctx.wave = 9
	var spawn_time: float = -1.0
	var living_at_spawn: int = -1
	var steps: int = 0
	while spawned.is_empty() and steps < 60 * 10:
		g._player.health.hp = g._player.health.max_hp
		g.step(DT)
		steps += 1
		if not spawned.is_empty():
			spawn_time = g.ctx.time
			living_at_spawn = g.ctx.enemies.count_living()
	t.call(
		"check", warnings.size() == 1 and warnings[0]["wave"] == 10, "avertissement à la vague 10"
	)
	t.call("check", spawned.size() == 1, "un seul boss")
	if warnings.size() == 1 and spawned.size() == 1:
		var lead: float = spawn_time - (warnings[0]["at"] as float)
		t.call(
			"check",
			(
				lead >= (warnings[0]["s"] as float) - 0.03
				and lead <= (warnings[0]["s"] as float) + 0.1
			),
			"le boss apparaît ~%.1f s après l'avertissement (%.2f)" % [warnings[0]["s"], lead]
		)
		t.call("check", is_equal_approx(warnings[0]["s"] as float, 2.0), "avertissement de 2 s")
		var p: Vector2 = warnings[0]["p"]
		var boss: BossData = DataRegistry.wave_table().boss
		t.call(
			"check",
			p.distance_to(g.ctx.shape.water_point(IslandShape.theta_of(p), boss.radius)) < 0.001,
			"le boss sort de la mer (rivage, côté ennemis)"
		)
		t.call("check", g.ctx.boss_id == spawned[0], "ctx.boss_id renseigné")
		var e: Enemy = g.ctx.enemies.slots[spawned[0]]
		t.call(
			"check",
			e.is_boss() and e.level == 1 and e.pos.distance_to(p) < 0.01,
			"boss de niveau 1 au point annoncé"
		)
		t.call(
			"check",
			living_at_spawn == 1,
			"rien d'autre n'apparaît pendant l'avertissement (%d)" % living_at_spawn
		)
	# La vague n'est pas terminée tant que le boss vit.
	for i: int in 240:
		g._player.health.hp = g._player.health.max_hp
		g.step(DT)
	t.call("check", completed.is_empty(), "pas de fin de vague tant que le boss est en vie")
	steps = 0
	while completed.is_empty() and steps < 60 * 90:
		g._player.health.hp = g._player.health.max_hp
		for e: Enemy in g.ctx.enemies.slots:
			if e.is_hittable():
				_hit(e.id, 1.0e7)
		g.step(DT)
		steps += 1
	t.call(
		"check", completed == [10], "vague 10 terminée une fois tout éliminé (%s)" % str(completed)
	)
	t.call("check", g.ctx.bosses_defeated == 1 and g.ctx.boss_id == -1, "boss vaincu compté")
	EventBus.boss_warning.disconnect(l1)
	EventBus.boss_spawned.disconnect(l2)
	EventBus.wave_completed.disconnect(l3)
	_free_gameplay(g)


func test_boss_phases_reward_and_no_stagger() -> void:
	var g: Gameplay = await _make_gameplay()
	var phases: Array[int] = []
	var defeated: Array[Vector2i] = []
	var died: Array[int] = []
	var l1: Callable = func(_i: int, p: int) -> void: phases.append(p)
	var l2: Callable = func(i: int, r: int) -> void: defeated.append(Vector2i(i, r))
	var l3: Callable = func(i: int, _r: int, _p: Vector3) -> void: died.append(i)
	EventBus.boss_phase_changed.connect(l1)
	EventBus.boss_defeated.connect(l2)
	EventBus.enemy_died.connect(l3)
	var e: Enemy = _spawn_boss(g, Vector2(8.0, 0.0))
	var hp: float = e.health.max_hp
	_hit(e.id, 1.0)
	t.call(
		"check",
		e.state != Enemy.State.STAGGER and e.boss.phase == 1,
		"un impact n'interrompt pas le boss"
	)
	_hit(e.id, hp * 0.35)  # ~64 % : franchit 66 %
	t.call("check", phases == [2], "phase 2 annoncée une fois (%s)" % str(phases))
	t.call("check", e.state == Enemy.State.RECOVER, "rugissement au changement de phase")
	_hit(e.id, hp * 0.05)  # ~59 % : toujours phase 2
	t.call("check", phases == [2], "pas de nouvelle annonce dans la même phase")
	_hit(e.id, hp * 0.30)  # ~29 % : franchit 33 %
	t.call("check", phases == [2, 3] and e.boss.phase == 3, "phase 3")
	t.call("check", g.ctx.boss_id == e.id and defeated.is_empty(), "toujours vivant")
	var coins_before: int = g.ctx.coins
	_hit(e.id, hp)
	_hit(e.id, hp)
	t.call(
		"check",
		defeated == [Vector2i(e.id, 120)],
		"boss_defeated une fois, récompense 120 (%s)" % str(defeated)
	)
	t.call("check", died == [e.id], "enemy_died une fois")
	t.call(
		"check",
		g.ctx.coins == coins_before + 120 and g.ctx.bosses_defeated == 1,
		"pièces et compteur de boss"
	)
	t.call("check", g.ctx.boss_id == -1, "plus de boss actif")
	EventBus.boss_phase_changed.disconnect(l1)
	EventBus.boss_defeated.disconnect(l2)
	EventBus.enemy_died.disconnect(l3)
	_free_gameplay(g)


func test_boss_slam_hits_only_inside_radius() -> void:
	var g: Gameplay = await _make_gameplay()
	var landed: Array[float] = []
	var waves: Array[float] = []
	var l1: Callable = func(d: float, _s: Vector2) -> void: landed.append(d)
	var l2: Callable = func(_p: Vector2, r: float) -> void: waves.append(r)
	EventBus.enemy_attack_landed.connect(l1)
	EventBus.shockwave.connect(l2)
	var boss: BossData = DataRegistry.wave_table().boss
	# Joueur dans le rayon : touché.
	var e: Enemy = _spawn_boss(g, Vector2(2.6, 0.0))
	e.state = Enemy.State.WINDUP
	for i: int in 70:
		g.step(DT)
	t.call(
		"check", waves == [boss.shock_radius], "onde de choc émise avec son rayon (%s)" % str(waves)
	)
	t.call(
		"check",
		landed.size() == 1 and is_equal_approx(landed[0], boss.damage),
		"le joueur dans le rayon encaisse %.0f" % boss.damage
	)
	# Joueur hors du rayon : onde visible, aucun dégât.
	landed.clear()
	waves.clear()
	e.pos = Vector2(9.0, 0.0)
	g._player.teleport(Vector2(-3.0, 0.0))
	e.state = Enemy.State.WINDUP
	e.state_time = 0.0
	e.vel = Vector2.ZERO
	e.boss.charge_cooldown = 99.0
	for i: int in 70:
		g.step(DT)
		e.pos = Vector2(9.0, 0.0)
		if e.state != Enemy.State.WINDUP and not waves.is_empty():
			break
	t.call("check", waves.size() == 1, "l'onde de choc a lieu même sans cible")
	t.call("check", landed.is_empty(), "joueur hors du rayon : aucun dégât")
	EventBus.enemy_attack_landed.disconnect(l1)
	EventBus.shockwave.disconnect(l2)
	_free_gameplay(g)


func test_boss_charge_is_telegraphed_and_dodgeable() -> void:
	var g: Gameplay = await _make_gameplay()
	var landed: Array[float] = []
	var l1: Callable = func(d: float, _s: Vector2) -> void: landed.append(d)
	EventBus.enemy_attack_landed.connect(l1)
	var boss: BossData = DataRegistry.wave_table().boss
	var em: EnemyManager = _enemies(g)
	# 1) Charge sur un joueur immobile : télégraphiée, un seul impact, puis récupération.
	var e: Enemy = _spawn_boss(g, Vector2(8.0, 0.0))
	e.boss.phase = 2
	e.boss.charge_cooldown = 0.0
	g._player.teleport(Vector2.ZERO)
	g.step(DT)
	t.call("check", e.state == Enemy.State.CHARGE_WINDUP, "la charge commence par un armement")
	t.call("check", em._telegraph_line.visible, "ligne de charge visible pendant l'armement")
	var saw_charging: bool = false
	for i: int in 240:
		g._player.health.hp = g._player.health.max_hp
		g.step(DT)
		saw_charging = saw_charging or e.state == Enemy.State.CHARGING
		if e.state == Enemy.State.RECOVER:
			break
	t.call("check", saw_charging, "puis la charge")
	t.call(
		"check",
		landed.size() == 1 and absf(landed[0] - boss.damage * boss.charge_damage_mult) < 0.01,
		"un seul impact de %.0f (%s)" % [boss.damage * boss.charge_damage_mult, str(landed)]
	)
	t.call("check", e.boss.charge_cooldown > 0.0, "temps de recharge de la charge")
	t.call("check", not em._telegraph_line.visible or e.state != Enemy.State.CHARGE_WINDUP)
	# 2) Esquive : le joueur se déplace après le verrouillage de la visée.
	landed.clear()
	e.pos = Vector2(8.0, 0.0)
	e.vel = Vector2.ZERO
	e.state = Enemy.State.CHASE
	e.boss.charge_cooldown = 0.0
	g._player.teleport(Vector2.ZERO)
	g.step(DT)
	t.call("check", e.state == Enemy.State.CHARGE_WINDUP)
	var lock_time: float = boss.charge_windup - EnemyManager.CHARGE_AIM_LOCK + 0.05
	while e.state_time < lock_time:
		g.step(DT)
	g._player.teleport(Vector2(0.0, 7.0))
	for i: int in 240:
		g._player.health.hp = g._player.health.max_hp
		g.step(DT)
		if e.state == Enemy.State.RECOVER:
			break
	t.call("check", landed.is_empty(), "esquivée : aucun dégât")
	t.call("check", e.state == Enemy.State.RECOVER, "la charge se termine (mur ou durée)")
	EventBus.enemy_attack_landed.disconnect(l1)
	_free_gameplay(g)


func test_boss_summons_in_phase_three_only() -> void:
	var g: Gameplay = await _make_gameplay()
	var e: Enemy = _spawn_boss(g, Vector2(9.0, 0.0))
	g._player.teleport(Vector2(-6.0, 0.0))
	e.boss.phase = 2
	e.boss.summon_timer = 0.0
	e.boss.charge_cooldown = 99.0
	g.step(DT)
	t.call("check", g.ctx.enemies.count_living() == 1, "phase 2 : pas d'invocation")
	e.boss.phase = 3
	e.boss.summon_timer = 0.0
	g.step(DT)
	var boss: BossData = DataRegistry.wave_table().boss
	t.call(
		"check",
		g.ctx.enemies.count_living() == 1 + boss.summon_count,
		"phase 3 : %d ennemis invoqués" % boss.summon_count
	)
	var interval: float = e.boss.summon_timer
	t.call("check", interval > boss.summon_interval - 0.1, "intervalle d'invocation réarmé")
	for other: Enemy in g.ctx.enemies.slots:
		if other.is_active() and not other.is_boss():
			t.call(
				"check",
				(
					other.data.id == boss.summon_enemy.id
					and (
						other.pos.length()
						<= g.ctx.shape.enemy_limit(IslandShape.theta_of(other.pos)) + 0.001
					)
				),
				"invoqués dans l'arène"
			)
	_free_gameplay(g)


# --- Bouton retour ---


func test_back_button_drives_gameplay_navigation() -> void:
	var stack_before: int = UIManager.stack.size()
	var g: Gameplay = await _make_gameplay()
	t.call("check", UIManager.stack.has(g), "l'écran de jeu répond au retour")
	var menu_calls: Array[int] = [0]
	g.menu_action = func() -> void: menu_calls[0] += 1
	t.call("check", g.state == Gameplay.State.RUN)
	_press_back()
	t.call(
		"check",
		g.state == Gameplay.State.PAUSED,
		"retour en jeu : pause (une seule bascule, pas de double traitement)"
	)
	t.call("check", (t as SceneTree).paused and g._pause_menu.visible, "menu pause affiché")
	_press_back()
	t.call(
		"check",
		g.state == Gameplay.State.RUN and not (t as SceneTree).paused,
		"retour en pause : reprise"
	)
	g._toggle_upgrades()
	_press_back()
	t.call(
		"check",
		g.state == Gameplay.State.RUN and not g._panel.is_open(),
		"retour dans les améliorations : fermeture sans pause"
	)
	_press_back()
	t.call("check", g.state == Gameplay.State.PAUSED, "retour suivant : pause")
	_press_back()
	g.state = Gameplay.State.DYING
	_press_back()
	t.call(
		"check", g.state == Gameplay.State.DYING and menu_calls[0] == 0, "pendant la mort : ignoré"
	)
	g.state = Gameplay.State.GAME_OVER
	_press_back()
	t.call("check", menu_calls[0] == 1, "écran de défaite : retour au menu")
	t.call(
		"check",
		UIManager.handle_back(),
		"retour toujours consommé en partie (jamais de sortie accidentelle)"
	)
	_free_gameplay(g)
	t.call(
		"check",
		UIManager.stack.size() == stack_before,
		"l'écran est retiré de la pile à sa fermeture"
	)


func test_back_during_upgrades_with_death_and_app_pause() -> void:
	var g: Gameplay = await _make_gameplay()
	g._toggle_upgrades()
	g._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	t.call(
		"check",
		g.state == Gameplay.State.PAUSED and not g._panel.is_open(),
		"mise en arrière-plan pendant les améliorations : pause propre"
	)
	g._toggle_pause()
	g.ctx.config.upgrade_pause = GameConfig.UpgradePause.NONE
	g._toggle_upgrades()
	EventBus.player_died.emit()
	t.call(
		"check",
		g.state == Gameplay.State.DYING and not g._panel.is_open(),
		"mort pendant les améliorations : panneau fermé"
	)
	g.ctx.config.upgrade_pause = GameConfig.UpgradePause.FULL_STOP
	_free_gameplay(g)


func test_back_on_boot_needs_two_presses_to_quit() -> void:
	var tree: SceneTree = t as SceneTree
	var boot: Node = (load("res://scenes/boot/boot.tscn") as PackedScene).instantiate()
	var quits: Array[int] = [0]
	boot.set("quit_action", func() -> void: quits[0] += 1)
	tree.root.add_child(boot)
	await tree.process_frame
	t.call("check", UIManager.stack.has(boot), "l'accueil répond au retour")
	_press_back()
	t.call("check", quits[0] == 0, "1re pression : on ne quitte pas")
	t.call(
		"check",
		UIManager.current_toast() == "Appuyez encore pour quitter",
		"message d'avertissement"
	)
	_press_back()
	t.call("check", quits[0] == 1, "2e pression rapprochée : on quitte")
	tree.root.remove_child(boot)
	boot.free()
	t.call("check", UIManager.stack.size() == 0, "pile vide une fois les écrans fermés")


func test_pause_menu_settings_screen() -> void:
	UserSettings.path_override = "user://test_settings.cfg"
	DirAccess.remove_absolute(UserSettings.path_override)
	Haptics.set_level(2)
	var g: Gameplay = await _make_gameplay()
	var pm: PauseMenu = g._pause_menu
	pm._open_settings()
	var screen: SettingsScreen = pm.get_child(pm.get_child_count() - 1) as SettingsScreen
	t.call("check", screen != null, "RÉGLAGES s'ouvre depuis la pause")
	var segs: Array[Node] = screen.content.find_children("*", "AxSegment", true, false)
	# Ordre des sélecteurs : vibrations, graphismes, jeu pendant les améliorations, langue.
	var hap: AxSegment = segs[0] as AxSegment
	t.call("check", hap.selected == 2, "vibrations : niveau actuel affiché")
	hap._buttons[3].pressed.emit()
	t.call(
		"check",
		UserSettings.haptics_level() == 3 and Haptics.level() == 3,
		"vibrations : niveau choisi et sauvegardé"
	)
	var up: AxSegment = segs[2] as AxSegment
	t.call("check", up.selected == 0, "arrêt total par défaut")
	up._buttons[1].pressed.emit()
	t.call(
		"check",
		g.ctx.config.upgrade_pause == GameConfig.UpgradePause.SLOW,
		"le mode d'amélioration choisi est appliqué à la partie"
	)
	up._buttons[0].pressed.emit()
	t.call(
		"check",
		g.ctx.config.upgrade_pause == GameConfig.UpgradePause.FULL_STOP,
		"retour à l'arrêt total"
	)
	screen.queue_free()
	Haptics.set_level(2)
	Haptics.reset()
	_free_gameplay(g)
	DirAccess.remove_absolute(UserSettings.path_override)


# --- Arène agrandie ---


## Projette un point du sol à l'aide de la caméra (largeur fixe) : retourne (x, y) en [-1, 1]
## pour un écran de ratio largeur/hauteur donné.
func _ndc(cam: Camera3D, world: Vector3, aspect: float) -> Vector2:
	var p: Vector3 = cam.global_transform.affine_inverse() * world
	var f: float = tan(deg_to_rad(cam.fov * 0.5))
	return Vector2(p.x / (-p.z) / f, p.y / (-p.z) / f * aspect)


func test_island_camera_follows_and_turrets_visible_from_the_centre() -> void:
	var g: Gameplay = await _make_gameplay()
	var cfg: GameConfig = g.ctx.config
	t.call(
		"check",
		cfg.arena_radius > 14.0,
		"île entière jouable (%.1f m de rayon moyen)" % cfg.arena_radius
	)
	t.call("check", is_equal_approx(cfg.ring_radius(), cfg.turret_ring_radius))
	t.call(
		"check",
		cfg.ring_radius() < cfg.arena_radius,
		(
			"les tourelles sont posées DANS l'île (anneau %.1f < %.1f)"
			% [cfg.ring_radius(), cfg.arena_radius]
		)
	)
	var cam: Camera3D = g._camera.camera()
	t.call("check", cam.keep_aspect == Camera3D.KEEP_WIDTH, "largeur fixe")
	t.call(
		"check",
		absf(g._camera.visible_width - cfg.view_width) < 0.05,
		"largeur visible = view_width (%.1f m)" % g._camera.visible_width
	)
	var aspects: Array[float] = [9.0 / 21.0, 9.0 / 16.0, 3.0 / 4.0]
	var worst_x: float = 0.0
	var worst_tall: float = 0.0
	g._player.teleport(Vector2.ZERO)
	for i: int in 240:
		g._camera.step(g.ctx, DT)
	for turret: Turret in g._turrets.turrets:
		for k: int in 12:
			var foot: Vector2 = turret.pos2 + Vector2.from_angle(TAU * float(k) / 12.0) * 1.2
			for point: Vector3 in [Vector3(foot.x, 0.0, foot.y), Vector3(foot.x, 2.4, foot.y)]:
				for aspect: float in aspects:
					var n: Vector2 = _ndc(cam, point, aspect)
					worst_x = maxf(worst_x, absf(n.x))
					worst_tall = maxf(worst_tall, absf(n.y))
	print(
		"[scenario] cadrage : largeur pire cas %.3f, hauteur pire cas %.3f" % [worst_x, worst_tall]
	)
	t.call(
		"check",
		worst_x <= 0.97 and worst_tall <= 0.985,
		(
			"joueur au centre : les 4 tourelles tiennent à l'écran (%.3f / %.3f)"
			% [worst_x, worst_tall]
		)
	)
	# La caméra suit : joueur au bord, le point visé a bougé de façon sensible.
	var before: Vector3 = cam.global_position
	g._player.teleport(Vector2(0.0, -cfg.arena_radius * 0.9))
	for i: int in 240:
		g._camera.step(g.ctx, DT)
	t.call(
		"check",
		cam.global_position.distance_to(before) > cfg.arena_radius * 0.5,
		"la caméra suit le joueur sur toute l'île"
	)
	for turret: Turret in g._turrets.turrets:
		t.call(
			"check",
			is_equal_approx(turret.pos2.length(), cfg.ring_radius()),
			"tourelle posée sur l'anneau"
		)
	_free_gameplay(g)


func test_turret_ranges_cover_the_big_arena() -> void:
	var g: Gameplay = await _make_gameplay()
	var cfg: GameConfig = g.ctx.config
	for turret: Turret in g._turrets.turrets:
		var reach: float = turret.stats.attack_range - cfg.ring_radius()
		t.call(
			"check",
			reach > 0.0,
			"%s : sa portée dépasse le centre de l'arène (%.1f)" % [turret.data.id, reach]
		)
		t.call(
			"check",
			turret.stats.attack_range < cfg.ring_radius() + cfg.arena_radius,
			"%s : et ne couvre pas toute l'arène (il faut attirer les ennemis)" % turret.data.id
		)
	_free_gameplay(g)


# --- Boucle longue avec améliorations ---


func test_long_run_with_upgrades_keeps_economy_consistent() -> void:
	var g: Gameplay = await _make_gameplay()
	var rewards: Array[int] = [0]
	var pacing_min: float = 10.0
	var pacing_max: float = 0.0
	var l: Callable = func(_i: int, r: int, _p: Vector3) -> void: rewards[0] += r
	EventBus.enemy_died.connect(l)
	var steps: int = 0
	var negative: bool = false
	while steps < 60 * 150 and g.ctx.player_alive:
		g._joystick.vector = BotInput.compute(g.ctx)
		g.step(DT)
		if steps % 30 == 0:
			UpgradeBot.act(g._upgrades, g.ctx)
		negative = negative or g.ctx.coins < 0
		pacing_min = minf(pacing_min, g.ctx.pacing)
		pacing_max = maxf(pacing_max, g.ctx.pacing)
		steps += 1
	var levels: int = 0
	for lv: int in g.ctx.turret_levels:
		levels += lv - 1
	print(
		(
			"[scenario] 150 s avec achats : vague %d, kills %d, niveaux %d, dépensé %d, rythme %.2f..%.2f"
			% [g.ctx.wave, g.ctx.kills, levels, g.ctx.coins_spent, pacing_min, pacing_max]
		)
	)
	t.call("check", not negative, "le solde n'est jamais négatif")
	t.call(
		"check",
		g.ctx.coins + g.ctx.coins_spent == rewards[0],
		(
			"pièces + dépenses == somme des récompenses (%d + %d vs %d)"
			% [g.ctx.coins, g.ctx.coins_spent, rewards[0]]
		)
	)
	t.call("check", levels > 0 and g.ctx.coins_spent > 0, "des améliorations ont été achetées")
	var expected_spent: int = 0
	for i: int in g.ctx.turret_data.size():
		expected_spent += CostCurve.total_to(
			g.ctx.balance.upgrade_cost_base,
			g.ctx.balance.upgrade_cost_mult,
			g.ctx.turret_levels[i],
			g.ctx.turret_data[i].cost_scale
		)
	t.call(
		"check",
		expected_spent == g.ctx.coins_spent,
		"dépenses cohérentes avec les niveaux (%d vs %d)" % [expected_spent, g.ctx.coins_spent]
	)
	t.call(
		"check",
		(
			pacing_min >= 1.0 - g.ctx.balance.pacing_max - 0.0001
			and pacing_max <= 1.0 + g.ctx.balance.pacing_max + 0.0001
		),
		"rythme adaptatif borné"
	)
	t.call("check", g.ctx.wave >= 3, "au moins 3 vagues (%d)" % g.ctx.wave)
	EventBus.enemy_died.disconnect(l)
	_free_gameplay(g)
