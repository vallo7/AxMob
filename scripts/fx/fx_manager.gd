class_name FxManager
extends Node3D
## Effets visuels de la phase 5, pilotés par les événements du jeu (EventBus) : étincelles de
## bouche et d'impact, onde de choc de la hache lourde, éclatement de confettis à la mort,
## pièces qui jaillissent puis filent vers le joueur, poussière, apparitions, anneaux.
##
## Architecture « fluide » : quatre MultiMesh seulement (étincelles, fumées, anneaux, pièces) +
## les ombres + les flux de haches = ~7 appels de dessin pour TOUS les effets, quel que soit leur
## nombre. Le mouvement est calculé dans les shaders (le CPU écrit une fois par particule à
## l'émission). Les plafonds viennent du profil de qualité ; au plafond la plus ancienne est
## recyclée, aucune allocation en jeu.

enum Shape { DOT, STAR, ROUND, SQUARE, BLOB }

const SPARK_SHADER: Shader = preload("res://assets/shaders/ax_fx_spark.gdshader")
const PUFF_SHADER: Shader = preload("res://assets/shaders/ax_fx_puff.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/ax_fx_ring.gdshader")
const COIN_SHADER: Shader = preload("res://assets/shaders/ax_fx_coin.gdshader")

## Capacités allouées (le profil de qualité fixe le plafond utile).
const SPARK_CAPACITY: int = 320
const PUFF_CAPACITY: int = 120
const RING_CAPACITY: int = 40
const COIN_CAPACITY: int = 60

const MUZZLE_HEIGHT: float = 1.1
const COIN_POP_TIME: float = 0.38
const COIN_GRAVITY: float = 22.0
## Poussière : un sable plus foncé que le sol pour rester lisible sur la plage claire.
# poussière cartoon : crème claire (le contour est foncé par le shader)
const SAND: Color = Color(0.99, 0.93, 0.80, 0.92)
const WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const GOLD: Color = Color(1.0, 0.82, 0.25, 1.0)
const CONFETTI: Array[Color] = [
	Color(1.0, 0.42, 0.36),
	Color(1.0, 0.8, 0.28),
	Color(0.36, 0.86, 0.78),
	Color(0.55, 0.62, 1.0),
	Color(1.0, 0.62, 0.86),
]

## Compteurs de diagnostic (tests, overlay debug).
var spawned: Dictionary = {"spark": 0, "puff": 0, "ring": 0, "coin": 0}

var _ctx: RunContext
var _feel: FeelConfig
var _profile: QualityProfile = QualityProfile.for_tier(QualityProfile.Tier.MEDIUM)
var _sparks: FxBatch
var _puffs: FxBatch
var _rings: FxBatch
var _coins: FxBatch
var _shadows: BlobShadows
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _category_style: Dictionary = {}
var _coin_arrivals: PackedFloat64Array = PackedFloat64Array()
var _coin_streak: int = 0
var _last_coin_time: float = -10.0
var _turret_positions: Array[Vector2] = []
var _kill_times: Array[float] = []
var _last_multikill: float = -10.0


func setup(ctx: RunContext, feel: FeelConfig, turret_positions: Array[Vector2]) -> void:
	_ctx = ctx
	_feel = feel
	_rng.seed = 90210
	_turret_positions = turret_positions
	for data: TurretData in ctx.turret_data:
		_category_style[data.projectile.category] = data.projectile
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_puffs = _make_batch(quad, PUFF_SHADER, PUFF_CAPACITY, -1)
	_sparks = _make_batch(quad, SPARK_SHADER, SPARK_CAPACITY, 2)
	_rings = _make_batch(plane, RING_SHADER, RING_CAPACITY, 1)
	_coins = _make_batch(quad, COIN_SHADER, COIN_CAPACITY, 3)
	_shadows = BlobShadows.new()
	_shadows.name = "BlobShadows"
	add_child(_shadows)
	_shadows.setup(ctx, turret_positions)
	apply_profile(_profile)
	EventBus.turret_fired.connect(_on_turret_fired)
	EventBus.axe_hit.connect(_on_axe_hit)
	EventBus.axe_splash.connect(_on_axe_splash)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	EventBus.shockwave.connect(_on_shockwave)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.turret_upgraded.connect(_on_turret_upgraded)
	EventBus.combat_activated.connect(_on_combat_activated)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_phase_changed.connect(_on_boss_phase)


