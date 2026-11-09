class_name EnemyManager
extends Node3D
## Simule tous les ennemis en un seul passage par tick (pas de _process par ennemi),
## entretient la SpatialGrid, applique les dégâts des haches et déclenche les attaques.
## Gère aussi les niveaux d'ennemis et le boss (onde de choc, charge, invocation).

const FLASH_TIME: float = 0.08
const SEPARATION_STRENGTH: float = 6.0
const EDGE_MARGIN: float = 1.2
const EDGE_STRENGTH: float = 4.0
const MAX_ENEMY_RADIUS: float = 1.6
const BRAKE_ACCEL: float = 40.0
## Une barre de vie reste affichée ce temps (s) après un impact.
const BAR_SHOW_TIME: float = 2.5
const CHARGE_AIM_LOCK: float = 0.3
const SUMMON_RING: float = 2.2
const BOSS_ROAR_TIME: float = 0.8
## Marge de portée : une charge qui arrive tout juste au contact du joueur reste utile.
const CHARGE_REACH_SLACK: float = 1.0
## Au-delà de cette distance au joueur, l'animation n'avance qu'un tick sur deux (plan §2.3).
## Part du temps de mort pendant laquelle l'animation joue avant le rétrécissement final.
const DEATH_ANIM_SHARE: float = 0.75
## Modèles préchauffés au chargement (évite les à-coups aux premières apparitions).
const PREWARM: Dictionary = {&"basic": 6, &"fast": 5, &"heavy": 3, &"elite": 2, &"boss": 1}

var _ctx: RunContext
## Modèles libres par nom de modèle (un pool par type : les squelettes ne sont pas partagés).
var _free_rigs: Dictionary = {}
var _tick: int = 0
var _pool_root: Node3D
var _warm_frames: int = 0
var _telegraph_ring: MeshInstance3D
var _telegraph_fill: MeshInstance3D
var _telegraph_line: MeshInstance3D
var _juice_out: EnemyJuice.Out = EnemyJuice.Out.new()
## Animation lointaine (profil de qualité) : distance au carré et 1 tick sur N.
var _far_dist_sq: float = 14.0 * 14.0
var _far_divisor: int = 2


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	_pool_root = Node3D.new()
	_pool_root.name = "RigPool"
	_pool_root.visible = false
	add_child(_pool_root)
	for e: Enemy in ctx.enemies.slots:
		var holder: Node3D = Node3D.new()
		holder.visible = false
		add_child(holder)
		e.visual = holder
	_prewarm()
	_build_telegraphs()
	EventBus.axe_hit.connect(_on_axe_hit)
	EventBus.axe_splash.connect(_on_axe_splash)
	EventBus.enemy_spawn_requested.connect(_on_spawn_requested)
	EventBus.quality_changed.connect(func(_t: int) -> void: apply_profile(QualityManager.profile))
	apply_profile(QualityManager.profile)


## Profil de qualité : les ennemis lointains animent un tick sur N (au N-uple du pas).
func apply_profile(profile: QualityProfile) -> void:
	_far_dist_sq = profile.far_anim_dist * profile.far_anim_dist
	_far_divisor = maxi(profile.far_anim_divisor, 1)


func _on_spawn_requested(data: EnemyData, position: Vector2, level: int) -> void:
	spawn(data, position, level)


