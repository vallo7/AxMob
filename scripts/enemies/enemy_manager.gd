class_name EnemyManager
extends Node3D
## Simule tous les ennemis en un seul passage par tick (pas de _process par ennemi),
## entretient la SpatialGrid, applique les dégâts des haches et déclenche les attaques.

const FLASH_TIME: float = 0.08
const SEPARATION_STRENGTH: float = 6.0
const EDGE_MARGIN: float = 1.2
const EDGE_STRENGTH: float = 4.0
const MAX_ENEMY_RADIUS: float = 1.0
const BRAKE_ACCEL: float = 40.0

var _ctx: RunContext
var _meshes: Dictionary = {}  # StringName -> CapsuleMesh
var _materials: Dictionary = {}  # StringName -> Array[StandardMaterial3D] (normal, flash, windup)


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	for e: Enemy in ctx.enemies.slots:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.visible = false
		add_child(mi)
		e.visual = mi
	EventBus.axe_hit.connect(_on_axe_hit)
	EventBus.enemy_spawn_requested.connect(_on_spawn_requested)


func _on_spawn_requested(
	data: EnemyData, position: Vector2, hp_mult: float, dmg_mult: float
) -> void:
	spawn(data, position, hp_mult, dmg_mult)


func spawn(data: EnemyData, position: Vector2, hp_mult: float, dmg_mult: float) -> int:
	var id: int = _ctx.enemies.find_free()
	if id < 0:
		return -1
	var e: Enemy = _ctx.enemies.slots[id]
	e.data = data
	e.pos = position
	e.vel = Vector2.ZERO
	e.state = Enemy.State.SPAWNING
	e.state_time = 0.0
	e.health = HealthComponent.new(data.max_hp * hp_mult, 0.0)
	e.damage_mult = dmg_mult
	e.flash_left = 0.0
	e.contact_rearm_at = 0.0
	e.reward_granted = false
	var to_player: Vector2 = _ctx.player_pos - position
	e.facing = to_player.normalized() if to_player.length() > 0.001 else Vector2(0.0, 1.0)
	e.visual.mesh = _mesh_for(data)
	e.visual.material_override = _material_for(data, 0)
	e.visual.visible = true
	_ctx.grid.insert(id, position)
	_sync_visual(e)
	return id


func step(dt: float) -> void:
	for e: Enemy in _ctx.enemies.slots:
		if e.state == Enemy.State.INACTIVE:
			continue
		e.state_time += dt
		e.flash_left = maxf(e.flash_left - dt, 0.0)
		match e.state:
			Enemy.State.SPAWNING:
				if e.state_time >= _ctx.config.spawn_invuln:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.CHASE:
				_step_chase(e, dt)
			Enemy.State.WINDUP:
				_step_windup(e, dt)
			Enemy.State.RECOVER:
				_move(e, Vector2.ZERO, dt)
				if e.state_time >= e.data.recover_time:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.STAGGER:
				_move(e, Vector2.ZERO, dt)
				if e.state_time >= _ctx.config.stagger_time:
					_enter(e, Enemy.State.CHASE)
			Enemy.State.DYING:
				if e.state_time >= _ctx.config.death_time:
					e.state = Enemy.State.INACTIVE
					e.visual.visible = false
		_sync_visual(e)
	_rebuild_grid()


func _enter(e: Enemy, state: Enemy.State) -> void:
	e.state = state
	e.state_time = 0.0


func _step_chase(e: Enemy, dt: float) -> void:
	var to_player: Vector2 = _ctx.player_pos - e.pos
	var dist: float = to_player.length()
	var desired: Vector2 = Vector2.ZERO
	if _ctx.player_alive and dist > 0.001:
		e.facing = to_player / dist
		desired = e.facing * e.data.speed
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
	if _ctx.player_alive and _player_gap(e) <= e.data.attack_range + _ctx.config.attack_leeway:
		EventBus.enemy_attack_landed.emit(e.data.damage * e.damage_mult, e.pos)
	_enter(e, Enemy.State.RECOVER)


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


func _on_axe_hit(enemy_id: int, raw_damage: float, category: int, direction: Vector2) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if not e.is_hittable():
		return
	var dmg: float = DamageCalculator.compute(raw_damage, e.data.resistance(category))
	var applied: float = e.health.apply_damage(dmg)
	EventBus.enemy_hit.emit(enemy_id, applied)
	e.flash_left = FLASH_TIME
	e.vel += direction * _ctx.config.knockback_speed * e.data.stagger_scale
	if e.health.is_dead():
		_kill(e)
	elif e.data.stagger_scale >= 0.5 and e.state != Enemy.State.STAGGER:
		_enter(e, Enemy.State.STAGGER)


func _kill(e: Enemy) -> void:
	_enter(e, Enemy.State.DYING)
	e.vel = Vector2.ZERO
	if not e.reward_granted:
		e.reward_granted = true
		EventBus.enemy_died.emit(e.id, e.data.reward, Planar.to3(e.pos))


func _rebuild_grid() -> void:
	_ctx.grid.clear()
	for e: Enemy in _ctx.enemies.slots:
		if e.state != Enemy.State.INACTIVE and e.state != Enemy.State.DYING:
			_ctx.grid.insert(e.id, e.pos)


func _sync_visual(e: Enemy) -> void:
	var scale_f: float = 1.0
	var mat_index: int = 0
	match e.state:
		Enemy.State.SPAWNING:
			scale_f = lerpf(0.3, 1.0, clampf(e.state_time / _ctx.config.spawn_invuln, 0.0, 1.0))
		Enemy.State.WINDUP:
			scale_f = 1.0 + 0.2 * clampf(e.state_time / e.data.windup_time, 0.0, 1.0)
			mat_index = 2
		Enemy.State.DYING:
			scale_f = 1.0 - clampf(e.state_time / _ctx.config.death_time, 0.0, 1.0)
	if e.flash_left > 0.0:
		mat_index = 1
	e.visual.material_override = _material_for(e.data, mat_index)
	e.visual.scale = Vector3.ONE * maxf(scale_f, 0.01)
	e.visual.position = Vector3(e.pos.x, e.data.height * 0.5 * scale_f, e.pos.y)


func _mesh_for(data: EnemyData) -> CapsuleMesh:
	if not _meshes.has(data.id):
		var m: CapsuleMesh = CapsuleMesh.new()
		m.radius = data.radius
		m.height = maxf(data.height, data.radius * 2.0 + 0.01)
		m.radial_segments = 12
		m.rings = 4
		_meshes[data.id] = m
	return _meshes[data.id] as CapsuleMesh


func _material_for(data: EnemyData, index: int) -> StandardMaterial3D:
	if not _materials.has(data.id):
		var normal: StandardMaterial3D = StandardMaterial3D.new()
		normal.albedo_color = data.color
		var flash: StandardMaterial3D = StandardMaterial3D.new()
		flash.albedo_color = Color.WHITE
		flash.emission_enabled = true
		flash.emission = Color.WHITE
		var windup: StandardMaterial3D = StandardMaterial3D.new()
		windup.albedo_color = data.color.lightened(0.35)
		windup.emission_enabled = true
		windup.emission = Color(1.0, 0.35, 0.1)
		windup.emission_energy_multiplier = 1.4
		_materials[data.id] = [normal, flash, windup]
	return (_materials[data.id] as Array)[index] as StandardMaterial3D