func _make_batch(mesh: Mesh, shader: Shader, capacity: int, priority: int) -> FxBatch:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	var batch: FxBatch = FxBatch.new()
	add_child(batch)
	batch.setup(mesh, mat, capacity)
	return batch


## Applique un profil de qualité (plafonds, densité, ombres).
func apply_profile(profile: QualityProfile) -> void:
	_profile = profile
	_sparks.set_limit(profile.spark_capacity)
	_puffs.set_limit(profile.puff_capacity)
	_rings.set_limit(profile.ring_capacity)
	_coins.set_limit(profile.coin_capacity)
	_shadows.set_enabled(profile.blob_shadows)


func shadows() -> BlobShadows:
	return _shadows


func density() -> float:
	return _profile.fx_density * _feel.fx_scale


## Appelé chaque image : l'horloge des shaders suit la simulation (pause/ralenti compris) avec
## l'interpolation du moteur pour rester fluide sur les écrans > 60 Hz.
func _process(_delta: float) -> void:
	var t: float = _ctx.time
	if _ctx.advancing:
		t += Engine.get_physics_interpolation_fraction() * _ctx.last_dt
	_sparks.set_time(t)
	_puffs.set_time(t)
	_rings.set_time(t)
	_coins.set_time(t)
	_coins.set_param(&"target", Vector3(_ctx.player_pos.x, 1.0, _ctx.player_pos.y))


## Un appel par tick de simulation : arrivée des pièces, ombres.
func step(_dt: float) -> void:
	_process_coin_arrivals()
	_shadows.update(_ctx.player_alive)


# --- Primitives d'émission -----------------------------------------------------------------


func _count(n: int) -> int:
	var d: float = density()
	if d <= 0.0:
		return 0
	return maxi(1, roundi(float(n) * d))


func _spark(
	pos: Vector3,
	vel: Vector3,
	color: Color,
	size: float,
	life: float,
	shape: Shape = Shape.DOT,
	gravity: float = 0.0,
	drag: float = 0.0,
	stretch: float = 0.0,
	grow: float = 0.0
) -> void:
	_sparks.emit(
		pos,
		vel,
		Vector3(gravity, drag, grow),
		Vector3(stretch, 0.0, 0.0),
		color,
		Color(_ctx.time, life, size, float(shape))
	)
	spawned["spark"] = int(spawned["spark"]) + 1


func _confetti(pos: Vector3, vel: Vector3, color: Color, size: float, life: float) -> void:
	var shape: Shape = Shape.ROUND if _rng.randf() < 0.5 else Shape.SQUARE
	_sparks.emit(
		pos,
		vel,
		Vector3(16.0, 0.8, -0.25),
		Vector3(0.0, _rng.randf_range(-9.0, 9.0), 0.0),
		color,
		Color(_ctx.time, life, size, float(shape))
	)
	spawned["spark"] = int(spawned["spark"]) + 1


func _puff(pos: Vector3, vel: Vector3, color: Color, size: float, life: float, grow: float) -> void:
	_puffs.emit(
		pos,
		vel,
		Vector3(-0.6, 2.2, grow),
		Vector3.ZERO,
		color,
		Color(_ctx.time, life, size, float(Shape.BLOB))
	)
	spawned["puff"] = int(spawned["puff"]) + 1


func _ring(
	pos: Vector3, r0: float, r1: float, life: float, color: Color, thick: float, fill: float = 0.0
) -> void:
	_rings.emit(
		pos + Vector3(0.0, 0.06, 0.0),
		Vector3(r0, r1, thick),
		Vector3.ZERO,
		Vector3.ZERO,
		color,
		Color(_ctx.time, life, fill, 0.0)
	)
	spawned["ring"] = int(spawned["ring"]) + 1


