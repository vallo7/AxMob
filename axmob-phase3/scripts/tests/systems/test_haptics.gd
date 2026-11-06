extends RefCounted
## Retour haptique : planificateur (priorités, délais, plafond, amplitude) et liaison avec les
## événements du jeu. Le moteur ne vibre pas en headless : on enregistre les appels du backend.

var t: Object


func _planner(user_factor: float = 1.0, config: HapticsConfig = null) -> HapticPlanner:
	var p: HapticPlanner = HapticPlanner.new(config if config != null else HapticsConfig.new())
	p.user_factor = user_factor
	return p


func _pattern(id: StringName) -> HapticPattern:
	return HapticPatterns.defaults()[id] as HapticPattern


func test_default_patterns_are_sane() -> void:
	var table: Dictionary = HapticPatterns.defaults()
	var required: Array[StringName] = [
		&"ui_tap",
		&"ui_confirm",
		&"ui_denied",
		&"back_hint",
		&"contact",
		&"kill",
		&"multi_kill",
		&"heavy_shot",
		&"hurt_light",
		&"hurt_heavy",
		&"death",
		&"wave_start",
		&"wave_clear",
		&"boss_warning",
		&"boss_phase",
		&"boss_slam",
		&"boss_defeated",
	]
	for id: StringName in required:
		t.call("check", table.has(id), "motif %s défini" % id)
	for id: StringName in table:
		var p: HapticPattern = table[id] as HapticPattern
		t.call("check", p.id == id and not p.pulses.is_empty(), "%s : impulsions" % id)
		t.call("check", p.total_ms() <= 700, "%s : motif court (%d ms)" % [id, p.total_ms()])
		for pulse: Vector3 in p.pulses:
			t.call("check", pulse.x >= 10.0 and pulse.x <= 250.0, "%s : durée plausible" % id)
			t.call("check", pulse.y > 0.0 and pulse.y <= 1.0, "%s : amplitude 0..1" % id)
			t.call("check", pulse.z >= 0.0, "%s : pause positive" % id)
	var hurt: HapticPattern = table[&"hurt_heavy"]
	var kill: HapticPattern = table[&"kill"]
	t.call(
		"check",
		hurt.vibration_ms() > kill.vibration_ms() * 3,
		"un coup reçu se sent bien plus qu'une élimination"
	)
	t.call(
		"check",
		int(table[&"death"].priority) > int(hurt.priority),
		"la mort est plus prioritaire que les dégâts"
	)
	t.call("check", int(hurt.priority) > int(kill.priority))


func test_pulses_are_scheduled_in_order() -> void:
	var p: HapticPlanner = _planner()
	t.call("check", p.request(_pattern(&"ui_confirm"), 1.0, 1000.0), "motif accepté")
	var first: Array[Vector2] = p.pump(1000.0)
	t.call(
		"check",
		first.size() == 1 and is_equal_approx(first[0].x, 18.0),
		"1re impulsion tout de suite"
	)
	t.call("check", p.pump(1057.0).is_empty(), "la pause de 40 ms est respectée")
	var second: Array[Vector2] = p.pump(1058.0)
	t.call(
		"check",
		second.size() == 1 and is_equal_approx(second[0].x, 28.0),
		"2e impulsion après la pause"
	)
	t.call("check", p.pending() == 0)


func test_amplitude_scaling_and_clamping() -> void:
	var p: HapticPlanner = _planner(1.35)
	p.request(_pattern(&"hurt_light"), 0.5, 0.0)  # 0,6 × 0,5 × 1 × 1,35
	var out: Array[Vector2] = p.pump(0.0)
	t.call(
		"check",
		out.size() == 1 and absf(out[0].y - 0.405) < 0.001,
		"amplitude = base × échelle × niveau (%.3f)" % out[0].y
	)
	var q: HapticPlanner = _planner(1.35)
	q.request(_pattern(&"hurt_heavy"), 5.0, 0.0)
	for pulse: Vector2 in q.pump(1.0e9):
		t.call("check", pulse.y <= 1.0, "amplitude plafonnée à 1")
	var cfg: HapticsConfig = HapticsConfig.new()
	cfg.master_intensity = 0.5
	var r: HapticPlanner = _planner(1.0, cfg)
	r.request(_pattern(&"hurt_light"), 1.0, 0.0)
	t.call("check", absf(r.pump(0.0)[0].y - 0.3) < 0.001, "intensité générale appliquée")


