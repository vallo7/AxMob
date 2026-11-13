class_name GameAudio
extends Node
## Traduit les événements du jeu (EventBus) en sons et en musique adaptative (phase 5).
## Aucun gameplay ne dépend du son : tout passe par l'AudioManager, qui ignore ce qui manque.
##
## Musique : le RYTHME joue toujours ; l'HARMONIE entre dès que le joueur déclenche le combat et
## reste ~5 s après le dernier contact (la musique « répond » à l'action) ; la MÉLODIE se joint
## quand la foule grossit ou après la vague 3. Le boss remplace le morceau (fondu enchaîné).

const CATEGORY_NAMES: Array[String] = ["rapid", "heavy", "multi", "pierce"]
const COMBAT_HOLD: float = 5.0
const BOSS_RETURN_DELAY: float = 3.5
const SLOW_UPDATE: float = 0.1

var _ctx: RunContext
var _combat_hold: float = 0.0
var _boss_alive: bool = false
var _slow: float = 0.0
var _throw_names: Array[StringName] = []
var _hit_names: Array[StringName] = []
var _mat_names: Dictionary = {}
var _die_names: Dictionary = {}


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	for n: String in CATEGORY_NAMES:
		_throw_names.append(StringName("throw_" + n))
		_hit_names.append(StringName("hit_" + n))
	for kind: StringName in [&"shell", &"squish", &"hollow", &"bubble", &"kraken"]:
		_mat_names[kind] = StringName("mat_" + String(kind))
		_die_names[kind] = StringName("die_" + String(kind))
	EventBus.turret_fired.connect(_on_turret_fired)
	EventBus.axe_hit.connect(_on_axe_hit)
	EventBus.axe_splash_resolved.connect(_on_splash_resolved)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.enemy_windup.connect(_on_enemy_windup)
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.combat_activated.connect(_on_combat_activated)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_step.connect(_on_player_step)
	EventBus.wave_started.connect(func(_w: int) -> void: AudioManager.play(&"wave_start"))
	EventBus.wave_completed.connect(func(_w: int) -> void: AudioManager.play(&"wave_clear"))
	EventBus.boss_warning.connect(_on_boss_warning)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(
		func(_i: int, _p: int) -> void: AudioManager.play(&"boss_phase")
	)
	EventBus.shockwave.connect(_on_shockwave)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.multi_kill.connect(_on_multi_kill)
	EventBus.turret_upgraded.connect(
		func(_t: int, _l: int) -> void: AudioManager.play(&"turret_upgrade")
	)
	EventBus.upgrade_denied.connect(func(_t: int) -> void: AudioManager.play(&"ui_denied"))
	EventBus.game_over.connect(func(_w: int, _c: int) -> void: AudioManager.play(&"game_over"))
	EventBus.run_paused.connect(_on_paused)
	AudioManager.set_muffled(false)
	AudioManager.play_music(&"run", 1.2)
	AudioManager.play_ambience()


func _exit_tree() -> void:
	AudioManager.set_muffled(false)


func _process(delta: float) -> void:
	_slow += delta
	if _slow < SLOW_UPDATE:
		return
	var dt: float = _slow
	_slow = 0.0
	_update_music(dt)


## Dose les couches de la musique d'après l'action en cours.
func _update_music(dt: float) -> void:
	if not _ctx.player_alive:
		AudioManager.set_layers(PackedFloat32Array([0.55, 0.0, 0.0]))
		return
	if _ctx.combat_active():
		_combat_hold = COMBAT_HOLD
	else:
		_combat_hold = maxf(_combat_hold - dt, 0.0)
	var active: bool = _combat_hold > 0.0
	var crowd: int = _ctx.enemies.count_living()
	var harmony: float = 1.0 if active or _boss_alive else 0.0
	var melody: float = 1.0 if _boss_alive or (active and (crowd >= 4 or _ctx.wave >= 3)) else 0.0
	AudioManager.set_layers(PackedFloat32Array([1.0, harmony, melody]))


# --- Événements ------------------------------------------------------------------------------


func _on_turret_fired(
	turret_id: int, _data: TurretData, origin: Vector2, _direction: Vector2
) -> void:
	var cat: int = _ctx.turret_data[turret_id].projectile.category
	AudioManager.play(_throw_names[cat], origin, 0.0, 1.0, -1, _ctx.player_pos)


