extends Node
## Gestionnaire de qualité graphique (autoload « QualityManager »), refonte de la phase 6.
##  - applique un profil (QualityProfile) : échelle du rendu 3D, cadence max, contours, plafonds
##    d'effets (via EventBus.quality_changed, que chaque système écoute) ;
##  - mode AUTO : le QualityGovernor mesure les durées d'image ; on DESCEND tout de suite, on ne
##    MONTE qu'à un moment sûr (début de vague, pause, menu), au plus une fois toutes les 20 s ;
##  - plafond anti-plantage (Diagnostics/CrashGuard) : un profil qui a fait planter l'appli n'est
##    plus choisi, ni en AUTO ni en mode imposé, jusqu'à pardon après plusieurs lancements stables ;
##  - surveillance de la mémoire vidéo : au-delà du budget du profil, on descend avant que le
##    système ne tue l'appli ;
##  - l'anticrénelage matériel (MSAA) n'est JAMAIS activé sur mobile ; les réglages du viewport ne
##    sont touchés que s'ils changent vraiment (chaque changement réalloue les cibles de rendu).
## L'interface (CanvasLayer) reste dessinée à la résolution NATIVE : seule la 3D est réduite.

const MODE_NAMES: Array[String] = ["AUTO", "BAS", "MOYEN", "ÉLEVÉ"]
const MIN_UP_INTERVAL: float = 20.0
const MIN_DOWN_INTERVAL: float = 2.5
const MEMORY_DOWN_INTERVAL: float = 5.0
const MAX_CHANGES: int = 10
const MEM_MARGIN: float = 0.92
const MEM_FORCED_MARGIN: float = 1.25

var profile: QualityProfile
var governor: QualityGovernor
## 0 = auto, 1..3 = profil imposé (Bas, Moyen, Élevé).
var mode: int = 0
## Dernier facteur d'échelle 3D appliqué (diagnostic).
var applied_scale: float = 1.0
## Profil maximal autorisé (plantages passés, pression mémoire de la session).
var ceiling: int = QualityProfile.Tier.HIGH
## Nombre de changements de profil depuis le lancement.
var changes: int = 0
## Vrai si la session précédente a planté (l'interface l'annonce une fois).
var crash_notice_pending: bool = false

var _is_mobile: bool = false
var _first_guarded: bool = false
var _in_run: bool = false
var _last_change_s: float = -100.0
var _pending_up: int = -1
var _mem_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_mobile = OS.has_feature("mobile")
	ceiling = Diagnostics.guard.ceiling()
	mode = UserSettings.quality_mode()
	crash_notice_pending = bool(Diagnostics.previous["crashed"])
	# Toute première session AVEC garde anti-plantage : on ne reprend pas aveuglément un profil
	# élevé gardé d'une version plus ancienne (celle qui plantait en graphisme élevé).
	_first_guarded = int(Diagnostics.guard.state["sessions"]) == 0
	if _first_guarded and mode == 3:
		mode = 0
		UserSettings.set_quality_mode(0)
	# Un profil imposé devenu interdit retombe sur AUTO (sinon la boucle de plantage se répète).
	if mode > 0 and mode - 1 > ceiling:
		mode = 0
		UserSettings.set_quality_mode(0)
	var start: QualityProfile.Tier = _start_tier()
	governor = QualityGovernor.new(start)
	governor.ceiling = QualityProfile.clamp_tier(ceiling)
	# Pas de gouverneur sans écran (tests headless) ni quand le joueur impose un profil.
	governor.enabled = mode == 0 and DisplayServer.get_name() != "headless"
	apply_tier(start, "démarrage")
	Diagnostics.begin_session(int(start), mode)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_paused.connect(_on_run_paused)
	EventBus.wave_started.connect(func(_w: int) -> void: _apply_pending())