func test_weak_and_short_pulses() -> void:
	var p: HapticPlanner = _planner()
	t.call(
		"check", not p.request(_pattern(&"kill"), 0.1, 0.0), "impulsion trop faible : rien à vibrer"
	)
	t.call("check", p.pump(1.0e9).is_empty())
	var short: HapticPattern = HapticPattern.new(
		&"short", HapticPattern.Priority.NORMAL, 0, [Vector3(5.0, 1.0, 0.0)]
	)
	t.call("check", p.request(short, 1.0, 0.0))
	var out: Array[Vector2] = p.pump(0.0)
	t.call(
		"check",
		is_equal_approx(out[0].x, float(HapticsConfig.new().min_pulse_ms)),
		"durée minimale imposée"
	)


func test_disabled_setting_blocks_everything() -> void:
	var p: HapticPlanner = _planner(0.0)
	t.call("check", not p.enabled())
	for id: StringName in HapticPatterns.defaults():
		t.call("check", not p.request(_pattern(id), 1.0, 0.0), "%s bloqué si désactivé" % id)
	t.call("check", p.pump(1.0e9).is_empty())
	var cfg: HapticsConfig = HapticsConfig.new()
	cfg.master_intensity = 0.0
	t.call(
		"check",
		not _planner(1.0, cfg).request(_pattern(&"death"), 1.0, 0.0),
		"intensité générale nulle"
	)


func test_per_pattern_cooldown() -> void:
	var p: HapticPlanner = _planner()
	var contact: HapticPattern = _pattern(&"contact")
	t.call("check", p.request(contact, 1.0, 0.0))
	p.pump(1000.0)
	t.call(
		"check",
		not p.request(contact, 1.0, float(contact.cooldown_ms) - 1.0),
		"dans le délai : refusé"
	)
	t.call("check", p.request(contact, 1.0, float(contact.cooldown_ms)), "délai écoulé : accepté")


func test_priority_blocks_and_preempts() -> void:
	var p: HapticPlanner = _planner()
	t.call("check", p.request(_pattern(&"death"), 1.0, 0.0), "mort acceptée")
	t.call(
		"check", not p.request(_pattern(&"hurt_heavy"), 1.0, 10.0), "dégâts bloqués pendant la mort"
	)
	t.call(
		"check",
		not p.request(_pattern(&"boss_warning"), 1.0, 10.0),
		"priorité égale : pas d'interruption"
	)
	t.call(
		"check", not p.request(_pattern(&"kill"), 1.0, 10.0), "une élimination ne coupe pas la mort"
	)
	p.reset()
	# Un motif prioritaire remplace ce qui n'a pas encore démarré.
	p.request(_pattern(&"ui_confirm"), 1.0, 0.0)
	t.call("check", p.request(_pattern(&"hurt_heavy"), 1.0, 10.0), "priorité supérieure : accepté")
	var pulses: Array[Vector2] = p.pump(1.0e9)
	t.call(
		"check",
		pulses.size() == 2,
		"seules les impulsions du motif prioritaire restent (%d)" % pulses.size()
	)
	t.call("check", is_equal_approx(pulses[0].x, 60.0))


func test_busy_ends_and_lower_priority_resumes() -> void:
	var p: HapticPlanner = _planner()
	p.request(_pattern(&"kill"), 1.0, 0.0)
	t.call(
		"check",
		not p.request(_pattern(&"heavy_shot"), 1.0, 5.0),
		"même priorité pendant un motif : ignoré"
	)
	p.pump(1000.0)
	t.call(
		"check", p.request(_pattern(&"heavy_shot"), 1.0, 100.0), "motif terminé : on peut rejouer"
	)


func test_budget_limits_frequent_patterns_but_not_urgent_ones() -> void:
	var cfg: HapticsConfig = HapticsConfig.new()
	cfg.budget_ms_per_5s = 100
	var p: HapticPlanner = _planner(1.0, cfg)
	var tap: HapticPattern = _pattern(&"ui_tap")
	var accepted: int = 0
	for i: int in 12:
		if p.request(tap, 1.0, float(i) * 100.0):
			accepted += 1
		p.pump(float(i) * 100.0 + 50.0)
	t.call(
		"check",
		accepted >= 5 and accepted <= 7,
		"le plafond coupe les motifs fréquents (%d acceptés)" % accepted
	)
	t.call(
		"check",
		p.request(_pattern(&"hurt_light"), 1.0, 1250.0),
		"les dégâts passent malgré le plafond"
	)
	p.pump(1.0e9)
	t.call("check", p.request(tap, 1.0, 9000.0), "la fenêtre de 5 s se libère")


