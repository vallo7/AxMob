class_name UpgradeManager
extends Node
## Améliorations de tourelles en partie (10 niveaux par catégorie). Un achat = dépense atomique
## des pièces PUIS passage de niveau PUIS signal turret_upgraded. Si les pièces manquent,
## ou si le niveau maximal est atteint, rien ne change.
## Coût du niveau n -> n+1 = base × facteur de catégorie × multiplicateur^(n-1) (CostCurve).

var _ctx: RunContext
var _economy: EconomyManager


func setup(ctx: RunContext, economy: EconomyManager) -> void:
	_ctx = ctx
	_economy = economy


func level_of(turret_id: int) -> int:
	return _ctx.turret_levels[turret_id]


func is_max(turret_id: int) -> bool:
	return level_of(turret_id) >= _ctx.turret_max_level(turret_id)


## Coût de la prochaine amélioration, ou -1 au niveau maximal.
func cost_to_upgrade(turret_id: int) -> int:
	if is_max(turret_id):
		return -1
	var data: TurretData = _ctx.turret_data[turret_id]
	var b: BalanceConfig = _ctx.balance
	return CostCurve.cost(
		b.upgrade_cost_base, b.upgrade_cost_mult, level_of(turret_id), data.cost_scale
	)


func can_upgrade(turret_id: int) -> bool:
	var cost: int = cost_to_upgrade(turret_id)
	return cost >= 0 and _economy.can_afford(cost)


func affordable_count() -> int:
	var n: int = 0
	for i: int in _ctx.turret_data.size():
		if can_upgrade(i):
			n += 1
	return n


func try_upgrade(turret_id: int) -> bool:
	var cost: int = cost_to_upgrade(turret_id)
	if cost < 0 or not _economy.spend(cost):
		EventBus.upgrade_denied.emit(turret_id)
		return false
	_ctx.turret_levels[turret_id] += 1
	EventBus.turret_upgraded.emit(turret_id, _ctx.turret_levels[turret_id])
	return true