func _on_axe_hit(enemy_id: int, _damage: float, category: int, _direction: Vector2) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if e.data == null:
		return
	AudioManager.play(_hit_names[category], e.pos, 0.0, 1.0, -1, _ctx.player_pos)
	AudioManager.play(
		_mat_names.get(e.data.sound_kind, &"mat_shell") as StringName,
		e.pos,
		0.0,
		1.0,
		-1,
		_ctx.player_pos
	)


func _on_splash_resolved(center: Vector2, _radius: float, hits: int) -> void:
	var vol: float = -1.0 + 0.7 * float(mini(hits, 5))
	AudioManager.play(&"splash_heavy", center, vol, 1.0, -1, _ctx.player_pos)
	AudioManager.duck_music(-4.0 - 0.8 * float(mini(hits, 4)))


func _on_enemy_died(enemy_id: int, reward: int, position: Vector3) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if e.data == null:
		return
	var pos: Vector2 = Vector2(position.x, position.z)
	if e.boss != null:
		AudioManager.play(&"die_kraken", pos, 0.0, 1.0, -1, _ctx.player_pos)
		return
	AudioManager.play(
		_die_names.get(e.data.sound_kind, &"die_shell") as StringName,
		pos,
		0.0,
		1.0,
		-1,
		_ctx.player_pos
	)
	if reward > 0:
		AudioManager.play(&"coin_spawn", pos, 0.0, 1.0, -1, _ctx.player_pos)


func _on_enemy_spawned(enemy_id: int, position: Vector2) -> void:
	var from_water: bool = _ctx.enemies.slots[enemy_id].from_water
	AudioManager.play(
		&"spawn_water" if from_water else &"spawn_sand", position, 0.0, 1.0, -1, _ctx.player_pos
	)


func _on_enemy_windup(enemy_id: int, charging: bool) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if e.data == null:
		return
	if charging:
		AudioManager.play(&"boss_charge", e.pos, 0.0, 1.0, -1, _ctx.player_pos)
		return
	# Seuls les ennemis dangereux préviennent par un son (les petits restent lisibles à l'écran).
	if e.data.sound_kind != &"shell" and e.data.sound_kind != &"squish":
		AudioManager.play(&"enemy_windup", e.pos, 0.0, 1.0, -1, _ctx.player_pos)


## La hauteur monte avec la série de pièces : gamme pentatonique ascendante (do ré mi sol la do...).
func _on_coin_collected(streak: int) -> void:
	AudioManager.play(&"coin_get", AudioManager.NO_POS, 0.0, 1.0, clampi(streak - 1, 0, 7))


func _on_combat_activated(_contacts: int, position: Vector3) -> void:
	AudioManager.play(
		&"combat_activate", Vector2(position.x, position.z), 0.0, 1.0, -1, _ctx.player_pos
	)


func _on_player_damaged(amount: float, _hp: float) -> void:
	if amount <= 0.0:
		return
	AudioManager.play(&"player_hurt")
	AudioManager.duck_music(-5.0)


func _on_player_died() -> void:
	AudioManager.play(&"player_death")
	AudioManager.duck_music(-10.0)
	AudioManager.set_muffled(true)


func _on_player_step(speed_ratio: float) -> void:
	AudioManager.play(&"step_sand", AudioManager.NO_POS, (speed_ratio - 1.0) * 3.0)


func _on_boss_warning(_wave: int, _seconds: float, _position: Vector2) -> void:
	AudioManager.play(&"boss_warning")
	AudioManager.duck_music(-6.0)


func _on_boss_spawned(_id: int) -> void:
	_boss_alive = true
	AudioManager.play(&"boss_roar")
	AudioManager.play_music(&"boss", 0.8)


func _on_shockwave(position: Vector2, _radius: float) -> void:
	AudioManager.play(&"boss_slam", position, 0.0, 1.0, -1, _ctx.player_pos)
	AudioManager.duck_music(-6.0)


func _on_boss_defeated(_id: int, _reward: int) -> void:
	_boss_alive = false
	AudioManager.play(&"boss_defeated")
	AudioManager.duck_music(-8.0)
	get_tree().create_timer(BOSS_RETURN_DELAY).timeout.connect(_return_to_run_music)


func _return_to_run_music() -> void:
	if not _boss_alive and _ctx.player_alive:
		AudioManager.play_music(&"run", 1.5)


func _on_multi_kill(_count: int, _position: Vector3) -> void:
	AudioManager.play(&"multi_kill")
	AudioManager.duck_music(-3.0)


func _on_paused(paused: bool) -> void:
	AudioManager.set_muffled(paused)
