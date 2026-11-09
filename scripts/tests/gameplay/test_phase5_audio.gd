extends RefCounted
## Tests de la phase 5 (son) : bus, limites de déclenchement, polyphonie, musique adaptative,
## ducking et branchement des événements du jeu sur les sons.

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


func _heavy_id() -> int:
	var datas: Array[TurretData] = DataRegistry.turrets()
	for i: int in datas.size():
		if datas[i].projectile.category == ProjectileData.Category.HEAVY:
			return i
	return -1


func _spawn(g: Gameplay, pos: Vector2) -> Enemy:
	var id: int = _enemies(g).spawn(DataRegistry.enemies()[0], pos, 1)
	var e: Enemy = g.ctx.enemies.slots[id]
	e.state = Enemy.State.CHASE
	e.health.max_hp = 500.0
	e.health.hp = 500.0
	return e


# --- Son ------------------------------------------------------------------------------------------


func test_audio_buses_are_built() -> void:
	for bus: StringName in [&"Music", &"SFX", &"UI", &"Ambience"] + AudioManager.PAN_BUSES:
		_check(AudioServer.get_bus_index(bus) >= 0, "bus %s" % bus)
	_check(
		AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Master")) >= 1,
		"limiteur sur Master"
	)
	for i: int in AudioManager.PAN_BUSES.size():
		var idx: int = AudioServer.get_bus_index(AudioManager.PAN_BUSES[i])
		var panner: AudioEffectPanner = AudioServer.get_bus_effect(idx, 0) as AudioEffectPanner
		_check(
			panner != null and is_equal_approx(panner.pan, AudioManager.PAN_VALUES[i]),
			"panoramique du sous-bus %d" % i
		)
		_check(AudioServer.get_bus_send(idx) == &"SFX", "sous-bus %d -> SFX" % i)


func test_audio_rate_limit_modes_and_unknown_sounds() -> void:
	AudioManager.stop_all()
	await (t as SceneTree).create_timer(0.25).timeout
	AudioManager.set_sound_mode(0)
	_check(AudioManager.play(&"ui_confirm"), "premier déclenchement accepté")
	_check(
		not AudioManager.play(&"ui_confirm"), "second déclenchement immédiat refusé (délai minimal)"
	)
	_check(not AudioManager.play(&"son_inexistant"), "son inconnu ignoré sans erreur")
	await (t as SceneTree).create_timer(0.25).timeout
	AudioManager.set_sound_mode(2)
	_check(not AudioManager.play(&"ui_confirm"), "mode silence : rien ne joue")
	AudioManager.set_sound_mode(0)
	_check(UserSettings.sound_mode() == 0, "mode de son sauvegardé")
	_check(AudioManager.sound_label() == "MUSIQUE + EFFETS", "libellé")


func test_audio_voice_stealing_keeps_vital_sounds() -> void:
	await (t as SceneTree).create_timer(0.3).timeout
	var old_limit: int = AudioManager._voice_limit
	AudioManager.stop_all()
	AudioManager._voice_limit = 2
	AudioManager.play(&"step_sand")
	AudioManager.play(&"enemy_spawn")
	var vital: bool = AudioManager.play(&"player_hurt")
	_check(vital, "l'alerte de dégâts coupe un son d'ambiance plutôt que d'être perdue")
	_check(AudioManager.active_voices() <= 2, "polyphonie respectée")
	var low: bool = AudioManager.play(&"coin_spawn")
	_check(not low, "un son peu important n'écrase pas un son vital")
	AudioManager._voice_limit = old_limit
	await (t as SceneTree).create_timer(0.2).timeout


func test_adaptive_music_layers_fade_smoothly() -> void:
	AudioManager.play_music(&"run", 0.1)
	_check(AudioManager.music_kind() == &"run", "morceau de jeu")
	AudioManager.set_layers(PackedFloat32Array([1.0, 0.0, 0.0]))
	AudioManager._update_layers(5.0)
	AudioManager.set_layers(PackedFloat32Array([1.0, 1.0, 1.0]))
	AudioManager._update_layers(0.1)
	_check(
		AudioManager.layer_value(1) > 0.0 and AudioManager.layer_value(1) < 1.0,
		"montée progressive (pas de coupure)"
	)
	AudioManager._update_layers(2.0)
	_check(is_equal_approx(AudioManager.layer_value(2), 1.0), "couche pleine")
	var stream: AudioStreamSynchronized = (
		AudioManager._music_streams[&"run"] as AudioStreamSynchronized
	)
	_check(stream != null and stream.stream_count == 3, "trois couches synchronisées")
	_check(absf(stream.get_sync_stream_volume(2)) < 0.5, "volume de couche ≈ 0 dB")
	AudioManager.set_layers(PackedFloat32Array([1.0, 0.0, 0.0]))
	AudioManager._update_layers(3.0)
	_check(stream.get_sync_stream_volume(1) < -40.0, "couche coupée")
	AudioManager.play_music(&"none", 0.1)


func test_duck_and_muffle() -> void:
	AudioManager._duck_db = 0.0
	AudioManager.duck_music(-6.0)
	_check(AudioManager._duck_db == -6.0, "la musique s'abaisse")
	AudioManager.duck_music(-2.0)
	_check(AudioManager._duck_db == -6.0, "un ducking plus faible n'efface pas un plus fort")
	AudioManager._process(1.0)
	_check(AudioManager._duck_db > -6.0, "elle remonte seule")
	AudioManager.set_muffled(true)
	_check(AudioManager.is_muffled(), "étouffée (pause)")
	AudioManager.set_muffled(false)


func test_game_events_trigger_sounds() -> void:
	AudioManager.stop_all()
	var g: Gameplay = await _make_gameplay()
	await (t as SceneTree).create_timer(0.3).timeout
	var before: int = AudioManager.played
	EventBus.player_damaged.emit(10.0, 90.0)
	_check(AudioManager.played > before, "coup subi -> son de dégâts")
	await (t as SceneTree).create_timer(0.3).timeout
	var b2: int = AudioManager.played
	var heavy: int = _heavy_id()
	EventBus.turret_fired.emit(
		heavy, DataRegistry.turrets()[heavy], Vector2(10.0, 3.0), Vector2.LEFT
	)
	_check(AudioManager.played > b2, "tir de la tourelle lourde -> son de lancer")
	await (t as SceneTree).create_timer(0.3).timeout
	var e: Enemy = _spawn(g, Vector2(4.0, 0.0))
	var b3: int = AudioManager.played
	EventBus.axe_hit.emit(e.id, 10.0, ProjectileData.Category.RAPID, Vector2.RIGHT)
	_check(AudioManager.played >= b3 + 1, "impact -> son d'impact (+ matière)")
	_check(AudioManager.music_kind() == &"run", "la partie lance la musique de jeu")
	_free(g)
	AudioManager.play_music(&"none", 0.1)