func spawn(data: EnemyData, position: Vector2, level: int = 1) -> int:
	var id: int = _ctx.enemies.find_free()
	if id < 0:
		return -1
	var balance: BalanceConfig = _ctx.balance
	var e: Enemy = _ctx.enemies.slots[id]
	e.data = data
	e.level = maxi(level, 1)
	e.pos = position
	e.vel = Vector2.ZERO
	e.state = Enemy.State.SPAWNING
	e.state_time = 0.0
	e.health = HealthComponent.new(data.max_hp * EnemyLevels.hp_mult(balance, e.level), 0.0)
	e.damage_mult = EnemyLevels.damage_mult(balance, e.level)
	e.speed_mult = EnemyLevels.speed_mult(balance, e.level)
	e.reward_value = EnemyLevels.reward(data.reward, balance, e.level)
	e.flash_left = 0.0
	e.bar_until = -1.0
	e.contact_rearm_at = 0.0
	e.recover_for = 0.0
	e.reward_granted = false
	e.boss = null
	var to_player: Vector2 = _ctx.player_pos - position
	e.facing = to_player.normalized() if to_player.length() > 0.001 else Vector2(0.0, 1.0)
	e.roaring = false
	e.anim_state = -1
	e.hit_kick = 0.0
	e.hit_dir = Vector2.ZERO
	e.juice_phase = float(id) * 1.7
	e.idle_phase = float(id) * 0.9
	_attach_rig(e)
	_ctx.grid.insert(id, position)
	_sync_visual(e)
	# Emplacement recyclé : le modèle apparaît directement à sa place (pas de glissement).
	e.visual.reset_physics_interpolation()
	EventBus.enemy_spawned.emit(id, position)
	if data is BossData:
		e.boss = BossState.new(data as BossData)
		_ctx.boss_id = id
		EventBus.boss_spawned.emit(id)
	return id


func step(dt: float) -> void:
	_tick += 1
	for e: Enemy in _ctx.enemies.slots:
		if e.state == Enemy.State.INACTIVE:
			continue
		e.state_time += dt
		e.flash_left = maxf(e.flash_left - dt, 0.0)
		if e.boss != null:
			e.boss.charge_cooldown -= dt
			e.boss.summon_timer -= dt
		match e.state:
			Enemy.State.SPAWNING:
				if e.state_time >= _ctx.config.spawn_invuln:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.CHASE:
				_step_chase(e, dt)
			Enemy.State.WINDUP:
				_step_windup(e, dt)
			Enemy.State.CHARGE_WINDUP:
				_step_charge_windup(e, dt)
			Enemy.State.CHARGING:
				_step_charging(e, dt)
			Enemy.State.RECOVER:
				_move(e, Vector2.ZERO, dt)
				if e.state_time >= e.recover_for:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.STAGGER:
				_move(e, Vector2.ZERO, dt)
				if e.state_time >= _ctx.config.stagger_time:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.DYING:
				if e.state_time >= _death_time(e):
					e.state = Enemy.State.INACTIVE
					e.visual.visible = false
					_release_rig(e)
		_advance_animation(e, dt)
		EnemyJuice.advance(e, EnemyJuice.profile_of(e), e.data.speed * e.speed_mult, dt)
		_sync_visual(e)
	_rebuild_grid()
	_update_telegraphs()


func _enter(e: Enemy, state: Enemy.State) -> void:
	e.state = state
	e.state_time = 0.0
	if state == Enemy.State.WINDUP or state == Enemy.State.CHARGE_WINDUP:
		EventBus.enemy_windup.emit(e.id, state == Enemy.State.CHARGE_WINDUP)
	if state != Enemy.State.RECOVER:
		e.roaring = false


func _enter_recover(e: Enemy, duration: float) -> void:
	e.recover_for = duration
	_enter(e, Enemy.State.RECOVER)


func _death_time(e: Enemy) -> float:
	return e.data.death_time if e.data.death_time > 0.0 else _ctx.config.death_time


func _step_chase(e: Enemy, dt: float) -> void:
	if e.boss != null and _boss_specials(e):
		return
	var to_player: Vector2 = _ctx.player_pos - e.pos
	var dist: float = to_player.length()
	var desired: Vector2 = Vector2.ZERO
	if _ctx.player_alive and dist > 0.001:
		e.facing = to_player / dist
		desired = e.facing * e.data.speed * e.speed_mult
	_move(e, desired, dt)
	if _ctx.player_alive and _player_gap(e) <= e.data.attack_range:
		_enter(e, Enemy.State.WINDUP)


