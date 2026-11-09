class_name QualityGovernor
extends RefCounted
## Gouverneur de qualité : choisit le profil graphique (Bas / Moyen / Élevé) à partir des durées
## d'image mesurées, avec hystérésis. Logique PURE (aucun accès au moteur) : on lui donne les
## durées, il répond par un changement de profil ou rien. Testée avec des durées simulées.
##
## Principes :
##  - On DESCEND vite (deux fenêtres de 2,5 s consécutives trop lentes, ou une fenêtre très lente) :
##    un jeu qui saccade est pire qu'un jeu un peu moins joli.
##  - On MONTE lentement et prudemment : l'écran limite à 60 i/s, une image « à l'heure » ne prouve
##    pas qu'il reste de la marge. Après 12 s sans aucun raté, on SONDE le profil du dessus ; si la
##    fenêtre suivante est mauvaise, on revient et on interdit ce profil pour la session (plafond).
##  - Après tout changement : période de stabilisation (les allocations du moteur faussent les
##    mesures) ; les images > 250 ms (chargement, mise en arrière-plan) sont ignorées.

const WINDOW: float = 2.5
const WARMUP: float = 2.0
const SETTLE: float = 3.0
const SLOW_FRAME_MS: float = 20.0
const VERY_SLOW_FRAME_MS: float = 27.0
const JANK_FRAME_MS: float = 28.0
const JANK_RATIO_BAD: float = 0.10
const GOOD_FRAME_MS: float = 17.6
const JANK_RATIO_GOOD: float = 0.01
const GOOD_BEFORE_PROBE: float = 12.0
const IGNORE_ABOVE_S: float = 0.25

var tier: QualityProfile.Tier = QualityProfile.Tier.MEDIUM
## Profil maximal autorisé cette session (abaissé quand une sonde échoue).
var ceiling: QualityProfile.Tier = QualityProfile.Tier.HIGH
var enabled: bool = true

var _frames: int = 0
var _sum: float = 0.0
var _jank: int = 0
var _window_time: float = 0.0
var _hold: float = WARMUP
var _bad_streak: int = 0
var _good_time: float = 0.0
var _probing: bool = false


func _init(start_tier: QualityProfile.Tier = QualityProfile.Tier.MEDIUM) -> void:
	tier = start_tier


## Redémarre les mesures (début de partie, retour de pause) sans changer de profil.
func reset(warmup: float = WARMUP) -> void:
	_frames = 0
	_sum = 0.0
	_jank = 0
	_window_time = 0.0
	_hold = warmup
	_bad_streak = 0
	_good_time = 0.0
	_probing = false


## Donne la durée d'une image (secondes). Renvoie le nouveau profil, ou -1 si inchangé.
func feed(delta: float) -> int:
	if not enabled or delta <= 0.0 or delta > IGNORE_ABOVE_S:
		return -1
	if _hold > 0.0:
		_hold -= delta
		return -1
	_frames += 1
	_sum += delta
	_window_time += delta
	if delta * 1000.0 > JANK_FRAME_MS:
		_jank += 1
	if _window_time < WINDOW:
		return -1
	return _end_window()


func _end_window() -> int:
	var avg_ms: float = _sum / float(maxi(_frames, 1)) * 1000.0
	var jank_ratio: float = float(_jank) / float(maxi(_frames, 1))
	var window: float = _window_time
	_frames = 0
	_sum = 0.0
	_jank = 0
	_window_time = 0.0
	var bad: bool = avg_ms > SLOW_FRAME_MS or jank_ratio > JANK_RATIO_BAD
	var very_bad: bool = avg_ms > VERY_SLOW_FRAME_MS
	if bad:
		_good_time = 0.0
		_bad_streak += 1
		if _probing:
			# La sonde échoue : retour au profil précédent, plafond abaissé.
			_probing = false
			ceiling = maxi(tier - 1, QualityProfile.Tier.LOW) as QualityProfile.Tier
			return _change(tier - 1)
		if (very_bad or _bad_streak >= 2) and tier > QualityProfile.Tier.LOW:
			return _change(tier - 1)
		return -1
	_bad_streak = 0
	var good: bool = avg_ms <= GOOD_FRAME_MS and jank_ratio <= JANK_RATIO_GOOD
	if good:
		_good_time += window
		if _probing and _good_time >= WINDOW:
			_probing = false
		if _good_time >= GOOD_BEFORE_PROBE and tier < ceiling:
			var up: int = _change(tier + 1)
			_probing = true
			return up
	else:
		_good_time = 0.0
	return -1


func _change(new_tier: int) -> int:
	var t: QualityProfile.Tier = QualityProfile.clamp_tier(new_tier)
	if t == tier:
		return -1
	tier = t
	reset(SETTLE)
	return int(t)
