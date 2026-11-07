class_name CombatWindow
extends RefCounted
## Fenêtre d'activation du combat (plan §5.1).
## Le cooldown limite la fréquence d'activation, pas la cadence de tir.
## Chaque activation prolonge (sans empiler) la fenêtre jusqu'à now + duration.

var duration: float
var cooldown: float
var window_end: float = -1.0
var _next_allowed: float = -1.0


func _init(p_duration: float = 2.0, p_cooldown: float = 0.5) -> void:
	duration = p_duration
	cooldown = p_cooldown


func try_activate(now: float) -> bool:
	if now < _next_allowed:
		return false
	_next_allowed = now + cooldown
	window_end = now + duration
	return true


func is_active(now: float) -> bool:
	return now < window_end


func remaining(now: float) -> float:
	return maxf(window_end - now, 0.0)


func reset() -> void:
	window_end = -1.0
	_next_allowed = -1.0
