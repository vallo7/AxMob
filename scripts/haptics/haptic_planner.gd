class_name HapticPlanner
extends RefCounted
## Planificateur de vibrations (logique pure, testable) : décide quels motifs jouer et quand.
## Règles : réglage désactivé = rien ; délai minimal par motif ; un motif en cours n'est
## interrompu que par une priorité STRICTEMENT supérieure ; plafond de vibration cumulée
## (sauf HIGH/CRITICAL) ; amplitude finale bornée, impulsions trop faibles ignorées.
## `pump(now)` rend les impulsions arrivées à échéance : (durée ms, amplitude).

const BUDGET_WINDOW_MS: float = 5000.0

var config: HapticsConfig
## Facteur du niveau choisi par le joueur (UserSettings.HAPTICS_LEVELS) ; 0 = désactivé.
var user_factor: float = 1.0

var _queue: Array[Vector3] = []  # (début ms, durée ms, amplitude)
var _busy_until: float = -1.0
var _busy_priority: int = -1
var _last_played: Dictionary = {}  # id -> ms
var _budget_log: Array[Vector2] = []  # (instant ms, durée vibrée ms)


func _init(p_config: HapticsConfig) -> void:
	config = p_config


func enabled() -> bool:
	return user_factor > 0.0 and config.master_intensity > 0.0


## Demande un motif ; retourne vrai s'il est accepté (au moins planifié).
func request(pattern: HapticPattern, scale: float, now_ms: float) -> bool:
	if not enabled() or pattern.pulses.is_empty():
		return false
	if (
		_last_played.has(pattern.id)
		and now_ms < (_last_played[pattern.id] as float) + float(pattern.cooldown_ms)
	):
		return false
	var busy: bool = now_ms < _busy_until
	if busy and int(pattern.priority) <= _busy_priority:
		return false
	var urgent: bool = pattern.priority >= HapticPattern.Priority.HIGH
	if (
		not urgent
		and _budget_used(now_ms) + float(pattern.vibration_ms()) > float(config.budget_ms_per_5s)
	):
		return false
	if busy:
		_queue.clear()  # le motif prioritaire remplace ce qui n'a pas encore démarré
	var gain: float = scale * config.master_intensity * user_factor
	var t: float = now_ms
	var vibrated: float = 0.0
	for pulse: Vector3 in pattern.pulses:
		var duration: float = maxf(pulse.x, float(config.min_pulse_ms))
		var amplitude: float = clampf(pulse.y * gain, 0.0, 1.0)
		if amplitude >= config.min_amplitude:
			_queue.append(Vector3(t, duration, amplitude))
			vibrated += duration
		t += duration + pulse.z
	if vibrated <= 0.0:
		return false
	_busy_until = t
	_busy_priority = int(pattern.priority)
	_last_played[pattern.id] = now_ms
	_budget_log.append(Vector2(now_ms, vibrated))
	return true


## Impulsions à jouer maintenant : Vector2(durée ms, amplitude).
func pump(now_ms: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var i: int = 0
	while i < _queue.size():
		if _queue[i].x <= now_ms:
			out.append(Vector2(_queue[i].y, _queue[i].z))
			_queue.remove_at(i)
		else:
			i += 1
	if _queue.is_empty() and now_ms >= _busy_until:
		_busy_priority = -1
	return out


## Abandonne ce qui n'a pas démarré (pause, retour au menu).
func clear() -> void:
	_queue.clear()
	_busy_until = -1.0
	_busy_priority = -1


## Efface aussi les délais, la priorité en cours et le plafond (début de partie, tests).
func reset() -> void:
	clear()
	_last_played.clear()
	_budget_log.clear()


func pending() -> int:
	return _queue.size()


func _budget_used(now_ms: float) -> float:
	var total: float = 0.0
	var i: int = 0
	while i < _budget_log.size():
		if now_ms - _budget_log[i].x > BUDGET_WINDOW_MS:
			_budget_log.remove_at(i)
		else:
			total += _budget_log[i].y
			i += 1
	return total
