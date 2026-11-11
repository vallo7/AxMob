class_name UserSettings
extends RefCounted
## Réglages joueur persistés dans user://settings.cfg (ConfigFile). Minimal : la phase 7
## (SaveManager, versionnage, migrations) les reprendra. Valeurs par défaut si absent/invalide.

const JOYSTICK_SENS: Array[float] = [0.70, 0.85, 1.0, 1.2, 1.45]
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


## Mode de qualité graphique : 0 = auto (gouverneur), 1 = bas, 2 = moyen, 3 = élevé.
static func quality_mode() -> int:
	return _get_int("graphics", "quality_mode", 0, 3)


static func set_quality_mode(mode: int) -> void:
	_set_int("graphics", "quality_mode", clampi(mode, 0, 3))


## Dernier profil retenu par le gouverneur (point de départ du prochain lancement).
static func auto_tier() -> int:
	return _get_int("graphics", "auto_tier", QualityProfile.Tier.MEDIUM, 2)


static func set_auto_tier(tier: int) -> void:
	_set_int("graphics", "auto_tier", clampi(tier, 0, 2))


## Son : 0 = musique + effets, 1 = effets seuls, 2 = silence.
static func sound_mode() -> int:
	return _get_int("audio", "sound_mode", 0, 2)


static func set_sound_mode(mode: int) -> void:
	_set_int("audio", "sound_mode", clampi(mode, 0, 2))


## Langue : 0 = auto (téléphone), 1 = français, 2 = anglais.
static func language_mode() -> int:
	return _get_int("ui", "language", 0, 2)


static func set_language_mode(mode: int) -> void:
	_set_int("ui", "language", clampi(mode, 0, 2))


## Musique / effets : interrupteurs et volumes (0..10) indépendants. Remplacent le « mode de son »
## unique de la phase 5 (conservé plus haut pour compatibilité : il en est une vue).
static func music_enabled() -> bool:
	return _get_int("audio", "music_on", 1, 1) == 1


static func set_music_enabled(on: bool) -> void:
	_set_int("audio", "music_on", 1 if on else 0)


static func sfx_enabled() -> bool:
	return _get_int("audio", "sfx_on", 1, 1) == 1


static func set_sfx_enabled(on: bool) -> void:
	_set_int("audio", "sfx_on", 1 if on else 0)


static func music_volume_step() -> int:
	return _get_int("audio", "music_vol", 10, 10)


static func set_music_volume_step(step: int) -> void:
	_set_int("audio", "music_vol", clampi(step, 0, 10))


static func sfx_volume_step() -> int:
	return _get_int("audio", "sfx_vol", 10, 10)


static func set_sfx_volume_step(step: int) -> void:
	_set_int("audio", "sfx_vol", clampi(step, 0, 10))


## Sensibilité du joystick : 5 crans ; 1.0 = comportement d'origine. Plus c'est vif, plus la course
## du pouce nécessaire pour atteindre la vitesse maximale est courte.


static func joystick_step() -> int:
	return _get_int("controls", "joystick_sens", 2, JOYSTICK_SENS.size() - 1)


static func set_joystick_step(step: int) -> void:
	_set_int("controls", "joystick_sens", clampi(step, 0, JOYSTICK_SENS.size() - 1))


static func joystick_sensitivity() -> float:
	return JOYSTICK_SENS[joystick_step()]


## Vrai si un profil automatique a déjà été mémorisé (sinon : premier lancement).
static func has_auto_tier() -> bool:
	return _load().has_section_key("graphics", "auto_tier")


## Compteur d'images et mesures à l'écran (réservé aux tests sur téléphone).
static func show_fps() -> bool:
	return _get_int("debug", "show_fps", 0, 1) == 1


static func set_show_fps(on: bool) -> void:
	_set_int("debug", "show_fps", 1 if on else 0)
