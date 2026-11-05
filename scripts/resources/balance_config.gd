class_name BalanceConfig
extends Resource
## Vagues et difficulté (plan §5.7). Budget de la vague n = b0 + b1 × n^p.
## Valeurs provisoires : seul le jeu réel les valide.

@export var wave_budget_b0: float = 4.0
@export var wave_budget_b1: float = 2.5
@export var wave_budget_p: float = 1.15
@export var first_wave_delay: float = 1.5
@export var wave_rest_time: float = 2.5
@export var spawn_duration_base: float = 5.0
@export var spawn_duration_per_wave: float = 0.6
@export var spawn_duration_max: float = 14.0
## Croissance linéaire par vague des PV et des dégâts ennemis (provisoire, avant EnemyLevelData).
@export var enemy_hp_growth: float = 0.05
@export var enemy_damage_growth: float = 0.03


func budget(wave: int) -> float:
	return wave_budget_b0 + wave_budget_b1 * pow(float(wave), wave_budget_p)


func spawn_duration(wave: int) -> float:
	return minf(spawn_duration_base + spawn_duration_per_wave * float(wave), spawn_duration_max)
