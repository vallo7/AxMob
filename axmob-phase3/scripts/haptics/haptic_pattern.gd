class_name HapticPattern
extends RefCounted
## Un motif de vibration : une suite d'impulsions (durée ms, amplitude 0..1, pause ms après).

enum Priority { LOW, NORMAL, HIGH, CRITICAL }

var id: StringName
var priority: Priority
## Délai minimal (ms) entre deux déclenchements de CE motif.
var cooldown_ms: int
var pulses: Array[Vector3] = []


func _init(
	p_id: StringName, p_priority: Priority, p_cooldown_ms: int, p_pulses: Array[Vector3]
) -> void:
	id = p_id
	priority = p_priority
	cooldown_ms = p_cooldown_ms
	pulses = p_pulses


## Durée totale (ms) du motif, pauses comprises (hors durée minimale appliquée au jeu).
func total_ms() -> int:
	var total: float = 0.0
	for p: Vector3 in pulses:
		total += p.x + p.z
	return roundi(total)


func vibration_ms() -> int:
	var total: float = 0.0
	for p: Vector3 in pulses:
		total += p.x
	return roundi(total)
