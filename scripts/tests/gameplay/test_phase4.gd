extends RefCounted
## Tests de la phase 4 : modèles Blender intégrés (joueur, ennemis, tourelles, haches, décor),
## animations pilotées par la simulation, paramètres de teinte par instance.

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


## Données d'un type d'ennemi par identifiant (le boss est porté par la table de vagues).
func _enemy(id: StringName) -> EnemyData:
	var boss: EnemyData = DataRegistry.wave_table().boss
	if boss.id == id:
		return boss
	for data: EnemyData in DataRegistry.enemies():
		if data.id == id:
			return data
	return null


func _free(g: Gameplay) -> void:
	(t as SceneTree).paused = false
	(t as SceneTree).root.remove_child(g)
	g.free()


func test_model_rig_applies_shared_material_and_loops_cleanly() -> void:
	var rig: ModelRig = ModelRig.create("enemy_basic")
	t.call("check", rig != null and rig.player != null, "modèle animé chargé")
	for mi: Node in rig.root.find_children("*", "MeshInstance3D", true, false):
		t.call(
			"check",
			(mi as MeshInstance3D).material_override == ModelRig.PALETTE,
			"matériau partagé"
		)
	for anim: StringName in [&"idle", &"run", &"attack", &"hit", &"death"]:
		t.call("check", rig.has_anim(anim), "animation %s" % anim)
	# Boucle : plus de clé dupliquée en fin de piste (l'export en ajoute une, retirée au chargement).
	var run_anim: Animation = rig.player.get_animation(&"run")
	var duplicated: int = 0
	for track: int in run_anim.get_track_count():
		var n: int = run_anim.track_get_key_count(track)
		if (
			n >= 3
			and (
				run_anim.track_get_key_value(track, n - 1)
				== run_anim.track_get_key_value(track, n - 2)
			)
		):
			duplicated += 1
	t.call("check", duplicated == 0, "boucle sans image dupliquée (%d pistes)" % duplicated)
	rig.root.free()


func test_model_rig_play_finished_and_instance_parameters() -> void:
	var rig: ModelRig = ModelRig.create("enemy_basic")
	rig.play(&"hit", 1.0, true)
	t.call("check", rig.current == &"hit" and not rig.finished(), "hit en cours")
	rig.advance(rig.length_of(&"hit") + 0.1)
	t.call("check", rig.finished(), "hit terminé après sa durée")
	rig.play(&"inconnue", 1.0)
	t.call("check", rig.current == &"hit", "animation inconnue ignorée sans erreur")
	rig.set_flash(0.8)
	t.call("check", is_equal_approx(rig.get_flash(), 0.8), "flash par instance")
	rig.set_tint(Color(1.0, 0.0, 0.0, 0.5))
	t.call(
		"check", rig.get_tint().is_equal_approx(Color(1.0, 0.0, 0.0, 0.5)), "teinte par instance"
	)
	rig.root.free()


func test_every_enemy_type_has_a_model_with_required_animations() -> void:
	var needed: Array[StringName] = [&"idle", &"run", &"attack", &"hit", &"death"]
	for id: StringName in [&"basic", &"fast", &"heavy", &"elite", &"boss"]:
		var data: EnemyData = _enemy(id)
		var rig: ModelRig = ModelRig.create(data.model())
		t.call("check", rig != null, "modèle de %s" % id)
		if rig == null:
			continue
		for anim: StringName in needed:
			t.call("check", rig.has_anim(anim), "%s : animation %s" % [id, anim])
		if id == &"boss":
			for anim: StringName in [&"charge_windup", &"charge", &"roar"]:
				t.call("check", rig.has_anim(anim), "boss : animation %s" % anim)
		rig.root.free()


