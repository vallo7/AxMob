class_name WaveManager
extends Node
## Vagues par budget de points (plan §5.7). Cycle : REST -> SPAWNING -> CLEARING -> REST.
## Les apparitions sont étalées sur la durée de la vague ; la vague se termine quand tout
## le budget est apparu et que tous les ennemis sont éliminés.

enum State { REST, SPAWNING, CLEARING }

const SPAWN_RETRY_DELAY: float = 0.3
const SPAWN_ANGLE_TRIES: int = 8

var state: State = State.REST

var _ctx: RunContext
var _enemy_types: Array[EnemyData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending: Array[EnemyData] = []
var _rest_left: float = 0.0
var _spawn_interval: float = 1.0
var _spawn_timer: float = 0.0
var _hp_mult: float = 1.0
var _dmg_mult: float = 1.0


func setup(ctx: RunContext, enemy_types: Array[EnemyData], seed_value: int = 0) -> void:
	_ctx = ctx
	_enemy_types = enemy_types
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_rest_left = ctx.balance.first_wave_delay
	state = State.REST


func step(dt: float) -> void:
	match state:
		State.REST:
			_rest_left -= dt
			if _rest_left <= 0.0:
				_start_wave()
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
	_pending = WaveBudget.compose(balance.budget(n), WaveBudget.available(_enemy_types, n), _rng)
	_pending.shuffle()
	_spawn_interval = balance.spawn_duration(n) / float(maxi(_pending.size(), 1))
	_spawn_timer = 0.0
	_hp_mult = 1.0 + balance.enemy_hp_growth * float(n - 1)
	_dmg_mult = 1.0 + balance.enemy_damage_growth * float(n - 1)
	state = State.SPAWNING
	EventBus.wave_started.emit(n)


func _try_spawn_next() -> void:
	if _pending.is_empty():
		state = State.CLEARING
		return
	if _ctx.enemies.count_living() >= _ctx.config.enemy_cap or _ctx.enemies.find_free() < 0:
		_spawn_timer = SPAWN_RETRY_DELAY
		return
	var data: EnemyData = _pending.pop_back()
	EventBus.enemy_spawn_requested.emit(data, _pick_spawn_position(), _hp_mult, _dmg_mult)
	_spawn_timer = _spawn_interval
	if _pending.is_empty():
		state = State.CLEARING


## Sur le bord de l'arène, le plus loin possible du joueur parmi quelques essais.
func _pick_spawn_position() -> Vector2:
	var radius: float = _ctx.config.arena_radius - 1.0
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
