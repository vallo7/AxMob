class_name BossData
extends EnemyData
## Boss : un EnemyData avec trois phases (seuils de PV), une onde de choc, une charge
## télégraphiée et l'invocation de petits ennemis (plan §5.5).

## Fractions de PV sous lesquelles on passe en phase 2, puis 3.
@export var phase_thresholds: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export_group("Onde de choc (attaque de base)")
@export var shock_radius: float = 3.4
@export_group("Charge (phase 2+)")
@export var charge_windup: float = 0.9
@export var charge_speed: float = 14.0
@export var charge_duration: float = 0.55
@export var charge_cooldown: float = 6.0
@export var charge_damage_mult: float = 1.3
@export var charge_min_distance: float = 5.0
@export_group("Invocation (phase 3)")
@export var summon_enemy: EnemyData
@export var summon_count: int = 3
@export var summon_interval: float = 7.0
@export_group("Avertissement")
@export var warning_time: float = 2.0


## Portée d'une charge ; au-delà (avec marge), le boss poursuit au lieu de charger.
func charge_reach() -> float:
	return charge_speed * charge_duration