func _coin_pop(pos: Vector3, n: int) -> void:
	var count: int = mini(_count(n), 5)
	var fly: float = _feel.coin_fly_time
	for i: int in count:
		var a: float = _rng.randf() * TAU
		var speed: float = _rng.randf_range(1.5, 3.6)
		var vel: Vector3 = Vector3(cos(a) * speed, _rng.randf_range(5.5, 8.0), sin(a) * speed)
		_coins.emit(
			pos + Vector3(0.0, 0.5, 0.0),
			vel,
			Vector3(COIN_POP_TIME, COIN_GRAVITY, 0.0),
			Vector3.ZERO,
			WHITE,
			Color(_ctx.time, COIN_POP_TIME + fly, 0.34, _rng.randf_range(14.0, 22.0))
		)
		spawned["coin"] = int(spawned["coin"]) + 1
		_coin_arrivals.append(_ctx.time + COIN_POP_TIME + fly + 0.02 * float(i))


func _process_coin_arrivals() -> void:
	while not _coin_arrivals.is_empty() and _coin_arrivals[0] <= _ctx.time:
		_coin_arrivals.remove_at(0)
		_coin_streak = _coin_streak + 1 if _ctx.time - _last_coin_time < 0.4 else 1
		_last_coin_time = _ctx.time
		var p: Vector3 = Vector3(_ctx.player_pos.x, 1.0, _ctx.player_pos.y)
		_spark(p, Vector3.ZERO, Color(1.0, 0.9, 0.45, 0.9), 0.55, 0.16, Shape.STAR)
		EventBus.coin_collected.emit(_coin_streak)


func _polar(angle: float, speed: float, up: float) -> Vector3:
	return Vector3(cos(angle) * speed, up, sin(angle) * speed)


func _category_color(category: int) -> Color:
	var style: ProjectileData = _category_style.get(category) as ProjectileData
	return style.impact_color if style != null else Color(1.0, 0.8, 0.35)


# --- Événements -----------------------------------------------------------------------------


func _on_turret_fired(
	turret_id: int, _data: TurretData, origin: Vector2, direction: Vector2
) -> void:
	var cat: int = _ctx.turret_data[turret_id].projectile.category
	var heavy: bool = cat == ProjectileData.Category.HEAVY
	var color: Color = _category_color(cat)
	var base: Vector3 = Vector3(origin.x, MUZZLE_HEIGHT, origin.y)
	var fwd: Vector3 = Vector3(direction.x, 0.0, direction.y)
	var angle: float = atan2(direction.y, direction.x)
	_spark(base + fwd * 0.45, Vector3.ZERO, WHITE, 1.5 if heavy else 0.95, 0.10, Shape.STAR)
	_spark(base + fwd * 0.3, fwd * 2.0, color, 1.1 if heavy else 0.7, 0.14, Shape.DOT)
	for i: int in _count(8 if heavy else 5):
		var a: float = angle + _rng.randf_range(-0.45, 0.45)
		_spark(
			base + fwd * 0.4,
			_polar(a, _rng.randf_range(6.0, 13.0), _rng.randf_range(0.5, 2.5)),
			color,
			0.13,
			_rng.randf_range(0.18, 0.32),
			Shape.DOT,
			9.0,
			1.2,
			1.0
		)
	if heavy:
		for i: int in _count(2):
			_puff(base + fwd * 0.5, fwd * 2.0 + Vector3(0.0, 0.6, 0.0), SAND, 0.55, 0.55, 1.6)


