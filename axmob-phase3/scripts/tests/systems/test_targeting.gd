extends RefCounted
## TargetScorer et WaveBudget.

var t: Object


func test_closer_scores_higher() -> void:
	var near: float = TargetScorer.score(3.0, 13.0, 1.0, 5.0, 0, 0.0)
	var far: float = TargetScorer.score(11.0, 13.0, 1.0, 5.0, 0, 0.0)
	t.call("check", near > far)


func test_low_hp_scores_higher() -> void:
	var hurt: float = TargetScorer.score(6.0, 13.0, 0.2, 5.0, 0, 0.0)
	var healthy: float = TargetScorer.score(6.0, 13.0, 1.0, 5.0, 0, 0.0)
	t.call("check", hurt > healthy, "achever les cibles blessées")


func test_assigned_penalty_spreads_fire() -> void:
	var free_target: float = TargetScorer.score(6.0, 13.0, 1.0, 5.0, 0, 0.0)
	var taken: float = TargetScorer.score(6.0, 13.0, 1.0, 5.0, 2, 0.0)
	t.call("check", free_target > taken)


func test_priority_and_threat() -> void:
	var elite: float = TargetScorer.score(6.0, 13.0, 1.0, 5.0, 0, 0.6)
	var normal: float = TargetScorer.score(6.0, 13.0, 1.0, 5.0, 0, 0.0)
	t.call("check", elite > normal)
	var close_to_player: float = TargetScorer.score(6.0, 13.0, 1.0, 1.0, 0, 0.0)
	var far_from_player: float = TargetScorer.score(6.0, 13.0, 1.0, 9.0, 0, 0.0)
	t.call("check", close_to_player > far_from_player, "priorité aux menaces")


func test_wave_budget_never_exceeded_and_unlocks() -> void:
	var all: Array[EnemyData] = DataRegistry.enemies()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var balance: BalanceConfig = DataRegistry.balance()
	for wave: int in [1, 2, 3, 5, 8, 15, 30]:
		var cands: Array[EnemyData] = WaveBudget.available(all, wave)
		var list: Array[EnemyData] = WaveBudget.compose(balance.budget(wave), cands, rng)
		var cost: float = 0.0
		for e: EnemyData in list:
			cost += e.wave_cost
			t.call("check", e.unlock_wave <= wave, "ennemi non débloqué vague %d" % wave)
		t.call("check", cost <= balance.budget(wave) + 0.0001, "budget respecté vague %d" % wave)
		t.call("check", not list.is_empty())


func test_budget_grows_monotonically() -> void:
	var balance: BalanceConfig = DataRegistry.balance()
	for n: int in range(1, 40):
		t.call("check", balance.budget(n + 1) > balance.budget(n), "budget croissant")


func test_data_registry_loads_everything() -> void:
	t.call("check", DataRegistry.config() != null)
	t.call("check", DataRegistry.balance() != null)
	t.call("check", DataRegistry.enemies().size() == 4)
	var turrets: Array[TurretData] = DataRegistry.turrets()
	t.call("check", turrets.size() == 4)
	var categories: Dictionary = {}
	for td: TurretData in turrets:
		t.call("check", td.projectile != null, "hache associée à %s" % td.id)
		categories[td.projectile.category] = true
	t.call("check", categories.size() == 4, "4 catégories distinctes")