func _step_windup(e: Enemy, dt: float) -> void:
	e.vel = Steering.approach(e.vel, Vector2.ZERO, BRAKE_ACCEL, dt)
	e.pos += e.vel * dt
	_resolve_player_overlap(e)
	var to_player: Vector2 = _ctx.player_pos - e.pos
	if to_player.length() > 0.001:
		e.facing = to_player.normalized()
	if e.state_time < e.data.windup_time:
		return
	# ATTACK : un seul test par attaque, jamais de dégâts à chaque frame.
	if e.boss != null:
		_boss_slam(e)
	elif _ctx.player_alive and _player_gap(e) <= e.data.attack_range + _ctx.config.attack_leeway:
		EventBus.enemy_attack_landed.emit(e.data.damage * e.damage_mult, e.pos)
	var phase: int = e.boss.phase if e.boss != null else 1
	_enter_recover(e, e.data.recover_time * BossPhases.recover_scale(phase))


## Distance de surface à surface entre le joueur et cet ennemi.
func _player_gap(e: Enemy) -> float:
	return e.pos.distance_to(_ctx.player_pos) - _ctx.config.player_radius - e.data.radius


func _move(e: Enemy, desired: Vector2, dt: float) -> void:
	var arena_r: float = _ctx.config.arena_radius
	desired += _separation(e)
	desired += Steering.edge_push(e.pos, arena_r - e.data.radius, EDGE_MARGIN, EDGE_STRENGTH)
	e.vel = Steering.approach(e.vel, desired, e.data.max_accel, dt)
	e.pos += e.vel * dt
	_resolve_player_overlap(e)
	e.pos = Steering.clamp_to_arena(e.pos, e.data.radius, arena_r)


func _separation(e: Enemy) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for j: int in _ctx.grid.query_circle(e.pos, e.data.radius + MAX_ENEMY_RADIUS):
		if j == e.id:
			continue
		var other: Enemy = _ctx.enemies.slots[j]
		if other.state == Enemy.State.INACTIVE or other.state == Enemy.State.DYING:
			continue
		var delta: Vector2 = e.pos - other.pos
		var d: float = delta.length()
		var overlap: float = e.data.radius + other.data.radius - d
		if overlap <= 0.0:
			continue
		if d < 0.001:
			delta = Vector2.from_angle(float(e.id) * 2.4)
			d = 1.0
		push += delta / d * overlap * SEPARATION_STRENGTH
	return push


## Le joueur ne se laisse pas traverser : l'ennemi est repoussé hors de son cercle.
func _resolve_player_overlap(e: Enemy) -> void:
	var min_dist: float = _ctx.config.player_radius + e.data.radius
	var delta: Vector2 = e.pos - _ctx.player_pos
	var d: float = delta.length()
	if d >= min_dist:
		return
	if d < 0.001:
		delta = Vector2.from_angle(float(e.id) * 2.4)
		d = 1.0
	e.pos = _ctx.player_pos + delta / d * min_dist


# --- Boss -----------------------------------------------------------------------------------


## Décide des capacités spéciales ; retourne vrai si l'état a changé (la poursuite est sautée).
func _boss_specials(e: Enemy) -> bool:
	var b: BossState = e.boss
	if not _ctx.player_alive:
		return false
	if BossPhases.can_summon(b.phase) and b.summon_timer <= 0.0:
		_boss_summon(e)
		b.summon_timer = b.data.summon_interval
	var to_player: Vector2 = _ctx.player_pos - e.pos
	var dist: float = to_player.length()
	if (
		BossPhases.can_charge(b.phase)
		and b.charge_cooldown <= 0.0
		and dist >= b.data.charge_min_distance
		and dist <= b.data.charge_reach() + CHARGE_REACH_SLACK
	):
		b.charge_dir = to_player / maxf(dist, 0.001)
		b.charge_hit = false
		_enter(e, Enemy.State.CHARGE_WINDUP)
		return true
	return false


