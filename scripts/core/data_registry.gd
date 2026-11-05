class_name DataRegistry
extends RefCounted
## Point d'accès unique aux Resources de données. Chemins explicites (pas de listage de
## dossier : le listage de res:// est fragile dans un export Android).

const CONFIG_PATH: String = "res://resources/balancing/game_config.tres"
const BALANCE_PATH: String = "res://resources/balancing/balance_config.tres"
const ENEMY_PATHS: Array[String] = [
	"res://resources/enemies/basic.tres",
	"res://resources/enemies/fast.tres",
	"res://resources/enemies/heavy.tres",
]
## Ordre = emplacements des tourelles (sens horaire depuis le haut-droit).
const TURRET_PATHS: Array[String] = [
	"res://resources/turrets/rapid.tres",
	"res://resources/turrets/heavy.tres",
	"res://resources/turrets/multi.tres",
	"res://resources/turrets/pierce.tres",
]


static func config() -> GameConfig:
	return load(CONFIG_PATH) as GameConfig


static func balance() -> BalanceConfig:
	return load(BALANCE_PATH) as BalanceConfig


static func enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for path: String in ENEMY_PATHS:
		out.append(load(path) as EnemyData)
	return out


static func turrets() -> Array[TurretData]:
	var out: Array[TurretData] = []
	for path: String in TURRET_PATHS:
		out.append(load(path) as TurretData)
	return out