func test_haptics_autoload_maps_game_events_to_patterns() -> void:
	UserSettings.path_override = "user://test_settings.cfg"
	DirAccess.remove_absolute(UserSettings.path_override)
	Haptics.set_level(2)
	Haptics.reset()
	var played: Array[StringName] = []
	var calls: Array[Vector2] = []
	var listener: Callable = func(id: StringName, _scale: float) -> void: played.append(id)
	Haptics.pattern_played.connect(listener)
	Haptics.backend = func(ms: int, amp: float) -> void: calls.append(Vector2(ms, amp))
	var cases: Array = [
		[func() -> void: EventBus.combat_activated.emit(2, Vector3.ZERO), &"contact"],
		[func() -> void: EventBus.player_damaged.emit(5.0, 95.0), &"hurt_light"],
		[func() -> void: EventBus.player_damaged.emit(25.0, 70.0), &"hurt_heavy"],
		[func() -> void: EventBus.player_died.emit(), &"death"],
		[func() -> void: EventBus.enemy_died.emit(0, 1, Vector3.ZERO), &"kill"],
		[func() -> void: EventBus.wave_started.emit(2), &"wave_start"],
		[func() -> void: EventBus.wave_completed.emit(2), &"wave_clear"],
		[func() -> void: EventBus.boss_warning.emit(10, 2.0, Vector2.ZERO), &"boss_warning"],
		[func() -> void: EventBus.boss_phase_changed.emit(0, 2), &"boss_phase"],
		[func() -> void: EventBus.boss_defeated.emit(0, 120), &"boss_defeated"],
		[func() -> void: EventBus.shockwave.emit(Vector2.ZERO, 3.0), &"boss_slam"],
		[func() -> void: EventBus.turret_upgraded.emit(0, 2), &"ui_confirm"],
		[func() -> void: EventBus.upgrade_denied.emit(0), &"ui_denied"],
	]
	for c: Array in cases:
		Haptics.reset()
		played.clear()
		(c[0] as Callable).call()
		t.call("check", played == [c[1]], "événement -> %s (obtenu %s)" % [c[1], str(played)])
	Haptics.tick(1.0e12)
	t.call("check", not calls.is_empty(), "le backend reçoit bien les impulsions")
	for call_v: Vector2 in calls:
		t.call(
			"check",
			call_v.x >= 15.0 and call_v.y > 0.0 and call_v.y <= 1.0,
			"appel valide (durée, amplitude)"
		)
	Haptics.pattern_played.disconnect(listener)
	Haptics.backend = Callable(Haptics, "_vibrate")
	Haptics.reset()
	DirAccess.remove_absolute(UserSettings.path_override)
	UserSettings.path_override = ""


func test_heavy_shots_only_vibrate_for_heavy_turret() -> void:
	Haptics.set_level(2)
	Haptics.reset()
	var played: Array[StringName] = []
	var listener: Callable = func(id: StringName, _s: float) -> void: played.append(id)
	Haptics.pattern_played.connect(listener)
	for data: TurretData in DataRegistry.turrets():
		Haptics.reset()
		played.clear()
		EventBus.turret_fired.emit(0, data, Vector2.ZERO, Vector2.RIGHT)
		var heavy: bool = data.projectile.category == ProjectileData.Category.HEAVY
		t.call(
			"check",
			(played == [&"heavy_shot"]) == heavy,
			"%s : tir lourd seulement pour la lourde" % data.id
		)
	Haptics.pattern_played.disconnect(listener)
	Haptics.reset()


func test_multi_kill_pattern_and_pause_clears_queue() -> void:
	Haptics.set_level(2)
	Haptics.reset()
	var played: Array[StringName] = []
	var listener: Callable = func(id: StringName, _s: float) -> void: played.append(id)
	Haptics.pattern_played.connect(listener)
	for i: int in 3:
		Haptics.planner.reset()
		EventBus.enemy_died.emit(i, 1, Vector3.ZERO)
	t.call(
		"check",
		played.has(&"multi_kill"),
		"3 éliminations rapprochées = multi-élimination (%s)" % str(played)
	)
	Haptics.reset()
	Haptics.play(&"death")
	t.call("check", Haptics.planner.pending() > 0)
	EventBus.run_paused.emit(true)
	t.call("check", Haptics.planner.pending() == 0, "la pause abandonne les vibrations en attente")
	Haptics.pattern_played.disconnect(listener)
	Haptics.reset()


func test_user_level_cycle_and_off() -> void:
	UserSettings.path_override = "user://test_settings.cfg"
	DirAccess.remove_absolute(UserSettings.path_override)
	Haptics.set_level(2)
	t.call("check", Haptics.level() == 2)
	t.call(
		"check",
		Haptics.cycle_level() == 3 and UserSettings.haptics_level() == 3,
		"niveau suivant sauvegardé"
	)
	t.call("check", Haptics.cycle_level() == 0, "puis désactivé")
	Haptics.reset()
	t.call("check", not Haptics.play(&"death"), "désactivé : aucune vibration")
	t.call(
		"check",
		Haptics.cycle_level() == 1 and Haptics.cycle_level() == 2,
		"la boucle revient à normal"
	)
	Haptics.reset()
	DirAccess.remove_absolute(UserSettings.path_override)
	UserSettings.path_override = ""