func _boss_summon(e: Enemy) -> void:
	var b: BossState = e.boss
	if b.data.summon_enemy == null:
		return
	var level: int = maxi(e.level / 2, 1)
	for i: int in b.data.summon_count:
		var angle: float = TAU * float(i) / float(maxi(b.data.summon_count, 1)) + float(e.id)
		var p: Vector2 = e.pos + Vector2.from_angle(angle) * (e.data.radius + SUMMON_RING)
		p = Steering.clamp_to_arena(p, b.data.summon_enemy.radius, _ctx.config.arena_radius)
		EventBus.enemy_spawn_requested.emit(b.data.summon_enemy, p, level)


## Onde de choc : touche le joueur s'il est dans le rayon à l'instant de l'impact.
func _boss_slam(e: Enemy) -> void:
	var radius: float = e.boss.data.shock_radius
	EventBus.shockwave.emit(e.pos, radius)
	if not _ctx.player_alive:
		return
	var reach: float = e.pos.distance_to(_ctx.player_pos) - _ctx.config.player_radius
	if reach <= radius:
		EventBus.enemy_attack_landed.emit(e.data.damage * e.damage_mult, e.pos)


func _step_charge_windup(e: Enemy, dt: float) -> void:
	var b: BossState = e.boss
	e.vel = Steering.approach(e.vel, Vector2.ZERO, BRAKE_ACCEL, dt)
	e.pos += e.vel * dt
	_resolve_player_overlap(e)
	# La visée suit le joueur puis se verrouille juste avant la charge : esquivable.
	if _ctx.player_alive and e.state_time < b.data.charge_windup - CHARGE_AIM_LOCK:
		var to_player: Vector2 = _ctx.player_pos - e.pos
		if to_player.length() > 0.001:
			b.charge_dir = to_player.normalized()
	e.facing = b.charge_dir
	if e.state_time >= b.data.charge_windup:
		_enter(e, Enemy.State.CHARGING)


func _step_charging(e: Enemy, dt: float) -> void:
	var b: BossState = e.boss
	e.vel = b.charge_dir * b.data.charge_speed
	e.pos += e.vel * dt
	e.facing = b.charge_dir
	var limit: float = maxf(_ctx.config.arena_radius - e.data.radius, 0.0)
	var at_wall: bool = e.pos.length() >= limit
	e.pos = Steering.clamp_to_arena(e.pos, e.data.radius, _ctx.config.arena_radius)
	var contact: float = e.data.radius + _ctx.config.player_radius
	var hit: bool = _ctx.player_alive and e.pos.distance_to(_ctx.player_pos) <= contact
	if hit:
		b.charge_hit = true
		EventBus.enemy_attack_landed.emit(
			e.data.damage * e.damage_mult * b.data.charge_damage_mult, e.pos
		)
		_resolve_player_overlap(e)
	if hit or at_wall or e.state_time >= b.data.charge_duration:
		e.vel = Vector2.ZERO
		b.charge_cooldown = b.data.charge_cooldown
		_enter_recover(e, e.data.recover_time * 1.4)


func _update_boss_phase(e: Enemy) -> void:
	var b: BossState = e.boss
	var phase: int = BossPhases.phase_for(e.health.fraction(), b.data.phase_thresholds)
	if phase <= b.phase:
		return
	b.phase = phase
	EventBus.boss_phase_changed.emit(e.id, phase)
	# Rugissement : courte pause visible, puis les nouvelles capacités se mettent en route.
	e.vel = Vector2.ZERO
	b.charge_cooldown = minf(b.charge_cooldown, 1.5)
	b.summon_timer = minf(b.summon_timer, 0.6)
	_enter_recover(e, BOSS_ROAR_TIME)
	e.roaring = true


# --- Dégâts, mort ---------------------------------------------------------------------------


func _on_axe_hit(enemy_id: int, raw_damage: float, category: int, direction: Vector2) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if not e.is_hittable():
		return
	_hurt(e, raw_damage, category, direction, 1.0)


