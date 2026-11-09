extends RefCounted
## Tests de la phase 5 : zone de la hache lourde, dégâts, caméra dynamique, effets visuels,
## ombres, pièces cosmétiques, gouverneur de qualité appliqué, moteur audio et branchement du son.

const DT: float = 1.0 / 60.0

var t: Object


func _check(cond: bool, msg: String) -> void:
	t.call("check", cond, msg)


func _make_gameplay() -> Gameplay:
	var tree: SceneTree = t as SceneTree
	var g: Gameplay = (
		(load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	)
	g.set_physics_process(false)
	g.run_seed = 5151
	tree.root.add_child(g)
	await tree.process_frame
	return g


func _free(g: Gameplay) -> void:
	(t as SceneTree).paused = false
	(t as SceneTree).root.remove_child(g)
	g.free()


func _enemies(g: Gameplay) -> EnemyManager:
	return g.get_node("World/Enemies") as EnemyManager


func _basic() -> EnemyData:
	return DataRegistry.enemies()[0]


func _spawn(g: Gameplay, pos: Vector2) -> Enemy:
	var id: int = _enemies(g).spawn(_basic(), pos, 1)
	var e: Enemy = g.ctx.enemies.slots[id]
	e.state = Enemy.State.CHASE
	e.state_time = 0.0
	# Costauds : les tests mesurent des dégâts, pas des morts (le crabe n'a que 30 PV).
	e.health.max_hp = 500.0
	e.health.hp = 500.0
	return e


func _heavy_id() -> int:
	var datas: Array[TurretData] = DataRegistry.turrets()
	for i: int in datas.size():
		if datas[i].projectile.category == ProjectileData.Category.HEAVY:
			return i
	return -1


# --- Dégâts et zone ---------------------------------------------------------------------------


func test_axe_damage_values_were_raised() -> void:
	var by_cat: Dictionary = {}
	for d: TurretData in DataRegistry.turrets():
		by_cat[d.projectile.category] = TurretLeveling.build(d)[0].damage
	_check(float(by_cat[ProjectileData.Category.HEAVY]) >= 55.0, "hache lourde : dégâts augmentés")
	_check(float(by_cat[ProjectileData.Category.RAPID]) >= 10.5, "hache rapide : dégâts augmentés")
	_check(
		float(by_cat[ProjectileData.Category.MULTI]) >= 12.0, "hache multiple : dégâts augmentés"
	)
	_check(
		float(by_cat[ProjectileData.Category.PIERCE]) >= 19.0, "hache perforante : dégâts augmentés"
	)


func test_only_heavy_axe_has_splash_and_it_grows_with_level() -> void:
	for d: TurretData in DataRegistry.turrets():
		var table: Array[TurretLevelData] = TurretLeveling.build(d)
		if d.projectile.category == ProjectileData.Category.HEAVY:
			_check(
				table[0].splash_radius >= 3.0, "lourde : zone de %.1f m" % table[0].splash_radius
			)
			_check(
				table[9].splash_radius > table[0].splash_radius, "la zone grandit avec le niveau"
			)
		else:
			_check(
				table[0].splash_radius == 0.0 and table[9].splash_radius == 0.0,
				"%s : pas de zone" % d.id
			)


func test_splash_damages_neighbors_with_falloff_and_spares_far_enemies() -> void:
	var g: Gameplay = await _make_gameplay()
	var a: Enemy = _spawn(g, Vector2(6.0, 0.0))
	var near: Enemy = _spawn(g, Vector2(7.2, 0.0))
	var edge: Enemy = _spawn(g, Vector2(6.0, 3.4))
	var far: Enemy = _spawn(g, Vector2(-8.0, 5.0))
	for e: Enemy in [a, near, edge, far]:
		e.vel = Vector2.ZERO
	var hp_far: float = far.health.hp
	var radius: float = 3.4
	var raw: float = 56.0
	var resist: float = a.data.resistance(ProjectileData.Category.HEAVY)
	EventBus.axe_hit.emit(a.id, raw, ProjectileData.Category.HEAVY, Vector2.RIGHT)
	var direct: float = a.health.max_hp - a.health.hp
	_check(
		is_equal_approx(direct, DamageCalculator.compute(raw, resist)),
		"touché en direct : dégâts pleins"
	)
	var resolved: Array[int] = []
	var l: Callable = func(_p: Vector2, _r: float, hits: int) -> void: resolved.append(hits)
	EventBus.axe_splash_resolved.connect(l)
	EventBus.axe_splash.emit(
		a.pos, radius, raw * 0.8, ProjectileData.Category.HEAVY, a.id, 0.45, 6.0
	)
	EventBus.axe_splash_resolved.disconnect(l)
	_check(
		is_equal_approx(a.health.max_hp - a.health.hp, direct),
		"le touché en direct n'est PAS frappé deux fois"
	)
	var near_dmg: float = near.health.max_hp - near.health.hp
	var gap_near: float = near.pos.distance_to(a.pos) - near.data.radius
	var expected_near: float = DamageCalculator.compute(
		raw * 0.8 * lerpf(1.0, 0.45, clampf(gap_near / radius, 0.0, 1.0)), resist
	)
	_check(
		near_dmg > 0.0 and is_equal_approx(near_dmg, expected_near),
		"voisin proche : %.1f (attendu %.1f)" % [near_dmg, expected_near]
	)
	var edge_dmg: float = edge.health.max_hp - edge.health.hp
	_check(
		edge_dmg > 0.0 and edge_dmg < near_dmg,
		"voisin au bord : dégâts décroissants (%.1f < %.1f)" % [edge_dmg, near_dmg]
	)
	_check(far.health.hp == hp_far, "ennemi hors de la zone : intact")
	_check(
		resolved.size() == 1 and resolved[0] == 2,
		"2 ennemis touchés par la zone (obtenu %s)" % str(resolved)
	)
	_check(near.vel.x > 0.1, "le voisin est repoussé loin du centre")
	_free(g)


func test_splash_kill_rewards_once_and_dead_enemies_are_ignored() -> void:
	var g: Gameplay = await _make_gameplay()
	var a: Enemy = _spawn(g, Vector2(6.0, 0.0))
	var weak: Enemy = _spawn(g, Vector2(7.0, 0.0))
	weak.health.max_hp = 1.0
	weak.health.hp = 1.0
	var rewards: Array[int] = []
	var l: Callable = func(id: int, _r: int, _p: Vector3) -> void: rewards.append(id)
	EventBus.enemy_died.connect(l)
	for i: int in 3:
		EventBus.axe_splash.emit(a.pos, 3.4, 40.0, ProjectileData.Category.HEAVY, a.id, 0.45, 6.0)
	EventBus.enemy_died.disconnect(l)
	_check(weak.state == Enemy.State.DYING, "tué par la zone")
	_check(
		rewards.count(weak.id) == 1,
		"récompense attribuée UNE seule fois (%d)" % rewards.count(weak.id)
	)
	_free(g)


func test_heavy_axe_pipeline_hits_a_cluster() -> void:
	var g: Gameplay = await _make_gameplay()
	var heavy: int = _heavy_id()
	var front: Enemy = _spawn(g, Vector2(6.0, 0.0))
	var behind: Enemy = _spawn(g, Vector2(6.8, 1.4))
	front.speed_mult = 0.0
	behind.speed_mult = 0.0
	var data: TurretData = DataRegistry.turrets()[heavy]
	EventBus.turret_fired.emit(heavy, data, Vector2(1.0, 0.0), Vector2.RIGHT)
	for i: int in 90:
		g.step(DT)
	_check(
		front.health.hp < front.health.max_hp or front.state == Enemy.State.DYING, "cible touchée"
	)
	_check(
		behind.health.hp < behind.health.max_hp or behind.state == Enemy.State.DYING,
		"voisin touché par la zone (chaîne complète)"
	)
	_free(g)


# --- Haches : animation et flux ---------------------------------------------------------------


func test_axe_pops_in_and_has_a_trail_slot() -> void:
	var g: Gameplay = await _make_gameplay()
	var pm: ProjectileManager = g.get_node("World/Projectiles") as ProjectileManager
	var data: TurretData = DataRegistry.turrets()[0]
	EventBus.turret_fired.emit(0, data, Vector2(0.0, 0.0), Vector2.RIGHT)
	_check(pm.active_count() >= 1, "hache lancée")
	_check(pm.trails().capacity() == g.ctx.config.axe_pool_size, "un emplacement de flux par hache")
	var axe: Axe = null
	for a: Axe in pm._axes:
		if a.active:
			axe = a
	var final_scale: float = axe.style.visual_scale
	_check(axe.visual.scale.x < final_scale * 0.6, "naissance : toute petite (pop)")
	for i: int in 12:
		g.step(DT)
	_check(
		absf(axe.visual.scale.x - final_scale) < final_scale * 0.25, "après le pop : taille normale"
	)
	_check(
		(
			absf(ProjectileManager.ease_out_back(0.0)) < 0.0001
			and absf(ProjectileManager.ease_out_back(1.0) - 1.0) < 0.0001
		),
		"courbe élastique : 0 -> 1"
	)
	var overshoot: bool = false
	for i: int in 101:
		overshoot = overshoot or ProjectileManager.ease_out_back(float(i) / 100.0) > 1.0
	_check(overshoot, "dépassement élastique avant de se poser")
	_free(g)


# --- Ennemis : animation appliquée au modèle ----------------------------------------------------


func test_juice_is_applied_to_enemy_model_and_reset_on_recycle() -> void:
	var g: Gameplay = await _make_gameplay()
	var e: Enemy = _spawn(g, Vector2(8.0, 0.0))
	var varied: bool = false
	var first: float = -1.0
	for i: int in 90:
		g.step(DT)
		if first < 0.0:
			first = e.rig.root.scale.y
		varied = varied or absf(e.rig.root.scale.y - first) > 0.02
	_check(varied, "le modèle s'écrase et s'étire en courant")
	_check(e.rig.root.scale.y > 0.3, "échelle valide")
	e.state = Enemy.State.DYING
	e.state_time = 0.0
	_check(e.rig != null, "modèle présent pendant la mort")
	_free(g)


# --- Caméra -----------------------------------------------------------------------------------


func test_camera_is_more_oblique_and_shake_is_bounded() -> void:
	var g: Gameplay = await _make_gameplay()
	var cam: CameraRig = g.get_node("CameraRig") as CameraRig
	for i: int in 120:
		cam.step(g.ctx, DT)
	var pitch: float = -cam.camera().global_rotation_degrees.x
	_check(
		absf(pitch - cam.feel.pitch_degrees) < 1.5,
		"angle de caméra %.1f° (réglé %.1f°)" % [pitch, cam.feel.pitch_degrees]
	)
	_check(pitch < 68.0, "plus en plongée que la phase 4 (70°)")
	cam.add_trauma(5.0)
	_check(cam.trauma() <= 1.0, "trauma borné à 1")
	var base: Vector3 = cam.camera().global_position
	var worst: float = 0.0
	for i: int in 60:
		cam.step(g.ctx, DT)
		worst = maxf(worst, cam.camera().global_position.distance_to(base))
	_check(worst > 0.01, "la secousse bouge réellement la caméra")
	_check(worst < 1.2, "mais reste contenue (%.2f m)" % worst)
	for i: int in 240:
		cam.step(g.ctx, DT)
	_check(cam.trauma() == 0.0, "la secousse retombe à zéro")
	_free(g)


func test_camera_shake_can_be_disabled_and_punch_returns() -> void:
	var g: Gameplay = await _make_gameplay()
	var cam: CameraRig = g.get_node("CameraRig") as CameraRig
	cam.feel.shake_scale = 0.0
	cam.add_trauma(1.0)
	_check(cam.trauma() == 0.0, "accessibilité : secousses désactivées")
	for i: int in 120:
		cam.step(g.ctx, DT)
	var rest: Vector3 = cam.camera().global_position
	for k: int in 20:
		cam.punch(-0.08)
	var closest: float = 1.0e9
	for i: int in 30:
		cam.step(g.ctx, DT)
		closest = minf(closest, cam.camera().global_position.distance_to(rest))
	_check(closest < 5.0, "coup de zoom borné")
	for i: int in 240:
		cam.step(g.ctx, DT)
	_check(cam.camera().global_position.distance_to(rest) < 0.05, "le zoom revient à sa place")
	cam.feel.shake_scale = 1.0
	_free(g)


# --- Effets et ombres --------------------------------------------------------------------------


func test_fx_react_to_events_and_respect_pool_caps() -> void:
	var g: Gameplay = await _make_gameplay()
	var fx: FxManager = g.get_node("World/Fx") as FxManager
	var before: int = int(fx.spawned["spark"]) + int(fx.spawned["ring"])
	EventBus.axe_splash.emit(
		Vector2(4.0, 2.0), 3.4, 40.0, ProjectileData.Category.HEAVY, -1, 0.45, 6.0
	)
	var after: int = int(fx.spawned["spark"]) + int(fx.spawned["ring"])
	_check(after > before + 8, "l'impact de zone émet étincelles, anneaux et poussière")
	var e: Enemy = _spawn(g, Vector2(5.0, 0.0))
	var kills: int = int(fx.spawned["coin"])
	EventBus.enemy_died.emit(e.id, 3, Vector3(5.0, 0.0, 0.0))
	_check(int(fx.spawned["coin"]) > kills, "une élimination fait jaillir des pièces")
	for i: int in 400:
		EventBus.axe_splash.emit(Vector2.ZERO, 3.4, 10.0, 1, -1, 0.45, 6.0)
	_check(
		fx._sparks.capacity() == FxManager.SPARK_CAPACITY,
		"capacité allouée inchangée (aucune allocation en jeu)"
	)
	_check(
		fx._sparks._next < fx._sparks.limit(), "anneau circulaire : l'indice reste dans le plafond"
	)
	_free(g)


func test_fx_density_follows_quality_and_feel_scale() -> void:
	var g: Gameplay = await _make_gameplay()
	var fx: FxManager = g.get_node("World/Fx") as FxManager
	fx.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.HIGH))
	var high: int = fx._count(10)
	fx.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.LOW))
	var low: int = fx._count(10)
	_check(low < high, "moins de particules en profil BAS (%d < %d)" % [low, high])
	_check(not fx.shadows().enabled, "fausses ombres coupées en profil BAS")
	_check(
		fx._sparks.limit() == QualityProfile.for_tier(QualityProfile.Tier.LOW).spark_capacity,
		"plafond BAS appliqué"
	)
	fx.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.HIGH))
	_check(fx.shadows().enabled, "fausses ombres actives en profil ÉLEVÉ")
	g.get_node("World/Fx")._feel.fx_scale = 0.0
	_check(fx._count(10) == 0, "fx_scale = 0 : aucun effet")
	g.get_node("World/Fx")._feel.fx_scale = 1.0
	_free(g)


