class_name ProjectileManager
extends Node3D
## Pool de haches (128 par défaut, recyclage de la plus ancienne au plafond).
## Collision par balayage de cercle contre la SpatialGrid : un seul impact par ennemi et
## par hache, pas d'effet tunnel. Les dégâts sont appliqués par l'EnemyManager (via EventBus).

const AXE_MODEL: PackedScene = preload("res://assets/models/axe_light.glb")
const MAX_ENEMY_RADIUS: float = 1.6
const BOUNDS_MARGIN: float = 2.5

var _ctx: RunContext
var _axes: Array[Axe] = []


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	for i: int in ctx.config.axe_pool_size:
		var a: Axe = Axe.new()
		a.visual = AXE_MODEL.instantiate() as Node3D
		a.visual.visible = false
		add_child(a.visual)
		_axes.append(a)
	EventBus.turret_fired.connect(_on_turret_fired)


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
	a.visual.scale = Vector3.ONE * p.visual_scale
	a.visual.visible = true
	_sync_visual(a)


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
			EventBus.axe_hit.emit(id, a.damage, a.category, a.dir)
			a.pierce_left -= 1
			if a.pierce_left < 0:
				_deactivate(a)
				return
	a.pos = p1
	if p1.length() > _ctx.config.arena_radius + BOUNDS_MARGIN:
		_deactivate(a)
		return
	_sync_visual(a)


func _deactivate(a: Axe) -> void:
	a.active = false
	a.visual.visible = false


func _sync_visual(a: Axe) -> void:
	a.visual.position = Vector3(a.pos.x, _ctx.config.axe_height, a.pos.y)
	a.visual.rotation.y = a.spin