## Impact de zone : tous les ennemis touchables dans le rayon (sauf celui déjà frappé en direct)
## prennent des dégâts décroissants avec la distance et sont repoussés du centre.
func _on_axe_splash(
	center: Vector2,
	radius: float,
	raw_damage: float,
	category: int,
	source_id: int,
	falloff: float,
	knockback: float
) -> void:
	var hits: int = 0
	for id: int in _ctx.grid.query_circle(center, radius + MAX_ENEMY_RADIUS):
		if id == source_id:
			continue
		var e: Enemy = _ctx.enemies.slots[id]
		if not e.is_hittable():
			continue
		var offset: Vector2 = e.pos - center
		var gap: float = offset.length() - e.data.radius
		if gap > radius:
			continue
		var edge: float = clampf(gap / maxf(radius, 0.01), 0.0, 1.0)
		var dmg: float = raw_damage * lerpf(1.0, falloff, edge)
		var away: Vector2 = offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
		_hurt(e, dmg, category, away, knockback / maxf(_ctx.config.knockback_speed, 0.01))
		hits += 1
	EventBus.axe_splash_resolved.emit(center, radius, hits)


func _hurt(e: Enemy, raw_damage: float, category: int, direction: Vector2, knock: float) -> void:
	var dmg: float = DamageCalculator.compute(raw_damage, e.data.resistance(category))
	var applied: float = e.health.apply_damage(dmg)
	EventBus.enemy_hit.emit(e.id, applied)
	e.flash_left = FLASH_TIME
	e.bar_until = _ctx.time + BAR_SHOW_TIME
	e.hit_kick = 1.0
	e.hit_dir = direction
	e.vel += direction * _ctx.config.knockback_speed * e.data.stagger_scale * knock
	if e.health.is_dead():
		_kill(e)
		return
	if e.boss != null:
		_update_boss_phase(e)
	elif e.data.stagger_scale >= 0.5 and e.state != Enemy.State.STAGGER:
		_enter(e, Enemy.State.STAGGER)


func _kill(e: Enemy) -> void:
	_enter(e, Enemy.State.DYING)
	e.vel = Vector2.ZERO
	if e.reward_granted:
		return
	e.reward_granted = true
	EventBus.enemy_died.emit(e.id, e.reward_value, Planar.to3(e.pos))
	if e.boss != null:
		if _ctx.boss_id == e.id:
			_ctx.boss_id = -1
		EventBus.boss_defeated.emit(e.id, e.reward_value)


func _rebuild_grid() -> void:
	_ctx.grid.clear()
	for e: Enemy in _ctx.enemies.slots:
		if e.state != Enemy.State.INACTIVE and e.state != Enemy.State.DYING:
			_ctx.grid.insert(e.id, e.pos)


# --- Rendu : modèles Blender animés (phase 4) -------------------------------------------------


## Réchauffe le rendu : montre le pool de modèles (minuscule, au centre) 2 images pour que le
## moteur envoie maillages et variantes de shaders au GPU AVANT la première apparition d'ennemi
## (sinon : micro-saccade au premier ennemi de chaque type, très visible sur mobile).
func warm_up_rendering() -> void:
	_pool_root.scale = Vector3.ONE * 0.001
	_pool_root.visible = true
	_warm_frames = 2
	get_tree().process_frame.connect(_warm_tick)


func _warm_tick() -> void:
	_warm_frames -= 1
	if _warm_frames > 0:
		return
	_pool_root.visible = false
	_pool_root.scale = Vector3.ONE
	get_tree().process_frame.disconnect(_warm_tick)


func _prewarm() -> void:
	for id: StringName in PREWARM:
		var list: Array = []
		var model_name: String = "enemy_%s" % id
		for i: int in int(PREWARM[id]):
			var rig: ModelRig = ModelRig.create(model_name)
			if rig != null:
				_pool_root.add_child(rig.root)
				list.append(rig)
		_free_rigs[model_name] = list


