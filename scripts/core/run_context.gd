class_name RunContext
extends RefCounted
## État partagé d'une partie, injecté en lecture seule (par convention) dans les systèmes.
## Les systèmes ne se connaissent pas : ils lisent ici et communiquent par EventBus.

var config: GameConfig
var balance: BalanceConfig
var time: float = 0.0
var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO
var player_alive: bool = true
var grid: SpatialGrid = SpatialGrid.new(2.0)
var enemies: EnemyStore
var combat: CombatWindow
var wave: int = 0
var kills: int = 0
var coins: int = 0


func _init(p_config: GameConfig, p_balance: BalanceConfig) -> void:
	config = p_config
	balance = p_balance
	combat = CombatWindow.new(p_config.window_duration, p_config.activation_cooldown)
	enemies = EnemyStore.new(p_config.enemy_cap)


func combat_active() -> bool:
	return combat.is_active(time)
