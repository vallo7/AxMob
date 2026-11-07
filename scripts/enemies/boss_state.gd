class_name BossState
extends RefCounted
## État d'exécution d'un boss (le pool d'ennemis reste générique : seul le boss porte ceci).

var data: BossData
var phase: int = 1
var charge_cooldown: float = 0.0
var summon_timer: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var charge_hit: bool = false


func _init(p_data: BossData) -> void:
	data = p_data
	charge_cooldown = p_data.charge_cooldown * 0.5
	summon_timer = p_data.summon_interval * 0.5
