class_name ProjectileManager
extends Node3D
## Pool de haches (128 par défaut, recyclage de la plus ancienne au plafond).
## Collision par balayage de cercle contre la SpatialGrid : un seul impact par ennemi et
## par hache, pas d'effet tunnel. Les dégâts sont appliqués par l'EnemyManager (via EventBus).
##
## Phase 5 : impact de zone (hache lourde : `axe_splash`), animation de vol vivante (pop élastique
## à la bouche, oscillation, petit saut du lancer, coup d'échelle à chaque impact) et flux
## lumineux (TrailBatch : un seul MultiMesh pour toutes les haches).

const MAX_ENEMY_RADIUS: float = 1.6
const BOUNDS_MARGIN: float = 2.5
## Échelle de départ du « pop » d'apparition (fraction de la taille finale).
const POP_FROM: float = 0.3
const KICK_DECAY: float = 7.0
## Durée de croissance de la traînée à la naissance de la hache (s).
const TRAIL_GROW_TIME: float = 0.08

var _ctx: RunContext
var _feel: FeelConfig
var _axes: Array[Axe] = []
var _trails: TrailBatch
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(ctx: RunContext, feel: FeelConfig = null) -> void:
	_ctx = ctx
	_feel = feel if feel != null else FeelConfig.new()
	_rng.seed = 5150
	_trails = TrailBatch.new()
	_trails.name = "Trails"
	add_child(_trails)
	_trails.setup(ctx.config.axe_pool_size)
	for i: int in ctx.config.axe_pool_size:
		var a: Axe = Axe.new()
		a.slot = i
		a.visual = Node3D.new()
		a.visual.visible = false
		add_child(a.visual)
		_axes.append(a)
	EventBus.turret_fired.connect(_on_turret_fired)


func trails() -> TrailBatch:
	return _trails


func active_count() -> int:
	var n: int = 0
	for a: Axe in _axes:
		if a.active:
			n += 1
	return n


func step(dt: float) -> void:
	for a: Axe in _axes:
		if a.active:
			_step_axe(a, dt)


func _on_turret_fired(
	turret_id: int, data: TurretData, origin: Vector2, direction: Vector2
) -> void:
	var stats: TurretLevelData = _ctx.turret_stats(turret_id)
	var count: int = maxi(stats.axe_count, 1)
	for i: int in count:
		var angle: float = 0.0
		if count > 1:
			angle = deg_to_rad(stats.fan_angle_deg) * (float(i) / float(count - 1) - 0.5)
		_spawn(data, stats, origin, direction.rotated(angle))


func _spawn(data: TurretData, stats: TurretLevelData, origin: Vector2, direction: Vector2) -> void:
	var a: Axe = _acquire()
	var p: ProjectileData = data.projectile
	a.active = true
	a.style = p
	a.pos = origin
	a.dir = direction.normalized()
	a.speed = p.speed * stats.projectile_speed_mult
	a.acceleration = p.acceleration
	a.max_speed = p.max_speed * stats.projectile_speed_mult
	a.radius = p.radius
	a.damage = stats.damage
	a.category = p.category
	a.life_left = p.lifetime
	a.pierce_left = stats.pierce
	a.spin = 0.0
	a.spin_speed = p.spin_speed
	a.born = _ctx.time
	a.hit_ids.clear()
	a.splash_radius = stats.splash_radius
	a.splash_mult = p.splash_damage_mult
	a.splash_falloff = p.splash_falloff
	a.splash_knockback = p.splash_knockback
	a.wobble_phase = _rng.randf() * TAU
	a.hit_kick = 0.0
	_show_model(a, p.model())
	a.visual.visible = true
	_sync_visual(a, 0.0)
	# Emplacement réutilisé : pas d'interpolation depuis l'ancienne position.
	a.visual.reset_physics_interpolation()
	_trails.reset_trail(a.slot)


## Emplacement libre, sinon la hache la plus ancienne est recyclée.
func _acquire() -> Axe:
	var oldest: Axe = _axes[0]
	for a: Axe in _axes:
		if not a.active:
			return a
		if a.born < oldest.born:
			oldest = a
	return oldest


