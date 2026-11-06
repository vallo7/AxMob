class_name UpgradeBot
extends RefCounted
## Politique d'achat simple pour les tests et le simulateur : améliore la catégorie de plus bas
## niveau qu'on peut payer (répartit la puissance), sans jamais dépasser le solde.


static func act(upgrades: UpgradeManager, ctx: RunContext) -> int:
	var bought: int = 0
	while true:
		var best: int = -1
		for i: int in ctx.turret_data.size():
			if not upgrades.can_upgrade(i):
				continue
			if best < 0 or ctx.turret_levels[i] < ctx.turret_levels[best]:
				best = i
		if best < 0 or not upgrades.try_upgrade(best):
			break
		bought += 1
	return bought