func _process(delta: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if governor.enabled:
		var changed: int = governor.feed(delta)
		if changed >= 0:
			_on_governor(changed, now)
	_mem_timer += delta
	if _mem_timer >= Diagnostics.SAMPLE_INTERVAL:
		_mem_timer = 0.0
		_check_memory(now)


func _start_tier() -> QualityProfile.Tier:
	var t: QualityProfile.Tier
	if mode > 0:
		t = QualityProfile.clamp_tier(mode - 1)
	elif UserSettings.has_auto_tier():
		t = QualityProfile.clamp_tier(UserSettings.auto_tier())
	else:
		var size: Vector2i = DisplayServer.window_get_size()
		var ram_mb: int = int(float(OS.get_memory_info().get("physical", -1)) / Diagnostics.MB)
		t = DeviceProfile.suggest(RenderingServer.get_video_adapter_name(), ram_mb, size.x * size.y)
	if _first_guarded:
		t = QualityProfile.clamp_tier(mini(int(t), int(QualityProfile.Tier.MEDIUM)))
	return QualityProfile.clamp_tier(mini(int(t), ceiling))


# --- Moments sûrs ---


func _on_run_started() -> void:
	_in_run = true
	governor.reset()


func _on_run_paused(paused: bool) -> void:
	governor.reset()
	if paused:
		_apply_pending()


## À appeler en quittant une partie (menu, chargement) : plus de « moment délicat ».
func leave_run() -> void:
	_in_run = false
	_apply_pending()


func _safe_moment() -> bool:
	return not _in_run or get_tree().paused


# --- Décisions ---


func _on_governor(target: int, now: float) -> void:
	if target == profile.tier:
		_pending_up = -1
		return
	if target < profile.tier:
		_pending_up = -1
		if now - _last_change_s < MIN_DOWN_INTERVAL:
			governor.tier = profile.tier
			return
		apply_tier(QualityProfile.clamp_tier(target), "fluidité")
		return
	# Montée : jamais au-dessus du plafond, rarement, et seulement à un moment sûr.
	if target > ceiling or changes >= MAX_CHANGES or now - _last_change_s < MIN_UP_INTERVAL:
		governor.tier = profile.tier
		governor.reset()
		return
	_pending_up = target
	if _safe_moment():
		_apply_pending()


func _apply_pending() -> void:
	if _pending_up < 0 or _pending_up <= profile.tier:
		_pending_up = -1
		return
	var target: int = _pending_up
	_pending_up = -1
	if target <= ceiling:
		apply_tier(QualityProfile.clamp_tier(target), "essai de montée")
		governor.reset()


func _check_memory(now: float) -> void:
	var margin: float = MEM_MARGIN if mode == 0 else MEM_FORCED_MARGIN
	if Diagnostics.video_mb <= profile.video_budget_mb * margin:
		return
	if profile.tier == QualityProfile.Tier.LOW or now - _last_change_s < MEMORY_DOWN_INTERVAL:
		return
	# La session ne remontera plus au-dessus de ce profil.
	ceiling = mini(ceiling, int(profile.tier) - 1)
	governor.ceiling = QualityProfile.clamp_tier(ceiling)
	governor.tier = QualityProfile.clamp_tier(int(profile.tier) - 1)
	apply_tier(governor.tier, "mémoire vidéo %.0f Mo" % Diagnostics.video_mb)


# --- Réglages ---


## Un mode est-il choisissable ? (ÉLEVÉ ne l'est plus après un plantage à ce profil.)
func mode_available(m: int) -> bool:
	return m == 0 or m - 1 <= Diagnostics.guard.ceiling()


## Change le mode (AUTO / BAS / MOYEN / ÉLEVÉ), sauvegardé. Retourne faux si le mode est interdit.
func set_mode(new_mode: int) -> bool:
	new_mode = clampi(new_mode, 0, 3)
	if not mode_available(new_mode):
		return false
	mode = new_mode
	UserSettings.set_quality_mode(mode)
	_pending_up = -1
	if mode == 0:
		governor.enabled = DisplayServer.get_name() != "headless"
		governor.tier = QualityProfile.clamp_tier(mini(UserSettings.auto_tier(), ceiling))
		governor.ceiling = QualityProfile.clamp_tier(ceiling)
		governor.reset()
		apply_tier(governor.tier, "mode AUTO")
	else:
		governor.enabled = false
		apply_tier(QualityProfile.clamp_tier(mode - 1), "mode imposé")
	return true


func cycle_mode() -> void:
	for i: int in 4:
		var candidate: int = (mode + 1 + i) % 4
		if set_mode(candidate):
			return


func apply_tier(tier: QualityProfile.Tier, reason: String = "") -> void:
	var previous: int = int(profile.tier) if profile != null else -1
	profile = QualityProfile.for_tier(tier)
	var root: Window = get_tree().root
	var size: Vector2 = Vector2(DisplayServer.window_get_size())
	var new_scale: float = profile.render_scale_for(size.x, size.y)
	# Chaque réglage du viewport réalloue les cibles de rendu : on ne touche que ce qui change.
	if root.scaling_3d_mode != Viewport.SCALING_3D_MODE_BILINEAR:
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if absf(new_scale - root.scaling_3d_scale) > 0.01:
		root.scaling_3d_scale = new_scale
	applied_scale = root.scaling_3d_scale
	var msaa: Viewport.MSAA = profile.effective_msaa(_is_mobile)
	if root.msaa_3d != msaa:
		root.msaa_3d = msaa
	Engine.max_fps = profile.max_fps
	ToonStyle.apply_profile(profile)
	if previous != int(tier):
		_last_change_s = float(Time.get_ticks_msec()) / 1000.0
		if previous >= 0:
			changes += 1
			if mode == 0:
				UserSettings.set_auto_tier(int(tier))
		Diagnostics.note_tier(int(tier), reason)
	EventBus.quality_changed.emit(int(tier))


func mode_label() -> String:
	var name: String = Loc.t("quality_" + ["AUTO", "LOW", "MEDIUM", "HIGH"][mode])
	if mode == 0:
		return "%s (%s)" % [name, Loc.t("quality_" + ["LOW", "MEDIUM", "HIGH"][profile.tier])]
	return name