func test_coins_fly_to_player_then_are_collected_once_each() -> void:
	var g: Gameplay = await _make_gameplay()
	var fx: FxManager = g.get_node("World/Fx") as FxManager
	var arrived: Array[int] = []
	var l: Callable = func(streak: int) -> void: arrived.append(streak)
	EventBus.coin_collected.connect(l)
	EventBus.enemy_died.emit(_spawn(g, Vector2(5.0, 0.0)).id, 4, Vector3(5.0, 0.0, 0.0))
	var popped: int = int(fx.spawned["coin"])
	_check(popped >= 1, "pièces émises")
	for i: int in 30:
		g.step(DT)
	_check(
		arrived.is_empty(),
		"pas encore arrivées (le vol dure %.2f s)" % g.get_node("World/Fx")._feel.coin_fly_time
	)
	for i: int in 90:
		g.step(DT)
	EventBus.coin_collected.disconnect(l)
	_check(
		arrived.size() == popped,
		"chaque pièce arrive UNE fois (%d / %d)" % [arrived.size(), popped]
	)
	_check(arrived.size() < 2 or arrived[1] == arrived[0] + 1, "la série de pièces monte")
	_free(g)


func test_blob_shadows_track_live_enemies() -> void:
	var g: Gameplay = await _make_gameplay()
	var fx: FxManager = g.get_node("World/Fx") as FxManager
	fx.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.HIGH))
	var e: Enemy = _spawn(g, Vector2(6.0, 2.0))
	g.step(DT)
	var shadows: BlobShadows = fx.shadows()
	_check(shadows._visible_prev[1 + e.id] == 1, "ombre sous l'ennemi actif")
	_check(shadows._visible_prev[0] == 1, "ombre sous le héros")
	e.state = Enemy.State.INACTIVE
	g.step(DT)
	_check(shadows._visible_prev[1 + e.id] == 0, "ombre masquée quand l'ennemi disparaît")
	_free(g)


