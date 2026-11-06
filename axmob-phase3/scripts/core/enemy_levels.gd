class_name EnemyLevels
extends RefCounted
## Niveau de puissance des ennemis : axe distinct du type (plan §4). Un niveau multiplie PV,
## dégâts, vitesse (plafonnée) et récompense, et change la teinte.

const TINT_TIERS: int = 4


static func hp_mult(balance: BalanceConfig, level: int) -> float:
	return pow(balance.level_hp_growth, float(maxi(level, 1) - 1))


static func damage_mult(balance: BalanceConfig, level: int) -> float:
	return pow(balance.level_damage_growth, float(maxi(level, 1) - 1))


static func speed_mult(balance: BalanceConfig, level: int) -> float:
	var m: float = pow(balance.level_speed_growth, float(maxi(level, 1) - 1))
	return minf(m, balance.level_speed_cap)


static func reward_mult(balance: BalanceConfig, level: int) -> float:
	return pow(balance.level_reward_growth, float(maxi(level, 1) - 1))


static func reward(base_reward: int, balance: BalanceConfig, level: int) -> int:
	return maxi(roundi(float(base_reward) * reward_mult(balance, level)), 1)


## Teinte (0..3) : niveaux 1-2, 3-4, 5-6, 7+. Les matériaux sont partagés par (type, teinte).
static func tint_tier(level: int) -> int:
	return clampi((level - 1) / 2, 0, TINT_TIERS - 1)


## Niveau flottant de la vague : 1 + (n-1) / waves_per_level.
static func wave_level(balance: BalanceConfig, wave: int) -> float:
	return 1.0 + float(maxi(wave - 1, 0)) / maxf(balance.waves_per_level, 0.1)


## Niveau d'un ennemi qui apparaît : partie entière du niveau de la vague, +1 avec une
## probabilité égale à la partie fractionnaire (mélange progressif, jamais de saut brutal).
static func level_for_spawn(balance: BalanceConfig, wave: int, rng: RandomNumberGenerator) -> int:
	var f: float = wave_level(balance, wave)
	var base: int = floori(f)
	var level: int = base + (1 if rng.randf() < f - float(base) else 0)
	return clampi(level, 1, balance.max_enemy_level)
