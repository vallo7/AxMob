extends Node
## Gestionnaire de qualité graphique (autoload « QualityManager »).
##  - applique un profil (QualityProfile) : échelle et anticrénelage du rendu 3D, cadence max,
##    plafonds d'effets (via EventBus.quality_changed, que chaque système écoute) ;
##  - en mode AUTO, nourrit le QualityGovernor avec les durées d'image et change de profil à chaud ;
##  - mémorise le dernier profil stable pour le prochain lancement (pas de phase de mesure inutile).
## L'interface (CanvasLayer) reste dessinée à la résolution NATIVE : seule la 3D est réduite.

const MODE_NAMES: Array[String] = ["AUTO", "BAS", "MOYEN", "ÉLEVÉ"]

var profile: QualityProfile
var governor: QualityGovernor
## 0 = auto, 1..3 = profil imposé (Bas, Moyen, Élevé).
var mode: int = 0
## Dernier facteur d'échelle 3D appliqué (diagnostic).
var applied_scale: float = 1.0


func _ready() -> void:
	mode = UserSettings.quality_mode()
	var start: QualityProfile.Tier = _start_tier()
	governor = QualityGovernor.new(start)
	# Pas de gouverneur sans écran (tests headless) ni quand le joueur impose un profil.
	governor.enabled = mode == 0 and DisplayServer.get_name() != "headless"
	apply_tier(start)
	EventBus.run_started.connect(func() -> void: governor.reset())
	EventBus.run_paused.connect(func(_p: bool) -> void: governor.reset())


func _process(delta: float) -> void:
	if governor.enabled:
		var changed: int = governor.feed(delta)
		if changed >= 0:
			apply_tier(QualityProfile.clamp_tier(changed))
			UserSettings.set_auto_tier(changed)
			print("[quality] profil -> %s" % QualityProfile.NAMES[changed])


func _start_tier() -> QualityProfile.Tier:
	if mode > 0:
		return QualityProfile.clamp_tier(mode - 1)
	return QualityProfile.clamp_tier(UserSettings.auto_tier())


## Change le mode (AUTO / BAS / MOYEN / ÉLEVÉ), sauvegardé.
func set_mode(new_mode: int) -> void:
	mode = clampi(new_mode, 0, 3)
	UserSettings.set_quality_mode(mode)
	if mode == 0:
		governor.enabled = DisplayServer.get_name() != "headless"
		governor.tier = QualityProfile.clamp_tier(UserSettings.auto_tier())
		governor.ceiling = QualityProfile.Tier.HIGH
		governor.reset()
		apply_tier(governor.tier)
	else:
		governor.enabled = false
		apply_tier(QualityProfile.clamp_tier(mode - 1))


func cycle_mode() -> void:
	set_mode((mode + 1) % 4)


func apply_tier(tier: QualityProfile.Tier) -> void:
	profile = QualityProfile.for_tier(tier)
	var root: Window = get_tree().root
	var size: Vector2 = Vector2(DisplayServer.window_get_size())
	applied_scale = profile.render_scale_for(size.x, size.y)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = applied_scale
	root.msaa_3d = profile.msaa
	Engine.max_fps = profile.max_fps
	EventBus.quality_changed.emit(int(tier))


func mode_label() -> String:
	var name: String = MODE_NAMES[mode]
	if mode == 0:
		return "%s (%s)" % [name, QualityProfile.NAMES[profile.tier]]
	return name
