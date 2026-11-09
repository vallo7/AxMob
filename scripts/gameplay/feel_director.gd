class_name FeelDirector
extends RefCounted
## Arrêt sur image (hit-stop) et ralenti. Décide du facteur de temps de la simulation à partir de
## demandes (EventBus.time_punch, impacts de zone, mort du boss, mort du joueur). Les durées sont
## en secondes RÉELLES (le hit-stop ne dure pas plus longtemps quand il ralentit le temps).
## Logique pure : `advance(delta_reel)` renvoie le facteur à appliquer au pas de simulation.

const SPLASH_COOLDOWN: float = 0.35

var _feel: FeelConfig
var _hold_left: float = 0.0
var _hold_scale: float = 1.0
var _slow_left: float = 0.0
var _slow_scale: float = 1.0
## Temps réel écoulé depuis le dernier arrêt sur image de zone (évite l'effet « hachure »).
var _since_splash: float = 10.0


func _init(feel: FeelConfig) -> void:
	_feel = feel


func bind_events() -> void:
	EventBus.time_punch.connect(request)
	EventBus.axe_splash_resolved.connect(_on_splash_resolved)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_died.connect(func() -> void: request(0.8, 0.4))


## Demande un ralenti : `duration` s réelles à l'échelle `scale` (0.05 = quasi figé).
## Une demande plus forte ou plus longue remplace celle en cours.
func request(duration: float, scale: float) -> void:
	if duration <= 0.0:
		return
	if scale <= 0.15:
		if duration >= _hold_left or scale < _hold_scale:
			_hold_left = maxf(duration, _hold_left)
			_hold_scale = scale
	elif duration >= _slow_left or scale < _slow_scale:
		_slow_left = maxf(duration, _slow_left)
		_slow_scale = scale


func is_active() -> bool:
	return _hold_left > 0.0 or _slow_left > 0.0


## Fait avancer les minuteurs (temps réel) et renvoie le facteur de temps courant (0..1).
func advance(real_delta: float) -> float:
	_since_splash += real_delta
	var scale: float = 1.0
	if _hold_left > 0.0:
		scale = minf(scale, _hold_scale)
		_hold_left = maxf(_hold_left - real_delta, 0.0)
	if _slow_left > 0.0:
		scale = minf(scale, _slow_scale)
		_slow_left = maxf(_slow_left - real_delta, 0.0)
	if _hold_left <= 0.0:
		_hold_scale = 1.0
	if _slow_left <= 0.0:
		_slow_scale = 1.0
	return scale


func _on_splash_resolved(_pos: Vector2, _radius: float, hits: int) -> void:
	# +1 : l'ennemi touché en direct compte aussi.
	if hits + 1 >= _feel.hitstop_min_hits and _since_splash >= SPLASH_COOLDOWN:
		_since_splash = 0.0
		request(_feel.hitstop_splash, 0.04)


func _on_boss_defeated(_id: int, _reward: int) -> void:
	request(_feel.hitstop_boss_death, 0.03)
	request(_feel.slowmo_boss_death_time, _feel.slowmo_boss_death_scale)