func test_enemy_animation_follows_simulation_state() -> void:
	var g: Gameplay = await _make_gameplay()
	var basic: EnemyData = _enemy(&"basic")
	var id: int = g._enemies.spawn(basic, Vector2(6.0, 0.0), 1)
	var e: Enemy = g.ctx.enemies.slots[id]
	t.call("check", e.rig != null and e.visual.visible, "modèle attaché à l'apparition")
	t.call("check", e.rig.root.get_parent() == e.visual, "modèle sous le support de l'ennemi")
	for i: int in 40:
		g.step(DT)
	t.call(
		"check",
		e.state == Enemy.State.CHASE and e.rig.current == &"run",
		"poursuite : animation run (%s)" % e.rig.current
	)
	e.state = Enemy.State.WINDUP
	e.state_time = 0.0
	g.step(DT)
	t.call("check", e.rig.current == &"attack", "armement : animation attack")
	e.health.max_hp = 1.0e6
	e.health.hp = 1.0e6
	EventBus.axe_hit.emit(id, 1.0, 0, Vector2.RIGHT)
	g.step(DT)
	t.call("check", e.rig.get_flash() > 0.0, "flash d'impact (paramètre d'instance)")
	_free(g)


func test_death_plays_then_model_returns_to_pool() -> void:
	var g: Gameplay = await _make_gameplay()
	var basic: EnemyData = _enemy(&"basic")
	var id: int = g._enemies.spawn(basic, Vector2(8.0, 0.0), 1)
	var e: Enemy = g.ctx.enemies.slots[id]
	for i: int in 45:  # au-delà de l'invulnérabilité d'apparition
		g._enemies.step(DT)
	EventBus.axe_hit.emit(id, 1.0e6, 0, Vector2.RIGHT)
	g._enemies.step(DT)
	t.call(
		"check",
		e.state == Enemy.State.DYING and e.rig.current == &"death",
		"mort : animation death"
	)
	for i: int in 30:
		g._enemies.step(DT)
	t.call(
		"check",
		e.state == Enemy.State.INACTIVE and e.rig == null,
		(
			"modèle rendu au pool après la mort (état %d, t=%.2f, vie %.1f)"
			% [e.state, e.state_time, e.health.hp]
		)
	)
	t.call("check", not e.visual.visible, "support masqué")
	# Réutilisation : le même modèle sert à l'apparition suivante, sans nouvelle instance.
	var before: int = g._enemies._pool_root.get_child_count()
	var id2: int = g._enemies.spawn(basic, Vector2(5.0, 5.0), 1)
	var e2: Enemy = g.ctx.enemies.slots[id2]
	t.call("check", e2.rig != null, "nouvel ennemi : modèle attribué")
	t.call(
		"check",
		g._enemies._pool_root.get_child_count() == before - 1,
		"modèle repris dans le pool (%d -> %d)" % [before, g._enemies._pool_root.get_child_count()]
	)
	_free(g)


func test_level_tier_tint_is_a_shader_parameter_not_a_material() -> void:
	var g: Gameplay = await _make_gameplay()
	var basic: EnemyData = _enemy(&"basic")
	var low: Enemy = g.ctx.enemies.slots[g._enemies.spawn(basic, Vector2(4.0, 0.0), 1)]
	var high: Enemy = g.ctx.enemies.slots[g._enemies.spawn(basic, Vector2(-4.0, 0.0), 7)]
	t.call("check", low.rig.get_tint().a == 0.0, "niveau 1 : couleurs d'origine")
	t.call(
		"check",
		high.rig.get_tint().a > 0.0 and high.rig.get_glow() > 0.0,
		"niveau 7 : teinte et lueur"
	)
	var mat_low: Material = (
		(low.rig.root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D)
		. material_override
	)
	var mat_high: Material = (
		(high.rig.root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D)
		. material_override
	)
	t.call(
		"check", mat_low == mat_high, "un seul matériau pour tous les niveaux (batching préservé)"
	)
	_free(g)