func _attach_rig(e: Enemy) -> void:
	var model_name: String = e.data.model()
	var free: Array = _free_rigs.get(model_name, []) as Array
	var rig: ModelRig = (
		free.pop_back() as ModelRig if not free.is_empty() else ModelRig.create(model_name)
	)
	_free_rigs[model_name] = free
	e.rig = rig
	if rig == null:
		e.visual.visible = false
		return
	if rig.root.get_parent() != null:
		rig.root.reparent(e.visual, false)
	else:
		e.visual.add_child(rig.root)
	rig.current = &""
	rig.root.transform = Transform3D.IDENTITY
	rig.set_flash(0.0)
	rig.set_alert(Color(1.0, 0.35, 0.1, 0.0))
	var tier: int = EnemyLevels.tint_tier(e.level)
	rig.set_tint(EnemyLevels.tier_tint(tier))
	rig.set_glow(EnemyLevels.tier_glow(tier))
	rig.play(&"idle", 1.0, true)
	e.visual.visible = true


func _release_rig(e: Enemy) -> void:
	if e.rig == null:
		return
	e.rig.root.reparent(_pool_root, false)
	var model_name: String = e.rig.model_name
	var free: Array = _free_rigs.get(model_name, []) as Array
	free.append(e.rig)
	_free_rigs[model_name] = free
	e.rig = null


func _advance_animation(e: Enemy, dt: float) -> void:
	if e.rig == null:
		return
	_choose_animation(e)
	# Les ennemis lointains n'animent qu'un tick sur N, à N fois le pas (profil de qualité).
	if e.pos.distance_squared_to(_ctx.player_pos) <= _far_dist_sq:
		e.rig.advance(dt)
	elif (_tick + e.id) % _far_divisor == 0:
		e.rig.advance(dt * float(_far_divisor))


## Choisit l'animation d'après l'état de simulation. Les durées de la simulation (armement,
## étourdissement, mort) restent maîtresses : les clips sont accélérés ou ralentis pour s'y caler.
func _choose_animation(e: Enemy) -> void:
	var rig: ModelRig = e.rig
	var changed: bool = e.anim_state != int(e.state)
	e.anim_state = int(e.state)
	match e.state:
		Enemy.State.SPAWNING, Enemy.State.ATTACK:
			rig.play(&"idle", 1.0)
		Enemy.State.CHASE:
			var nominal: float = maxf(e.data.speed * e.speed_mult, 0.1)
			var ratio: float = e.vel.length() / nominal
			if ratio > 0.2:
				rig.play(&"run", clampf(ratio, 0.5, 1.5))
			else:
				rig.play(&"idle", 1.0)
		Enemy.State.WINDUP:
			if changed:
				var speed: float = (
					rig.length_of(&"attack")
					* ModelRig.STRIKE_FRACTION
					/ maxf(e.data.windup_time, 0.05)
				)
				rig.play(&"attack", speed, true)
		Enemy.State.CHARGE_WINDUP:
			if changed:
				var speed: float = (
					rig.length_of(&"charge_windup") / maxf(e.boss.data.charge_windup, 0.05)
				)
				rig.play(&"charge_windup", speed, true)
		Enemy.State.CHARGING:
			rig.play(&"charge", 1.0)
		Enemy.State.RECOVER:
			if e.roaring:
				if changed or rig.current != &"roar":
					rig.play(&"roar", rig.length_of(&"roar") / BOSS_ROAR_TIME, true)
			elif not (rig.current == &"attack" and not rig.finished()):
				rig.play(&"idle", 1.0)
		Enemy.State.STAGGER:
			if changed:
				rig.play(&"hit", rig.length_of(&"hit") / maxf(_ctx.config.stagger_time, 0.05), true)
		Enemy.State.DYING:
			if changed:
				var speed: float = (
					rig.length_of(&"death") / maxf(_death_time(e) * DEATH_ANIM_SHARE, 0.05)
				)
				rig.play(&"death", speed, true)


