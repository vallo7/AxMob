extends Node
## Retour haptique (autoload « Haptics »). Écoute les événements du jeu (EventBus), les traduit
## en motifs (HapticPatterns) et fait jouer les impulsions via Input.vibrate_handheld
## (durée ms, amplitude 0..1 — signature vérifiée dans Godot 4.7.2).
##
## ANDROID : la permission VIBRATE doit être cochée dans le preset d'export
## (permissions/vibrate=true dans export_presets.cfg) sinon vibrate_handheld() est sans effet.
## Les réglages système du téléphone (vibration coupée, ne pas déranger) peuvent aussi
## empêcher la vibration : rien à faire côté jeu.

signal pattern_played(id: StringName, scale: float)

## Fonction qui fait vibrer : (durée ms: int, amplitude: float). Remplaçable (tests).
var backend: Callable = Callable(self, "_vibrate")
var planner: HapticPlanner

var _patterns: Dictionary = {}
var _config: HapticsConfig
var _recent_kills: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = DataRegistry.haptics()
	if _config == null:
		_config = HapticsConfig.new()
	_patterns = HapticPatterns.defaults()
	planner = HapticPlanner.new(_config)
	set_level(UserSettings.haptics_level())
	EventBus.combat_activated.connect(_on_combat_activated)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(func() -> void: play(&"death"))
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.turret_fired.connect(_on_turret_fired)
	EventBus.wave_started.connect(func(_w: int) -> void: play(&"wave_start"))
	EventBus.wave_completed.connect(func(_w: int) -> void: play(&"wave_clear"))
	EventBus.boss_warning.connect(
		func(_w: int, _s: float, _p: Vector2) -> void: play(&"boss_warning")
	)
	EventBus.boss_phase_changed.connect(func(_i: int, _p: int) -> void: play(&"boss_phase"))
	EventBus.boss_defeated.connect(func(_i: int, _r: int) -> void: play(&"boss_defeated"))
	EventBus.shockwave.connect(func(_p: Vector2, _r: float) -> void: play(&"boss_slam"))
	EventBus.turret_upgraded.connect(func(_i: int, _l: int) -> void: play(&"ui_confirm"))
	EventBus.upgrade_denied.connect(func(_i: int) -> void: play(&"ui_denied"))
	EventBus.run_paused.connect(_on_run_paused)


func _process(_delta: float) -> void:
	tick(float(Time.get_ticks_msec()))


## Joue les impulsions arrivées à échéance. Public pour les tests (horloge simulée).
func tick(now_ms: float) -> void:
	for pulse: Vector2 in planner.pump(now_ms):
		backend.call(int(pulse.x), pulse.y)


## Joue un motif par son identifiant ; `scale` règle son amplitude (0..1+).
func play(id: StringName, scale: float = 1.0, now_ms: float = -1.0) -> bool:
	if not _patterns.has(id) or planner == null:
		return false
	var now: float = now_ms if now_ms >= 0.0 else float(Time.get_ticks_msec())
	var accepted: bool = planner.request(_patterns[id] as HapticPattern, scale, now)
	if accepted:
		pattern_played.emit(id, scale)
	return accepted


## Remet le planificateur à zéro (début de partie, tests).
func reset() -> void:
	planner.reset()
	_recent_kills.clear()


func has_pattern(id: StringName) -> bool:
	return _patterns.has(id)


## Niveau choisi par le joueur : 0 désactivées, 1 légères, 2 normales, 3 fortes. Persisté.
func set_level(level: int) -> void:
	var lv: int = clampi(level, 0, UserSettings.HAPTICS_LEVELS.size() - 1)
	planner.user_factor = UserSettings.HAPTICS_LEVELS[lv]
	if lv == 0:
		planner.clear()


func level() -> int:
	for i: int in UserSettings.HAPTICS_LEVELS.size():
		if is_equal_approx(UserSettings.HAPTICS_LEVELS[i], planner.user_factor):
			return i
	return UserSettings.DEFAULT_HAPTICS_LEVEL


## Passe au niveau suivant (boucle) et le sauvegarde ; retourne le nouveau niveau.
func cycle_level() -> int:
	var next: int = (level() + 1) % UserSettings.HAPTICS_LEVELS.size()
	set_level(next)
	UserSettings.set_haptics_level(next)
	return next


func _vibrate(duration_ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)


func _on_combat_activated(contacts: int, _position: Vector3) -> void:
	play(&"contact", clampf(0.6 + 0.15 * float(contacts), 0.6, 1.0))


func _on_player_damaged(amount: float, _hp_left: float) -> void:
	var strength: float = clampf(amount / maxf(_config.damage_full_scale, 0.001), 0.35, 1.0)
	var heavy: bool = strength >= _config.heavy_hit_fraction
	play(&"hurt_heavy" if heavy else &"hurt_light", strength)


func _on_enemy_died(_id: int, _reward: int, _position: Vector3) -> void:
	var now: float = float(Time.get_ticks_msec())
	_recent_kills.append(now)
	while (
		not _recent_kills.is_empty()
		and now - _recent_kills[0] > float(_config.multi_kill_window_ms)
	):
		_recent_kills.remove_at(0)
	if _recent_kills.size() >= _config.multi_kill_count and play(&"multi_kill"):
		_recent_kills.clear()
		return
	play(&"kill")


func _on_turret_fired(_id: int, data: TurretData, _origin: Vector2, _dir: Vector2) -> void:
	if data.projectile != null and data.projectile.category == ProjectileData.Category.HEAVY:
		play(&"heavy_shot")


func _on_run_paused(paused: bool) -> void:
	if paused:
		planner.clear()