func _on_axe_hit(enemy_id: int, _damage: float, category: int, direction: Vector2) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if e.data == null:
		return
	var color: Color = _category_color(category)
	var dir3: Vector3 = Vector3(direction.x, 0.0, direction.y)
	var contact: Vector3 = Vector3(e.pos.x, 0.9, e.pos.y) - dir3 * e.data.radius * 0.6
	_spark(contact, Vector3.ZERO, WHITE, 1.15, 0.12, Shape.STAR)
	_ring(Vector3(e.pos.x, 0.0, e.pos.y), 0.2, 1.0 + e.data.radius, 0.22, color, 0.35)
	var back: float = atan2(-direction.y, -direction.x)
	for i: int in _count(7):
		var a: float = back + _rng.randf_range(-1.25, 1.25)
		_spark(
			contact,
			_polar(a, _rng.randf_range(4.0, 10.0), _rng.randf_range(1.0, 4.0)),
			color,
			0.15,
			_rng.randf_range(0.2, 0.36),
			Shape.DOT,
			13.0,
			1.0,
			1.2
		)


func _on_axe_splash(
	center: Vector2,
	radius: float,
	_damage: float,
	_category: int,
	_source: int,
	_falloff: float,
	_knockback: float
) -> void:
	var c: Vector3 = Vector3(center.x, 0.0, center.y)
	_ring(c, 0.3, radius * 1.05, 0.40, Color(1.0, 0.55, 0.18, 0.95), 0.26, 0.30)
	_ring(c, 0.1, radius * 0.72, 0.28, Color(1.0, 0.95, 0.8, 0.85), 0.22)
	for i: int in _count(10):
		var a: float = TAU * float(i) / 10.0 + _rng.randf_range(-0.2, 0.2)
		var r: float = radius * _rng.randf_range(0.35, 0.85)
		_puff(
			c + Vector3(cos(a) * r * 0.5, 0.5, sin(a) * r * 0.5),
			_polar(a, _rng.randf_range(1.8, 3.4), 0.9),
			SAND,
			_rng.randf_range(0.9, 1.4),
			_rng.randf_range(0.55, 0.85),
			1.5
		)
	for i: int in _count(16):
		var a2: float = _rng.randf() * TAU
		_spark(
			c + Vector3(0.0, 0.5, 0.0),
			_polar(a2, _rng.randf_range(6.0, 14.0), _rng.randf_range(3.0, 8.0)),
			Color(1.0, _rng.randf_range(0.45, 0.8), 0.2),
			_rng.randf_range(0.14, 0.24),
			_rng.randf_range(0.35, 0.6),
			Shape.DOT,
			16.0,
			0.8,
			1.1
		)


func _on_enemy_died(enemy_id: int, reward: int, position: Vector3) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	if e.data == null:
		return
	var big: bool = e.data.bar_always
	var tint: Color = e.data.color.lightened(0.25)
	var pos: Vector3 = position + Vector3(0.0, 0.5, 0.0)
	_ring(position, 0.25, 2.6 if big else 1.7, 0.32, tint, 0.3)
	_spark(pos, Vector3.ZERO, WHITE, 1.6 if big else 1.2, 0.14, Shape.STAR)
	for i: int in _count(18 if big else 10):
		var c: Color = tint if i % 3 == 0 else CONFETTI[_rng.randi() % CONFETTI.size()]
		var a: float = _rng.randf() * TAU
		_confetti(
			pos,
			_polar(a, _rng.randf_range(2.0, 6.5), _rng.randf_range(4.0, 9.0)),
			c,
			_rng.randf_range(0.15, 0.26),
			_rng.randf_range(0.6, 1.0)
		)
	for i: int in _count(3):
		var a2: float = _rng.randf() * TAU
		_puff(pos, _polar(a2, 1.4, 1.2), SAND, 0.9 if big else 0.7, 0.55, 1.5)
	if _rng.randf() <= _feel.coin_pop_chance:
		_coin_pop(position, clampi(reward, 1, 5))
	# Série d'éliminations rapprochées.
	_kill_times.append(_ctx.time)
	while not _kill_times.is_empty() and _ctx.time - _kill_times[0] > _feel.multikill_window:
		_kill_times.remove_at(0)
	if _kill_times.size() >= _feel.multikill_count and _ctx.time - _last_multikill > 1.2:
		_last_multikill = _ctx.time
		_ring(position, 0.5, 4.2, 0.55, GOLD, 0.2, 0.18)
		for i: int in _count(8):
			_spark(
				pos,
				_polar(TAU * float(i) / 8.0, 8.0, 3.0),
				GOLD,
				0.2,
				0.5,
				Shape.STAR,
				6.0,
				1.0,
				0.0
			)
		EventBus.multi_kill.emit(_kill_times.size(), position)


