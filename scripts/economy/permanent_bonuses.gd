class_name PermanentBonuses
extends RefCounted
## Effet cumulé des améliorations permanentes sur UNE partie (calculé au lancement, lecture seule).
## Valeurs neutres par défaut : une partie de test ou le simulateur n'ont aucun bonus.

var hp_add: float = 0.0
var power_mult: float = 1.0
var rate_mult: float = 1.0
var coin_mult: float = 1.0
var speed_mult: float = 1.0


static func neutral() -> PermanentBonuses:
	return PermanentBonuses.new()
