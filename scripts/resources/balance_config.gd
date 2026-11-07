class_name BalanceConfig
extends Resource
## Vagues, niveaux d'ennemis, économie et rythme adaptatif (plan §5.6, §5.7).
## Budget de la vague n = b0 + b1 × n^p. Valeurs provisoires : seul le jeu réel les valide.

@export_group("Vagues")
@export var wave_budget_b0: float = 4.0
@export var wave_budget_b1: float = 2.5
@export var wave_budget_p: float = 1.15
@export var first_wave_delay: float = 1.5
@export var wave_rest_time: float = 2.5
@export var spawn_duration_base: float = 5.0
@export var spawn_duration_per_wave: float = 0.6
@export var spawn_duration_max: float = 14.0

@export_group("Niveaux d'ennemis")
## Une vague sur N fait monter d'un niveau la population (mélange progressif : pas de saut).
@export var waves_per_level: float = 3.0
@export var max_enemy_level: int = 20
## Multiplicateurs par niveau (composés : croissance^(niveau-1)).
@export var level_hp_growth: float = 1.28
@export var level_damage_growth: float = 1.14
@export var level_speed_growth: float = 1.025
@export var level_reward_growth: float = 1.22
## Plafond du gain de vitesse cumulé (les ennemis ne deviennent jamais injouables).
@export var level_speed_cap: float = 1.3

@export_group("Économie des tourelles")
## Coût du passage du niveau n à n+1 : base × facteur de catégorie × multiplicateur^(n-1).
@export var upgrade_cost_base: float = 14.0
@export var upgrade_cost_mult: float = 1.6

@export_group("Rythme adaptatif")
## Variation maximale de la cadence d'apparition (jamais des stats ennemies) : ±15 %.
@export var pacing_max: float = 0.15
@export var pacing_hp_weight: float = 0.6
@export var pacing_kill_weight: float = 0.4
## Demi-vie (s) des compteurs d'apparitions/éliminations récents.
@export var pacing_half_life: float = 10.0
## Journalise les changements de rythme dans la console (debug).
@export var pacing_log: bool = false


func budget(wave: int) -> float:
	return wave_budget_b0 + wave_budget_b1 * pow(float(wave), wave_budget_p)


func spawn_duration(wave: int) -> float:
	return minf(spawn_duration_base + spawn_duration_per_wave * float(wave), spawn_duration_max)