func _on_enemy_spawned(enemy_id: int, position: Vector2) -> void:
	var p: Vector3 = Vector3(position.x, 0.0, position.y)
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	var big: float = clampf(e.data.radius / 0.5, 0.8, 3.2) if e.data != null else 1.0
	if e.from_water:
		_spawn_water(p, big)
	else:
		_spawn_sand(p, big)


## Sortie de l'eau : anneau d'écume, gerbe de gouttes, bulles claires.
func _spawn_water(p: Vector3, big: float) -> void:
	var foam: Color = Color(0.92, 1.0, 1.0, 0.9)
	_ring(p, 0.3 * big, 2.1 * big, 0.5, foam, 0.28)
	_ring(p, 0.2 * big, 1.3 * big, 0.38, Color(0.55, 0.9, 1.0, 0.7), 0.2)
	for i: int in _count(int(7.0 * big)):
		var a: float = _rng.randf() * TAU
		_spark(
			p + Vector3(cos(a) * 0.4 * big, 0.15, sin(a) * 0.4 * big),
			Vector3(cos(a) * 1.6, _rng.randf_range(3.2, 5.6), sin(a) * 1.6),
			Color(0.8, 0.96, 1.0, 0.95),
			_rng.randf_range(0.14, 0.26),
			0.55,
			Shape.ROUND,
			14.0
		)
	for i: int in _count(int(3.0 * big)):
		_puff(
			p + Vector3(0.0, 0.2, 0.0),
			_polar(_rng.randf() * TAU, 1.3, 1.1),
			Color(1.0, 1.0, 1.0, 0.85),
			0.75 * big,
			0.55,
			1.6
		)


## Sortie du sable : fissure sombre, éclats de sable et de cailloux, nuage de poussière.
func _spawn_sand(p: Vector3, big: float) -> void:
	_ring(p, 0.2 * big, 1.5 * big, 0.45, Color(0.55, 0.36, 0.16, 0.8), 0.3)
	_ring(p, 0.3 * big, 2.2 * big, 0.55, Color(1.0, 0.9, 0.6, 0.55), 0.22)
	for i: int in _count(int(6.0 * big)):
		var a: float = _rng.randf() * TAU
		_puff(
			p + Vector3(0.0, 0.25, 0.0),
			_polar(a, 1.7, 1.5),
			Color(0.93, 0.78, 0.5, 0.92),
			0.8 * big,
			0.6,
			1.5
		)
	for i: int in _count(int(8.0 * big)):
		var a2: float = _rng.randf() * TAU
		_spark(
			p + Vector3(0.0, 0.2, 0.0),
			Vector3(cos(a2) * 2.2, _rng.randf_range(3.0, 5.4), sin(a2) * 2.2),
			Color(0.62, 0.42, 0.2, 1.0),
			_rng.randf_range(0.1, 0.2),
			0.6,
			Shape.SQUARE,
			16.0
		)


func _on_shockwave(position: Vector2, radius: float) -> void:
	var c: Vector3 = Vector3(position.x, 0.0, position.y)
	_ring(c, 0.5, radius, 0.55, Color(1.0, 0.32, 0.2, 0.95), 0.2, 0.22)
	_ring(c, 0.3, radius * 0.6, 0.4, Color(1.0, 0.85, 0.6, 0.8), 0.18)
	for i: int in _count(14):
		var a: float = TAU * float(i) / 14.0
		_puff(c + Vector3(0.0, 0.4, 0.0), _polar(a, radius * 1.5, 1.0), SAND, 1.5, 0.7, 1.8)
	for i: int in _count(20):
		var a2: float = _rng.randf() * TAU
		_spark(
			c + Vector3(0.0, 0.4, 0.0),
			_polar(a2, _rng.randf_range(6.0, 15.0), _rng.randf_range(4.0, 10.0)),
			Color(1.0, 0.55, 0.25),
			0.2,
			0.6,
			Shape.DOT,
			17.0,
			0.8,
			1.0
		)


