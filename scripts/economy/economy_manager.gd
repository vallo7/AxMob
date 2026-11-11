class_name EconomyManager
extends Node
## Pièces et statistiques de la partie. Récompense créditée une seule fois, à enemy_died.
## Les dépenses passent par spend() : jamais de solde négatif, solde publié à chaque changement.

var _ctx: RunContext


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func can_afford(amount: int) -> bool:
	return amount >= 0 and _ctx.coins >= amount


## Dépense atomique : tout ou rien. Retourne faux (et ne change rien) si le solde est insuffisant.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	_ctx.coins -= amount
	_ctx.coins_spent += amount
	EventBus.coins_changed.emit(_ctx.coins)
	return true


func _on_enemy_died(_enemy_id: int, reward: int, _position: Vector3) -> void:
	_ctx.coins += int(round(float(reward) * _ctx.bonuses.coin_mult))
	_ctx.kills += 1
	EventBus.coins_changed.emit(_ctx.coins)


func _on_boss_defeated(_enemy_id: int, _reward: int) -> void:
	_ctx.bosses_defeated += 1
