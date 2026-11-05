class_name EconomyManager
extends Node
## Pièces et statistiques de la partie. Récompense créditée une seule fois, à enemy_died.
## (Dépenses, améliorations et bonus permanents : phases 3 et 7.)

var _ctx: RunContext


func setup(ctx: RunContext) -> void:
	_ctx = ctx
	EventBus.enemy_died.connect(_on_enemy_died)


func _on_enemy_died(_enemy_id: int, reward: int, _position: Vector3) -> void:
	_ctx.coins += reward
	_ctx.kills += 1
	EventBus.coins_changed.emit(_ctx.coins)