func _on_player_damaged(amount: float, _hp: float) -> void:
	if amount <= 0.0:
		return
	var p: Vector3 = Vector3(_ctx.player_pos.x, 0.9, _ctx.player_pos.y)
	_ring(Vector3(p.x, 0.0, p.z), 0.3, 1.9, 0.3, Color(1.0, 0.25, 0.25, 0.9), 0.3)
	_spark(p, Vector3.ZERO, Color(1.0, 0.8, 0.8), 1.5, 0.12, Shape.STAR)
	for i: int in _count(10):
		var a: float = _rng.randf() * TAU
		_spark(
			p,
			_polar(a, _rng.randf_range(3.0, 8.0), _rng.randf_range(1.0, 5.0)),
			Color(1.0, 0.3, 0.3),
			0.16,
			0.4,
			Shape.DOT,
			12.0,
			1.0,
			1.0
		)


func _on_turret_upgraded(turret_id: int, _level: int) -> void:
	var pos: Vector2 = _turret_pos(turret_id)
	var p: Vector3 = Vector3(pos.x, 0.0, pos.y)
	_ring(p, 0.4, 3.2, 0.6, GOLD, 0.22, 0.2)
	for i: int in _count(14):
		var a: float = _rng.randf() * TAU
		_spark(
			p + Vector3(0.0, 0.8, 0.0),
			_polar(a, _rng.randf_range(1.0, 3.5), _rng.randf_range(3.0, 7.0)),
			GOLD,
			_rng.randf_range(0.18, 0.3),
			_rng.randf_range(0.6, 1.0),
			Shape.STAR,
			7.0,
			0.6,
			0.0
		)


func _on_combat_activated(contacts: int, position: Vector3) -> void:
	var p: Vector3 = position + Vector3(0.0, 0.8, 0.0)
	_spark(
		p,
		Vector3.ZERO,
		Color(1.0, 0.85, 0.4, 0.95),
		0.9 + 0.2 * float(mini(contacts, 3)),
		0.14,
		Shape.STAR
	)
	for i: int in _count(5):
		var a: float = _rng.randf() * TAU
		_spark(
			p,
			_polar(a, _rng.randf_range(2.5, 5.5), _rng.randf_range(0.5, 2.0)),
			Color(1.0, 0.7, 0.25),
			0.12,
			0.25,
			Shape.DOT,
			6.0,
			1.0,
			1.0
		)


func _on_wave_started(_wave: int) -> void:
	_ring(Vector3.ZERO, 1.0, _ctx.config.arena_radius * 1.1, 1.0, Color(0.7, 0.9, 1.0, 0.5), 0.07)


func _on_boss_phase(enemy_id: int, _phase: int) -> void:
	var e: Enemy = _ctx.enemies.slots[enemy_id]
	var p: Vector3 = Vector3(e.pos.x, 0.0, e.pos.y)
	_ring(p, 0.8, 6.0, 0.7, Color(1.0, 0.3, 0.2, 0.9), 0.18, 0.15)
	for i: int in _count(12):
		var a: float = TAU * float(i) / 12.0
		_spark(
			p + Vector3(0.0, 1.0, 0.0),
			_polar(a, 9.0, 3.0),
			Color(1.0, 0.45, 0.25),
			0.22,
			0.5,
			Shape.DOT,
			8.0,
			0.8,
			1.2
		)


func _turret_pos(turret_id: int) -> Vector2:
	return _turret_positions[clampi(turret_id, 0, _turret_positions.size() - 1)]
