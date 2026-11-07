class_name TurretManager
extends Node3D
## Instancie les tourelles sur leurs emplacements fixes et leur attribue des cibles (10 Hz).
## Attribution gloutonne en commençant par la tourelle la plus contrainte ; hystérésis :
## une cible est conservée au moins `target_hold_time` s, puis seulement si un nouveau
## score ne la dépasse pas d'au moins `switch_margin` (plan §5.3).

const TURRET_SCENE: PackedScene = preload("res://scenes/turrets/turret.tscn")

var turrets: Array[Turret] = []

var _ctx: RunContext
var _retarget_acc: float = 0.0


func setup(ctx: RunContext, datas: Array[TurretData]) -> void:
	_ctx = ctx
	ctx.set_turrets(datas)
	for i: int in datas.size():
		var angle: float = deg_to_rad(-45.0 + 90.0 * float(i))
		var slot: Vector2 = Vector2(cos(angle), sin(angle)) * ctx.config.ring_radius()
		var turret: Turret = TURRET_SCENE.instantiate() as Turret
		add_child(turret)
		turret.setup(i, datas[i], ctx, slot)
		turrets.append(turret)
	EventBus.turret_upgraded.connect(_on_turret_upgraded)


func _on_turret_upgraded(turret_id: int, level: int) -> void:
	if turret_id >= 0 and turret_id < turrets.size():
		turrets[turret_id].apply_level(level)


func step(dt: float) -> void:
	_retarget_acc += dt
	if _retarget_acc >= _ctx.config.retarget_interval:
		_retarget_acc = 0.0
		if _ctx.combat_active():
			_retarget()
	for turret: Turret in turrets:
		turret.step(dt)


func _retarget() -> void:
	var candidates: Dictionary = {}  # turret_id -> PackedInt32Array
	for turret: Turret in turrets:
		candidates[turret.turret_id] = _candidates_for(turret)
	var order: Array[Turret] = turrets.duplicate()
	order.sort_custom(
		func(a: Turret, b: Turret) -> bool:
			var ca: PackedInt32Array = candidates[a.turret_id]
			var cb: PackedInt32Array = candidates[b.turret_id]
			return ca.size() < cb.size()
	)
	var assigned: PackedInt32Array = PackedInt32Array()
	assigned.resize(_ctx.enemies.capacity())
	for turret: Turret in order:
		var cands: PackedInt32Array = candidates[turret.turret_id]
		var chosen: int = _choose(turret, cands, assigned)
		if chosen != turret.target_id:
			turret.target_id = chosen
			turret.target_since = _ctx.time
		if chosen >= 0:
			assigned[chosen] += 1


func _candidates_for(turret: Turret) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for id: int in _ctx.grid.query_circle(turret.pos2, turret.stats.attack_range):
		if _ctx.enemies.slots[id].is_hittable():
			out.append(id)
	return out


func _choose(turret: Turret, cands: PackedInt32Array, assigned: PackedInt32Array) -> int:
	var best: int = -1
	var best_score: float = -INF
	var current_score: float = -INF
	for id: int in cands:
		var e: Enemy = _ctx.enemies.slots[id]
		var s: float = TargetScorer.score(
			e.pos.distance_to(turret.pos2),
			turret.stats.attack_range,
			e.health.fraction(),
			e.pos.distance_to(_ctx.player_pos),
			assigned[id],
			e.data.target_priority
		)
		if id == turret.target_id:
			current_score = s
		if s > best_score:
			best_score = s
			best = id
	if best < 0 or turret.target_id < 0 or is_inf(current_score):
		return best
	var held: float = _ctx.time - turret.target_since
	var much_better: bool = (
		best_score > current_score + _ctx.config.switch_margin * maxf(absf(current_score), 0.1)
	)
	if held < _ctx.config.target_hold_time or not much_better:
		return turret.target_id
	return best
