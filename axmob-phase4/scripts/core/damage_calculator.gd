class_name DamageCalculator
extends RefCounted
## Dégâts = dégâts de la hache × résistance de l'ennemi à sa catégorie × niveau (plan §5.4).


static func compute(base_damage: float, resistance: float, level_multiplier: float = 1.0) -> float:
	return maxf(base_damage * resistance * level_multiplier, 0.0)