func test_turrets_use_blender_models_with_tiers_and_recoil() -> void:
	var g: Gameplay = await _make_gameplay()
	for turret: Turret in g._turrets.turrets:
		t.call(
			"check",
			turret._pivot != null and turret._barrel != null and turret._muzzle != null,
			"noeuds du modèle (%s)" % turret.data.id
		)
		t.call("check", turret._tiers.size() == 3, "trois paliers visuels")
		t.call(
			"check",
			turret._muzzle_distance > 0.5,
			"distance de bouche lue sur le modèle (%.2f)" % turret._muzzle_distance
		)
		var rest_z: float = turret._barrel.position.z
		turret._recoil = 1.0
		turret._apply_visuals()
		t.call("check", turret._barrel.position.z > rest_z, "le canon recule")
		turret._recoil = 0.0
		turret._apply_visuals()
	_free(g)


func test_each_axe_category_shows_its_own_model() -> void:
	var g: Gameplay = await _make_gameplay()
	var seen: Dictionary = {}
	for turret: Turret in g._turrets.turrets:
		var p: ProjectileData = turret.data.projectile
		seen[p.model()] = true
	t.call("check", seen.size() == 4, "quatre modèles de haches distincts (%s)" % str(seen.keys()))
	var data: TurretData = g._turrets.turrets[0].data
	var stats: TurretLevelData = g.ctx.turret_stats(0)
	g._projectiles._spawn(data, stats, Vector2.ZERO, Vector2.RIGHT)
	var axe: Axe = null
	for a: Axe in g._projectiles._axes:
		if a.active:
			axe = a
	t.call(
		"check",
		axe != null and axe.shown != null and axe.shown.visible,
		"hache affichée avec son modèle"
	)
	_free(g)


func test_beach_island_is_the_arena_with_clear_decor_rules() -> void:
	var g: Gameplay = await _make_gameplay()
	var island: Node3D = g._arena.get_node("Island") as Node3D
	var k: float = g.ctx.config.island_scale()
	t.call("check", is_equal_approx(island.scale.x, k), "île mise à l'échelle du rayon de jeu")
	t.call("check", g._arena.ocean_material != null, "mer animée (shader)")
	t.call("check", g._arena.backdrop != null, "arrière-plan horizon présent")
	t.call("check", island.find_child("Rim", true, false) == null, "plus de bordure d'arène")
	var tall: PackedStringArray = PackedStringArray(
		["deco_palm", "deco_umbrella", "deco_sandcastle"]
	)
	var solids: int = 0
	for entry: Dictionary in Arena.DECOR:
		var angle: float = entry["angle"] as float
		var inland: float = entry["in"] as float
		var model: String = entry["model"] as String
		if tall.has(model):
			t.call(
				"check",
				absf(angle) <= 105.0,
				"%s (%.0f°) : élément haut au nord, jamais devant le joueur" % [model, angle]
			)
		if (entry["solid"] as float) > 0.0:
			solids += 1
			t.call("check", inland > 0.0, "%s solide sur le sable (pas dans l'eau)" % model)
	# 4 tourelles + les décors solides sont des obstacles.
	t.call(
		"check",
		g.ctx.obstacles.count() == 4 + solids,
		"obstacles : 4 tourelles + %d décors (%d)" % [solids, g.ctx.obstacles.count()]
	)
	# Le centre de l'île est dégagé pour le combat.
	t.call(
		"check",
		not g.ctx.obstacles.overlaps(Vector2.ZERO, 0.5, 4.0),
		"le centre de l'île est dégagé (4 m)"
	)
	_free(g)


func test_player_model_animates_from_state() -> void:
	var g: Gameplay = await _make_gameplay()
	var p: PlayerController = g._player
	t.call("check", p._rig != null and p._rig.current == &"idle", "héros immobile : idle")
	for i: int in 30:
		p.step(DT, Vector2(1.0, 0.0))
	t.call("check", p._rig.current == &"run", "héros en mouvement : run (%s)" % p._rig.current)
	EventBus.enemy_attack_landed.emit(1.0, Vector2(5.0, 0.0))
	t.call("check", p._rig.current == &"hit", "touché : animation hit")
	_free(g)
