class_name WaveManager
extends Node
## Vagues par budget de points (plan §5.7). Cycle : REST -> (BOSS_WARNING) -> SPAWNING ->
## CLEARING -> REST. Les apparitions sont étalées sur la durée de la vague ; la vague se
## termine quand tout le budget est apparu et que tous les ennemis (boss compris) sont
## éliminés. Le rythme d'apparition s'adapte en douceur (AdaptivePacing), jamais les stats.

enum State { REST, BOSS_WARNING, SPAWNING, CLEARING }

const SPAWN_RETRY_DELAY: float = 0.3
const SPAWN_ANGLE_TRIES: int = 8

var state: State = State.REST

var _ctx: RunContext
var _table: WaveTable
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending: Array[SpawnOrder] = []
var _rest_left: float = 0.0
var _spawn_interval: float = 1.0
var _spawn_timer: float = 0.0
var _boss_timer: float = 0.0
var _boss_pos: Vector2 = Vector2.ZERO
var _recent_spawns: float = 0.0
var _recent_kills: float = 0.0
var _last_kills: int = 0


func setup(ctx: RunContext, table: WaveTable, seed_value: int = 0) -> void:
	_ctx = ctx
	_table = table
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_rest_left = ctx.balance.first_wave_delay
	state = State.REST


func step(dt: float) -> void:
	_track_recent(dt)
	match state:
		State.REST:
			_rest_left -= dt
			if _rest_left <= 0.0:
				_start_wave()
		State.BOSS_WARNING:
			_boss_timer -= dt
			if _boss_timer <= 0.0:
				EventBus.enemy_spawn_requested.emit(
					_table.boss, _boss_pos, _table.boss_level(_ctx.wave)
				)
				state = State.SPAWNING
		State.SPAWNING:
			_spawn_timer -= dt
			if _spawn_timer <= 0.0:
				_try_spawn_next()
		State.CLEARING:
			if _ctx.enemies.count_living() == 0:
				EventBus.wave_completed.emit(_ctx.wave)
				_rest_left = _ctx.balance.wave_rest_time
				state = State.REST


func _start_wave() -> void:
	_ctx.wave += 1
	var n: int = _ctx.wave
	var balance: BalanceConfig = _ctx.balance
	var is_boss_wave: bool = _table.is_boss_wave(n)
	var budget: float = balance.budget(n)
	if is_boss_wave:
		budget *= _table.boss_budget_fraction
	var picks: Array[EnemyData] = WaveBudget.compose(
		budget, WaveBudget.available(_table.enemies, n), _rng
	)
	_pending.clear()
	for data: EnemyData in picks:
		_pending.append(SpawnOrder.new(data, EnemyLevels.level_for_spawn(balance, n, _rng)))
	_pending.shuffle()
	_spawn_interval = balance.spawn_duration(n) / float(maxi(_pending.size(), 1))
	_spawn_timer = 0.0
	EventBus.wave_started.emit(n)
	if is_boss_wave:
		_boss_pos = _boss_spawn_position()
		_boss_timer = _table.boss.warning_time
		state = State.BOSS_WARNING
		EventBus.boss_warning.emit(n, _boss_timer, _boss_pos)
	else:
		state = State.SPAWNING


func _try_spawn_next() -> void:
	if _pending.is_empty():
		state = State.CLEARING
		return
	if _ctx.enemies.count_living() >= _ctx.config.enemy_cap or _ctx.enemies.find_free() < 0:
		_spawn_timer = SPAWN_RETRY_DELAY
		return
	var order: SpawnOrder = _pending.pop_back()
	EventBus.enemy_spawn_requested.emit(order.data, _pick_spawn_position(), order.level)
	_recent_spawns += 1.0
	_spawn_timer = _spawn_interval / _update_pacing()
	if _pending.is_empty():
		state = State.CLEARING


## Compteurs récents (demi-vie configurable) : base du rythme adaptatif.
func _track_recent(dt: float) -> void:
	var decay: float = pow(0.5, dt / maxf(_ctx.balance.pacing_half_life, 0.1))
	_recent_spawns *= decay
	_recent_kills = _recent_kills * decay + float(_ctx.kills - _last_kills)
	_last_kills = _ctx.kills


func _update_pacing() -> float:
	var ratio: float = 0.5
	if _recent_spawns >= 1.0:
		ratio = clampf(_recent_kills / _recent_spawns, 0.0, 1.0)
	var pacing: float = AdaptivePacing.factor(_ctx.balance, _ctx.player_hp_fraction, ratio)
	if _ctx.balance.pacing_log and absf(pacing - _ctx.pacing) >= 0.02:
		print(
			(
				"[pacing] vague %d : %.3f (PV %.0f %%, éliminations %.2f)"
				% [_ctx.wave, pacing, _ctx.player_hp_fraction * 100.0, ratio]
			)
		)
	_ctx.pacing = pacing
	return pacing


## Sur le bord de l'arène, le plus loin possible du joueur parmi quelques essais.
func _pick_spawn_position() -> Vector2:
	return _far_edge_point(_ctx.config.arena_radius - 1.0)


func _boss_spawn_position() -> Vector2:
	return _far_edge_point(_ctx.config.arena_radius - _table.boss.radius - 0.8)


func _far_edge_point(radius: float) -> Vector2:
	var best: Vector2 = Vector2(radius, 0.0)
	var best_dist: float = -1.0
	for i: int in SPAWN_ANGLE_TRIES:
		var p: Vector2 = Vector2.from_angle(_rng.randf() * TAU) * radius
		var d: float = p.distance_to(_ctx.player_pos)
		if d >= _ctx.config.spawn_min_player_dist:
			return p
		if d > best_dist:
			best_dist = d
			best = p
	return best
