class_name RunContext
extends RefCounted
## État partagé d'une partie, injecté en lecture seule (par convention) dans les systèmes.
## Les systèmes ne se connaissent pas : ils lisent ici et communiquent par EventBus.

var config: GameConfig
var balance: BalanceConfig
var time: float = 0.0
## Dernier pas de simulation (s) et indicateur « la simulation a avancé à ce tick » : servent à
## interpoler les effets à l'affichage (phase 5) sans jamais faire reculer le temps des shaders.
var last_dt: float = 1.0 / 60.0
var advancing: bool = false
var player_pos: Vector2 = Vector2.ZERO
var player_vel: Vector2 = Vector2.ZERO
var player_alive: bool = true
var player_hp_fraction: float = 1.0
var grid: SpatialGrid = SpatialGrid.new(2.0)
var enemies: EnemyStore
var combat: CombatWindow
var wave: int = 0
var kills: int = 0
var coins: int = 0
var coins_spent: int = 0
var bosses_defeated: int = 0
## Améliorations permanentes appliquées à CETTE partie (neutres par défaut).
var bonuses: PermanentBonuses = PermanentBonuses.new()
## Vrai une fois la partie versée à la sauvegarde (SaveManager.record_run) : jamais deux fois.
var run_recorded: bool = false
## Identifiant du boss vivant (-1 si aucun).
var boss_id: int = -1
## Rythme adaptatif courant (1 = neutre), exposé pour l'overlay de debug.
var pacing: float = 1.0
## Catégories de tourelles de la partie et leur niveau courant (même indice).
var turret_data: Array[TurretData] = []
var turret_levels: PackedInt32Array = PackedInt32Array()
## Tables de niveaux (une par catégorie, Array[TurretLevelData]) : calculées une seule fois.
var turret_tables: Array = []


func _init(p_config: GameConfig, p_balance: BalanceConfig) -> void:
	config = p_config
	balance = p_balance
	combat = CombatWindow.new(p_config.window_duration, p_config.activation_cooldown)
	enemies = EnemyStore.new(p_config.enemy_cap)


func combat_active() -> bool:
	return combat.is_active(time)


func set_turrets(datas: Array[TurretData]) -> void:
	turret_data = datas
	turret_levels = PackedInt32Array()
	turret_levels.resize(datas.size())
	turret_levels.fill(1)
	turret_tables.clear()
	for data: TurretData in datas:
		turret_tables.append(_with_bonuses(TurretLeveling.build(data)))


## Statistiques actuelles d'une tourelle (niveau courant) ou d'un niveau donné.
func turret_stats(turret_id: int, level: int = -1) -> TurretLevelData:
	var table: Array = turret_tables[turret_id] as Array
	var lv: int = turret_levels[turret_id] if level < 0 else level
	return table[clampi(lv, 1, table.size()) - 1] as TurretLevelData


func turret_max_level(turret_id: int) -> int:
	return (turret_tables[turret_id] as Array).size()


## Applique les bonus permanents (puissance, cadence) à une table de niveaux. La table d'origine
## (ressource partagée) n'est jamais modifiée : on travaille sur des copies.
func _with_bonuses(table: Array[TurretLevelData]) -> Array[TurretLevelData]:
	if is_equal_approx(bonuses.power_mult, 1.0) and is_equal_approx(bonuses.rate_mult, 1.0):
		return table
	var out: Array[TurretLevelData] = []
	for row: TurretLevelData in table:
		var c: TurretLevelData = row.duplicate() as TurretLevelData
		c.damage *= bonuses.power_mult
		c.fire_rate *= bonuses.rate_mult
		out.append(c)
	return out
