class_name AdaptivePacing
extends RefCounted
## Adaptation douce du RYTHME d'apparition (plan §5.7) : jamais les statistiques des ennemis.
## > 1 = apparitions plus rapprochées (joueur à l'aise), < 1 = plus espacées (joueur en difficulté).
## Borné à 1 ± pacing_max.


## hp_fraction : PV du joueur (0..1). kill_ratio : éliminations récentes / apparitions
## récentes (0..1, 1 = il élimine tout ce qui apparaît).
static func factor(balance: BalanceConfig, hp_fraction: float, kill_ratio: float) -> float:
	var hp_term: float = (clampf(hp_fraction, 0.0, 1.0) - 0.5) * 2.0
	var kill_term: float = (clampf(kill_ratio, 0.0, 1.0) - 0.5) * 2.0
	var raw: float = balance.pacing_hp_weight * hp_term + balance.pacing_kill_weight * kill_term
	return 1.0 + clampf(raw, -1.0, 1.0) * balance.pacing_max
