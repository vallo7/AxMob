class_name WaveBudget
extends RefCounted
## Compose la liste d'ennemis d'une vague à partir d'un budget de points.


static func available(all_enemies: Array[EnemyData], wave: int) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for e: EnemyData in all_enemies:
		if e.unlock_wave <= wave:
			out.append(e)
	return out


## Tire des ennemis pondérés tant que le budget le permet. Ne dépasse jamais le budget,
## sauf pour garantir au moins un ennemi (le moins cher) si le budget est trop faible.
static func compose(
	budget: float, candidates: Array[EnemyData], rng: RandomNumberGenerator
) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	if candidates.is_empty():
		return out
	var remaining: float = budget
	while true:
		var affordable: Array[EnemyData] = []
		var total_weight: float = 0.0
		for e: EnemyData in candidates:
			if e.wave_cost <= remaining:
				affordable.append(e)
				total_weight += e.spawn_weight
		if affordable.is_empty():
			break
		var roll: float = rng.randf() * total_weight
		var chosen: EnemyData = affordable[affordable.size() - 1]
		for e: EnemyData in affordable:
			roll -= e.spawn_weight
			if roll <= 0.0:
				chosen = e
				break
		out.append(chosen)
		remaining -= chosen.wave_cost
	if out.is_empty():
		var cheapest: EnemyData = candidates[0]
		for e: EnemyData in candidates:
			if e.wave_cost < cheapest.wave_cost:
				cheapest = e
		out.append(cheapest)
	return out