func _step_axe(a: Axe, dt: float) -> void:
	a.life_left -= dt
	if a.life_left <= 0.0:
		_deactivate(a)
		return
	a.speed = minf(a.speed + a.acceleration * dt, a.max_speed)
	a.spin += a.spin_speed * dt
	var p0: Vector2 = a.pos
	var p1: Vector2 = p0 + a.dir * a.speed * dt
	var reach: float = p0.distance_to(p1) * 0.5 + a.radius + MAX_ENEMY_RADIUS
	for id: int in _ctx.grid.query_circle((p0 + p1) * 0.5, reach):
		if a.hit_ids.has(id):
			continue
		var e: Enemy = _ctx.enemies.slots[id]
		if not e.is_hittable():
			continue
		if SweptCircle.hits(p0, p1, a.radius, e.pos, e.data.radius):
			a.hit_ids.append(id)
			a.hit_kick = 1.0
			EventBus.axe_hit.emit(id, a.damage, a.category, a.dir)
			if a.splash_radius > 0.0:
				EventBus.axe_splash.emit(
					e.pos,
					a.splash_radius,
					a.damage * a.splash_mult,
					a.category,
					id,
					a.splash_falloff,
					a.splash_knockback
				)
			a.pierce_left -= 1
			if a.pierce_left < 0:
				_deactivate(a)
				return
	a.pos = p1
	if p1.length() > _ctx.config.arena_radius + BOUNDS_MARGIN:
		_deactivate(a)
		return
	_sync_visual(a, dt)


## Affiche le modèle de la catégorie (créé au premier usage sur cet emplacement).
func _show_model(a: Axe, model_name: String) -> void:
	var model: Node3D = a.models.get(model_name) as Node3D
	if model == null:
		var rig: ModelRig = ModelRig.create(model_name)
		if rig == null:
			return
		model = rig.root
		a.visual.add_child(model)
		a.models[model_name] = model
	if a.shown != model:
		if a.shown != null:
			a.shown.visible = false
		a.shown = model
	model.visible = true


func _deactivate(a: Axe) -> void:
	a.active = false
	a.visual.visible = false
	_trails.hide_trail(a.slot)


## Animation de la hache en vol : pop élastique à la naissance, petit saut du lancer, oscillation,
## coup d'échelle après un impact, flux lumineux orienté selon la trajectoire.
func _sync_visual(a: Axe, dt: float) -> void:
	var p: ProjectileData = a.style
	var age: float = _ctx.time - a.born
	var y: float = _ctx.config.axe_height
	var s: float = 1.0
	if p.pop_time > 0.0 and age < p.pop_time:
		var over: float = p.pop_overshoot * _feel.axe_pop_scale
		s = lerpf(POP_FROM, 1.0, ease_out_back(age / p.pop_time, over))
	if p.arc_height > 0.0:
		y += p.arc_height * sin(clampf(age / maxf(p.arc_time, 0.01), 0.0, 1.0) * PI)
	a.hit_kick = maxf(a.hit_kick - dt * KICK_DECAY, 0.0)
	s *= 1.0 + 0.3 * a.hit_kick
	var tilt: float = (
		deg_to_rad(p.wobble_deg)
		* _feel.axe_wobble_scale
		* sin(age * p.wobble_speed + a.wobble_phase)
	)
	a.visual.position = Vector3(a.pos.x, y, a.pos.y)
	a.visual.rotation = Vector3(tilt, a.spin, tilt * 0.5)
	a.visual.scale = Vector3.ONE * (p.visual_scale * s)
	var grow: float = clampf(age / TRAIL_GROW_TIME, 0.0, 1.0)
	var speed_k: float = clampf(a.speed / maxf(p.speed, 1.0), 0.6, 1.5)
	_trails.show_trail(
		a.slot,
		Vector3(a.pos.x, y - 0.05, a.pos.y),
		a.dir,
		p.trail_length * speed_k * grow,
		p.trail_width * s,
		p.trail_color
	)


## Dépassement élastique « back » (0 -> 1, avec un léger rebond au-delà de 1). `over` règle
## l'amplitude : 0.35 ≈ 10 % de dépassement.
static func ease_out_back(u: float, over: float = 0.35) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	var c1: float = 1.70158 * over / 0.35
	var m: float = x - 1.0
	return 1.0 + (c1 + 1.0) * m * m * m + c1 * m * m
