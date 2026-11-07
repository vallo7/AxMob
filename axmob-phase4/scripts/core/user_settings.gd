class_name UserSettings
extends RefCounted
## Réglages joueur persistés dans user://settings.cfg (ConfigFile). Minimal : la phase 7
## (SaveManager, versionnage, migrations) les reprendra. Valeurs par défaut si absent/invalide.

const DEFAULT_PATH: String = "user://settings.cfg"
const HAPTICS_LEVELS: Array[float] = [0.0, 0.6, 1.0, 1.35]
const HAPTICS_NAMES: Array[String] = ["Désactivées", "Légères", "Normales", "Fortes"]
const DEFAULT_HAPTICS_LEVEL: int = 2

## Chemin de remplacement (tests) ; vide = DEFAULT_PATH.
static var path_override: String = ""


static func _path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH


static func _load() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(_path()) != OK:
		return ConfigFile.new()
	return cfg


static func _get_int(section: String, key: String, fallback: int, max_value: int) -> int:
	var v: Variant = _load().get_value(section, key, fallback)
	if typeof(v) != TYPE_INT:
		return fallback
	return clampi(v as int, 0, max_value)


static func _set_int(section: String, key: String, value: int) -> void:
	var cfg: ConfigFile = _load()
	cfg.set_value(section, key, value)
	cfg.save(_path())


## 0 = désactivées, 1 = légères, 2 = normales, 3 = fortes.
static func haptics_level() -> int:
	return _get_int("haptics", "level", DEFAULT_HAPTICS_LEVEL, HAPTICS_LEVELS.size() - 1)


static func set_haptics_level(level: int) -> void:
	_set_int("haptics", "level", clampi(level, 0, HAPTICS_LEVELS.size() - 1))


## Comportement du jeu pendant le panneau d'amélioration (GameConfig.UpgradePause).
static func upgrade_pause(fallback: int) -> int:
	return _get_int("gameplay", "upgrade_pause", fallback, 2)


static func set_upgrade_pause(mode: int) -> void:
	_set_int("gameplay", "upgrade_pause", clampi(mode, 0, 2))
