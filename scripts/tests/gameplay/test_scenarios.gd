extends RefCounted
## Scénarios headless de la boucle complète : on instancie la vraie scène Gameplay et on la
## fait avancer pas à pas (Gameplay.step), sans dépendre de la boucle physique du moteur.

const DT: float = 1.0 / 60.0

var t: Object


func _make_gameplay() -> Gameplay:
	var tree: SceneTree = t as SceneTree
	var g: Gameplay = (
		(load("res://scenes/gameplay/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	)
	g.set_physics_process(false)  # on pilote la simulation à la main : déterministe
	tree.root.add_child(g)
	await tree.process_frame
	return g


func _free_gameplay(g: Gameplay) -> void:
	(t as SceneTree).root.remove_child(g)
	g.free()


func _joystick(g: Gameplay) -> FloatingJoystick:
	return g.get_node("Ui/Joystick") as FloatingJoystick


## Spawn direct d'un ennemi basique en CHASE (hors vagues) à une distance de surface donnée.
func _spawn_basic(g: Gameplay, gap: float, angle: float = 0.0) -> Enemy:
	var data: EnemyData = DataRegistry.enemies()[0]
	var dist: float = g.ctx.config.player_radius + data.radius + gap
	var em: EnemyManager = g.get_node("World/Enemies") as EnemyManager
	var id: int = em.spawn(data, g.ctx.player_pos + Vector2.from_angle(angle) * dist, 1.0, 1.0)
	var e: Enemy = g.ctx.enemies.slots[id]
	e.state = Enemy.State.CHASE
	e.state_time = 0.0
	return e


func test_graze_triggers_turrets_without_damage() -> void:
	var g: Gameplay = await _make_gameplay()
	var rec: EventRecorder = EventRecorder.new()
	rec.start()
	# Écart de surface 0,35 : dans l'anneau de déclenchement (0,45), hors anneau de dégâts (0,25).
	var e: Enemy = _spawn_basic(g, 0.35)
	g.step(DT)
	t.call("check", rec.n("combat") == 1, "frôler émet combat_activated")
	t.call("check", g.ctx.combat_active(), "fenêtre active")
	for i: int in 6:
		g.step(DT)
	var untouched: bool = g.ctx.player_alive and g._player.health.hp == g.ctx.config.player_hp
	t.call("check", untouched, "aucun dégât en frôlant")
	t.call("check", e.is_active())
	rec.stop()
	_free_gameplay(g)


func test_contact_does_not_retrigger_every_frame() -> void:
	var g: Gameplay = await _make_gameplay()
	var rec: EventRecorder = EventRecorder.new()
	rec.start()
	_spawn_basic(g, 0.3)
	for i: int in 60:
		g.step(DT)
	# En 1 s avec un ennemi collé : peu d'activations (rearm 0,4 s, cooldown 0,5 s).
	var n: int = rec.n("combat")
	t.call("check", n >= 1 and n <= 3, "anti-répétition (%d activations en 1 s)" % n)
	rec.stop()
	_free_gameplay(g)


func test_turrets_fire_kill_and_reward_once() -> void:
	var g: Gameplay = await _make_gameplay()
	var rec: EventRecorder = EventRecorder.new()
	rec.start()
	for k: int in 3:
		_spawn_basic(g, 0.3, float(k) * 2.1)
	# Le joueur tourne en rond : il frôle sans rester à portée d'attaque.
	for i: int in 600:
		_joystick(g).vector = Vector2(cos(float(i) * 0.05), sin(float(i) * 0.05))
		g.step(DT)
	t.call("check", rec.n("fired") > 0, "les tourelles tirent")
	t.call("check", rec.n("hit") > 0, "les haches touchent")
	t.call("check", rec.n("died") >= 3, "les 3 ennemis meurent (%d)" % rec.n("died"))
	t.call(
		"check",
		g.ctx.coins == rec.reward_sum,
		"pièces == somme des récompenses (%d/%d)" % [g.ctx.coins, rec.reward_sum]
	)
	t.call("check", g.ctx.kills == rec.n("died"), "kills == enemy_died")
	t.call("check", not rec.coins_history.is_empty() and rec.coins_history[-1] == g.ctx.coins)
	rec.stop()
	_free_gameplay(g)


func test_passive_player_dies_and_game_over_once() -> void:
	var g: Gameplay = await _make_gameplay()
	var rec: EventRecorder = EventRecorder.new()
	rec.start()
	var steps: int = 0
	while g.state != Gameplay.State.GAME_OVER and steps < 60 * 240:
		g.step(DT)
		steps += 1
	t.call(
		"check",
		g.state == Gameplay.State.GAME_OVER,
		"la partie se termine (%d s simulées)" % (steps / 60)
	)
	t.call("check", not g.ctx.player_alive)
	t.call("check", rec.n("game_over") == 1, "game_over émis une seule fois")
	t.call("check", g._game_over.visible, "écran de défaite affiché")
	t.call("check", rec.n("damaged") >= 1)
	rec.stop()
	_free_gameplay(g)


func test_bot_survives_and_waves_progress() -> void:
	var g: Gameplay = await _make_gameplay()
	var rec: EventRecorder = EventRecorder.new()
	rec.start()
	var max_enemies: int = 0
	var start_us: int = Time.get_ticks_usec()
	var steps: int = 0
	while steps < 60 * 90 and g.ctx.player_alive:
		_joystick(g).vector = BotInput.compute(g.ctx)
		g.step(DT)
		max_enemies = maxi(max_enemies, g.ctx.enemies.count_living())
		steps += 1
	var ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0 / float(steps)
	var summary: String = (
		"%d s simulées, vague %d, kills %d, pièces %d, PV %d"
		% [steps / 60, g.ctx.wave, g.ctx.kills, g.ctx.coins, int(g._player.health.hp)]
	)
	summary += ", max ennemis %d, salves %d, %.2f ms/tick" % [max_enemies, rec.n("fired"), ms]
	print("[scenario] bot : ", summary, " (CPU serveur, headless)")
	t.call("check", g.ctx.wave >= 2, "au moins 2 vagues en 90 s (%d)" % g.ctx.wave)
	t.call("check", g.ctx.kills >= 5, "des éliminations (%d)" % g.ctx.kills)
	t.call("check", max_enemies <= g.ctx.config.enemy_cap, "plafond d'ennemis respecté")
	rec.stop()
	_free_gameplay(g)


func test_stress_full_cap_and_invariants() -> void:
	var g: Gameplay = await _make_gameplay()
	var em: EnemyManager = g.get_node("World/Enemies") as EnemyManager
	var pm: ProjectileManager = g.get_node("World/Projectiles") as ProjectileManager
	var types: Array[EnemyData] = DataRegistry.enemies()
	var cap: int = g.ctx.config.enemy_cap
	for i: int in cap:
		var angle: float = float(i) * 2.399
		var ring: float = 3.0 + float(i % 5) * 1.0
		em.spawn(types[i % types.size()], Vector2.from_angle(angle) * ring, 1.0, 1.0)
	t.call("check", g.ctx.enemies.find_free() == -1, "pool d'ennemis plein (%d)" % cap)
	var arena_r: float = g.ctx.config.arena_radius
	var inside: bool = true
	var max_axes: int = 0
	var start_us: int = Time.get_ticks_usec()
	var steps: int = 360
	for i: int in steps:
		_joystick(g).vector = Vector2(cos(float(i) * 0.04), sin(float(i) * 0.04))
		g.step(DT)
		max_axes = maxi(max_axes, pm.active_count())
		if g.ctx.player_pos.length() > arena_r + 0.001:
			inside = false
		for e: Enemy in g.ctx.enemies.slots:
			if e.is_active() and e.pos.length() > arena_r + 0.001:
				inside = false
	var ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0 / float(steps)
	print("[scenario] stress %d ennemis : %.2f ms/tick, haches max %d" % [cap, ms, max_axes])
	t.call("check", inside, "joueur et ennemis restent dans l'arène")
	t.call("check", max_axes <= g.ctx.config.axe_pool_size, "plafond de haches respecté")
	t.call("check", ms < 10.0, "simulation < 10 ms/tick sur la machine de CI (%.2f)" % ms)
	_free_gameplay(g)
