class_name DoublePress
extends RefCounted
## « Appuyez encore pour quitter » : la 2e pression dans la fenêtre confirme.

var window_s: float
var _last: float = -INF


func _init(p_window_s: float = 2.0) -> void:
	window_s = p_window_s


## `now` en secondes. Retourne vrai si c'est la confirmation (et réarme).
func press(now: float) -> bool:
	if now - _last <= window_s:
		_last = -INF
		return true
	_last = now
	return false