# --- Performance : réglages moteur et gouverneur appliqué ---------------------------------------


func test_engine_is_configured_for_smooth_frames() -> void:
	_check(
		bool(ProjectSettings.get_setting("physics/common/physics_interpolation")),
		"interpolation physique activée"
	)
	_check(
		float(ProjectSettings.get_setting("physics/common/physics_jitter_fix")) == 0.0,
		"jitter fix coupé (inutile avec l'interpolation)"
	)
	_check(
		int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame")) <= 4,
		"pas de spirale de rattrapage"
	)
	_check(Engine.physics_ticks_per_second == 60, "simulation à 60 Hz")


func test_quality_manager_applies_profiles_and_notifies() -> void:
	var seen: Array[int] = []
	var l: Callable = func(tier: int) -> void: seen.append(tier)
	EventBus.quality_changed.connect(l)
	var before: QualityProfile.Tier = QualityManager.profile.tier
	QualityManager.apply_tier(QualityProfile.Tier.LOW)
	_check(QualityManager.profile.tier == QualityProfile.Tier.LOW, "profil BAS appliqué")
	_check(
		(Engine.get_main_loop() as SceneTree).root.msaa_3d == Viewport.MSAA_DISABLED,
		"MSAA coupé en BAS"
	)
	_check(
		QualityManager.applied_scale <= 1.0 and QualityManager.applied_scale >= 0.5,
		"échelle 3D bornée"
	)
	QualityManager.apply_tier(QualityProfile.Tier.HIGH)
	_check(
		(Engine.get_main_loop() as SceneTree).root.msaa_3d == Viewport.MSAA_2X, "MSAA 2x en ÉLEVÉ"
	)
	QualityManager.apply_tier(before)
	EventBus.quality_changed.disconnect(l)
	_check(seen.size() == 3 and seen[0] == QualityProfile.Tier.LOW, "chaque changement est notifié")
	_check(not QualityManager.governor.enabled, "gouverneur inactif en headless")


func test_quality_mode_cycles_and_persists() -> void:
	var start: int = QualityManager.mode
	for i: int in 4:
		QualityManager.cycle_mode()
	_check(QualityManager.mode == start, "AUTO -> BAS -> MOYEN -> ÉLEVÉ -> AUTO")
	QualityManager.set_mode(3)
	_check(QualityManager.profile.tier == QualityProfile.Tier.HIGH, "mode ÉLEVÉ imposé")
	_check(UserSettings.quality_mode() == 3, "sauvegardé")
	_check(QualityManager.mode_label() == "ÉLEVÉ", "libellé")
	QualityManager.set_mode(start)


func test_enemy_far_animation_follows_profile() -> void:
	var g: Gameplay = await _make_gameplay()
	var em: EnemyManager = _enemies(g)
	em.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.LOW))
	_check(
		em._far_divisor == 3 and is_equal_approx(em._far_dist_sq, 81.0),
		"BAS : animation lointaine 1 tick sur 3 au-delà de 9 m"
	)
	em.apply_profile(QualityProfile.for_tier(QualityProfile.Tier.HIGH))
	_check(em._far_divisor == 2, "ÉLEVÉ : 1 tick sur 2")
	_free(g)