func _sync_visual(e: Enemy) -> void:
	if e.rig == null:
		return
	var scale_f: float = 1.0
	var alert: float = 0.0
	match e.state:
		Enemy.State.WINDUP:
			var wp: float = clampf(e.state_time / e.data.windup_time, 0.0, 1.0)
			alert = 0.12 + 0.5 * wp * (0.8 + 0.2 * sin(e.state_time * 30.0))
		Enemy.State.CHARGE_WINDUP:
			var cp: float = clampf(e.state_time / maxf(e.boss.data.charge_windup, 0.01), 0.0, 1.0)
			alert = 0.15 + 0.5 * cp * (0.8 + 0.2 * sin(e.state_time * 30.0))
		Enemy.State.CHARGING:
			alert = 0.35
		Enemy.State.DYING:
			var k: float = clampf(e.state_time / _death_time(e), 0.0, 1.0)
			scale_f = 1.0 - smoothstep(0.7, 1.0, k)
	e.rig.set_flash(0.85 if e.flash_left > 0.0 else 0.0)
	e.rig.set_alert(Color(1.0, 0.4, 0.12, alert))
	e.visual.rotation.y = Planar.yaw_from_dir(e.facing)
	e.visual.scale = Vector3.ONE * maxf(scale_f, 0.01) * e.data.visual_scale
	e.visual.position = Vector3(e.pos.x, 0.0, e.pos.y)
	_apply_juice(e)


## Animation procédurale (EnemyJuice) appliquée au modèle, par-dessus le clip Blender.
func _apply_juice(e: Enemy) -> void:
	var j: JuiceProfile = EnemyJuice.profile_of(e)
	var nominal: float = e.data.speed * e.speed_mult
	EnemyJuice.compute(e, j, _ctx.config.spawn_invuln, _death_time(e), nominal, _juice_out)
	var root: Node3D = e.rig.root
	root.position = _juice_out.offset
	root.rotation = _juice_out.rot
	root.scale = _juice_out.scale * _juice_out.uniform


func _build_telegraphs() -> void:
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.18, 0.12, 0.22)
	var fill: StandardMaterial3D = StandardMaterial3D.new()
	fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill.albedo_color = Color(1.0, 0.3, 0.1, 0.4)
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 40
	_telegraph_ring = MeshInstance3D.new()
	_telegraph_ring.mesh = disc
	_telegraph_ring.material_override = red
	_telegraph_ring.visible = false
	add_child(_telegraph_ring)
	_telegraph_fill = MeshInstance3D.new()
	_telegraph_fill.mesh = disc
	_telegraph_fill.material_override = fill
	_telegraph_fill.visible = false
	add_child(_telegraph_fill)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 0.02, 1.0)
	_telegraph_line = MeshInstance3D.new()
	_telegraph_line.mesh = box
	_telegraph_line.material_override = red
	_telegraph_line.visible = false
	add_child(_telegraph_line)


## Annonce visuelle des attaques du boss : disque de l'onde de choc, ligne de la charge.
func _update_telegraphs() -> void:
	_telegraph_ring.visible = false
	_telegraph_fill.visible = false
	_telegraph_line.visible = false
	if _ctx.boss_id < 0:
		return
	var e: Enemy = _ctx.enemies.slots[_ctx.boss_id]
	if e.boss == null:
		return
	if e.state == Enemy.State.WINDUP:
		var r: float = e.boss.data.shock_radius
		var p: float = clampf(e.state_time / maxf(e.data.windup_time, 0.01), 0.0, 1.0)
		_place_disc(_telegraph_ring, e.pos, r)
		_place_disc(_telegraph_fill, e.pos, maxf(r * p, 0.05))
	elif e.state == Enemy.State.CHARGE_WINDUP:
		var length: float = e.boss.data.charge_speed * e.boss.data.charge_duration
		var width: float = e.data.radius * 2.0
		var mid: Vector2 = e.pos + e.boss.charge_dir * length * 0.5
		_telegraph_line.visible = true
		_telegraph_line.position = Vector3(mid.x, 0.04, mid.y)
		_telegraph_line.rotation.y = Planar.yaw_from_dir(e.boss.charge_dir)
		_telegraph_line.scale = Vector3(width, 1.0, length)


func _place_disc(node: MeshInstance3D, center: Vector2, radius: float) -> void:
	node.visible = true
	node.position = Vector3(center.x, 0.04, center.y)
	node.scale = Vector3(radius, 1.0, radius)
