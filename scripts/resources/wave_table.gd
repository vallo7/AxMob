class_name WaveTable
extends Resource
## Déblocages et boss (plan §5.7). Les déblocages par type sont portés par EnemyData.unlock_wave
## (rapide dès 3, lourd dès 5, élite dès 7) ; la table liste les types et programme les boss.

@export var enemies: Array[EnemyData] = []
@export var boss: BossData
## Un boss toutes les N vagues (10 par défaut : vagues 10, 20, ...).
@export var boss_every: int = 10
## Part du budget normal conservée dans une vague de boss (le boss prend la place du reste).
@export var boss_budget_fraction: float = 0.5


func is_boss_wave(wave: int) -> bool:
	return boss != null and boss_every > 0 and wave > 0 and wave % boss_every == 0


## Niveau du boss : 1 à la première apparition, +1 à chaque nouvelle.
func boss_level(wave: int) -> int:
	return maxi(wave / maxi(boss_every, 1), 1)
