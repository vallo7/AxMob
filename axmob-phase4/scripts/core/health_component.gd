class_name HealthComponent
extends RefCounted
## Points de vie + invulnérabilité courte après un coup. Sans noeud : testable.

var max_hp: float
var hp: float
var invuln_left: float = 0.0
var invuln_time: float


func _init(p_max_hp: float = 100.0, p_invuln_time: float = 0.0) -> void:
	max_hp = p_max_hp
	hp = p_max_hp
	invuln_time = p_invuln_time


## Retourne les dégâts réellement appliqués (0 si invulnérable ou déjà mort).
func apply_damage(amount: float) -> float:
	if hp <= 0.0 or invuln_left > 0.0 or amount <= 0.0:
		return 0.0
	var applied: float = minf(amount, hp)
	hp -= applied
	invuln_left = invuln_time
	return applied


func tick(dt: float) -> void:
	invuln_left = maxf(invuln_left - dt, 0.0)


func is_dead() -> bool:
	return hp <= 0.0


func is_invulnerable() -> bool:
	return invuln_left > 0.0


func fraction() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
